import PodoKit
import SwiftUI

@main
struct PodoApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .environment(appEnvironment.authStore)
                .environment(appEnvironment.playerStore)
        }
    }
}
