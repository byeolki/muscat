import Foundation

public struct Album: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let updatedAt: Date
    public let createdAt: Date
}

public enum AlbumVersionType: String, Codable {
    case regular
    case repackage
    case remaster
    case single
    case ep
    case compilation
    case live
    case other
}

/// One track inside `GET /albums/:id`. Enriched the same way the library list is
/// (override-resolved title/artist, split `artists`), but without the per-user
/// favorite state or the `override` blob the list endpoints carry.
public struct AlbumTrackEntry: Codable, Hashable, Identifiable, TrackDisplayable {
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

    public var durationMilliseconds: Double? { duration }
}

public struct AlbumVersion: Codable, Hashable, Identifiable {
    public let id: String
    public let albumId: String
    public let versionType: AlbumVersionType
    public let releaseYear: Int?
    public let artworkPath: String?
    public let updatedAt: Date
    public let createdAt: Date
    public let tracks: [AlbumTrackEntry]
}

public struct AlbumDetail: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let updatedAt: Date
    public let createdAt: Date
    public let versions: [AlbumVersion]
}
