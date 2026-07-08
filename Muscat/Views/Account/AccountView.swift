import MuscatKit
import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            List {
                if let user = authStore.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                Text(String(user.name.prefix(1)).uppercased())
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.appAccent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundStyle(Color.appTextPrimary)
                                    if user.role == .admin {
                                        BadgeLabel(text: "ADMIN")
                                    }
                                }
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .themedRow()
                    }
                }

                Section {
                    NavigationLink {
                        MyFilesView()
                    } label: {
                        menuRow(icon: "tray.and.arrow.up", title: "My Files")
                    }
                    .themedRow()

                    NavigationLink {
                        RadioView()
                    } label: {
                        menuRow(icon: "dot.radiowaves.left.and.right", title: "Radio Station")
                    }
                    .themedRow()

                    if authStore.currentUser?.role == .admin {
                        NavigationLink {
                            AdminView()
                        } label: {
                            menuRow(icon: "gearshape.2", title: "Admin")
                        }
                        .themedRow()
                    }
                }

                Section {
                    Button {
                        Task { await authStore.logout() }
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(Color.appDanger)
                            .frame(maxWidth: .infinity)
                    }
                    .themedRow()
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Account")
        }
    }

    private func menuRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.appAccent)
                .frame(width: 30)
            Text(title)
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.vertical, 2)
    }
}
