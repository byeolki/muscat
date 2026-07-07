import Foundation

/// `GET /upload/files` — enriched (not raw `sources` rows).
public struct UploadedFileEntry: Codable, Hashable, Identifiable {
    public let sourceId: String
    public let trackId: String
    public let trackTitle: String
    public let filename: String
    public let path: String
    public let fileSize: Int?
    public let addedAt: Date?
    public let addedByName: String?

    public var id: String { sourceId }
}

/// One entry in `POST /upload`'s `uploaded` array — success has `path`, failure has
/// `error`; neither includes a `source_id`/`track_id` (server-side gap, see README).
public struct UploadResultItem: Codable, Hashable {
    public let filename: String
    public let path: String?
    public let error: String?
}

struct UploadResponse: Decodable {
    let uploaded: [UploadResultItem]
}

struct RenameFileRequest: Encodable {
    let filename: String
}
