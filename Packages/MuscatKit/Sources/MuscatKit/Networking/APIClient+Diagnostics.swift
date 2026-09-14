import Foundation

public extension APIClient {
    /// Tells the server something went wrong here.
    ///
    /// A failure on a phone is invisible to whoever runs the server, which is why
    /// "it stops playing sometimes" is so hard to act on: the only machine that
    /// saw it had no way to say so. This puts it in the server log.
    ///
    /// Never throws and never retries. A report that fails is not worth a second
    /// failure on top of the first, and reporting must not be able to make the
    /// original problem worse.
    func reportClientError(kind: String, message: String, context: String? = nil) async {
        #if os(iOS)
        let platform = "ios"
        #else
        let platform = "macos"
        #endif
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        struct Report: Encodable {
            let platform: String
            let kind: String
            let message: String
            let context: String?
            let appVersion: String?
        }
        try? await sendNoContent(
            method: "POST",
            path: "api/v1/client-errors",
            body: Report(
                platform: platform,
                kind: String(kind.prefix(200)),
                message: String(message.prefix(2000)),
                context: context.map { String($0.prefix(500)) },
                appVersion: version
            )
        )
    }
}
