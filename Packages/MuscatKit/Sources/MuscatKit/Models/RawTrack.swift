import Foundation

/// The server enriches both `GET /favorites` and `GET /playlists/:id` the same way it
/// enriches the library list — override-resolved `title`/`is_cover`, a resolved
/// `artists` array, `has_video`, and favorite state — so despite the name this is no
/// longer a bare `tracks` row. The name (and the split from `Track`) stuck around
/// because these two endpoints wrap/shape it slightly differently (`{ track }[]` for
/// favorites, flat `+ position` for playlists), not because the data is less complete.
public struct RawTrack: Codable, Hashable, Identifiable {
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

    /// Comma-joined, override-resolved artist names — safe for display.
    public var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }

    /// `canonical_duration` is stored server-side in milliseconds; convert to seconds
    /// for playback/display.
    public var durationSeconds: Double? {
        canonicalDuration.map { $0 / 1000 }
    }

    /// Best id to pass to `GET /artwork/:id`: album artwork first, else the track's own
    /// id when it has a generated thumbnail.
    public var artworkId: String? {
        albumVersionId ?? (thumbnailPath != nil ? id : nil)
    }
}

/// A `RawTrack` plus its position within a playlist (`GET /playlists/:id`).
public struct PlaylistTrackEntry: Codable, Hashable, Identifiable {
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

    /// Comma-joined, override-resolved artist names — safe for display.
    public var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }

    /// `canonical_duration` is stored server-side in milliseconds; convert to seconds
    /// for playback/display.
    public var durationSeconds: Double? {
        canonicalDuration.map { $0 / 1000 }
    }

    /// Best id to pass to `GET /artwork/:id`: album artwork first, else the track's own
    /// id when it has a generated thumbnail.
    public var artworkId: String? {
        albumVersionId ?? (thumbnailPath != nil ? id : nil)
    }
}
