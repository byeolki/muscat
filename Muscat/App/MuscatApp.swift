import MuscatKit
import SwiftUI

@main
struct MuscatApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .environment(appEnvironment.authStore)
                .environment(appEnvironment.playerStore)
                .preferredColorScheme(.dark)
                .tint(.appAccent)
        }
    }
}
