import MuscatKit
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import PhotosUI
#endif

/// Metadata edit sheet for a single track — title, artist, cover-song flag, alternate
/// search names, and a manually-uploaded thumbnail. Mirrors the field layout and
/// save semantics of the web dashboard's TrackEditModal (see podo/web), including the
/// same slightly unusual mapping: the "Artist" field writes `original_artist`, and
/// "Cover by" (shown only when Cover song is on) writes `artist` — that's how the
/// server's override table is actually shaped, not a typo.
struct TrackEditView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let track: TrackDetail
    let onSaved: () async -> Void

    @State private var title: String
    @State private var artist: String
    @State private var coverByArtist: String
    @State private var isCover: Bool
    @State private var alternateTitles: String

    @State private var hasThumbnail: Bool
    @State private var thumbnailBust = 0
    @State private var isUploadingThumbnail = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    #endif
    @State private var showFileImporter = false

    init(track: TrackDetail, onSaved: @escaping () async -> Void) {
        self.track = track
        self.onSaved = onSaved
        let ov = track.override
        _title = State(initialValue: ov?.title ?? track.title)
        _artist = State(initialValue: ov?.originalArtist ?? "")
        _coverByArtist = State(initialValue: ov?.artist ?? track.displayArtist)
        _isCover = State(initialValue: ov?.isCover ?? track.isCover)
        _alternateTitles = State(initialValue: ov?.alternateTitles ?? "")
        _hasThumbnail = State(initialValue: track.thumbnailPath != nil)
    }

    private var canSubmit: Bool { !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Thumbnail")
                        thumbnailRow
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Info")
                        TextField("", text: $title, prompt: Text("Title").foregroundStyle(Color.appTextTertiary))
                            .themedField()
                        TextField("", text: $artist, prompt: Text("Artist").foregroundStyle(Color.appTextTertiary))
                            .themedField()

                        Toggle("Cover song", isOn: $isCover)
                            .tint(Color.appAccent)
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(14)
                            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if isCover {
                            TextField("", text: $coverByArtist, prompt: Text("Cover by").foregroundStyle(Color.appTextTertiary))
                                .themedField()
                        }

                        TextField(
                            "", text: $alternateTitles,
                            prompt: Text("Alternate names (comma-separated)").foregroundStyle(Color.appTextTertiary)
                        )
                        .themedField()
                    }

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Save").frame(maxWidth: .infinity)
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
            .navigationTitle("Edit Track")
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

    private var thumbnailRow: some View {
        HStack(spacing: 14) {
            RemoteArtworkView(artworkId: hasThumbnail ? track.id : track.artworkId, cornerRadius: 10, cacheBust: thumbnailBust)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                #if os(iOS)
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(isUploadingThumbnail ? "Uploading…" : "Choose Image", systemImage: "photo")
                }
                .buttonStyle(SurfaceButtonStyle())
                .disabled(isUploadingThumbnail)
                .onChange(of: selectedPhoto) { _, newValue in
                    Task { await uploadPickedPhoto(newValue) }
                }
                #else
                Button {
                    showFileImporter = true
                } label: {
                    Label(isUploadingThumbnail ? "Uploading…" : "Choose Image File", systemImage: "photo")
                }
                .buttonStyle(SurfaceButtonStyle())
                .disabled(isUploadingThumbnail)
                .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.jpeg, .png, .webP]) { result in
                    Task { await uploadImportedFile(result) }
                }
                #endif

                if hasThumbnail {
                    Button {
                        Task { await removeThumbnail() }
                    } label: {
                        Text("Remove custom thumbnail")
                            .font(.caption)
                            .foregroundStyle(Color.appDanger)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Auto-generated (YouTube / video frame)")
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
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
            _ = try await appEnvironment.apiClient.updateTrackMetadata(
                trackId: track.id,
                title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title,
                artist: coverByArtist.isEmpty ? nil : coverByArtist,
                originalArtist: artist.isEmpty ? nil : artist,
                isCover: isCover,
                alternateTitles: alternateTitles.isEmpty ? nil : alternateTitles
            )
            await onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func removeThumbnail() async {
        do {
            try await appEnvironment.apiClient.deleteTrackThumbnail(trackId: track.id)
            hasThumbnail = false
            thumbnailBust += 1
            await onSaved()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    #if os(iOS)
    private func uploadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await uploadThumbnailData(data, filename: "thumbnail.jpg", mimeType: "image/jpeg")
    }
    #else
    private func uploadImportedFile(_ result: Result<URL, Error>) async {
        guard let url = try? result.get() else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        await uploadThumbnailData(data, filename: url.lastPathComponent, mimeType: mimeType(for: url.pathExtension))
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "png": return "image/png"
        case "webp": return "image/webp"
        default: return "image/jpeg"
        }
    }
    #endif

    private func uploadThumbnailData(_ data: Data, filename: String, mimeType: String) async {
        isUploadingThumbnail = true
        defer { isUploadingThumbnail = false }
        do {
            _ = try await appEnvironment.apiClient.uploadTrackThumbnail(
                trackId: track.id, imageData: data, filename: filename, mimeType: mimeType
            )
            hasThumbnail = true
            thumbnailBust += 1
            await onSaved()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
