import Foundation

/// The Muscat server emits snake_case JSON everywhere and dates as ISO-8601 strings
/// with millisecond fractional seconds (`Date.prototype.toJSON()` in Node). Foundation's
/// built-in `.iso8601` strategy only parses whole-second precision, so decoding/encoding
/// go through these shared formatters instead of relying on the default strategies.
enum MuscatDateCoding {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decode(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let date = withFractionalSeconds.date(from: string) {
            return date
        }
        if let date = withoutFractionalSeconds.date(from: string) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected ISO-8601 date string, got \(string)"
        )
    }

    static func encode(_ date: Date, to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(withFractionalSeconds.string(from: date))
    }
}

extension JSONDecoder {
    /// Configured for every Muscat API response: snake_case keys, fractional ISO-8601 dates.
    static var muscat: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { try MuscatDateCoding.decode($0) }
        return decoder
    }
}

extension JSONEncoder {
    /// Configured for every Muscat API request body: snake_case keys, fractional ISO-8601 dates.
    static var muscat: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { try MuscatDateCoding.encode($0, to: $1) }
        return encoder
    }
}
