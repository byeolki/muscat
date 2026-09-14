import AVFoundation
import Foundation
import Observation

/// Orchestrates playback: owns the queue, the `AVPlayer`-backed engine, and lock-screen
/// integration. Observed by SwiftUI via `.environment(playerStore)`.
@Observable
@MainActor
public final class PlayerStore {
    public private(set) var currentTrack: QueueTrack?
    public private(set) var isPlaying = false
    public private(set) var currentSeconds: Double = 0
    public private(set) var duration: Double?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    public private(set) var repeatMode: RepeatMode
    /// Per-track loudness leveling (server-side ReplayGain/loudnorm via ffmpeg) so
    /// quiet and loud tracks don't require a volume tweak between songs.
    public private(set) var normalize: Bool
    /// Stops playback after a delay, or at the end of the current track.
    public private(set) var sleepTimer: SleepTimer = .off

    private static let repeatModeDefaultsKey = "muscat.repeatMode"
    private static let shuffleDefaultsKey = "muscat.shuffle"
    private static let normalizeDefaultsKey = "muscat.normalize"

    private var queue = PlaybackQueue()
    /// Set when the saved preference says shuffle, applied as soon as a queue exists.
    private var restoreShuffleOnNextQueue = false
    private var sleepTimerTask: Task<Void, Never>?
    private let engine = AudioPlayerEngine()
    private let nowPlaying = NowPlayingCenter()
    private let apiClient: APIClient
    #if os(iOS)
    #endif

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        if let raw = UserDefaults.standard.string(forKey: Self.repeatModeDefaultsKey),
           let mode = RepeatMode(rawValue: raw) {
            repeatMode = mode
        } else {
            repeatMode = .off
        }
        if UserDefaults.standard.bool(forKey: Self.shuffleDefaultsKey) {
            // Nothing is queued yet, so this only records the preference; the queue
            // picks it up when something is played.
            restoreShuffleOnNextQueue = true
        }
        normalize = UserDefaults.standard.bool(forKey: Self.normalizeDefaultsKey)
        configureAudioSession()
        wireEngineCallbacks()
        wireNowPlayingCallbacks()
        nowPlaying.activate()
    }

    /// Repeat-all wraps the "next" affordance around to the first track, same as the
    /// web client disabling its next button only when `repeatMode !== 'all'`.
    public var hasNext: Bool { queue.hasNext || (repeatMode == .all && !queue.items.isEmpty) }
    public var isShuffled: Bool { queue.isShuffled }
    public var hasPrevious: Bool { queue.hasPrevious }

    // MARK: - Sleep timer

    /// Arms (or cancels) the sleep timer. A deadline is held as an absolute
    /// `Date` rather than a countdown so it stays correct while the app is
    /// suspended in the background — which is exactly when it's being used.
    public func setSleepTimer(_ timer: SleepTimer) {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimer = timer

        guard case .at(let deadline) = timer else { return }
        sleepTimerTask = Task { [weak self] in
            let seconds = deadline.timeIntervalSinceNow
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled else { return }
            self?.fireSleepTimer()
        }
    }

    /// Seconds left on a deadline timer, for a live countdown in the UI.
    public var sleepTimerRemaining: TimeInterval? {
        guard case .at(let deadline) = sleepTimer else { return nil }
        return max(0, deadline.timeIntervalSinceNow)
    }

    private func fireSleepTimer() {
        sleepTimerTask?.cancel()
        sleepTimerTask = nil
        sleepTimer = .off
        pause()
    }

    /// Shuffles what is queued, or puts it back in the order it arrived in. The
    /// track playing keeps playing either way — the original order is kept so
    /// turning shuffle off doesn't mean reloading the list that produced it.
    public func toggleShuffle() {
        queue.setShuffled(!queue.isShuffled)
        UserDefaults.standard.set(queue.isShuffled, forKey: Self.shuffleDefaultsKey)
    }

    public func cycleRepeatMode() {
        let order = RepeatMode.allCases
        let currentIndex = order.firstIndex(of: repeatMode) ?? 0
        repeatMode = order[(currentIndex + 1) % order.count]
        UserDefaults.standard.set(repeatMode.rawValue, forKey: Self.repeatModeDefaultsKey)
    }

    /// Toggling mid-track reloads the current stream (at the same position and
    /// play/pause state) so the new setting actually takes effect immediately,
    /// instead of only applying starting with the next track.
    public func toggleNormalize() {
        normalize.toggle()
        UserDefaults.standard.set(normalize, forKey: Self.normalizeDefaultsKey)
        guard let track = currentTrack else { return }
        Task { await loadAndPlay(track: track, resumeAt: currentSeconds, autoplay: isPlaying) }
    }

    /// Replaces the queue with `tracks` and starts playing the one at `index`.
    ///
    /// `shuffled` starts a shuffled run of the whole list, which is what a Shuffle
    /// button means: a different order every press, not a mode you have to undo.
    public func play(tracks: [QueueTrack], startAt index: Int, shuffled: Bool = false) {
        queue.replaceAll(tracks, startAt: index)
        if shuffled || restoreShuffleOnNextQueue {
            restoreShuffleOnNextQueue = false
            // `keepingCurrent: false` for a shuffle that is starting the list, so it
            // begins on a random track rather than the one at the top.
            queue.setShuffled(true, keepingCurrent: !shuffled)
        }
        guard let track = queue.currentTrack else { return }
        Task { await loadAndPlay(track: track) }
    }

    /// Shuffles `tracks` and plays them from the top.
    public func shuffle(tracks: [QueueTrack]) {
        guard !tracks.isEmpty else { return }
        play(tracks: tracks, startAt: 0, shuffled: true)
    }

    public func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    public func resume() {
        engine.play()
        isPlaying = true
        nowPlaying.updatePlaybackRate(isPlaying: true)
    }

    public func pause() {
        engine.pause()
        isPlaying = false
        nowPlaying.updatePlaybackRate(isPlaying: false)
    }

    public func skipToNext() {
        guard let track = queue.advanceToNext(wrapping: repeatMode == .all) else { return }
        Task { await loadAndPlay(track: track) }
    }

    /// Natural end-of-track (as opposed to a manual "skip next" tap): repeat-one loops
    /// the same track in place instead of advancing.
    private func handleTrackDidFinish() {
        // An "end of track" sleep timer outranks repeat and auto-advance; that's
        // the entire point of choosing it over a fixed delay.
        if case .endOfTrack = sleepTimer {
            fireSleepTimer()
            return
        }
        guard repeatMode == .one else {
            skipToNext()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            await self.seek(toSeconds: 0)
            self.resume()
        }
    }

    /// Restarts the current track if more than 3s in (typical UX), otherwise goes back.
    public func skipToPrevious() {
        if currentSeconds > 3 {
            Task { await seek(toSeconds: 0) }
            return
        }
        guard let track = queue.advanceToPrevious() else { return }
        Task { await loadAndPlay(track: track) }
    }

    public func seek(toSeconds seconds: Double) async {
        await engine.seek(toSeconds: seconds)
        currentSeconds = seconds
        nowPlaying.updateElapsed(seconds)
    }

    private func loadAndPlay(track: QueueTrack, resumeAt: Double = 0, autoplay: Bool = true) async {
        isLoading = true
        errorMessage = nil
        currentTrack = track
        currentSeconds = resumeAt
        duration = track.duration
        defer { isLoading = false }

        guard let url = await apiClient.streamURL(trackId: track.id, format: .aac, normalize: normalize) else {
            errorMessage = "Couldn't build a streaming URL."
            return
        }
        engine.load(url: url, autoplay: autoplay)
        if resumeAt > 0 {
            await engine.seek(toSeconds: resumeAt)
        }
        isPlaying = autoplay
        pushNowPlayingInfo(fetchArtwork: true)
        // Only a genuine track start counts as a play, not a normalize-toggle reload
        // of the track already playing.
        if resumeAt == 0 {
            try? await apiClient.recordPlayStart(trackId: track.id)
        }
    }



    private func wireEngineCallbacks() {
        // The player is the authority on whether sound is coming out. Anything that
        // stops it without asking this app — another app taking the session, a call,
        // headphones unplugged, Siri — used to leave the button offering Pause over
        // silence, because nothing told the store.
        engine.onPlaybackStateChange = { [weak self] playing in
            guard let self, self.isPlaying != playing else { return }
            self.isPlaying = playing
            self.nowPlaying.updatePlaybackRate(isPlaying: playing)
        }

        engine.onPeriodicTimeUpdate = { [weak self] seconds in
            guard let self else { return }
            self.currentSeconds = seconds
            self.nowPlaying.updateElapsed(seconds)
        }
        engine.onDurationAvailable = { [weak self] seconds in
            self?.duration = seconds
        }
        engine.onDidFinishPlaying = { [weak self] in
            self?.handleTrackDidFinish()
        }
        engine.onPlaybackStalled = { [weak self] in
            guard let self else { return }
            self.errorMessage = "Playback stalled. Check your network connection."
            self.report(kind: "playback.stalled", message: "the stream stopped delivering data")
        }
        engine.onFailedToLoad = { [weak self] message in
            guard let self else { return }
            self.isPlaying = false
            self.isLoading = false
            self.errorMessage = message
            self.nowPlaying.updatePlaybackRate(isPlaying: false)
            self.report(kind: "playback.failed", message: message)
        }
    }

    /// Sends a failure to the server so it appears in the log the operator reads.
    ///
    /// Fire-and-forget, and never allowed to surface: a report that fails must not
    /// become a second problem on top of the one it was describing. The track id
    /// goes with it because "it stopped" is only actionable if you know on what.
    private func report(kind: String, message: String) {
        let context = currentTrack.map { "track \($0.id) — \($0.title)" }
        Task { [apiClient] in await apiClient.reportClientError(kind: kind, message: message, context: context) }
    }

    private func wireNowPlayingCallbacks() {
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onToggle = { [weak self] in self?.togglePlayPause() }
        nowPlaying.onNext = { [weak self] in self?.skipToNext() }
        nowPlaying.onPrevious = { [weak self] in self?.skipToPrevious() }
        nowPlaying.onSeek = { [weak self] seconds in
            Task { await self?.seek(toSeconds: seconds) }
        }
    }

    private func pushNowPlayingInfo(fetchArtwork: Bool) {
        guard let currentTrack else { return }
        Task {
            var artworkURL: URL?
            var fallbackArtworkURL: URL?
            if fetchArtwork {
                if let artworkId = currentTrack.artworkId {
                    artworkURL = await apiClient.artworkURL(id: artworkId)
                }
                if let fallbackArtworkId = currentTrack.fallbackArtworkId {
                    fallbackArtworkURL = await apiClient.artworkURL(id: fallbackArtworkId)
                }
            }
            nowPlaying.update(
                track: currentTrack,
                currentSeconds: currentSeconds,
                duration: duration,
                isPlaying: isPlaying,
                artworkURL: artworkURL,
                fallbackArtworkURL: fallbackArtworkURL
            )
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Couldn't configure the audio session."
        }
        #endif
    }
}
