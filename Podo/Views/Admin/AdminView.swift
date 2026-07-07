import PodoKit
import SwiftUI

struct AdminView: View {
    var body: some View {
        List {
            NavigationLink("사용자 관리") { AdminUsersView() }
            NavigationLink("저장소 사용량") { AdminStorageView() }
            NavigationLink("라이브러리 스캔") { AdminLibraryView() }
        }
        .navigationTitle("관리자")
    }
}
