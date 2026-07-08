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

    /// Returns `nil` if the track has no lyrics, regardless of whether the server
    /// signals that via a `null` body or a 404.
    public func fetchLyrics(trackId: String) async throws -> LyricsResponse? {
        do {
            return try await send(method: "GET", path: "api/v1/tracks/\(trackId)/lyrics") as LyricsResponse
        } catch APIClientError.decoding {
            return nil
        } catch APIClientError.server(let statusCode, _) where statusCode == 404 {
            return nil
        }
    }
}
