import PodoKit
import SwiftUI

/// Source-agnostic track detail screen: works from the library list, playlists,
/// favorites, or search results as long as they can provide a `[QueueTrack]` queue
/// context (for prev/next) and this track's position in it.
struct TrackDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    let trackId: String
    let queue: [QueueTrack]
    let index: Int
    var initialIsFavorited = false

    @State private var detail: TrackDetail?
    @State private var lyrics: LyricsResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isFavorited = false
    @State private var showVideo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RemoteArtworkView(artworkId: detail?.albumVersionId, cornerRadius: 12)
                    .frame(width: 220, height: 220)
                    .padding(.top)

                VStack(spacing: 4) {
                    Text(detail?.title ?? queue[safe: index]?.title ?? "")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(detail?.displayArtist ?? queue[safe: index]?.displayArtist ?? "")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let originalArtist = detail?.override?.originalArtist, detail?.isCover == true {
                        Text("cover of \(originalArtist)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        playerStore.play(tracks: queue, startAt: index)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        Task { await toggleFavorite() }
                    } label: {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                    }
                    .buttonStyle(.bordered)
                    .tint(isFavorited ? .red : .secondary)

                    if detail?.hasVideo == true {
                        Button {
                            showVideo = true
                        } label: {
                            Image(systemName: "video.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                if let tags = detail?.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(tags) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.quaternary, in: Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                if let lyrics {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lyrics")
                            .font(.headline)
                        Text(lyrics.content)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(detail?.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            isFavorited = initialIsFavorited
            await load()
        }
        .sheet(isPresented: $showVideo) {
            VideoPlayerView(trackId: trackId, title: detail?.title ?? "")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let detailResult = appEnvironment.apiClient.fetchTrack(id: trackId)
            async let lyricsResult = appEnvironment.apiClient.fetchLyrics(trackId: trackId)
            detail = try await detailResult
            lyrics = try? await lyricsResult
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func toggleFavorite() async {
        do {
            isFavorited = try await appEnvironment.apiClient.toggleFavorite(trackId: trackId)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
