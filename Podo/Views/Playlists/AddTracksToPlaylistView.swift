import PodoKit
import SwiftUI

struct AddTracksToPlaylistView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let playlistId: String
    let onAdded: () async -> Void

    @State private var tracks: [Track] = []
    @State private var selectedIds: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(tracks) { track in
                Button {
                    toggle(track.id)
                } label: {
                    HStack {
                        Image(systemName: selectedIds.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedIds.contains(track.id) ? .accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).foregroundStyle(.primary)
                            Text(track.displayArtist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("트랙 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addSelected() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("추가 (\(selectedIds.count))")
                        }
                    }
                    .disabled(selectedIds.isEmpty || isSaving)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tracks = try await appEnvironment.apiClient.fetchTracks()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func addSelected() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await appEnvironment.apiClient.addTracks(playlistId: playlistId, trackIds: Array(selectedIds))
            await onAdded()
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
