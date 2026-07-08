import MuscatKit
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
                Section("Info") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Public Playlist", isOn: $isPublic)
                }

                Section("Cover Image") {
                    #if os(iOS)
                    PhotosPicker("Choose from Photo Library", selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task { await uploadPickedPhoto(newValue) }
                        }
                    #else
                    Button("Choose Image File") { showFileImporter = true }
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.jpeg, .png, .webP]) { result in
                            Task { await uploadImportedFile(result) }
                        }
                    #endif
                    Button("Remove Cover Image", role: .destructive) {
                        Task { await deleteCover() }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
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
