import Foundation
import Observation

/// Composition root: builds and owns every store/service for the app's lifetime.
/// Inject into SwiftUI with `.environment(appEnvironment)` from the App entry point,
/// and read individual stores with `@Environment(AuthStore.self)` /
/// `@Environment(PlayerStore.self)` (inject those too, see `MuscatApp`).
/// Marked `@Observable` solely so it can ride the modern `@Environment(Type.self)`
/// injection API — none of its own `let` properties need fine-grained tracking.
@Observable
@MainActor
public final class AppEnvironment {
    public let serverConfig: ServerConfig
    public let apiClient: APIClient
    public let authStore: AuthStore
    public let playerStore: PlayerStore

    public init() {
        let serverConfig = ServerConfig()
        let placeholderURL = URL(string: "https://localhost")!
        let client = APIClient(baseURL: serverConfig.baseURL ?? placeholderURL, tokenStore: KeychainStore())
        self.serverConfig = serverConfig
        self.apiClient = client
        self.authStore = AuthStore(apiClient: client)
        self.playerStore = PlayerStore(apiClient: client)
    }

    /// Persists the server URL and points the API client at it. Call after
    /// `verifyServerURL` succeeds.
    public func saveServerURL(_ url: URL) async {
        serverConfig.baseURL = url
        await apiClient.updateBaseURL(url)
    }

    /// Validates a candidate server URL via `GET /health` (bare route, no `/api/v1`
    /// prefix, no auth) without persisting anything.
    public func verifyServerURL(_ url: URL) async -> Bool {
        var request = URLRequest(url: url.appendingPathComponent("health"))
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return false }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        guard let health = try? JSONDecoder.muscat.decode(HealthResponse.self, from: data) else { return false }
        return health.status.lowercased() == "ok"
    }
}
