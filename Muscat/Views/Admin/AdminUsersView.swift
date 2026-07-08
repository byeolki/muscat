import MuscatKit
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct AdminUsersView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var users: [AdminUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isGeneratingInvite = false
    @State private var generatedInvite: String?

    var body: some View {
        List {
            Section {
                Button {
                    Task { await generateInvite() }
                } label: {
                    if isGeneratingInvite {
                        ProgressView()
                    } else {
                        Label("Generate Invite Code", systemImage: "person.badge.plus")
                    }
                }
                .disabled(isGeneratingInvite)

                if let generatedInvite {
                    HStack {
                        Text(generatedInvite)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        #if os(iOS)
                        Button {
                            UIPasteboard.general.string = generatedInvite
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        #else
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(generatedInvite, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        #endif
                    }
                }
            }

            Section("Users (\(users.count))") {
                ForEach(users) { user in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(user.name)
                            if user.role == .admin {
                                Text("ADMIN")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("User Management")
        .overlay {
            if isLoading && users.isEmpty {
                ProgressView()
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            users = try await appEnvironment.apiClient.fetchAdminUsers()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func generateInvite() async {
        isGeneratingInvite = true
        errorMessage = nil
        defer { isGeneratingInvite = false }
        do {
            generatedInvite = try await appEnvironment.apiClient.createInvite()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
