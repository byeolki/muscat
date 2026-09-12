import Foundation

/// Pulling music in from a URL. Admin-only on the server — it spends disk and
/// bandwidth and reaches a third-party site — so callers should gate the UI on
/// the current user's role rather than letting these fail with a 403.
extension APIClient {
    /// Classifies a link without downloading anything, so the UI can say what it
    /// is about to do.
    public func inspectURL(_ url: String) async throws -> URLInspection {
        let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        return try await send(method: "GET", path: "api/v1/download/inspect?url=\(encoded)")
    }

    /// Downloads whatever the link names. A collection URL is expanded; a share
    /// link that merely carries `&list=` is treated as the single item it names.
    public func startDownload(url: String, audioOnly: Bool = true) async throws -> DownloadJob {
        try await send(
            method: "POST", path: "api/v1/download",
            body: StartDownloadRequest(url: url, audioOnly: audioOnly)
        )
    }

    public func fetchDownloads() async throws -> [DownloadJob] {
        try await send(method: "GET", path: "api/v1/download")
    }

    public func fetchDownload(id: String) async throws -> DownloadJob {
        try await send(method: "GET", path: "api/v1/download/\(id)")
    }

    /// Downloads a remote playlist and keeps it as a playlist here, rather than
    /// scattering its tracks into the library. A one-time import: the result is
    /// an ordinary playlist with no link back to the source.
    public func importPlaylist(url: String, audioOnly: Bool = true) async throws -> PlaylistImport {
        try await send(
            method: "POST", path: "api/v1/playlists/from-url",
            body: ImportPlaylistRequest(url: url, audioOnly: audioOnly)
        )
    }
}
