import Foundation

/// Persists the user-provided self-hosted server URL. Not sensitive, so UserDefaults
/// (not Keychain) is sufficient here.
public final class ServerConfig: @unchecked Sendable {
    private static let defaultsKey = "podo.serverURL"
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var baseURL: URL? {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let string = defaults.string(forKey: Self.defaultsKey) else { return nil }
            return URL(string: string)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            defaults.set(newValue?.absoluteString, forKey: Self.defaultsKey)
        }
    }

    public var isConfigured: Bool { baseURL != nil }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    /// Normalizes user-entered server URLs: trims whitespace, adds `https://` if the
    /// user typed a bare host, and strips a trailing slash so path-joining stays simple.
    public static func normalize(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard let url = URL(string: trimmed), url.host != nil else { return nil }
        return url
    }
}
