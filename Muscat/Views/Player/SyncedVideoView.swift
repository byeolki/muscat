import AVKit
import MuscatKit
import SwiftUI

/// The track's video, shown in place of its artwork while the audio keeps playing.
///
/// The audio is the authority and never stops. The video is muted and follows it —
/// which is what makes switching to the video mid-song seamless rather than a
/// restart, and is how the web client has always done it. Playing the video's own
/// audio instead would mean stopping the music, losing the position, and running a
/// second decode of the same track.
struct SyncedVideoView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    let trackId: String
    /// Told when the video cannot be played, so the caller can fall back to artwork
    /// rather than leaving a black square where the cover used to be.
    let onFailure: (String) -> Void

    @State private var player: AVPlayer?
    @State private var statusObserver: NSKeyValueObservation?
    /// Drift beyond this is corrected by seeking. Below it, a seek would be more
    /// visible than the drift.
    private let tolerance: Double = 0.5

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                Color.black
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: trackId) { await load() }
        .onDisappear { teardown() }
        .task(id: trackId) {
            // Follows the audio for as long as the video is on screen.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                sync()
            }
        }
    }

    private func load() async {
        teardown()
        guard let url = await appEnvironment.apiClient.streamURL(trackId: trackId, mediaKind: .video) else {
            onFailure("Could not build a video streaming URL.")
            return
        }
        let item = AVPlayerItem(url: url)
        statusObserver = item.observe(\.status, options: [.new]) { item, _ in
            guard item.status == .failed else { return }
            let reason = item.error?.localizedDescription ?? "the video could not be played"
            Task { @MainActor in
                onFailure(reason)
                await appEnvironment.apiClient.reportClientError(
                    kind: "video.failed", message: reason, context: "track \(trackId)"
                )
            }
        }
        let p = AVPlayer(playerItem: item)
        // Muted, always: the sound is already coming from the audio player, and two
        // decodes of the same track playing together is an echo, not stereo.
        p.isMuted = true
        await p.seek(to: CMTime(seconds: playerStore.currentSeconds, preferredTimescale: 600))
        player = p
        if playerStore.isPlaying { p.play() }
    }

    private func sync() {
        guard let player else { return }
        if playerStore.isPlaying {
            if player.timeControlStatus != .playing { player.play() }
        } else if player.timeControlStatus != .paused {
            player.pause()
        }
        let drift = abs(player.currentTime().seconds - playerStore.currentSeconds)
        if drift.isFinite && drift > tolerance {
            player.seek(to: CMTime(seconds: playerStore.currentSeconds, preferredTimescale: 600),
                        toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func teardown() {
        statusObserver = nil
        player?.pause()
        player = nil
    }
}
