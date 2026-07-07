import PodoKit
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
                    .contextMenu {
                        Button {
                            playerStore.play(tracks: tracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            Label("재생", systemImage: "play.fill")
                        }
                    }
                    #if os(iOS)
                    .swipeActions(edge: .leading) {
                        Button {
                            playerStore.play(tracks: tracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            Label("재생", systemImage: "play.fill")
                        }
                        .tint(.accentColor)
                    }
                    #endif
                }
            }
            .navigationTitle("라이브러리")
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
                        Picker("정렬", selection: $sort) {
                            Text("최신순").tag(TrackSort.newest)
                            Text("오래된순").tag(TrackSort.oldest)
                            Text("인기순").tag(TrackSort.popular)
                            Text("재생순").tag(TrackSort.plays)
                        }
                        Picker("필터", selection: $filter) {
                            Text("전체").tag(TrackFilter.all)
                            Text("내가 추가한").tag(TrackFilter.mine)
                            Text("즐겨찾기").tag(TrackFilter.favorites)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if isLoading && tracks.isEmpty {
                    ProgressView()
                } else if let errorMessage, tracks.isEmpty {
                    ContentUnavailableFallback(message: errorMessage)
                } else if tracks.isEmpty {
                    ContentUnavailableFallback(message: "트랙이 없습니다.")
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

/// Small stand-in for `ContentUnavailableView` that also works on macOS 14 without
/// needing the exact SF Symbol configuration APIs to be double-checked offline.
private struct ContentUnavailableFallback: View {
    let message: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}
