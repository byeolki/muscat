import MuscatKit
import SwiftUI

struct LoginView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(AuthStore.self) private var authStore

    /// Set when the user asks to point the app at a different server, so
    /// `RootView` can send them back to onboarding.
    let onChangeServer: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !authStore.isLoading
    }

    /// Host only — the full URL is noise at this size, and the host is the part
    /// that tells you which library you're about to open.
    private var serverHost: String {
        appEnvironment.serverConfig.baseURL?.host() ?? "your server"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image("AppMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    // This app is Muscat. Podo is the server it talks to — naming
                    // it "Podo" here made the client look like the server.
                    Text("Muscat")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    Text("Your Podo library, on this device.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .padding(.bottom, 36)

            VStack(spacing: 14) {
                TextField("", text: $email, prompt: Text("Email").foregroundStyle(Color.appTextTertiary))
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    #endif
                    .autocorrectionDisabled()
                    .themedField()

                SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Color.appTextTertiary))
                    #if os(iOS)
                    .textContentType(.password)
                    #endif
                    .themedField()
                    .onSubmit { submit() }

                if let error = authStore.lastErrorMessage {
                    ErrorBanner(message: error)
                }

                Button(action: submit) {
                    if authStore.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                    }
                }
                .buttonStyle(AccentButtonStyle(fullWidth: true))
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)

                Button {
                    showRegister = true
                } label: {
                    Text("Have an invite code? ")
                        .foregroundStyle(Color.appTextSecondary)
                    + Text("Sign up")
                        .foregroundStyle(Color.appAccent)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .padding(.top, 6)
            }
            .frame(maxWidth: 420)

            Spacer()

            // Which server this is about to sign into, and a way out of it —
            // otherwise a typo'd address during onboarding is unrecoverable
            // without deleting the app.
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.caption2)
                Text(serverHost)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("·")
                Button("Change", action: onChangeServer)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.appAccent)
            }
            .font(.footnote)
            .foregroundStyle(Color.appTextTertiary)
            .padding(.bottom, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .themedScreen()
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }

    private func submit() {
        guard canSubmit else { return }
        Task { await authStore.login(email: email, password: password) }
    }
}
