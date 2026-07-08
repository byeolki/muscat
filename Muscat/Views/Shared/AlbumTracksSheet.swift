import MuscatKit
import SwiftUI

struct AlbumTracksSheet: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    let albumId: String

    @State private var album: AlbumDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let album {
                    ForEach(album.versions) { version in
                        Section(sectionTitle(for: version)) {
                            ForEach(Array(version.tracks.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    playerStore.play(
                                        tracks: version.tracks.map { QueueTrack($0) },
                                        startAt: index
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .foregroundStyle(.primary)
                                            Text(track.displayArtist)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if let duration = track.duration {
                                            Text(TrackRowView.formatted(duration))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(album?.title ?? "Album")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                }
            }
            .task { await load() }
        }
    }

    private func sectionTitle(for version: AlbumVersion) -> String {
        if let year = version.releaseYear {
            return "\(version.versionType.rawValue.capitalized) (\(year))"
        }
        return version.versionType.rawValue.capitalized
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            album = try await appEnvironment.apiClient.fetchAlbum(id: albumId)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
