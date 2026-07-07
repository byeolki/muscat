import Foundation

/// Ordered playback queue. Deliberately dumb (no shuffle/repeat yet) — `PlayerStore`
/// drives it. Playlist-sourced queues can be built the same way later by feeding in
/// the playlist's track list.
struct PlaybackQueue {
    private(set) var items: [Track] = []
    private(set) var currentIndex: Int?

    var currentTrack: Track? {
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

    mutating func replaceAll(_ tracks: [Track], startAt index: Int) {
        items = tracks
        currentIndex = tracks.indices.contains(index) ? index : nil
    }

    @discardableResult
    mutating func advanceToNext() -> Track? {
        guard hasNext, let currentIndex else { return nil }
        self.currentIndex = currentIndex + 1
        return currentTrack
    }

    @discardableResult
    mutating func advanceToPrevious() -> Track? {
        guard hasPrevious, let currentIndex else { return nil }
        self.currentIndex = currentIndex - 1
        return currentTrack
    }

    mutating func clear() {
        items = []
        currentIndex = nil
    }
}
