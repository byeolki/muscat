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
        ZStack {
            Color.appBackground.ignoresSafeArea()
            // Soft accent glow behind the artwork so the screen isn't a flat void.
            RadialGradient(
                colors: [Color.appAccent.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let track = playerStore.currentTrack {
                    Spacer(minLength: 12)

                    RemoteArtworkView(artworkId: track.artworkId, fallbackArtworkId: track.fallbackArtworkId, cornerRadius: 20)
                        .frame(width: 300, height: 300)
                        .shadow(color: .black.opacity(0.55), radius: 28, y: 14)

                    Spacer(minLength: 12)

                    VStack(spacing: 6) {
                        Text(track.title)
                            .font(.title2.bold())
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(track.displayArtist)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 28)

                    scrubber
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                    transportControls
                        .padding(.top, 18)

                    if let errorMessage = playerStore.errorMessage {
                        ErrorBanner(message: errorMessage)
                            .padding(.horizontal, 28)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 28)
                } else {
                    Spacer()
                    EmptyStateView(systemImage: "music.note", message: "Nothing is playing.")
                    Spacer()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 640)
        #endif
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 34, height: 34)
                    .background(Color.appSurfaceRaised, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Now Playing")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextTertiary)
                .kerning(1.2)
                .textCase(.uppercase)

            Spacer()

            // Balances the close button so the title stays centered.
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var scrubber: some View {
        VStack(spacing: 6) {
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
            .tint(Color.appAccent)

            HStack {
                Text(TrackRowView.formatted(scrubPosition ?? playerStore.currentSeconds))
                Spacer()
                Text(TrackRowView.formatted(playerStore.duration ?? 0))
            }
            .font(.caption)
            .foregroundStyle(Color.appTextTertiary)
            .monospacedDigit()
        }
    }

    private var transportControls: some View {
        HStack(spacing: 0) {
            Button {
                playerStore.cycleRepeatMode()
            } label: {
                Image(systemName: playerStore.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(playerStore.repeatMode == .off ? Color.appTextTertiary : Color.appAccent)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }

            Spacer()

            Button {
                playerStore.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(canGoBack ? Color.appTextPrimary : Color.appTextTertiary)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)

            Spacer()

            Button {
                playerStore.togglePlayPause()
            } label: {
                Image(systemName: playerStore.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 72, height: 72)
                    .background(Color.appAccent, in: Circle())
                    .shadow(color: Color.appAccent.opacity(0.35), radius: 16, y: 4)
            }

            Spacer()

            Button {
                playerStore.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(playerStore.hasNext ? Color.appTextPrimary : Color.appTextTertiary)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .disabled(!playerStore.hasNext)

            Spacer()

            // Balances the repeat button so play stays visually centered.
            Color.clear.frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
    }

    private var canGoBack: Bool {
        playerStore.hasPrevious || playerStore.currentSeconds > 3
    }
}
