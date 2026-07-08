import Foundation

public struct Playlist: Codable, Hashable, Identifiable {
    public let id: String
    public let ownerUserId: String
    public let name: String
    public let description: String?
    public let isPublic: Bool
    public let artworkPath: String?
    public let updatedAt: Date
    public let createdAt: Date
    public let deletedAt: Date?
}

public struct PlaylistDetail: Codable, Hashable, Identifiable {
    public let id: String
    public let ownerUserId: String
    public let name: String
    public let description: String?
    public let isPublic: Bool
    public let artworkPath: String?
    public let updatedAt: Date
    public let createdAt: Date
    public let deletedAt: Date?
    public let tracks: [PlaylistTrackEntry]
}

struct CreatePlaylistRequest: Encodable {
    let name: String
    let description: String?
    let isPublic: Bool?
}

struct UpdatePlaylistRequest: Encodable {
    let name: String?
    let description: String?
    let isPublic: Bool?
    let trackIds: [String]?
}

struct AddTracksRequest: Encodable {
    let trackIds: [String]
}

struct PlaylistCoverUploadResponse: Decodable {
    let artworkPath: String
}
