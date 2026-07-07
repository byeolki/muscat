import PodoKit
import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            List {
                if let user = authStore.currentUser {
                    Section("Account") {
                        LabeledContent("Name", value: user.name)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: user.role == .admin ? "Admin" : "User")
                    }
                }
                Section {
                    NavigationLink("My Files") {
                        MyFilesView()
                    }
                    NavigationLink("Radio Station") {
                        RadioView()
                    }
                    if authStore.currentUser?.role == .admin {
                        NavigationLink("Admin") {
                            AdminView()
                        }
                    }
                }
                Section {
                    Button("Log Out", role: .destructive) {
                        Task { await authStore.logout() }
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}
