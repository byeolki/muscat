import PodoKit
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
                Section("계정 정보") {
                    TextField("이름", text: $name)
                    TextField("이메일", text: $email)
                        #if os(iOS)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("비밀번호", text: $password)
                }
                Section("초대코드") {
                    TextField("관리자에게 받은 초대코드", text: $inviteToken)
                        .autocorrectionDisabled()
                }
                if let error = authStore.lastErrorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .navigationTitle("회원가입")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    registerButton
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
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
                Text("가입")
            }
        }
        .disabled(name.isEmpty || email.isEmpty || password.isEmpty || inviteToken.isEmpty || authStore.isLoading)
    }
}
