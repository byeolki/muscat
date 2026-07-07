#if os(iOS)
import ActivityKit
import Foundation

/// Live Activity / Dynamic Island payload. Deliberately text-only (no artwork) — the
/// content state has a strict size budget (a few KB) and embedding even a downsampled
/// JPEG risks silently failing to update, so this mirrors the doc's guidance of
/// "song info + a static progress readout" rather than a real image.
public struct PlaybackActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var artist: String
        public var currentSeconds: Double
        public var duration: Double
        public var isPlaying: Bool

        public init(title: String, artist: String, currentSeconds: Double, duration: Double, isPlaying: Bool) {
            self.title = title
            self.artist = artist
            self.currentSeconds = currentSeconds
            self.duration = duration
            self.isPlaying = isPlaying
        }
    }

    public var trackId: String

    public init(trackId: String) {
        self.trackId = trackId
    }
}
#endif
