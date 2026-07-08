import MuscatKit
import SwiftUI

struct TrackListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var tracks: [Track] = []
    @State private var sort: TrackSort = .newest
    @State private var filter: TrackFilter = .all
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    NavigationLink(value: track.id) {
                        TrackRowView(track: track)
                    }
                    .themedRow()
                    .contextMenu {
                        Button {
                            playerStore.play(tracks: tracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                    }
                    #if os(iOS)
                    .swipeActions(edge: .leading) {
                        Button {
                            playerStore.play(tracks: tracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            Label("Play", systemImage: "play.fill")
                        }
                        .tint(.appAccent)
                    }
                    #endif
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Library")
            .navigationDestination(for: String.self) { trackId in
                if let index = tracks.firstIndex(where: { $0.id == trackId }) {
                    TrackDetailView(
                        trackId: trackId,
                        queue: tracks.map { QueueTrack($0) },
                        index: index,
                        initialIsFavorited: tracks[index].isFavorited
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            Text("Newest").tag(TrackSort.newest)
                            Text("Oldest").tag(TrackSort.oldest)
                            Text("Most Favorited").tag(TrackSort.popular)
                            Text("Most Played").tag(TrackSort.plays)
                        }
                        Picker("Filter", selection: $filter) {
                            Text("All").tag(TrackFilter.all)
                            Text("Added by Me").tag(TrackFilter.mine)
                            Text("Favorites").tag(TrackFilter.favorites)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .overlay {
                if isLoading && tracks.isEmpty {
                    ProgressView().tint(Color.appAccent)
                } else if let errorMessage, tracks.isEmpty {
                    EmptyStateView(systemImage: "exclamationmark.circle", message: errorMessage)
                } else if tracks.isEmpty {
                    EmptyStateView(systemImage: "music.note.list", message: "No tracks yet.")
                }
            }
            .refreshable { await load() }
            .task(id: "\(sort.rawValue)-\(filter.rawValue)") { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tracks = try await appEnvironment.apiClient.fetchTracks(sort: sort, filter: filter)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
