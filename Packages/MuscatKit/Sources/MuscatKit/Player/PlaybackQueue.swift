import Foundation

/// Ordered playback queue. `PlayerStore` drives it, including repeat-mode
/// wraparound. Source-agnostic: anything that can produce `[QueueTrack]` (library
/// list, playlist, favorites, radio, search) can be played this way.
struct PlaybackQueue {
    private(set) var items: [QueueTrack] = []
    private(set) var currentIndex: Int?
    /// The order the tracks arrived in, kept so shuffle can be switched back off
    /// without having to reload the list that produced it.
    private var originalOrder: [QueueTrack] = []
    private(set) var isShuffled = false

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
        originalOrder = tracks
        isShuffled = false
        currentIndex = tracks.indices.contains(index) ? index : nil
    }

    /// Shuffles everything except the track playing, which stays put and stays
    /// playing — reshuffling the current track out from under the listener is the
    /// one thing a shuffle button must not do.
    mutating func setShuffled(_ shuffled: Bool) {
        guard shuffled != isShuffled else { return }
        isShuffled = shuffled

        guard let playing = currentTrack else {
            items = shuffled ? items.shuffled() : originalOrder
            return
        }

        if shuffled {
            var rest = items
            rest.removeAll { $0.id == playing.id }
            items = [playing] + rest.shuffled()
            currentIndex = 0
        } else {
            items = originalOrder
            currentIndex = originalOrder.firstIndex { $0.id == playing.id }
        }
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
