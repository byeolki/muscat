import PodoKit
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

struct EditPlaylistView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let playlist: PlaylistDetail
    let onSaved: () async -> Void

    @State private var name: String
    @State private var description: String
    @State private var isPublic: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    #endif
    @State private var showFileImporter = false

    init(playlist: PlaylistDetail, onSaved: @escaping () async -> Void) {
        self.playlist = playlist
        self.onSaved = onSaved
        _name = State(initialValue: playlist.name)
        _description = State(initialValue: playlist.description ?? "")
        _isPublic = State(initialValue: playlist.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("정보") {
                    TextField("이름", text: $name)
                    TextField("설명", text: $description)
                    Toggle("공개 플레이리스트", isOn: $isPublic)
                }

                Section("커버 이미지") {
                    #if os(iOS)
                    PhotosPicker("사진 보관함에서 선택", selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task { await uploadPickedPhoto(newValue) }
                        }
                    #else
                    Button("이미지 파일 선택") { showFileImporter = true }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.jpeg, .png, .webP]) { result in
                            Task { await uploadImportedFile(result) }
                        }
                    #endif
                    Button("커버 이미지 삭제", role: .destructive) {
                        Task { await deleteCover() }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("플레이리스트 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("저장")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await appEnvironment.apiClient.updatePlaylist(
                id: playlist.id,
                name: name,
                description: description.isEmpty ? nil : description,
                isPublic: isPublic
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteCover() async {
        do {
            try await appEnvironment.apiClient.deletePlaylistCover(playlistId: playlist.id)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    #if os(iOS)
    private func uploadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await uploadCoverData(data, filename: "cover.jpg", mimeType: "image/jpeg")
    }
    #else
    private func uploadImportedFile(_ result: Result<URL, Error>) async {
        guard let url = try? result.get() else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let mimeType = mimeType(for: url.pathExtension)
        await uploadCoverData(data, filename: url.lastPathComponent, mimeType: mimeType)
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "png": return "image/png"
        case "webp": return "image/webp"
        default: return "image/jpeg"
        }
    }
    #endif

    private func uploadCoverData(_ data: Data, filename: String, mimeType: String) async {
        do {
            _ = try await appEnvironment.apiClient.uploadPlaylistCover(
                playlistId: playlist.id, imageData: data, filename: filename, mimeType: mimeType
            )
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
