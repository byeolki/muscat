import PodoKit
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
                LoginView()
            }
        }
        .task {
            isServerConfigured = appEnvironment.serverConfig.isConfigured
            if isServerConfigured {
                await authStore.restoreSession()
            }
        }
    }
}
