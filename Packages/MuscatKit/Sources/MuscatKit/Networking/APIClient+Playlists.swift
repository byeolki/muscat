import Foundation

extension APIClient {
    /// Playlists owned by the current user (server filters by owner for this route).
    public func fetchMyPlaylists() async throws -> [Playlist] {
        try await send(method: "GET", path: "api/v1/playlists")
    }

    /// Other users' playlists marked `is_public`. `@Public` on the server, but sending
    /// auth doesn't hurt.
    public func fetchPublicPlaylists() async throws -> [Playlist] {
        try await send(method: "GET", path: "api/v1/playlists/public")
    }

    public func fetchPlaylist(id: String) async throws -> PlaylistDetail {
        try await send(method: "GET", path: "api/v1/playlists/\(id)")
    }

    public func createPlaylist(name: String, description: String? = nil, isPublic: Bool? = nil) async throws -> Playlist {
        try await send(
            method: "POST", path: "api/v1/playlists",
            body: CreatePlaylistRequest(name: name, description: description, isPublic: isPublic)
        )
    }

    /// Passing `trackIds` replaces the playlist's full track order.
    public func updatePlaylist(
        id: String,
        name: String? = nil,
        description: String? = nil,
        isPublic: Bool? = nil,
        trackIds: [String]? = nil
    ) async throws -> PlaylistDetail {
        try await send(
            method: "PATCH", path: "api/v1/playlists/\(id)",
            body: UpdatePlaylistRequest(name: name, description: description, isPublic: isPublic, trackIds: trackIds)
        )
    }

    /// Appends `trackIds` at the end of the playlist (does not reorder existing tracks).
    public func addTracks(playlistId: String, trackIds: [String]) async throws {
        try await sendNoContent(
            method: "POST", path: "api/v1/playlists/\(playlistId)/tracks",
            body: AddTracksRequest(trackIds: trackIds)
        )
    }

    public func deletePlaylist(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/playlists/\(id)")
    }

    /// jpg/png/webp, 10MB max (enforced server-side). Returns the server filesystem
    /// path — use `artworkURL(id: playlistId)` to actually render the cover.
    public func uploadPlaylistCover(playlistId: String, imageData: Data, filename: String, mimeType: String) async throws -> String {
        let response: PlaylistCoverUploadResponse = try await sendMultipart(
            path: "api/v1/playlists/\(playlistId)/cover",
            fieldName: "file",
            filename: filename,
            mimeType: mimeType,
            fileData: imageData
        )
        return response.artworkPath
    }

    public func deletePlaylistCover(playlistId: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/playlists/\(playlistId)/cover")
    }
}
