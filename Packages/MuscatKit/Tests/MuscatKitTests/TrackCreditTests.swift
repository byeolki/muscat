import XCTest
@testable import MuscatKit

/// Three places credit a track and they are deliberately different. Getting any of
/// them wrong is invisible until someone notices the wrong name on a lock screen.
final class TrackCreditTests: XCTestCase {
    private struct Sample: TrackDisplayable {
        let id = "t1"
        let title = "으르렁"
        let artists: [ArtistRef]
        let isCover: Bool
        let originalArtist: String?
        let albumVersionId: String? = nil
        let thumbnailPath: String? = nil
        let durationMilliseconds: Double? = 214_000
    }

    private func cover(performers: [String], original: String?) -> Sample {
        Sample(artists: performers.map { ArtistRef(name: $0) }, isCover: true, originalArtist: original)
    }

    /// A row leads with whose song it is, so the list can be scanned by song.
    func testRowLeadsWithTheOriginalArtist() {
        XCTAssertEqual(cover(performers: ["윤단"], original: "EXO").displayArtist, "EXO")
    }

    /// The system player answers "who am I listening to", which for a cover is
    /// whoever covered it.
    func testSystemPlayerCreditsThePerformer() {
        XCTAssertEqual(cover(performers: ["윤단"], original: "EXO").nowPlayingArtist, "윤단")
    }

    /// A player screen has room for the whole answer.
    func testPlayerLineCarriesBoth() {
        XCTAssertEqual(cover(performers: ["윤단"], original: "EXO").playerArtistLine, "EXO · covered by 윤단")
    }

    /// A cover nobody has attributed must not credit the coverer as the artist.
    func testUnattributedCoverDoesNotPromoteThePerformer() {
        let c = cover(performers: ["윤단"], original: nil)
        XCTAssertEqual(c.displayArtist, "")
        XCTAssertEqual(c.playerArtistLine, "Cover by 윤단")
        XCTAssertEqual(c.nowPlayingArtist, "윤단")
    }

    /// A track that is not a cover is its performer's own, everywhere.
    func testNonCoverIsTheSameEverywhere() {
        let t = Sample(artists: [ArtistRef(name: "Aster Vale")], isCover: false, originalArtist: nil)
        XCTAssertEqual(t.displayArtist, "Aster Vale")
        XCTAssertEqual(t.nowPlayingArtist, "Aster Vale")
        XCTAssertEqual(t.playerArtistLine, "Aster Vale")
    }
}
