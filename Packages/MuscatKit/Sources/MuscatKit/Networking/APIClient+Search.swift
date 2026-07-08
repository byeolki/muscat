import Foundation

extension APIClient {
    /// `types` defaults to all three (`track,artist,album`); `limit` is capped at 100
    /// server-side (default 20).
    public func search(query: String, types: Set<SearchScope> = [.track, .artist, .album], limit: Int = 20) async throws -> SearchResults {
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if !types.isEmpty {
            let typeValue = types.map(\.rawValue).joined(separator: ",")
            items.append(URLQueryItem(name: "type", value: typeValue))
        }
        return try await send(method: "GET", path: "api/v1/search", query: items)
    }
}
