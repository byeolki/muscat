import MuscatKit
import SwiftUI

struct SearchView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var query = ""
    @State private var results: SearchResults?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedAlbum: AlbumSheetItem?

    var body: some View {
        NavigationStack {
            List {
                if let tracks = results?.tracks, !tracks.isEmpty {
                    Section("Tracks") {
                        ForEach(tracks) { hit in
                            Button {
                                playerStore.play(
                                    tracks: [QueueTrack(
                                        id: hit.id, title: hit.name, displayArtist: hit.artist ?? "",
                                        albumVersionId: nil, duration: nil
                                    )],
                                    startAt: 0
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.name).foregroundStyle(.primary)
                                    if let artist = hit.artist {
                                        Text(artist).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let artists = results?.artists, !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists) { hit in
                            Button {
                                query = hit.name
                                Task { await runSearch() }
                            } label: {
                                Label(hit.name, systemImage: "person.wave.2")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if let albums = results?.albums, !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums) { hit in
                            Button {
                                selectedAlbum = AlbumSheetItem(id: hit.id)
                            } label: {
                                Label(hit.name, systemImage: "square.stack")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search tracks, artists, albums")
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let results, (results.tracks?.isEmpty ?? true), (results.artists?.isEmpty ?? true), (results.albums?.isEmpty ?? true) {
                    Text("No results found.").foregroundStyle(.secondary)
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await runSearch()
            }
            .sheet(item: $selectedAlbum) { item in
                AlbumTracksSheet(albumId: item.id)
            }
        }
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = nil
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            results = try await appEnvironment.apiClient.search(query: trimmed)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct AlbumSheetItem: Identifiable {
    let id: String
}
