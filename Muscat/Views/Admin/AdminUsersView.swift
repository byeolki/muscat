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
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Generate Invite Code", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(AccentButtonStyle(fullWidth: true))
                .disabled(isGeneratingInvite)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                if let generatedInvite {
                    HStack {
                        Text(generatedInvite)
                            .font(.callout.monospaced())
                            .foregroundStyle(Color.appAccent)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            copyToClipboard(generatedInvite)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.appAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(users) { user in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.appSurfaceRaised)
                                .frame(width: 38, height: 38)
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(user.name)
                                    .font(.subheadline.weight(.medium))
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
                    .padding(.vertical, 2)
                    .themedRow()
                }
            } header: {
                Text("USERS (\(users.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextTertiary)
                    .kerning(0.8)
            }

            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle("User Management")
        .overlay {
            if isLoading && users.isEmpty {
                ProgressView().tint(Color.appAccent)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
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
