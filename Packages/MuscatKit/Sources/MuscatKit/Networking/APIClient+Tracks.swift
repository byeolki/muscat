import Foundation

extension APIClient {
    public func fetchTracks(sort: TrackSort = .newest, filter: TrackFilter = .all) async throws -> [Track] {
        try await send(
            method: "GET",
            path: "api/v1/tracks",
            query: [
                URLQueryItem(name: "sort", value: sort.rawValue),
                URLQueryItem(name: "filter", value: filter.rawValue),
            ]
        )
    }

    public func fetchTrack(id: String) async throws -> TrackDetail {
        try await send(method: "GET", path: "api/v1/tracks/\(id)")
    }

    /// Call once playback of a track actually begins (not on every seek/resume).
    public func recordPlayStart(trackId: String) async throws {
        try await sendNoContent(method: "POST", path: "api/v1/tracks/\(trackId)/play")
    }

    /// Toggles favorite state; returns the new state.
    public func toggleFavorite(trackId: String) async throws -> Bool {
        let response: FavoriteToggleResponse = try await send(
            method: "POST", path: "api/v1/tracks/\(trackId)/favorite"
        )
        return response.favorited
    }

    /// One entry per stored language (`lyrics` is keyed by `(track_id, language)`);
    /// empty array if the track has no lyrics at all.
    public func fetchLyrics(trackId: String) async throws -> [LyricsResponse] {
        try await send(method: "GET", path: "api/v1/tracks/\(trackId)/lyrics")
    }
}
