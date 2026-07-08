import Foundation

public struct SearchTrackHit: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let type: String
    public let artist: String?
}

/// `id` here is literally the artist's name — there's no artist table/entity.
public struct SearchArtistHit: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let type: String
}

public struct SearchAlbumHit: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let type: String
}

/// Only the requested `type`s come back non-nil.
public struct SearchResults: Codable {
    public let tracks: [SearchTrackHit]?
    public let artists: [SearchArtistHit]?
    public let albums: [SearchAlbumHit]?
}

public enum SearchScope: String {
    case track
    case artist
    case album
}
