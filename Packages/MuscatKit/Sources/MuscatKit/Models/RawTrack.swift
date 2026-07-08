import Foundation

/// Exactly the `tracks` table columns, no enrichment (no override resolution, no
/// `artists`/`sources`). This is what the server hands back embedded in playlists
/// (`tracks: (RawTrack & {position})[]`) — modeled here as `PlaylistTrackEntry` since
/// JSON is flat and Swift can't easily compose two Codable structs into one.
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

    /// Fallback if `artworkId` (the album) turns out to have no artwork file on disk —
    /// the artwork endpoint checks whatever id it's given against albums, then
    /// playlists, then track thumbnails, so an album with no art on disk 404s instead
    /// of silently trying the track's own thumbnail.
    public var fallbackArtworkId: String? {
        guard albumVersionId != nil, thumbnailPath != nil else { return nil }
        return id
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
    public let position: Int

    /// Best-effort display name — raw rows have no `artists` array, just the
    /// unresolved `artist` column (comma-separated free text).
    public var displayArtist: String {
        artist ?? ""
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

    /// Fallback if `artworkId` (the album) turns out to have no artwork file on disk.
    public var fallbackArtworkId: String? {
        guard albumVersionId != nil, thumbnailPath != nil else { return nil }
        return id
    }
}
