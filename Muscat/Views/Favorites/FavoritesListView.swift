import MuscatKit
import SwiftUI

struct FavoritesListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var favorites: [FavoriteEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var queue: [QueueTrack] {
        favorites.map { QueueTrack($0.track) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(favorites.enumerated()), id: \.element.id) { index, entry in
                    NavigationLink(value: entry.track.id) {
                        RawTrackRowView(track: entry.track)
                    }
                    .themedRow()
                    .contextMenu {
                        Button {
                            playerStore.play(tracks: queue, startAt: index)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        Button(role: .destructive) {
                            Task { await unfavorite(trackId: entry.track.id) }
                        } label: {
                            Label("Remove Favorite", systemImage: "heart.slash")
                        }
                    }
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Favorites")
            .navigationDestination(for: String.self) { trackId in
                if let index = favorites.firstIndex(where: { $0.track.id == trackId }) {
                    TrackDetailView(trackId: trackId, queue: queue, index: index, initialIsFavorited: true)
                }
            }
            .overlay {
                if isLoading && favorites.isEmpty {
                    ProgressView().tint(Color.appAccent)
                } else if favorites.isEmpty {
                    EmptyStateView(systemImage: "heart", message: errorMessage ?? "No favorited tracks yet.")
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            favorites = try await appEnvironment.apiClient.fetchFavorites()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func unfavorite(trackId: String) async {
        do {
            _ = try await appEnvironment.apiClient.removeFavorite(trackId: trackId)
            favorites.removeAll { $0.track.id == trackId }
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
