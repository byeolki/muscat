import Foundation

extension APIClient {
    public func fetchFavorites() async throws -> [FavoriteEntry] {
        try await send(method: "GET", path: "api/v1/favorites")
    }

    /// Idempotent add — distinct from `toggleFavorite(trackId:)` on `APIClient+Tracks`,
    /// which flips state instead. Both hit the same `favorites` table server-side.
    @discardableResult
    public func addFavorite(trackId: String) async throws -> Bool {
        let response: FavoriteToggleResponse = try await send(method: "PUT", path: "api/v1/favorites/\(trackId)")
        return response.favorited
    }

    @discardableResult
    public func removeFavorite(trackId: String) async throws -> Bool {
        let response: FavoriteToggleResponse = try await send(method: "DELETE", path: "api/v1/favorites/\(trackId)")
        return response.favorited
    }
}
