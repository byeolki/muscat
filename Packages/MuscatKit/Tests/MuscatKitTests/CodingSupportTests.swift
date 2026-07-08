import XCTest
@testable import MuscatKit

final class CodingSupportTests: XCTestCase {
    func testDecodesFractionalSecondsISO8601Date() throws {
        let json = #"{"status":"ok","timestamp":"2024-01-15T10:30:00.123Z"}"#.data(using: .utf8)!
        let health = try JSONDecoder.muscat.decode(HealthResponse.self, from: json)
        XCTAssertEqual(health.status, "ok")
    }

    func testDecodesWholeSecondISO8601Date() throws {
        let json = #"{"status":"ok","timestamp":"2024-01-15T10:30:00Z"}"#.data(using: .utf8)!
        let health = try JSONDecoder.muscat.decode(HealthResponse.self, from: json)
        XCTAssertEqual(health.status, "ok")
    }

    func testSnakeCaseKeyDecoding() throws {
        let json = """
        {
            "id": "abc123", "title": "Song", "artist": null, "album_version_id": null,
            "track_number": null, "disc_number": null, "canonical_duration": 180,
            "is_cover": false, "play_count": 0, "added_by": null,
            "added_at": "2024-01-15T10:30:00.000Z", "updated_at": "2024-01-15T10:30:00.000Z",
            "deleted_at": null, "duration": 180, "artists": [{"name": "Someone"}],
            "has_video": false, "override": null, "favorite_count": 0, "is_favorited": false
        }
        """.data(using: .utf8)!
        let track = try JSONDecoder.muscat.decode(Track.self, from: json)
        XCTAssertEqual(track.id, "abc123")
        XCTAssertEqual(track.displayArtist, "Someone")
    }
}
