import MuscatKit
import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var authStore

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !authStore.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("Podo")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.appAccent)
                Text("Your music, your server.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.bottom, 40)

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .themedField()

                SecureField("Password", text: $password)
                    .themedField()

                if let error = authStore.lastErrorMessage {
                    ErrorBanner(message: error)
                }

                Button {
                    Task { await authStore.login(email: email, password: password) }
                } label: {
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
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .themedScreen()
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
}
