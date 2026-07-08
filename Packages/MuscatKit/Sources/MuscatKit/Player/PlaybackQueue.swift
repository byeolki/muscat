import Foundation

/// Ordered playback queue. Deliberately dumb (no shuffle) — `PlayerStore` drives it,
/// including repeat-mode wraparound. Source-agnostic: anything that can produce
/// `[QueueTrack]` (library list, playlist, favorites, radio, search) can be played
/// this way.
struct PlaybackQueue {
    private(set) var items: [QueueTrack] = []
    private(set) var currentIndex: Int?

    var currentTrack: QueueTrack? {
        guard let currentIndex, items.indices.contains(currentIndex) else { return nil }
        return items[currentIndex]
    }

    var hasNext: Bool {
        guard let currentIndex else { return false }
        return items.indices.contains(currentIndex + 1)
    }

    var hasPrevious: Bool {
        guard let currentIndex else { return false }
        return items.indices.contains(currentIndex - 1)
    }

    mutating func replaceAll(_ tracks: [QueueTrack], startAt index: Int) {
        items = tracks
        currentIndex = tracks.indices.contains(index) ? index : nil
    }

    /// `wrapping: true` (repeat-all) jumps back to the first track when already at the
    /// last one, instead of stopping.
    @discardableResult
    mutating func advanceToNext(wrapping: Bool = false) -> QueueTrack? {
        guard let currentIndex else { return nil }
        if hasNext {
            self.currentIndex = currentIndex + 1
        } else if wrapping && !items.isEmpty {
            self.currentIndex = 0
        } else {
            return nil
        }
        return currentTrack
    }

    @discardableResult
    mutating func advanceToPrevious() -> QueueTrack? {
        guard hasPrevious, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return currentTrack
    }

    mutating func clear() {
        items = []
        currentIndex = nil
    }
}
