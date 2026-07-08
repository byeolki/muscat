import Foundation

/// `GET /health` — bare route, no `/api/v1` prefix, `@Public`.
public struct HealthResponse: Codable {
    public let status: String
    public let timestamp: Date
}
