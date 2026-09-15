import Foundation

/// Thin, hand-written REST client for the Podo server. Every request/response body is
/// snake_case JSON (see `JSONDecoder.podo` / `JSONEncoder.podo`). Handles automatic
/// access-token refresh on 401: concurrent 401s coalesce onto a single in-flight
/// refresh via the `refreshTask` actor property, and each request is retried at most once.
public actor APIClient {
    private var baseURLValue: URL
    private let session: URLSession
    private let tokenStore: TokenStoring
    private var refreshTask: Task<TokenPair, Error>?

    /// Fired when refresh itself fails (refresh token expired/revoked) — the app should
    /// drop back to the login screen. Plain `@Sendable` closure instead of a delegate
    /// protocol so callers don't need to reason about actor/Sendable conformance.
    var onUnauthenticated: (@Sendable () -> Void)?

    init(baseURL: URL, tokenStore: TokenStoring, session: URLSession = .shared) {
        self.baseURLValue = baseURL
        self.tokenStore = tokenStore
        self.session = session
    }

    public var baseURL: URL { baseURLValue }

    public func updateBaseURL(_ url: URL) {
        baseURLValue = url
    }

    // MARK: - Controlled access to the token store for `APIClient+Auth`

    func tokenStoreSave(_ tokens: TokenPair) {
        tokenStore.save(tokens)
    }

    func tokenStoreClear() {
        tokenStore.clear()
    }

    func currentRefreshToken() -> String? {
        tokenStore.currentTokens()?.refreshToken
    }

    func setOnUnauthenticated(_ handler: @escaping @Sendable () -> Void) {
        onUnauthenticated = handler
    }

    // MARK: - Core request plumbing

    private func buildRequest(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String? = "application/json",
        authenticated: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURLValue.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIClientError.invalidServerURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw APIClientError.invalidServerURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let bodyData {
            request.httpBody = bodyData
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        if authenticated, let token = tokenStore.currentTokens()?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// Runs one request, transparently refreshing + retrying once on a 401.
    /// Returns the raw response body data for 2xx responses; throws otherwise.
    private func executeWithAuthRetry(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?,
        contentType: String? = "application/json",
        authenticated: Bool,
        allowRetry: Bool = true
    ) async throws -> Data {
        let request = try buildRequest(
            method: method, path: path, query: query, bodyData: bodyData,
            contentType: contentType, authenticated: authenticated
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIClientError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIClientError.unknown }

        if http.statusCode == 401, authenticated, allowRetry {
            do {
                _ = try await refreshTokensIfNeeded()
            } catch {
                tokenStore.clear()
                onUnauthenticated?()
                throw APIClientError.notAuthenticated
            }
            return try await executeWithAuthRetry(
                method: method, path: path, query: query, bodyData: bodyData, contentType: contentType,
                authenticated: authenticated, allowRetry: false
            )
        }

        guard (200..<300).contains(http.statusCode) else {
            if let body = try? JSONDecoder.podo.decode(ErrorResponseBody.self, from: data) {
                throw APIClientError.server(statusCode: http.statusCode, message: body.message)
            }
            throw APIClientError.server(
                statusCode: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }

        return data
    }

    /// Coalesces concurrent refresh attempts onto one in-flight task.
    @discardableResult
    private func refreshTokensIfNeeded() async throws -> TokenPair {
        if let existingTask = refreshTask {
            return try await existingTask.value
        }
        guard let refreshToken = tokenStore.currentTokens()?.refreshToken else {
            throw APIClientError.notAuthenticated
        }

        let task = Task<TokenPair, Error> {
            let bodyData = try JSONEncoder.podo.encode(RefreshRequest(refreshToken: refreshToken))
            let request = try self.buildRequest(
                method: "POST", path: "api/v1/auth/refresh", query: [], bodyData: bodyData, authenticated: false
            )
            let (data, response) = try await self.session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw APIClientError.notAuthenticated
            }
            let tokens = try JSONDecoder.podo.decode(TokenPair.self, from: data)
            self.tokenStore.save(tokens)
            return tokens
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    // MARK: - Typed entry points used by the `APIClient+*` extensions

    func send<Response: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws -> Response {
        let bodyData = try body.map { try JSONEncoder.podo.encode($0) }
        let data = try await executeWithAuthRetry(
            method: method, path: path, query: query, bodyData: bodyData, authenticated: authenticated
        )
        do {
            return try JSONDecoder.podo.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    func sendNoContent(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Encodable? = nil,
        authenticated: Bool = true
    ) async throws {
        let bodyData = try body.map { try JSONEncoder.podo.encode($0) }
        _ = try await executeWithAuthRetry(
            method: method, path: path, query: query, bodyData: bodyData, authenticated: authenticated
        )
    }

    /// Single-file `multipart/form-data` upload (playlist covers, track uploads).
    func sendMultipart<Response: Decodable>(
        method: String = "POST",
        path: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        authenticated: Bool = true
    ) async throws -> Response {
        let boundary = "Muscat-\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(
            Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".utf8)
        )
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        let data = try await executeWithAuthRetry(
            method: method, path: path, query: [], bodyData: body,
            contentType: "multipart/form-data; boundary=\(boundary)", authenticated: authenticated
        )
        do {
            return try JSONDecoder.podo.decode(Response.self, from: data)
        } catch {
            throw APIClientError.decoding(error)
        }
    }

    /// Builds an authenticated URL for things that can't set headers (AVPlayer, image
    /// views): appends `?token=<access_token>` per the server's guard fallback.
    /// Seconds of remaining life below which a token is refreshed before use.
    ///
    /// A URL handed to `AVPlayer` carries its token in the query string and is used
    /// for as long as the item is open, with no way for this client to intervene —
    /// so it has to leave here valid. An access token lives fifteen minutes, which
    /// is why playback used to stop partway through a listening session with
    /// NSURLErrorUserAuthenticationRequired: the next track was requested with a
    /// token that had quietly expired.
    private static let refreshMargin: TimeInterval = 120

    /// The access token, refreshed first if it is about to expire.
    ///
    /// Returns nil when the session is genuinely over, having cleared it and said
    /// so. Handing back the expired token instead — which is what falling back
    /// quietly amounts to — produces a player that answers 401 to everything, for
    /// ever, with nothing on screen explaining why and no way out but deleting the
    /// app.
    func freshAccessToken() async -> String? {
        guard let token = tokenStore.currentTokens()?.accessToken else { return nil }
        guard let expiry = Self.expiry(ofJWT: token) else { return token }
        guard expiry.timeIntervalSinceNow < Self.refreshMargin else { return token }
        do {
            return try await refreshTokensIfNeeded().accessToken
        } catch {
            tokenStore.clear()
            onUnauthenticated?()
            return nil
        }
    }

    /// The `exp` claim, read without verifying the signature — this is deciding
    /// when to refresh, not whether to trust it; the server does that.
    static func expiry(ofJWT token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// A URL with the query given and nothing added — for callers that have already
    /// attached a token they refreshed themselves.
    func unauthenticatedURL(path: String, query: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(
            url: baseURLValue.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { return nil }
        components.queryItems = query.isEmpty ? nil : query
        return components.url
    }

    /// Builds a URL with whatever token is stored. For anything long-lived, refresh
    /// first — see `freshAccessToken`.
    func authenticatedURL(path: String, query: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(
            url: baseURLValue.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { return nil }
        var items = query
        if let token = tokenStore.currentTokens()?.accessToken {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }
}
