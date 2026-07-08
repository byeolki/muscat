import MuscatKit
import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var inviteToken = ""

    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && !inviteToken.isEmpty && !authStore.isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Account")
                        TextField("Name", text: $name)
                            .themedField()
                        TextField("Email", text: $email)
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .themedField()
                        SecureField("Password", text: $password)
                            .themedField()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Invite code")
                        TextField("Code from your admin", text: $inviteToken)
                            .autocorrectionDisabled()
                            .themedField()
                        Text("Registration is invite-only. Ask your server admin for a code.")
                            .font(.caption)
                            .foregroundStyle(Color.appTextTertiary)
                    }

                    if let error = authStore.lastErrorMessage {
                        ErrorBanner(message: error)
                    }

                    Button {
                        Task {
                            await authStore.register(
                                name: name, email: email, password: password, inviteToken: inviteToken
                            )
                            if authStore.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        if authStore.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle("Sign Up")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
    }
}
