import MuscatKit
import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    /// Local scrub position while dragging — avoids fighting the engine's periodic
    /// updates mid-gesture.
    @State private var scrubPosition: Double?
    @State private var isScrubbing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let track = playerStore.currentTrack {
                    RemoteArtworkView(artworkId: track.albumVersionId, cornerRadius: 16)
                        .frame(width: 280, height: 280)
                        .padding(.top, 24)

                    VStack(spacing: 6) {
                        Text(track.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(track.displayArtist)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { scrubPosition ?? playerStore.currentSeconds },
                                set: { scrubPosition = $0 }
                            ),
                            in: 0...(max(playerStore.duration ?? 1, 1)),
                            onEditingChanged: { editing in
                                isScrubbing = editing
                                if !editing, let scrubPosition {
                                    Task {
                                        await playerStore.seek(toSeconds: scrubPosition)
                                        self.scrubPosition = nil
                                    }
                                }
                            }
                        )
                        HStack {
                            Text(TrackRowView.formatted(scrubPosition ?? playerStore.currentSeconds))
                            Spacer()
                            Text(TrackRowView.formatted(playerStore.duration ?? 0))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                    .padding(.horizontal)

                    HStack(spacing: 40) {
                        Button {
                            playerStore.skipToPrevious()
                        } label: {
                            Image(systemName: "backward.fill").font(.title)
                        }
                        .disabled(!playerStore.hasPrevious && playerStore.currentSeconds <= 3)

                        Button {
                            playerStore.togglePlayPause()
                        } label: {
                            Image(systemName: playerStore.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 56))
                        }

                        Button {
                            playerStore.skipToNext()
                        } label: {
                            Image(systemName: "forward.fill").font(.title)
                        }
                        .disabled(!playerStore.hasNext)

                        Button {
                            playerStore.cycleRepeatMode()
                        } label: {
                            Image(systemName: playerStore.repeatMode == .one ? "repeat.1" : "repeat")
                                .font(.title2)
                                .foregroundStyle(playerStore.repeatMode == .off ? .secondary : Color.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    if let errorMessage = playerStore.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } else {
                    Text("Nothing is playing.")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
