import MuscatKit
import SwiftUI

struct AdminView: View {
    var body: some View {
        List {
            NavigationLink("User Management") { AdminUsersView() }
            NavigationLink("Storage Usage") { AdminStorageView() }
            NavigationLink("Library Scan") { AdminLibraryView() }
        }
        .navigationTitle("Admin")
    }
}
