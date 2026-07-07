import Foundation

extension APIClient {
    /// Library-based recommendation station seeded from a track or artist name. Returns
    /// the same enriched track shape as `fetchTracks()`, capped at 200 server-side.
    public func fetchRadioStation(
        seedTrackId: String? = nil,
        seedArtistName: String? = nil,
        count: Int? = nil,
        exclude: [String] = []
    ) async throws -> [Track] {
        var query: [URLQueryItem] = []
        if let seedTrackId { query.append(URLQueryItem(name: "seed_track_id", value: seedTrackId)) }
        if let seedArtistName { query.append(URLQueryItem(name: "seed_artist_name", value: seedArtistName)) }
        if let count { query.append(URLQueryItem(name: "count", value: String(count))) }
        if !exclude.isEmpty { query.append(URLQueryItem(name: "exclude", value: exclude.joined(separator: ","))) }
        return try await send(method: "GET", path: "api/v1/radio", query: query)
    }

    /// Saves a recommendation station as a private playlist. The response is the bare
    /// playlist row (no `tracks` array) — call `fetchPlaylist(id:)` to get the tracks.
    public func createRadioMix(
        name: String? = nil,
        seedTrackId: String? = nil,
        seedArtistName: String? = nil,
        count: Int? = nil
    ) async throws -> Playlist {
        try await send(
            method: "POST", path: "api/v1/radio/mix",
            body: RadioMixRequest(name: name, seedTrackId: seedTrackId, seedArtistName: seedArtistName, count: count)
        )
    }

    /// Issues a public, token-authenticated infinite-repeat stream URL for a playlist
    /// you own. Defaults to a 90-day expiry server-side if `expiresInDays` is omitted.
    public func createRadioToken(playlistId: String, expiresInDays: Int? = nil) async throws -> RadioToken {
        try await send(
            method: "POST", path: "api/v1/playlists/\(playlistId)/radio-tokens",
            body: CreateRadioTokenRequest(expiresInDays: expiresInDays)
        )
    }

    public func fetchRadioTokens(playlistId: String) async throws -> [RadioToken] {
        try await send(method: "GET", path: "api/v1/playlists/\(playlistId)/radio-tokens")
    }

    public func deleteRadioToken(playlistId: String, tokenId: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/playlists/\(playlistId)/radio-tokens/\(tokenId)")
    }

    /// Public stream URL for a radio token — no auth needed, the token itself is the
    /// credential. `format` picks the file extension the broadcast controller expects.
    public func broadcastURL(token: String, format: StreamFormat = .mp3) -> URL {
        baseURL.appendingPathComponent("api/v1/broadcast/\(token).\(format.rawValue)")
    }
}
