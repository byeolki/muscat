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
                        Section {
                            ForEach(Array(version.tracks.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    playerStore.play(
                                        tracks: version.tracks.map { QueueTrack($0) },
                                        startAt: index
                                    )
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(track.title)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(Color.appTextPrimary)
                                            artistLineText(
                                                artist: track.displayArtist,
                                                isCover: track.isCover,
                                                originalArtist: nil
                                            )
                                            .font(.caption)
                                        }
                                        Spacer()
                                        if let duration = track.durationSeconds {
                                            Text(TrackRowView.formatted(duration))
                                                .font(.caption)
                                                .foregroundStyle(Color.appTextTertiary)
                                                .monospacedDigit()
                                        }
                                    }
                                    .contentShape(Rectangle())
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
                if isLoading {
                    ProgressView().tint(Color.appAccent)
                } else if let errorMessage {
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
