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

/// `tracks[]` here add `duration`/`artists` on top of the raw columns but do NOT
/// override-resolve `artist` (unlike `TracksService.findOne`).
public struct AlbumTrackEntry: Codable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let artist: String?
    public let albumVersionId: String?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let canonicalDuration: Double?
    public let isCover: Bool
    public let playCount: Int
    public let addedBy: String?
    public let addedAt: Date
    public let updatedAt: Date
    public let deletedAt: Date?
    public let duration: Double?
    public let artists: [ArtistRef]

    public var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }
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

public extension QueueTrack {
    init(_ track: AlbumTrackEntry) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            albumVersionId: track.albumVersionId,
            duration: track.duration
        )
    }
}
