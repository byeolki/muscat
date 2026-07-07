import PodoKit
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
                TextField("아티스트 이름으로 스테이션 시작 (비워두면 전체 라이브러리 기반)", text: $seedArtistName)
                Button {
                    Task { await startStation() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("스테이션 시작")
                    }
                }
                .disabled(isLoading)
            }

            if !stationTracks.isEmpty {
                Section {
                    Button {
                        playerStore.play(tracks: stationTracks.map { QueueTrack($0) }, startAt: 0)
                    } label: {
                        Label("전체 재생", systemImage: "play.fill")
                    }
                    Button {
                        Task { await saveMix() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("플레이리스트로 저장", systemImage: "square.and.arrow.down")
                        }
                    }
                    .disabled(isSaving)
                }

                Section("추천 트랙") {
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
        .navigationTitle("라디오")
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
            savedMixMessage = "\"\(playlist.name)\" 플레이리스트로 저장했습니다."
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
