import Foundation

struct RadioMixRequest: Encodable {
    let name: String?
    let seedTrackId: String?
    let seedArtistName: String?
    let count: Int?
}

struct CreateRadioTokenRequest: Encodable {
    let expiresInDays: Int?
}

/// Raw `playlist_radio_tokens` row — the client builds the actual stream URL itself
/// from `token` (`GET /api/v1/broadcast/:token`), the server doesn't hand back a URL.
public struct RadioToken: Codable, Hashable, Identifiable {
    public let id: String
    public let playlistId: String
    public let token: String
    public let createdBy: String?
    public let createdAt: Date
    public let expiresAt: Date
    public let revokedAt: Date?
    public let lastPlayedAt: Date?

    public var isActive: Bool {
        revokedAt == nil && expiresAt > Date()
    }
}
