import MuscatKit
import SwiftUI

struct AlbumTracksSheet: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    let albumId: String

    @State private var album: AlbumDetail?
    @State private var loadState = LoadableState<AlbumDetail>()

    var body: some View {
        NavigationStack {
            List {
                if let album {
                    ForEach(album.versions) { version in
                        Section {
                            ForEach(Array(version.tracks.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    playerStore.play(
                                        tracks: version.tracks.map { QueueTrack($0) },
                                        startAt: index
                                    )
                                } label: {
                                    // `AlbumTrackEntry` has no favorite/video state, so
                                    // those badges are simply absent here.
                                    TrackRowContent(
                                        title: track.title,
                                        artist: track.displayArtist,
                                        artworkId: track.artworkId,
                                        fallbackArtworkId: track.fallbackArtworkId,
                                        isCover: track.isCover,
                                        duration: track.durationSeconds
                                    )
                                }
                                .buttonStyle(.plain)
                                .themedRow()
                            }
                        } header: {
                            Text(sectionTitle(for: version))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextTertiary)
                                .kerning(0.8)
                                .textCase(.uppercase)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle(album?.title ?? "Album")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .overlay {
                if loadState.isLoading {
                    ProgressView().tint(Color.appAccent)
                } else if let errorMessage = loadState.errorMessage {
                    EmptyStateView(systemImage: "exclamationmark.circle", message: errorMessage)
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
        if let result = await loadState.run({ try await appEnvironment.apiClient.fetchAlbum(id: albumId) }) {
            album = result
        }
    }
}
