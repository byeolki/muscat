import Foundation

/// What the server makes of a pasted link, before anything is downloaded.
///
/// The distinction that matters is `isPlaylist`: a share link that merely carries
/// `&list=` is one item, while a link that names a collection is the whole thing.
/// Getting that wrong in the UI means someone taps "Add" and pulls two hundred
/// tracks they didn't ask for.
public struct URLInspection: Codable, Hashable, Sendable {
    public let url: String
    public let provider: String
    public let providerLabel: String
    public let isPlaylist: Bool
}

public struct DownloadJob: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let url: String
    public let provider: String
    public let status: Status
    public let progress: Double
    public let completedItems: Int
    public let totalItems: Int?
    public let error: String?
    public let createdAt: Date

    public enum Status: String, Codable, Sendable {
        case pending, running, done, failed
    }

    public var isFinished: Bool { status == .done || status == .failed }

    /// "3 of 12" while a playlist runs, a percentage for a single item.
    public var progressDescription: String {
        if let totalItems, totalItems > 1 {
            return "\(completedItems) of \(totalItems)"
        }
        switch status {
        case .pending: return "Queued"
        case .running: return progress > 0 ? "\(Int(progress))%" : "Starting…"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }
}

/// Result of turning a remote playlist link into a playlist here.
public struct PlaylistImport: Codable, Hashable, Sendable {
    public let playlistId: String
    public let name: String
    public let jobId: String
}

struct StartDownloadRequest: Encodable {
    let url: String
    let audioOnly: Bool
}

struct ImportPlaylistRequest: Encodable {
    let url: String
    let audioOnly: Bool
}
