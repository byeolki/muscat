import MuscatKit
import SwiftUI

/// Library-based recommendation station. Seed by artist name (simplest entry point —
/// picking a seed track would need a full library picker, deferred for now).
struct RadioView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var seedArtistName = ""
    @State private var stationTracks: [Track] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedMixMessage: String?

    var body: some View {
        List {
            Section {
                TextField("Start a station from an artist name (leave blank for whole library)", text: $seedArtistName)
                Button {
                    Task { await startStation() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Start Station")
                    }
                }
                .disabled(isLoading)
            }

            if !stationTracks.isEmpty {
                Section {
                    Button {
                        playerStore.play(tracks: stationTracks.map { QueueTrack($0) }, startAt: 0)
                    } label: {
                        Label("Play All", systemImage: "play.fill")
                    }
                    Button {
                        Task { await saveMix() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Save as Playlist", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isSaving)
                }

                Section("Recommended Tracks") {
                    ForEach(Array(stationTracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            playerStore.play(tracks: stationTracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            TrackRowView(track: track)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let savedMixMessage {
                Text(savedMixMessage).foregroundStyle(.green)
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Radio")
    }

    private func startStation() async {
        isLoading = true
        errorMessage = nil
        savedMixMessage = nil
        defer { isLoading = false }
        let trimmed = seedArtistName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            stationTracks = try await appEnvironment.apiClient.fetchRadioStation(
                seedArtistName: trimmed.isEmpty ? nil : trimmed
            )
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveMix() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let trimmed = seedArtistName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let playlist = try await appEnvironment.apiClient.createRadioMix(
                seedArtistName: trimmed.isEmpty ? nil : trimmed
            )
            savedMixMessage = "Saved as playlist \"\(playlist.name)\"."
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
