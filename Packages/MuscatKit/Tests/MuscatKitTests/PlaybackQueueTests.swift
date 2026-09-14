import XCTest
@testable import MuscatKit

/// Shuffle has three rules that are easy to get wrong and impossible to notice
/// from a screenshot, so they are pinned here.
final class PlaybackQueueTests: XCTestCase {
    private func tracks(_ n: Int) -> [QueueTrack] {
        (1...n).map { QueueTrack(id: "t\($0)", title: "Track \($0)", displayArtist: "A", artworkId: nil, duration: 180) }
    }

    /// Pressing Shuffle on a fresh list must not start with its first track — that
    /// is the one order nobody presses Shuffle to hear.
    func testShufflingAFreshListStartsSomewhereOtherThanTheTop() {
        var startedFirst = 0
        let runs = 50
        for _ in 0..<runs {
            var queue = PlaybackQueue()
            queue.replaceAll(tracks(12), startAt: 0)
            queue.setShuffled(true, keepingCurrent: false)
            if queue.currentTrack?.id == "t1" { startedFirst += 1 }
        }
        // One in twelve by chance; fifty runs starting at the top every time means
        // the current track is being pinned.
        XCTAssertLessThan(startedFirst, runs / 2, "shuffle keeps starting on the first track")
    }

    /// Toggling shuffle while something is playing must not change what is playing.
    func testShufflingMidTrackKeepsThatTrackPlaying() {
        var queue = PlaybackQueue()
        queue.replaceAll(tracks(20), startAt: 7)
        let playing = queue.currentTrack?.id
        queue.setShuffled(true)
        XCTAssertEqual(queue.currentTrack?.id, playing)
        XCTAssertEqual(queue.items.count, 20)
        XCTAssertEqual(Set(queue.items.map(\.id)).count, 20, "shuffling lost or duplicated a track")
    }

    /// Turning shuffle back off restores the order the tracks arrived in, without
    /// reloading the list that produced them.
    func testUnshufflingRestoresTheOriginalOrder() {
        let original = tracks(15)
        var queue = PlaybackQueue()
        queue.replaceAll(original, startAt: 3)
        queue.setShuffled(true)
        queue.setShuffled(false)
        XCTAssertEqual(queue.items.map(\.id), original.map(\.id))
        XCTAssertEqual(queue.currentTrack?.id, original[3].id)
    }
}
