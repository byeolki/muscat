import PodoKit
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
                Section("My Playlists") {
                    ForEach(myPlaylists) { playlist in
                        NavigationLink(value: playlist.id) {
                            PlaylistRow(playlist: playlist)
                        }
                    }
                    if myPlaylists.isEmpty && !isLoading {
                        Text("You have not created any playlists yet.")
                            .foregroundStyle(.secondary)
                    }
                }
                if !publicPlaylists.isEmpty {
                    Section("Public Playlists") {
                        ForEach(publicPlaylists) { playlist in
                            NavigationLink(value: playlist.id) {
                                PlaylistRow(playlist: playlist)
                            }
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
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
                    }
                }
            }
            .overlay {
                if isLoading && myPlaylists.isEmpty && publicPlaylists.isEmpty {
                    ProgressView()
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showCreate) {
                CreatePlaylistView { await load() }
            }
        }
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
            RemoteArtworkView(artworkId: playlist.id)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name).lineLimit(1)
                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if playlist.isPublic {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
