import Foundation

/// When playback should stop on its own.
///
/// `.at` carries an absolute deadline rather than a remaining duration: the app
/// is usually backgrounded (or the screen locked) while this runs, so anything
/// that has to be decremented on a timer would drift or stall.
public enum SleepTimer: Equatable {
    case off
    /// Stop once the track that's playing now reaches its end.
    case endOfTrack
    case at(Date)

    public var isActive: Bool { self != .off }

    /// Offered in the UI as one-tap presets.
    public static let presetMinutes = [15, 30, 45, 60, 90]

    public static func minutes(_ minutes: Int) -> SleepTimer {
        .at(Date().addingTimeInterval(TimeInterval(minutes) * 60))
    }
}
