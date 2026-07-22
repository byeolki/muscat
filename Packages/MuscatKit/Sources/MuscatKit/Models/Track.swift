import Foundation

public struct ArtistRef: Codable, Hashable {
    public let name: String
}

public struct Tag: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let kind: String
}

public enum MediaKind: String, Codable {
    case audio
    case video
}

public enum SourceOrigin: String, Codable {
    case local
    case ytdlp
}

public struct TrackMetadataOverride: Codable, Hashable {
    public let title: String?
    public let artist: String?
    public let originalArtist: String?
    public let isCover: Bool?
    public let videoLocator: String?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let alternateTitles: String?
    public let updatedAt: Date?
    public let updatedBy: String?
}

struct TrackMetadataUpdateRequest: Encodable {
    let title: String?
    let artist: String?
    let originalArtist: String?
    let isCover: Bool?
    let videoLocator: String?
    let trackNumber: Int?
    let discNumber: Int?
    let alternateTitles: String?
}

struct TrackThumbnailUploadResponse: Decodable {
    let thumbnailPath: String
}

public struct Source: Codable, Hashable, Identifiable {
    public let id: String
    public let trackId: String
    public let mediaKind: MediaKind
    public let origin: SourceOrigin
    public let format: String?
    public let codec: String?
    public let bitrate: Int?
    public let sampleRate: Int?
    public let channels: Int?
    public let duration: Double?
    public let timeOffset: Double
    public let priority: Int
    public let locator: String
    public let fileHash: String?
    public let fileSize: Int?
    public let replaygainTrack: Double?
    public let replaygainAlbum: Double?
    public let available: Bool
    public let updatedAt: Date
    public let createdAt: Date
    public let deletedAt: Date?

    /// `duration` is stored server-side in milliseconds (`ffprobe.service.ts` rounds
    /// `parseFloat(duration) * 1000`); convert to seconds for playback/display.
    public var durationSeconds: Double? {
        duration.map { $0 / 1000 }
    }
}

/// `GET /tracks` list item shape. Note the top-level `artist` is the RAW column
/// (not override-resolved) — use `displayArtist` or the `artists` array for display.
public struct Track: Codable, Hashable, Identifiable {
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
    public let duration: Double?
    public let artists: [ArtistRef]
    public let hasVideo: Bool
    public let override: TrackMetadataOverride?
    public let favoriteCount: Int
    public let isFavorited: Bool

    /// Comma-joined, override-resolved artist names — safe for display.
    public var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }

    /// `duration`/`canonical_duration` are stored server-side in milliseconds
    /// (`ffprobe.service.ts` rounds `parseFloat(duration) * 1000`); convert to seconds
    /// for playback/display.
    public var durationSeconds: Double? {
        duration.map { $0 / 1000 }
    }

    /// Best id to pass to `GET /artwork/:id`: album artwork first, else the track's own
    /// id when it has a generated thumbnail (server resolves `thumbnail_path` for a
    /// track id the same way it resolves album/playlist artwork).
    public var artworkId: String? {
        albumVersionId ?? (thumbnailPath != nil ? id : nil)
    }
}

/// `GET /tracks/:id` detail shape. `title`/`is_cover`/`track_number`/`disc_number` are
/// override-resolved here (unlike the list endpoint). No `favorite_count`/`is_favorited`
/// alias — carry those over from the originating `Track` if needed for UI state.
public struct TrackDetail: Codable, Hashable, Identifiable {
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
    public let duration: Double?
    public let sources: [Source]
    public let artists: [ArtistRef]
    public let tags: [Tag]
    public let override: TrackMetadataOverride?

    public var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }

    public var hasVideo: Bool {
        sources.contains { $0.mediaKind == .video }
    }

    /// Best available audio source: prefers higher `priority`, then availability.
    public var preferredAudioSource: Source? {
        sources
            .filter { $0.mediaKind == .audio && $0.available }
            .sorted { $0.priority > $1.priority }
            .first
    }

    /// `duration`/`canonical_duration` are stored server-side in milliseconds; convert
    /// to seconds for playback/display.
    public var durationSeconds: Double? {
        duration.map { $0 / 1000 }
    }

    /// Best id to pass to `GET /artwork/:id`: album artwork first, else the track's own
    /// id when it has a generated thumbnail.
    public var artworkId: String? {
        albumVersionId ?? (thumbnailPath != nil ? id : nil)
    }
}

public enum TrackSort: String, CaseIterable {
    case newest
    case oldest
    case popular
    case plays
}

public enum TrackFilter: String, CaseIterable {
    case all
    case mine
    case favorites
}

public struct FavoriteToggleResponse: Codable {
    public let favorited: Bool
}

public struct LyricsResponse: Codable {
    public let trackId: String
    public let type: LyricsType
    public let content: String
    public let source: LyricsSource
    public let updatedAt: Date
}

public enum LyricsType: String, Codable {
    case plain
    case synced
}

public enum LyricsSource: String, Codable {
    case local
    case user
}
