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
                VStack(spacing: 12) {
                    TextField("Artist name (blank = whole library)", text: $seedArtistName)
                        .themedField()
                    Button {
                        Task { await startStation() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Start Station", systemImage: "dot.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(isLoading)
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
                            TrackRowView(track: track)
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
            if let errorMessage {
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
