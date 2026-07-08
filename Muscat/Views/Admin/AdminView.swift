import MuscatKit
import SwiftUI

struct AdminView: View {
    var body: some View {
        List {
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
