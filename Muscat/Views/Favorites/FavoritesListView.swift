import MuscatKit
import SwiftUI

struct FavoritesListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var favorites: [FavoriteEntry] = []
    @State private var loadState = LoadableState<[FavoriteEntry]>()
    @State private var detailTrackId: String?

    private var queue: [QueueTrack] {
        favorites.map { QueueTrack($0.track) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(favorites.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 4) {
                        Button {
                            playerStore.play(tracks: queue, startAt: index)
                        } label: {
                            RawTrackRowView(track: entry.track)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            detailTrackId = entry.track.id
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appTextTertiary)
                                .padding(.vertical, 12)
                                .padding(.leading, 6)
                        }
                        .buttonStyle(.plain)
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
            .navigationDestination(item: $detailTrackId) { trackId in
                if let index = favorites.firstIndex(where: { $0.track.id == trackId }) {
                    TrackDetailView(trackId: trackId, queue: queue, index: index, initialIsFavorited: true)
                }
            }
            .overlay {
                if loadState.isLoading && favorites.isEmpty {
                    ProgressView().tint(Color.appAccent)
                } else if favorites.isEmpty {
                    EmptyStateView(systemImage: "heart", message: loadState.errorMessage ?? "No favorited tracks yet.")
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        if let result = await loadState.run({ try await appEnvironment.apiClient.fetchFavorites() }) {
            favorites = result
        }
    }

    private func unfavorite(trackId: String) async {
        do {
            _ = try await appEnvironment.apiClient.removeFavorite(trackId: trackId)
            favorites.removeAll { $0.track.id == trackId }
        } catch {
            loadState.fail(error)
        }
    }
}
