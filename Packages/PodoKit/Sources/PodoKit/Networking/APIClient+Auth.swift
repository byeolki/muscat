import Foundation

extension APIClient {
    func login(email: String, password: String) async throws -> MeResponse {
        let tokens: TokenPair = try await send(
            method: "POST", path: "api/v1/auth/login",
            body: LoginRequest(email: email, password: password),
            authenticated: false
        )
        tokenStoreSave(tokens)
        return try await fetchMe()
    }

    func register(name: String, email: String, password: String, inviteToken: String) async throws -> MeResponse {
        let tokens: TokenPair = try await send(
            method: "POST", path: "api/v1/auth/register",
            body: RegisterRequest(name: name, email: email, password: password, inviteToken: inviteToken),
            authenticated: false
        )
        tokenStoreSave(tokens)
        return try await fetchMe()
    }

    /// Best-effort server-side revocation; local session is always cleared regardless.
    func logout() async {
        if let refreshToken = currentRefreshToken() {
            try? await sendNoContent(
                method: "POST", path: "api/v1/auth/logout",
                body: LogoutRequest(refreshToken: refreshToken),
                authenticated: false
            )
        }
        tokenStoreClear()
    }

    func fetchMe() async throws -> MeResponse {
        try await send(method: "GET", path: "api/v1/auth/me")
    }

    func updateMe(name: String? = nil, currentPassword: String? = nil, newPassword: String? = nil) async throws -> MeResponse {
        try await send(
            method: "PATCH", path: "api/v1/auth/me",
            body: UpdateMeRequest(name: name, currentPassword: currentPassword, newPassword: newPassword)
        )
    }

    func hasStoredSession() -> Bool {
        currentRefreshToken() != nil
    }

    /// Admin-only. Generates a one-time invite token for `POST /auth/register`.
    public func createInvite() async throws -> String {
        let response: InviteResponse = try await send(method: "POST", path: "api/v1/auth/invite")
        return response.inviteToken
    }
}
