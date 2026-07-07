import Foundation
import Observation

/// Single source of truth for authentication state, observed by SwiftUI via the
/// `Observation` framework (`.environment(authStore)` / `@Environment(AuthStore.self)`).
@Observable
@MainActor
public final class AuthStore {
    public private(set) var currentUser: MeResponse?
    public private(set) var isAuthenticated = false
    public private(set) var isLoading = false
    public private(set) var lastErrorMessage: String?

    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        let handler: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in self?.handleForcedLogout() }
        }
        Task { await apiClient.setOnUnauthenticated(handler) }
    }

    /// Call once at app launch: if a session was persisted in the Keychain, validate it
    /// against the server before showing the main UI.
    public func restoreSession() async {
        guard await apiClient.hasStoredSession() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            currentUser = try await apiClient.fetchMe()
            isAuthenticated = true
        } catch {
            handleForcedLogout()
        }
    }

    public func login(email: String, password: String) async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        do {
            currentUser = try await apiClient.login(email: email, password: password)
            isAuthenticated = true
        } catch {
            lastErrorMessage = Self.message(for: error)
        }
    }

    public func register(name: String, email: String, password: String, inviteToken: String) async {
        isLoading = true
        lastErrorMessage = nil
        defer { isLoading = false }
        do {
            currentUser = try await apiClient.register(
                name: name, email: email, password: password, inviteToken: inviteToken
            )
            isAuthenticated = true
        } catch {
            lastErrorMessage = Self.message(for: error)
        }
    }

    public func logout() async {
        await apiClient.logout()
        currentUser = nil
        isAuthenticated = false
    }

    private func handleForcedLogout() {
        currentUser = nil
        isAuthenticated = false
        lastErrorMessage = "Your session expired. Please log in again."
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
