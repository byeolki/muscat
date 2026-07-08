import MuscatKit
import SwiftUI

struct RegisterView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var inviteToken = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Info") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                Section("Invite Code") {
                    TextField("Invite code from your admin", text: $inviteToken)
                        .autocorrectionDisabled()
                }
                if let error = authStore.lastErrorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("Sign Up")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    registerButton
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    registerButton
                }
                #endif
            }
        }
    }

    private var registerButton: some View {
        Button {
            Task {
                await authStore.register(name: name, email: email, password: password, inviteToken: inviteToken)
                if authStore.isAuthenticated {
                    dismiss()
                }
            }
        } label: {
            if authStore.isLoading {
                ProgressView()
            } else {
                Text("Sign Up")
            }
        }
        .disabled(name.isEmpty || email.isEmpty || password.isEmpty || inviteToken.isEmpty || authStore.isLoading)
    }
}
