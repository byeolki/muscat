import MuscatKit
import SwiftUI

struct PlaylistDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.editMode) private var editMode
    #endif

    let playlistId: String

    @State private var playlist: PlaylistDetail?
    @State private var loadState = LoadableState<PlaylistDetail>()
    @State private var showAddTracks = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showRadioTokens = false
    @State private var showSync = false
    @State private var favoritesOnly = false

    private var isOwner: Bool {
        guard let playlist, let user = authStore.currentUser else { return false }
        return playlist.ownerUserId == user.id
    }

    private var allEntries: [PlaylistTrackEntry] { playlist?.tracks ?? [] }
    private var favoriteEntries: [PlaylistTrackEntry] { allEntries.filter(\.isFavorited) }

    /// Filtered client-side so the toggle is instant and the queue you play is
    /// exactly the list on screen.
    private var visibleEntries: [PlaylistTrackEntry] {
        favoritesOnly ? favoriteEntries : allEntries
    }

    private var queue: [QueueTrack] {
        visibleEntries.map { QueueTrack($0) }
    }

    private var isAdmin: Bool { authStore.currentUser?.role == .admin }

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    RemoteArtworkView(artworkId: playlistId, cornerRadius: 16)
                        .frame(width: 180, height: 180)
                        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                    VStack(spacing: 5) {
                        Text(playlist?.name ?? "")
                            .font(.title3.bold())
                            .foregroundStyle(Color.appTextPrimary)
                        if let description = playlist?.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        if playlist?.isPublic == true {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                Text("Public")
                            }
                            .font(.caption)
                            .foregroundStyle(Color.appTextTertiary)
                        }
                    }
                    if !favoriteEntries.isEmpty {
                        Picker("", selection: $favoritesOnly) {
                            Text("All \(allEntries.count)").tag(false)
                            Text("Favorites \(favoriteEntries.count)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                    }

                    Button {
                        playerStore.play(tracks: queue, startAt: 0)
                    } label: {
                        Label(favoritesOnly ? "Play Favorites" : "Play All", systemImage: "play.fill")
                    }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(queue.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(visibleEntries) { entry in
                    Button {
                        if let index = visibleEntries.firstIndex(where: { $0.id == entry.id }) {
                            playerStore.play(tracks: queue, startAt: index)
                        }
                    } label: {
                        TrackRowContent(track: entry)
                    }
                    .buttonStyle(.plain)
                    .themedRow()
                }
                // Reordering and deleting index into the full list, so they're
                // only offered when the full list is what's on screen.
                .onDelete(perform: isOwner && !favoritesOnly ? removeTracks : nil)
                .onMove(perform: isOwner && !favoritesOnly ? moveTracks : nil)

                if visibleEntries.isEmpty && !loadState.isLoading {
                    Text(favoritesOnly ? "No favorited tracks in this playlist." : "This playlist is empty.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextTertiary)
                        .themedRow()
                }
            }

            if let errorMessage = loadState.errorMessage {
                ErrorBanner(message: errorMessage)
                    .themedRow()
            }
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle(playlist?.name ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddTracks = true
                    } label: {
                        Label("Add Tracks", systemImage: "plus")
                    }
                    if isOwner {
                        Button {
                            showEdit = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            showRadioTokens = true
                        } label: {
                            Label("Radio URL", systemImage: "dot.radiowaves.left.and.right")
                        }
                        if isAdmin {
                            Button {
                                showSync = true
                            } label: {
                                Label("Auto-sync", systemImage: "arrow.triangle.2.circlepath")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.appAccent)
                }
            }
            #if os(iOS)
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue.isEditing == true ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode?.wrappedValue.isEditing == true ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            #endif
        }
        .overlay {
            if loadState.isLoading && playlist == nil {
                ProgressView().tint(Color.appAccent)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showAddTracks) {
            AddTracksToPlaylistView(playlistId: playlistId) { await load() }
        }
        .sheet(isPresented: $showEdit) {
            if let playlist {
                EditPlaylistView(playlist: playlist) { await load() }
            }
        }
        .sheet(isPresented: $showRadioTokens) {
            RadioTokensView(playlistId: playlistId)
        }
        .sheet(isPresented: $showSync) {
            PlaylistSyncView(playlistId: playlistId) { await load() }
        }
        .confirmationDialog("Delete this playlist?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePlaylist() }
            }
        }
    }

    private func load() async {
        if let result = await loadState.run({ try await appEnvironment.apiClient.fetchPlaylist(id: playlistId) }) {
            playlist = result
        }
    }

    private func removeTracks(at offsets: IndexSet) {
        guard var currentTracks = playlist?.tracks else { return }
        currentTracks.remove(atOffsets: offsets)
        Task { await replaceOrder(with: currentTracks.map(\.id)) }
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        guard var currentTracks = playlist?.tracks else { return }
        currentTracks.move(fromOffsets: source, toOffset: destination)
        Task { await replaceOrder(with: currentTracks.map(\.id)) }
    }

    private func replaceOrder(with trackIds: [String]) async {
        do {
            playlist = try await appEnvironment.apiClient.updatePlaylist(id: playlistId, trackIds: trackIds)
        } catch {
            loadState.fail(error)
            await load()
        }
    }

    private func deletePlaylist() async {
        do {
            try await appEnvironment.apiClient.deletePlaylist(id: playlistId)
            dismiss()
        } catch {
            loadState.fail(error)
        }
    }
}
