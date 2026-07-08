import Foundation

extension APIClient {
    /// Any authenticated user may upload (not admin-only, despite living next to admin
    /// features in the UI). Allowed extensions: mp3/m4a/flac/aac/wav/ogg/opus/mp4/m4v/mkv,
    /// 500MB max. The server doesn't return the new `source_id`/`track_id` — call
    /// `fetchMyUploadedFiles()` afterward to resolve them.
    public func uploadFile(data: Data, filename: String, mimeType: String) async throws -> [UploadResultItem] {
        let response: UploadResponse = try await sendMultipart(
            path: "api/v1/upload", fieldName: "file", filename: filename, mimeType: mimeType, fileData: data
        )
        return response.uploaded
    }

    public func fetchMyUploadedFiles() async throws -> [UploadedFileEntry] {
        try await send(method: "GET", path: "api/v1/upload/files")
    }

    /// Server responds with an empty 200 body (not 204) — `sendNoContent` ignores the
    /// body either way, so this is safe.
    public func renameUploadedFile(sourceId: String, filename: String) async throws {
        try await sendNoContent(
            method: "PATCH", path: "api/v1/upload/files/\(sourceId)",
            body: RenameFileRequest(filename: filename)
        )
    }

    public func deleteUploadedFile(sourceId: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/upload/files/\(sourceId)")
    }
}
