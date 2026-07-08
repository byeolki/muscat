import Foundation

extension APIClient {
    public func fetchAdminUsers() async throws -> [AdminUser] {
        try await send(method: "GET", path: "api/v1/admin/users")
    }

    public func fetchStorageStats() async throws -> StorageStats {
        try await send(method: "GET", path: "api/v1/admin/storage")
    }

    public func fetchLibraryRoots() async throws -> [LibraryRoot] {
        try await send(method: "GET", path: "api/v1/library/roots")
    }

    public func addLibraryRoot(path: String) async throws -> LibraryRoot {
        try await send(
            method: "POST", path: "api/v1/library/roots",
            body: CreateLibraryRootRequest(path: path)
        )
    }

    public func deleteLibraryRoot(id: String) async throws {
        try await sendNoContent(method: "DELETE", path: "api/v1/library/roots/\(id)")
    }

    /// Kicks off an async background scan; returns the job id to poll via
    /// `fetchScanJobs()`/`fetchScanJob(id:)`.
    @discardableResult
    public func triggerLibraryScan(rootId: String) async throws -> String {
        let response: TriggerScanResponse = try await send(
            method: "POST", path: "api/v1/library/roots/\(rootId)/scan"
        )
        return response.jobId
    }

    /// Server orders oldest-first; reverse for a "most recent first" UI.
    public func fetchScanJobs() async throws -> [ScanJob] {
        try await send(method: "GET", path: "api/v1/library/scans")
    }
}
