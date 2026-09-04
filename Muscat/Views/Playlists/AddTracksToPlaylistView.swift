import MuscatKit
import SwiftUI

struct AddTracksToPlaylistView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let playlistId: String
    let onAdded: () async -> Void

    @State private var tracks: [Track] = []
    @State private var selectedIds: Set<String> = []
    @State private var loadState = LoadableState<[Track]>()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List(tracks) { track in
                Button {
                    toggle(track.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIds.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selectedIds.contains(track.id) ? Color.appAccent : Color.appTextTertiary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.appTextPrimary)
                            Text(track.displayArtist)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .themedRow()
            }
            .listStyle(.plain)
            .themedList()
            .navigationTitle("Add Tracks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addSelected() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add (\(selectedIds.count))")
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedIds.isEmpty ? Color.appTextTertiary : Color.appAccent)
                        }
                    }
                    .disabled(selectedIds.isEmpty || isSaving)
                }
            }
            .overlay {
                if loadState.isLoading {
                    ProgressView().tint(Color.appAccent)
                } else if let errorMessage = loadState.errorMessage {
                    EmptyStateView(systemImage: "exclamationmark.circle", message: errorMessage)
                }
            }
            .task { await load() }
        }
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    private func load() async {
        if let result = await loadState.run({ try await appEnvironment.apiClient.fetchTracks() }) {
            tracks = result
        }
    }

    private func addSelected() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appEnvironment.apiClient.addTracks(playlistId: playlistId, trackIds: Array(selectedIds))
            await onAdded()
            dismiss()
        } catch {
            loadState.fail(error)
        }
    }
}
