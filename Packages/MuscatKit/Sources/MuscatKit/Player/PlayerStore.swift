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

    private static let repeatModeDefaultsKey = "muscat.repeatMode"

    private var queue = PlaybackQueue()
    private let engine = AudioPlayerEngine()
    private let nowPlaying = NowPlayingCenter()
    private let apiClient: APIClient
    #if os(iOS)
    private let liveActivity = LiveActivityController()
    #endif

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        if let raw = UserDefaults.standard.string(forKey: Self.repeatModeDefaultsKey),
           let mode = RepeatMode(rawValue: raw) {
            repeatMode = mode
        } else {
            repeatMode = .off
        }
        configureAudioSession()
        wireEngineCallbacks()
        wireNowPlayingCallbacks()
        nowPlaying.activate()
    }

    /// Repeat-all wraps the "next" affordance around to the first track, same as the
    /// web client disabling its next button only when `repeatMode !== 'all'`.
    public var hasNext: Bool { queue.hasNext || (repeatMode == .all && !queue.items.isEmpty) }
    public var hasPrevious: Bool { queue.hasPrevious }

    public func cycleRepeatMode() {
        let order = RepeatMode.allCases
        let currentIndex = order.firstIndex(of: repeatMode) ?? 0
        repeatMode = order[(currentIndex + 1) % order.count]
        UserDefaults.standard.set(repeatMode.rawValue, forKey: Self.repeatModeDefaultsKey)
    }

    /// Replaces the queue with `tracks` and starts playing the one at `index`.
    public func play(tracks: [QueueTrack], startAt index: Int) {
        queue.replaceAll(tracks, startAt: index)
        guard let track = queue.currentTrack else { return }
        Task { await loadAndPlay(track: track) }
    }

    public func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    public func resume() {
        engine.play()
        isPlaying = true
        nowPlaying.updatePlaybackRate(isPlaying: true)
        updateLiveActivity()
    }

    public func pause() {
        engine.pause()
        isPlaying = false
        nowPlaying.updatePlaybackRate(isPlaying: false)
        updateLiveActivity()
    }

    public func skipToNext() {
        guard let track = queue.advanceToNext(wrapping: repeatMode == .all) else { return }
        Task { await loadAndPlay(track: track) }
    }

    /// Natural end-of-track (as opposed to a manual "skip next" tap): repeat-one loops
    /// the same track in place instead of advancing.
    private func handleTrackDidFinish() {
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

    private func loadAndPlay(track: QueueTrack) async {
        isLoading = true
        errorMessage = nil
        currentTrack = track
        currentSeconds = 0
        duration = track.duration
        defer { isLoading = false }

        guard let url = await apiClient.streamURL(trackId: track.id, format: .aac) else {
            errorMessage = "Couldn't build a streaming URL."
            return
        }
        engine.load(url: url, autoplay: true)
        isPlaying = true
        pushNowPlayingInfo(fetchArtwork: true)
        startLiveActivity(for: track)
        try? await apiClient.recordPlayStart(trackId: track.id)
    }

    private func startLiveActivity(for track: QueueTrack) {
        #if os(iOS)
        liveActivity.start(
            trackId: track.id, title: track.title, artist: track.displayArtist,
            currentSeconds: 0, duration: duration ?? 0, isPlaying: true
        )
        #endif
    }

    /// Discrete updates only (start/pause/resume/skip), not a per-second tick — the
    /// Dynamic Island shows a static progress readout, not a live-ticking counter.
    private func updateLiveActivity() {
        #if os(iOS)
        guard let currentTrack else { return }
        liveActivity.update(
            title: currentTrack.title, artist: currentTrack.displayArtist,
            currentSeconds: currentSeconds, duration: duration ?? 0, isPlaying: isPlaying
        )
        #endif
    }

    private func wireEngineCallbacks() {
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
            self?.errorMessage = "Playback stalled. Check your network connection."
        }
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
