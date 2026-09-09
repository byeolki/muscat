import MuscatKit
import SwiftUI

/// Top-level flow: server onboarding → login/register → main library + player.
struct RootView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(AuthStore.self) private var authStore

    @State private var isServerConfigured = false

    var body: some View {
        Group {
            if !isServerConfigured {
                ServerURLView(onConfigured: { isServerConfigured = true })
            } else if authStore.isAuthenticated {
                MainTabView()
            } else {
                LoginView(onChangeServer: changeServer)
            }
        }
        .themedScreen()
        .task {
            isServerConfigured = appEnvironment.serverConfig.isConfigured
            if isServerConfigured {
                await authStore.restoreSession()
            }
        }
    }

    /// Drops the stored server address and returns to onboarding. Without this a
    /// wrong address entered once could only be undone by reinstalling.
    private func changeServer() {
        appEnvironment.serverConfig.clear()
        isServerConfigured = false
    }
}
