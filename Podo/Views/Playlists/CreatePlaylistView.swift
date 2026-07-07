import PodoKit
import SwiftUI

struct CreatePlaylistView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let onCreated: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("정보") {
                    TextField("이름", text: $name)
                    TextField("설명 (선택)", text: $description)
                    Toggle("공개 플레이리스트", isOn: $isPublic)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("새 플레이리스트")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("만들기")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await appEnvironment.apiClient.createPlaylist(
                name: name,
                description: description.isEmpty ? nil : description,
                isPublic: isPublic
            )
            await onCreated()
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
