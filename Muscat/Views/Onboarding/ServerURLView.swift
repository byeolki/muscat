import MuscatKit
import SwiftUI

struct ServerURLView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let onConfigured: () -> Void

    @State private var urlText = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "server.rack")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Color.appAccent)
                }

                Text("Connect to Podo")
                    .font(.title.bold())
                    .foregroundStyle(Color.appTextPrimary)

                Text("Enter the address of your self-hosted Podo server.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 36)

            VStack(spacing: 16) {
                TextField("https://music.example.com", text: $urlText)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .themedField()

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                Button {
                    Task { await verifyAndSave() }
                } label: {
                    if isChecking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(AccentButtonStyle(fullWidth: true))
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .opacity(urlText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .frame(maxWidth: 420)

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .themedScreen()
    }

    private func verifyAndSave() async {
        guard let url = ServerConfig.normalize(urlText) else {
            errorMessage = "Please enter a valid server address."
            return
        }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        guard await appEnvironment.verifyServerURL(url) else {
            errorMessage = "Could not connect to the server. Please check the address."
            return
        }
        await appEnvironment.saveServerURL(url)
        onConfigured()
    }
}
