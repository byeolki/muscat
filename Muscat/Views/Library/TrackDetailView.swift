import MuscatKit
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
            VStack(spacing: 20) {
                RemoteArtworkView(artworkId: detail?.artworkId, fallbackArtworkId: detail?.fallbackArtworkId, cornerRadius: 16)
                    .frame(width: 240, height: 240)
                    .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                    .padding(.top, 20)

                VStack(spacing: 5) {
                    Text(detail?.title ?? queue[safe: index]?.title ?? "")
                        .font(.title2.bold())
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                    artistLineText(
                        artist: detail?.displayArtist ?? queue[safe: index]?.displayArtist ?? "",
                        isCover: detail?.isCover ?? false,
                        originalArtist: detail?.override?.originalArtist
                    )
                    .font(.subheadline)
                }
                .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button {
                        playerStore.play(tracks: queue, startAt: index)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))

                    iconWell(
                        systemImage: isFavorited ? "heart.fill" : "heart",
                        tint: isFavorited ? Color.appAccent : Color.appTextSecondary
                    ) {
                        Task { await toggleFavorite() }
                    }

                    if detail?.hasVideo == true {
                        iconWell(systemImage: "video.fill", tint: Color.appTextSecondary) {
                            showVideo = true
                        }
                    }
                }
                .padding(.horizontal, 24)

                if let tags = detail?.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags) { tag in
                                Text(tag.name)
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.appSurface, in: Capsule())
                                    .overlay(Capsule().stroke(Color.appBorder, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                if let lyrics {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LYRICS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.appTextTertiary)
                            .kerning(0.8)
                        Text(lyrics.content)
                            .font(.callout)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 24)
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 40)
        }
        .themedScreen()
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

    private func iconWell(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
