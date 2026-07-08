import Foundation

extension APIClient {
    public func fetchAlbums() async throws -> [Album] {
        try await send(method: "GET", path: "api/v1/albums")
    }

    public func fetchAlbum(id: String) async throws -> AlbumDetail {
        try await send(method: "GET", path: "api/v1/albums/\(id)")
    }
}
