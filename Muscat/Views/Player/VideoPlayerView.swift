import AVKit
import MuscatKit
import SwiftUI

/// Plays a track's video source (`has_video` / `sources[].media_kind == .video`).
/// No `format` is requested — video passthrough only, so the server doesn't need to
/// transcode the container, just the original file with Range support.
struct VideoPlayerView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    let trackId: String
    let title: String

    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var statusObserver: NSKeyValueObservation?

    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else if let errorMessage {
                    EmptyStateView(systemImage: "video.slash", message: errorMessage)
                } else {
                    ProgressView().tint(Color.appAccent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .themedScreen()
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .task {
            // This sheet is opened from a list, so its track is usually *not* the
            // one playing — there is nothing to follow, and the video brings its own
            // sound. Switching to the video of the track you are already listening
            // to is the other case, and it lives in the player, where the audio
            // keeps going and the picture follows it.
            playerStore.pause()
            await loadVideo()
        }
        .onDisappear {
            statusObserver = nil
            player?.pause()
        }
    }

    private func loadVideo() async {
        guard let url = await appEnvironment.apiClient.streamURL(trackId: trackId, mediaKind: .video) else {
            await fail("Could not build a video streaming URL.")
            return
        }
        let item = AVPlayerItem(url: url)
        // Without this the view sits on its spinner for ever when the item can't be
        // played — a 404 from the stream endpoint, a container iOS won't decode, an
        // expired token. "Nothing happens" was the whole failure mode.
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            guard item.status == .failed else { return }
            let reason = item.error?.localizedDescription ?? "the video could not be played"
            Task { @MainActor in await fail(reason) }
        }
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        newPlayer.play()
    }

    @MainActor
    private func fail(_ message: String) async {
        errorMessage = message
        player = nil
        await appEnvironment.apiClient.reportClientError(
            kind: "video.failed", message: message, context: "track \(trackId) — \(title)"
        )
    }
}
