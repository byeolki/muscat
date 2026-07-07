import PodoKit
import SwiftUI

struct ServerURLView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let onConfigured: () -> Void

    @State private var urlText = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text("Enter Your Podo Server Address")
                        .font(.title2.bold())
                    Text("Enter the address of your self-hosted Podo server.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("https://music.example.com", text: $urlText)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await verifyAndSave() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
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
