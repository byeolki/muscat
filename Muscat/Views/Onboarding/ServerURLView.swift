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
                Image("AppMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .accessibilityHidden(true)

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
                TextField("", text: $urlText, prompt: fieldPrompt("music.example.com"))
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .themedField()
                    .onSubmit { Task { await verifyAndSave() } }

                // The placeholder no longer shows a scheme, so say what happens
                // when it's left out rather than letting people guess.
                Text(verbatim: "https:// is assumed unless you type http://")
                    .font(.caption)
                    .foregroundStyle(Color.appTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, -6)

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
            }
            .frame(maxWidth: 420)

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
