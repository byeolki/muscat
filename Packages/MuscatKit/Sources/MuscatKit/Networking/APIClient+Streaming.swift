import Foundation

public enum StreamFormat: String {
    case aac
    case opus
    case mp3
    case flac
}

extension APIClient {
    /// Builds an authenticated stream URL (`?token=` query, since `AVPlayer` can't send
    /// custom headers). Pass `format` to force a codec you know `AVPlayer` can decode —
    /// omitting it streams the original file as-is, which may not always be playable.
    public func streamURL(
        trackId: String,
        mediaKind: MediaKind = .audio,
        sourceId: String? = nil,
        format: StreamFormat? = nil,
        bitrate: Int? = nil,
        seekMs: Int? = nil,
        normalize: Bool = false
    ) async -> URL? {
        var query: [URLQueryItem] = [URLQueryItem(name: "media_kind", value: mediaKind.rawValue)]
        if let sourceId { query.append(URLQueryItem(name: "source_id", value: sourceId)) }
        if let format { query.append(URLQueryItem(name: "format", value: format.rawValue)) }
        if let bitrate { query.append(URLQueryItem(name: "bitrate", value: String(bitrate))) }
        if let seekMs { query.append(URLQueryItem(name: "seek_ms", value: String(seekMs))) }
        if normalize { query.append(URLQueryItem(name: "normalize", value: "true")) }
        // Refreshed before the URL is built: `AVPlayer` keeps using this string for
        // the life of the item and cannot be handed a new one, so a token that
        // expires a minute from now is a track that stops a minute from now.
        // No URL at all rather than one carrying a token known to be dead: a nil
        // here becomes "couldn't build a streaming URL", which is at least a
        // sentence, where the token version becomes an opaque -1013 on every track.
        guard let token = await freshAccessToken() else { return nil }
        query.append(URLQueryItem(name: "token", value: token))
        return unauthenticatedURL(path: "api/v1/stream/\(trackId)", query: query)
    }

    /// `album_version_id` or a playlist id. Public endpoint, but we still build the URL
    /// through the actor so it always reflects the current server base URL.
    public func artworkURL(id: String) async -> URL? {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent("api/v1/artwork/\(id)"), resolvingAgainstBaseURL: false
        ) else { return nil }
        components.queryItems = nil
        return components.url
    }
}
