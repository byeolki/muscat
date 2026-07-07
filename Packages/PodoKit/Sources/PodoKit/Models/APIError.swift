import Foundation

/// Body shape produced by the server's `GlobalExceptionFilter` for every non-2xx response.
/// `message` is a plain string for most errors but becomes an array of strings for
/// class-validator failures, so it needs custom decoding.
struct ErrorResponseBody: Decodable {
    let statusCode: Int
    let message: String
    let timestamp: String?
    let path: String?

    private enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case message, timestamp, path
    }

    init(from decoder: Decoder) throws {
        // NestJS's default is actually `statusCode` (no underscore) even though the rest
        // of the API is snake_case, since it comes from the framework's HttpException,
        // not an application DTO. Try both spellings defensively.
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        self.statusCode = try container.decodeIfPresent(Int.self, forKey: AnyCodingKey("statusCode"))
            ?? container.decodeIfPresent(Int.self, forKey: AnyCodingKey("status_code"))
            ?? 0
        self.timestamp = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("timestamp"))
        self.path = try container.decodeIfPresent(String.self, forKey: AnyCodingKey("path"))

        if let single = try? container.decode(String.self, forKey: AnyCodingKey("message")) {
            self.message = single
        } else if let list = try? container.decode([String].self, forKey: AnyCodingKey("message")) {
            self.message = list.joined(separator: "\n")
        } else {
            self.message = "Unknown error"
        }
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
}

public enum APIClientError: Error, LocalizedError {
    case invalidServerURL
    case notAuthenticated
    case transport(Error)
    case decoding(Error)
    case server(statusCode: Int, message: String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "The server address is invalid."
        case .notAuthenticated:
            return "You need to log in."
        case .transport(let error):
            return error.localizedDescription
        case .decoding:
            return "Couldn't parse the server's response."
        case .server(_, let message):
            return message
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
