import MuscatKit
import SwiftUI

struct AdminView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var updateStatus: UpdateStatus?

    var body: some View {
        List {
            if let updateStatus, updateStatus.updateAvailable, let latest = updateStatus.latest {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Color.appAccent)
                            Text("Podo \(latest) is available")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appTextPrimary)
                        }
                        Text("This server is running \(updateStatus.current). Update it from the host, then pull to refresh here.")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                        if let releaseUrl = updateStatus.releaseUrl, let url = URL(string: releaseUrl) {
                            Link("Release notes", destination: url)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(14)
                    .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            NavigationLink {
                AdminUsersView()
            } label: {
                row(icon: "person.2", title: "User Management")
            }
            .themedRow()

            NavigationLink {
                AdminStorageView()
            } label: {
                row(icon: "internaldrive", title: "Storage Usage")
            }
            .themedRow()

            NavigationLink {
                AdminLibraryView()
            } label: {
                row(icon: "folder.badge.gearshape", title: "Library Scan")
            }
            .themedRow()
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle("Admin")
        .refreshable { await loadUpdateStatus() }
        .task { await loadUpdateStatus() }
    }

    /// Quiet by design: a failed check (no outbound network, checks disabled)
    /// leaves the banner hidden rather than showing an error on an admin screen
    /// that has nothing to do with updates.
    private func loadUpdateStatus() async {
        updateStatus = try? await appEnvironment.apiClient.fetchUpdateStatus()
    }

    private func row(icon: String, title: String) -> some View {
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
