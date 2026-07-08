import MuscatKit
import SwiftUI

struct PlaylistListView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var myPlaylists: [Playlist] = []
    @State private var publicPlaylists: [Playlist] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(myPlaylists) { playlist in
                        NavigationLink(value: playlist.id) {
                            PlaylistRow(playlist: playlist)
                        }
                        .themedRow()
                    }
                    if myPlaylists.isEmpty && !isLoading {
                        Text("You have not created any playlists yet.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextTertiary)
                            .themedRow()
                    }
                } header: {
                    sectionHeader("My Playlists")
                }

                if !publicPlaylists.isEmpty {
                    Section {
                        ForEach(publicPlaylists) { playlist in
                            NavigationLink(value: playlist.id) {
                                PlaylistRow(playlist: playlist)
                            }
                            .themedRow()
                        }
                    } header: {
                        sectionHeader("Public Playlists")
                    }
                }

                if let errorMessage {
                    ErrorBanner(message: errorMessage)
                        .themedRow()
                }
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Playlists")
            .navigationDestination(for: String.self) { playlistId in
                PlaylistDetailView(playlistId: playlistId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .overlay {
                if isLoading && myPlaylists.isEmpty && publicPlaylists.isEmpty {
                    ProgressView().tint(Color.appAccent)
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showCreate) {
                CreatePlaylistView { await load() }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let mine = appEnvironment.apiClient.fetchMyPlaylists()
            async let pub = appEnvironment.apiClient.fetchPublicPlaylists()
            myPlaylists = try await mine
            publicPlaylists = try await pub
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct PlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: playlist.id, cornerRadius: 8)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(playlist.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if playlist.isPublic {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextTertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
