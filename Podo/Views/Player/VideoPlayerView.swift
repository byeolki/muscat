import AVKit
import PodoKit
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
                    Button("닫기") { dismiss() }
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
            errorMessage = "영상 스트리밍 주소를 만들 수 없습니다."
            return
        }
        let newPlayer = AVPlayer(url: url)
        player = newPlayer
        newPlayer.play()
    }
}
