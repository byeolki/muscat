import AVFoundation
import Foundation

/// Wraps a single `AVPlayer` for audio playback. `AVAudioEngine` can't consume a network
/// stream URL directly (it needs pre-decoded buffers/files), so actual streaming/decoding
/// goes through `AVPlayer`, which natively handles HTTP range requests and progressive
/// download. A future EQ/crossfade pass can tap `AVPlayerItem`'s audio via
/// `MTAudioProcessingTap` without disturbing this class's public surface.
@MainActor
final class AudioPlayerEngine {
    var onPeriodicTimeUpdate: ((_ currentSeconds: Double) -> Void)?
    var onDurationAvailable: ((_ seconds: Double) -> Void)?
    var onDidFinishPlaying: (() -> Void)?
    var onPlaybackStalled: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var didFinishObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var durationLoadTask: Task<Void, Never>?

    var isPlaying: Bool { (player?.rate ?? 0) > 0 }

    var currentSeconds: Double {
        guard let time = player?.currentTime(), time.isValid else { return 0 }
        return time.seconds
    }

    /// Loads a new item and begins playback immediately if `autoplay` is true.
    func load(url: URL, autoplay: Bool) {
        teardownCurrentItem()

        let item = AVPlayerItem(url: url)
        let newPlayer = player ?? AVPlayer()
        newPlayer.replaceCurrentItem(with: item)
        player = newPlayer

        attachObservers(to: item, player: newPlayer)

        durationLoadTask = Task { [weak self] in
            guard let duration = try? await item.asset.load(.duration), duration.isValid, !duration.isIndefinite else {
                return
            }
            self?.onDurationAvailable?(duration.seconds)
        }

        if autoplay {
            newPlayer.play()
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(toSeconds seconds: Double) async {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        await player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        teardownCurrentItem()
        player?.replaceCurrentItem(with: nil)
    }

    private func attachObservers(to item: AVPlayerItem, player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard time.isValid else { return }
            self?.onPeriodicTimeUpdate?(time.seconds)
        }

        didFinishObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onDidFinishPlaying?()
        }

        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.onPlaybackStalled?()
        }
    }

    private func teardownCurrentItem() {
        durationLoadTask?.cancel()
        durationLoadTask = nil
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
        if let didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
        }
        didFinishObserver = nil
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }
        stalledObserver = nil
    }

    deinit {
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        if let didFinishObserver {
            NotificationCenter.default.removeObserver(didFinishObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
        }
    }
}
