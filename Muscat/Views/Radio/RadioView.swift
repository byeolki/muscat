import MuscatKit
import SwiftUI

/// Library-based recommendation station. Seed by artist name (simplest entry point —
/// picking a seed track would need a full library picker, deferred for now).
struct RadioView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore

    @State private var seedArtistName = ""
    @State private var stationTracks: [Track] = []
    @State private var loadState = LoadableState<[Track]>()
    @State private var isSaving = false
    @State private var savedMixMessage: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    TextField("", text: $seedArtistName, prompt: fieldPrompt("Artist name (blank = whole library)"))
                        .themedField()
                    Button {
                        Task { await startStation() }
                    } label: {
                        if loadState.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Start Station", systemImage: "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(loadState.isLoading)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !stationTracks.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            playerStore.play(tracks: stationTracks.map { QueueTrack($0) }, startAt: 0)
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SurfaceButtonStyle())

                        Button {
                            Task { await saveMix() }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Save Mix", systemImage: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(isSaving)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(Array(stationTracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            playerStore.play(tracks: stationTracks.map { QueueTrack($0) }, startAt: index)
                        } label: {
                            TrackRowContent(track: track)
                        }
                        .buttonStyle(.plain)
                        .themedRow()
                    }
                } header: {
                    Text("RECOMMENDED TRACKS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextTertiary)
                        .kerning(0.8)
                }
            }

            if let savedMixMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text(savedMixMessage)
                        .font(.footnote)
                }
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            if let errorMessage = loadState.errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle("Radio")
    }

    private func startStation() async {
        savedMixMessage = nil
        let trimmed = seedArtistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await loadState.run {
            try await appEnvironment.apiClient.fetchRadioStation(
                seedArtistName: trimmed.isEmpty ? nil : trimmed
            )
        }
        if let result { stationTracks = result }
    }

    /// Saves the station currently on screen rather than calling `POST /radio/mix`,
    /// which re-runs the seed and returns a freshly randomised selection — the saved
    /// playlist would not have matched what the user just listened to.
    private func saveMix() async {
        isSaving = true
        defer { isSaving = false }
        let trimmed = seedArtistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty
            ? "Mix · \(Date().formatted(date: .abbreviated, time: .omitted))"
            : "\(trimmed) Radio"
        do {
            let playlist = try await appEnvironment.apiClient.createPlaylist(
                name: name,
                description: trimmed.isEmpty ? "Auto-generated mix" : "Radio station seeded from \(trimmed)"
            )
            try await appEnvironment.apiClient.addTracks(
                playlistId: playlist.id, trackIds: stationTracks.map(\.id)
            )
            savedMixMessage = "Saved as playlist \"\(playlist.name)\"."
        } catch {
            loadState.fail(error)
        }
    }
}
