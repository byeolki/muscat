#if os(iOS)
import ActivityKit
import Foundation

/// Starts/updates/ends the lock-screen Live Activity + Dynamic Island for the currently
/// playing track. All local (no push token / remote updates) — the app updates it
/// directly whenever `PlayerStore`'s state changes.
@MainActor
final class LiveActivityController {
    private var activity: Activity<PlaybackActivityAttributes>?

    func start(trackId: String, title: String, artist: String, currentSeconds: Double, duration: Double, isPlaying: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = PlaybackActivityAttributes(trackId: trackId)
        let state = PlaybackActivityAttributes.ContentState(
            title: title, artist: artist, currentSeconds: currentSeconds, duration: duration, isPlaying: isPlaying
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(title: String, artist: String, currentSeconds: Double, duration: Double, isPlaying: Bool) {
        guard let activity else { return }
        let state = PlaybackActivityAttributes.ContentState(
            title: title, artist: artist, currentSeconds: currentSeconds, duration: duration, isPlaying: isPlaying
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }
}
#endif
