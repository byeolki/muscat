import Foundation

/// The server enriches both `GET /favorites` and `GET /playlists/:id` the same way it
/// enriches the library list — override-resolved `title`/`is_cover`, a resolved
/// `artists` array, `has_video`, and favorite state — so despite the name this is no
/// longer a bare `tracks` row. The name (and the split from `Track`) stuck around
/// because these two endpoints wrap/shape it slightly differently (`{ track }[]` for
/// favorites, flat `+ position` for playlists), not because the data is less complete.
public struct RawTrack: Codable, Hashable, Identifiable, TrackRowDisplayable {
    public let id: String
    public let title: String
    public let artist: String?
    public let albumVersionId: String?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let canonicalDuration: Double?
    public let isCover: Bool
    public let thumbnailPath: String?
    public let playCount: Int
    public let addedBy: String?
    public let addedAt: Date
    public let updatedAt: Date
    public let deletedAt: Date?
    public let artists: [ArtistRef]
    public let hasVideo: Bool
    public let override: TrackMetadataOverride?
    public let isFavorited: Bool

    public var durationMilliseconds: Double? { canonicalDuration }
    public var originalArtist: String? { override?.originalArtist }
}

/// A `RawTrack` plus its position within a playlist (`GET /playlists/:id`).
public struct PlaylistTrackEntry: Codable, Hashable, Identifiable, TrackRowDisplayable {
    public let id: String
    public let title: String
    public let artist: String?
    public let albumVersionId: String?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let canonicalDuration: Double?
    public let isCover: Bool
    public let thumbnailPath: String?
    public let playCount: Int
    public let addedBy: String?
    public let addedAt: Date
    public let updatedAt: Date
    public let deletedAt: Date?
    public let artists: [ArtistRef]
    public let hasVideo: Bool
    public let override: TrackMetadataOverride?
    public let isFavorited: Bool
    public let position: Int

    public var durationMilliseconds: Double? { canonicalDuration }
    public var originalArtist: String? { override?.originalArtist }
}
