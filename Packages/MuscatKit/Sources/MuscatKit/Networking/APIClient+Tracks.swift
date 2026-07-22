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

    /// Applies a metadata override (title/artist/is_cover/etc). Pass the full current
    /// form state for every field, not just changed ones — `nil` is encoded as JSON
    /// `null`, and the server treats an explicit `null` as "clear this field," not
    /// "leave it alone" (same convention `updatePlaylist` already relies on).
    @discardableResult
    public func updateTrackMetadata(
        trackId: String,
        title: String? = nil,
        artist: String? = nil,
        originalArtist: String? = nil,
        isCover: Bool? = nil,
        videoLocator: String? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        alternateTitles: String? = nil
    ) async throws -> TrackDetail {
        try await send(
            method: "PATCH", path: "api/v1/tracks/\(trackId)/metadata",
            body: TrackMetadataUpdateRequest(
                title: title, artist: artist, originalArtist: originalArtist, isCover: isCover,
                videoLocator: videoLocator, trackNumber: trackNumber, discNumber: discNumber,
                alternateTitles: alternateTitles
            )
        )
    }

    /// jpg/png/webp, 10MB max (enforced server-side). Takes precedence over both the
    /// yt-dlp sidecar and ffmpeg first-frame thumbnails the scanner would otherwise
    /// generate for this track. Returns the server filesystem path — use
    /// `artworkURL(id: trackId)` to actually render it.
    public func uploadTrackThumbnail(trackId: String, imageData: Data, filename: String, mimeType: String) async throws -> String {
        let response: TrackThumbnailUploadResponse = try await sendMultipart(
            path: "api/v1/tracks/\(trackId)/thumbnail",
            fieldName: "file",
            filename: filename,
            mimeType: mimeType,
            fileData: imageData
        )
        return response.thumbnailPath
    }

    public func deleteTrackThumbnail(trackId: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/tracks/\(trackId)/thumbnail")
    }
}
