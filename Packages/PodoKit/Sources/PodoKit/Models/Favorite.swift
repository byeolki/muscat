import Foundation

/// `GET /favorites` wraps each hit as `{ track: RawTrack }` — not a flat array.
public struct FavoriteEntry: Codable, Identifiable {
    public let track: RawTrack
    public var id: String { track.id }
}
