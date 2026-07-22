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

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Info")
                        TextField("", text: $name, prompt: Text("Name").foregroundStyle(Color.appTextTertiary))
                            .themedField()
                        TextField("", text: $description, prompt: Text("Description").foregroundStyle(Color.appTextTertiary))
                            .themedField()
                        Toggle("Public Playlist", isOn: $isPublic)
                            .tint(Color.appAccent)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(14)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Cover image")
                        #if os(iOS)
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose from Photo Library", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task { await uploadPickedPhoto(newValue) }
                        }
                        #else
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Choose Image File", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.jpeg, .png, .webP]) { result in
                            Task { await uploadImportedFile(result) }
                        }
                        #endif
                        Button {
                            Task { await deleteCover() }
                        } label: {
                            Text("Remove Cover Image")
                                .foregroundStyle(Color.appDanger)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SurfaceButtonStyle())
                    }

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle("Edit Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
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
