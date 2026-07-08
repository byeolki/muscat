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
                    Section {
                        ForEach(tracks) { hit in
                            Button {
                                playerStore.play(
                                    tracks: [QueueTrack(
                                        id: hit.id, title: hit.name, displayArtist: hit.artist ?? "",
                                        artworkId: nil, duration: nil
                                    )],
                                    startAt: 0
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    resultIcon("music.note")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(hit.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appTextPrimary)
                                        if let artist = hit.artist {
                                            Text(artist)
                                                .font(.caption)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .themedRow()
                        }
                    } header: {
                        sectionHeader("Tracks")
                    }
                }

                if let artists = results?.artists, !artists.isEmpty {
                    Section {
                        ForEach(artists) { hit in
                            Button {
                                query = hit.name
                                Task { await runSearch() }
                            } label: {
                                HStack(spacing: 12) {
                                    resultIcon("person.wave.2")
                                    Text(hit.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appTextPrimary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .themedRow()
                        }
                    } header: {
                        sectionHeader("Artists")
                    }
                }

                if let albums = results?.albums, !albums.isEmpty {
                    Section {
                        ForEach(albums) { hit in
                            Button {
                                selectedAlbum = AlbumSheetItem(id: hit.id)
                            } label: {
                                HStack(spacing: 12) {
                                    resultIcon("square.stack")
                                    Text(hit.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(Color.appTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(Color.appTextTertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .themedRow()
                        }
                    } header: {
                        sectionHeader("Albums")
                    }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .themedRow()
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Search tracks, artists, albums")
            .overlay {
                if isLoading {
                    ProgressView().tint(Color.appAccent)
                } else if let results,
                          (results.tracks?.isEmpty ?? true),
                          (results.artists?.isEmpty ?? true),
                          (results.albums?.isEmpty ?? true) {
                    EmptyStateView(systemImage: "magnifyingglass", message: "No results found.")
                } else if results == nil {
                    EmptyStateView(systemImage: "magnifyingglass", message: "Search your library.")
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

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
    }

    private func resultIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15))
            .foregroundStyle(Color.appTextTertiary)
            .frame(width: 36, height: 36)
            .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
