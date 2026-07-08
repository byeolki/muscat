import Foundation

/// Abstracts token persistence so `APIClient` doesn't need to know tokens live in the
/// Keychain. Conformances must be safe to call from the `APIClient` actor's isolation.
protocol TokenStoring: Sendable {
    func currentTokens() -> TokenPair?
    func save(_ tokens: TokenPair)
    func clear()
}
