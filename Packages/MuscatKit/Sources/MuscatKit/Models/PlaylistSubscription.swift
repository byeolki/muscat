import Foundation

/// Links a playlist to a remote one (a YouTube playlist, a SoundCloud set, ...)
/// that the server polls and appends from. One-way and additive — the server
/// never deletes local tracks because they vanished upstream.
public struct PlaylistSubscription: Codable, Hashable, Identifiable {
    public let playlistId: String
    public let sourceUrl: String
    public let provider: String
    public let audioOnly: Bool
    public let intervalMinutes: Int
    public let enabled: Bool
    public let lastSyncedAt: Date?
    public let lastStatus: SyncStatus?
    public let lastError: String?
    public let addedCount: Int
    public let createdAt: Date

    public var id: String { playlistId }

    public enum SyncStatus: String, Codable {
        case ok
        case failed
        case running
    }

    /// "Every 6 hours", "Once a day" — the same buckets the web dashboard offers.
    public var intervalDescription: String {
        switch intervalMinutes {
        case ..<60: return "Every \(intervalMinutes) minutes"
        case 60: return "Every hour"
        case ..<1440: return "Every \(intervalMinutes / 60) hours"
        case 1440: return "Once a day"
        default: return "Every \(intervalMinutes / 1440) days"
        }
    }
}

/// Result of a manual sync run.
public struct PlaylistSyncResult: Codable, Hashable {
    public let checked: Int
    public let added: Int
    public let skipped: Int
    public let failed: Int
}

struct SetSubscriptionRequest: Encodable {
    let sourceUrl: String
    let intervalMinutes: Int?
    let audioOnly: Bool?
    let enabled: Bool?
}
