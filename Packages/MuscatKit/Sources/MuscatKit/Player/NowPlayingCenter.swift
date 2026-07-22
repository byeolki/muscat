import Foundation
import MediaPlayer

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Wires lock-screen / control-center controls (`MPNowPlayingInfoCenter` +
/// `MPRemoteCommandCenter`) to closures owned by `PlayerStore`.
@MainActor
final class NowPlayingCenter {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((Double) -> Void)?

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var artworkTask: Task<Void, Never>?

    func activate() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onToggle?()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPrevious?()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onSeek?(event.positionTime)
            return .success
        }
    }

    func deactivate() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        infoCenter.nowPlayingInfo = nil
    }

    func update(
        track: QueueTrack,
        currentSeconds: Double,
        duration: Double?,
        isPlaying: Bool,
        artworkURL: URL?,
        fallbackArtworkURL: URL? = nil
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        infoCenter.nowPlayingInfo = info

        guard artworkURL != nil || fallbackArtworkURL != nil else { return }
        artworkTask?.cancel()
        artworkTask = Task { [weak self] in
            var image = await Self.loadPlatformImage(from: artworkURL)
            if image == nil {
                image = await Self.loadPlatformImage(from: fallbackArtworkURL)
            }
            guard let image, let self, !Task.isCancelled else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            var updated = self.infoCenter.nowPlayingInfo ?? [:]
            updated[MPMediaItemPropertyArtwork] = artwork
            self.infoCenter.nowPlayingInfo = updated
        }
    }

    #if os(iOS)
    private static func loadPlatformImage(from url: URL?) async -> UIImage? {
        guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
    #else
    private static func loadPlatformImage(from url: URL?) async -> NSImage? {
        guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }
    #endif

    func updatePlaybackRate(isPlaying: Bool) {
        guard var info = infoCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        infoCenter.nowPlayingInfo = info
    }

    /// Cheap periodic update — just the elapsed time, no artwork refetch.
    func updateElapsed(_ seconds: Double) {
        guard var info = infoCenter.nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        infoCenter.nowPlayingInfo = info
    }
}
