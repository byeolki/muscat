import Foundation

public struct AdminUser: Codable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let email: String
    public let role: UserRole
    public let createdAt: Date
}

public struct DirectoryStat: Codable, Hashable {
    public let path: String
    public let sizeBytes: Int
}

public struct DiskStat: Codable, Hashable {
    public let totalBytes: Int
    public let freeBytes: Int
    public let usedBytes: Int
}

public struct StorageStats: Codable, Hashable {
    public let uploadDir: DirectoryStat
    public let artworkDir: DirectoryStat
    public let transcodeCache: DirectoryStat
    public let disk: DiskStat
}

public struct InviteResponse: Codable {
    public let inviteToken: String
}

struct CreateLibraryRootRequest: Encodable {
    let path: String
}

public struct LibraryRoot: Codable, Hashable, Identifiable {
    public let id: String
    public let path: String
    public let enabled: Bool
    public let lastScanAt: Date?
    public let createdAt: Date
}

struct TriggerScanResponse: Decodable {
    let jobId: String
}

public enum ScanStatus: String, Codable {
    case running
    case completed
    case failed
}

/// `getScanJob` returns an empty body (not a 404) for an unknown id — decode failures
/// on a single lookup should be treated as "not found" rather than surfaced as errors.
public struct ScanJob: Codable, Hashable, Identifiable {
    public let id: String
    public let libraryRootId: String?
    public let status: ScanStatus
    public let totalFiles: Int
    public let processedFiles: Int
    public let added: Int
    public let updated: Int
    public let removed: Int
    public let error: String?
    public let startedAt: Date
    public let finishedAt: Date?
}
