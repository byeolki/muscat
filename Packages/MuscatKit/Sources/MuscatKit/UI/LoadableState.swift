import Foundation
import Observation

/// Replaces the `@State private var isLoading` / `errorMessage` pair + manual
/// `do { ... } catch { errorMessage = ... }` boilerplate that several list/detail
/// views used to hand-roll around their own fetches.
///
/// Usage:
/// ```swift
/// @State private var loadState = LoadableState<[Track]>()
///
/// var body: some View {
///     content
///         .overlay { if loadState.isLoading && tracks.isEmpty { ProgressView() } }
///         .task { await load() }
/// }
///
/// private func load() async {
///     if let result = await loadState.run({ try await apiClient.fetchTracks() }) {
///         tracks = result
///     }
/// }
/// ```
@Observable
@MainActor
public final class LoadableState<Value> {
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?

    public init() {}

    /// Runs `operation`, toggling `isLoading` around it and turning a thrown error into
    /// `errorMessage` (preferring `APIClientError.errorDescription` when available).
    /// Returns the produced value on success, or `nil` on failure.
    @discardableResult
    public func run(_ operation: () async throws -> Value) async -> Value? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await operation()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    /// Records a thrown error's message without touching `isLoading` — for follow-up
    /// mutations (delete/reorder/unfavorite) that run after the initial load.
    public func fail(_ error: Error) {
        errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
    }
}
