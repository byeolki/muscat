import PodoKit
import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        NavigationStack {
            List {
                if let user = authStore.currentUser {
                    Section("계정") {
                        LabeledContent("이름", value: user.name)
                        LabeledContent("이메일", value: user.email)
                        LabeledContent("역할", value: user.role == .admin ? "관리자" : "일반 사용자")
                    }
                }
                Section {
                    NavigationLink("내 파일") {
                        MyFilesView()
                    }
                    NavigationLink("라디오 스테이션") {
                        RadioView()
                    }
                    if authStore.currentUser?.role == .admin {
                        NavigationLink("관리자") {
                            AdminView()
                        }
                    }
                }
                Section {
                    Button("로그아웃", role: .destructive) {
                        Task { await authStore.logout() }
                    }
                }
            }
            .navigationTitle("계정")
        }
    }
}
