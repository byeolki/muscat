import MuscatKit
import SwiftUI

struct PlaylistDetailView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    let playlistId: String

    @State private var playlist: PlaylistDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddTracks = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var showRadioTokens = false

    private var isOwner: Bool {
        guard let playlist, let user = authStore.currentUser else { return false }
        return playlist.ownerUserId == user.id
    }

    private var queue: [QueueTrack] {
        (playlist?.tracks ?? []).map { QueueTrack($0) }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    RemoteArtworkView(artworkId: playlistId, cornerRadius: 12)
                        .frame(width: 160, height: 160)
                    VStack(spacing: 4) {
                        Text(playlist?.name ?? "")
                            .font(.title3.bold())
                        if let description = playlist?.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        playerStore.play(tracks: queue, startAt: 0)
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(queue.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(playlist?.tracks ?? []) { entry in
                    Button {
                        if let index = playlist?.tracks.firstIndex(where: { $0.id == entry.id }) {
                            playerStore.play(tracks: queue, startAt: index)
                        }
                    } label: {
                        RawTrackRowView(entry: entry)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: isOwner ? removeTracks : nil)
                .onMove(perform: isOwner ? moveTracks : nil)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
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
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #if os(iOS)
            if isOwner {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            #endif
        }
        .overlay {
            if isLoading && playlist == nil {
                ProgressView()
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
        .confirmationDialog("Delete this playlist?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePlaylist() }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            playlist = try await appEnvironment.apiClient.fetchPlaylist(id: playlistId)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
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
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
            await load()
        }
    }

    private func deletePlaylist() async {
        do {
            try await appEnvironment.apiClient.deletePlaylist(id: playlistId)
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
