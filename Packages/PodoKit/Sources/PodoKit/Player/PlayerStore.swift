import AVFoundation
import Foundation
import Observation

/// Orchestrates playback: owns the queue, the `AVPlayer`-backed engine, and lock-screen
/// integration. Observed by SwiftUI via `.environment(playerStore)`.
@Observable
@MainActor
public final class PlayerStore {
    public private(set) var currentTrack: Track?
    public private(set) var isPlaying = false
    public private(set) var currentSeconds: Double = 0
    public private(set) var duration: Double?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    private var queue = PlaybackQueue()
    private let engine = AudioPlayerEngine()
    private let nowPlaying = NowPlayingCenter()
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        configureAudioSession()
        wireEngineCallbacks()
        wireNowPlayingCallbacks()
        nowPlaying.activate()
    }

    public var hasNext: Bool { queue.hasNext }
    public var hasPrevious: Bool { queue.hasPrevious }

    /// Replaces the queue with `tracks` and starts playing the one at `index`.
    public func play(tracks: [Track], startAt index: Int) {
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
    }

    public func pause() {
        engine.pause()
        isPlaying = false
        nowPlaying.updatePlaybackRate(isPlaying: false)
    }

    public func skipToNext() {
        guard let track = queue.advanceToNext() else { return }
        Task { await loadAndPlay(track: track) }
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

    private func loadAndPlay(track: Track) async {
        isLoading = true
        errorMessage = nil
        currentTrack = track
        currentSeconds = 0
        duration = track.duration
        defer { isLoading = false }

        guard let url = await apiClient.streamURL(trackId: track.id, format: .aac) else {
            errorMessage = "스트리밍 주소를 만들 수 없습니다."
            return
        }
        engine.load(url: url, autoplay: true)
        isPlaying = true
        pushNowPlayingInfo(fetchArtwork: true)
        try? await apiClient.recordPlayStart(trackId: track.id)
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
            self?.skipToNext()
        }
        engine.onPlaybackStalled = { [weak self] in
            self?.errorMessage = "재생이 일시적으로 끊겼습니다. 네트워크를 확인하세요."
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
            if fetchArtwork, let albumVersionId = currentTrack.albumVersionId {
                artworkURL = await apiClient.artworkURL(id: albumVersionId)
            }
            nowPlaying.update(
                track: currentTrack,
                currentSeconds: currentSeconds,
                duration: duration,
                isPlaying: isPlaying,
                artworkURL: artworkURL
            )
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "오디오 세션을 구성하지 못했습니다."
        }
        #endif
    }
}
