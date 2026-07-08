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

    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    VideoPlayer(player: player)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            playerStore.pause()
            await loadVideo()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadVideo() async {
        guard let url = await appEnvironment.apiClient.streamURL(trackId: trackId, mediaKind: .video) else {
            errorMessage = "Could not build a video streaming URL."
            return
        }
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        newPlayer.play()
    }
}
