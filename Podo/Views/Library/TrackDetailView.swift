import PodoKit
import SwiftUI

struct TrackDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    let trackId: String
    /// Full list this track came from + its position, so the player queue can advance
    /// through the whole library rather than just this one track.
    let allTracks: [Track]
    let index: Int

    @State private var detail: TrackDetail?
    @State private var lyrics: LyricsResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RemoteArtworkView(albumVersionId: detail?.albumVersionId, cornerRadius: 12)
                    .frame(width: 220, height: 220)
                    .padding(.top)

                VStack(spacing: 4) {
                    Text(detail?.title ?? allTracks[safe: index]?.title ?? "")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(detail?.displayArtist ?? allTracks[safe: index]?.displayArtist ?? "")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let originalArtist = detail?.override?.originalArtist, detail?.isCover == true {
                        Text("cover of \(originalArtist)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Button {
                    playerStore.play(tracks: allTracks, startAt: index)
                } label: {
                    Label("재생", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
                        Text("가사")
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
            await load()
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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
