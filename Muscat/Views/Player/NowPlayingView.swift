import MuscatKit
import SwiftUI

struct NowPlayingView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Local scrub position while dragging — avoids fighting the engine's periodic
    /// updates mid-gesture.
    @State private var scrubPosition: Double?
    @State private var isScrubbing = false
    @State private var showSleepTimer = false
    /// Ticks once a second purely to redraw the countdown chip.
    @State private var now = Date()
    /// Colour pulled from the current artwork; nil until it resolves, and on a
    /// cover we can't read.
    @State private var palette: ArtworkPalette?

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                if let track = playerStore.currentTrack {
                    Spacer(minLength: 12)
                    artwork(for: track)
                    Spacer(minLength: 12)

                    titleBlock(for: track)
                        .padding(.horizontal, 32)

                    scrubber
                        .padding(.horizontal, 32)
                        .padding(.top, 22)

                    transportControls
                        .padding(.top, 10)

                    secondaryControls
                        .padding(.top, 18)

                    if let errorMessage = playerStore.errorMessage {
                        ErrorBanner(message: errorMessage)
                            .padding(.horizontal, 32)
                            .padding(.top, 14)
                    }
                } else {
                    Spacer()
                    EmptyStateView(systemImage: "music.note", message: "Nothing is playing.")
                    Spacer()
                }
            }
            .padding(.bottom, 26)
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 700)
        #endif
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now = $0 }
        .task(id: playerStore.currentTrack?.artworkId) { await loadPalette() }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerSheet(
                current: playerStore.sleepTimer,
                remainingLabel: sleepTimerLabel,
                onSelect: { playerStore.setSleepTimer($0) }
            )
        }
    }

    // MARK: - Background

    /// The artwork's own colour, faded into the app background.
    ///
    /// This screen used to be flat black with a fixed accent glow, which made
    /// every track look identical and left the cover floating in a void. Washing
    /// the top of the screen in a colour taken from the cover is what ties the
    /// two together; the wash is deliberately dark and desaturated (see
    /// `ArtworkPaletteLoader`) so white text stays readable over it.
    private var background: some View {
        ZStack {
            Color.appBackground
            LinearGradient(
                stops: [
                    // Three stops rather than two: a straight fade to the
                    // background colour leaves a visible band where it lands.
                    .init(color: washColor.opacity(palette == nil ? 0.10 : 0.66), location: 0),
                    .init(color: washColor.opacity(palette == nil ? 0.04 : 0.24), location: 0.42),
                    .init(color: .clear, location: 0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: palette)
    }

    private var washColor: Color { palette?.color ?? Color.appAccent }

    private func loadPalette() async {
        guard let artworkId = playerStore.currentTrack?.artworkId,
              let url = await appEnvironment.apiClient.artworkURL(id: artworkId) else {
            palette = nil
            return
        }
        palette = await ArtworkPaletteLoader.shared.palette(for: url)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Text("Now Playing")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .kerning(1.4)
                .textCase(.uppercase)

            Spacer()

            // Balances the close button so the title stays centered.
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    /// Shrinks while paused, the way the platform music apps do — it makes the
    /// play state readable from across a room, without another indicator.
    private func artwork(for track: QueueTrack) -> some View {
        RemoteArtworkView(
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            cornerRadius: 18
        )
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 340)
        .shadow(color: .black.opacity(0.5), radius: 30, y: 16)
        .scaleEffect(playerStore.isPlaying ? 1 : 0.88)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.78), value: playerStore.isPlaying)
        .padding(.horizontal, 32)
    }

    private func titleBlock(for track: QueueTrack) -> some View {
        VStack(spacing: 5) {
            Text(track.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(track.displayArtist)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
        }
    }

    private var scrubber: some View {
        VStack(spacing: 2) {
            ScrubBar(
                value: Binding(
                    get: { scrubPosition ?? playerStore.currentSeconds },
                    set: { scrubPosition = $0 }
                ),
                in: 0...scrubUpperBound,
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
                Text(formattedDuration(scrubPosition ?? playerStore.currentSeconds))
                Spacer()
                Text("-" + formattedDuration(max((playerStore.duration ?? 0) - (scrubPosition ?? playerStore.currentSeconds), 0)))
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.appTextTertiary)
            .monospacedDigit()
        }
    }

    /// Transport only. Repeat, loudness and the sleep timer used to sit in this
    /// same row, which made six controls of three different kinds compete for
    /// the same emphasis; they're a subordinate row now.
    private var transportControls: some View {
        HStack(spacing: 28) {
            Button {
                playerStore.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(canGoBack ? Color.appTextPrimary : Color.appTextTertiary)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Previous track")

            Button {
                playerStore.togglePlayPause()
            } label: {
                Image(systemName: playerStore.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 74, height: 74)
                    .background(Color.appAccent, in: Circle())
            }
            .accessibilityLabel(playerStore.isPlaying ? "Pause" : "Play")

            Button {
                playerStore.skipToNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(playerStore.hasNext ? Color.appTextPrimary : Color.appTextTertiary)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .disabled(!playerStore.hasNext)
            .accessibilityLabel("Next track")
        }
        .buttonStyle(.plain)
    }

    private var secondaryControls: some View {
        HStack(spacing: 0) {
            secondaryButton(
                systemImage: playerStore.repeatMode == .one ? "repeat.1" : "repeat",
                label: repeatLabel,
                isOn: playerStore.repeatMode != .off,
                accessibilityLabel: "Repeat, \(repeatLabel)"
            ) {
                playerStore.cycleRepeatMode()
            }

            secondaryButton(
                systemImage: "waveform",
                label: "Loudness",
                isOn: playerStore.normalize,
                accessibilityLabel: "Normalize volume"
            ) {
                playerStore.toggleNormalize()
            }

            secondaryButton(
                systemImage: playerStore.sleepTimer.isActive ? "moon.fill" : "moon",
                label: sleepTimerLabel ?? "Sleep",
                isOn: playerStore.sleepTimer.isActive,
                accessibilityLabel: "Sleep timer"
            ) {
                showSleepTimer = true
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
    }

    private func secondaryButton(
        systemImage: String,
        label: String,
        isOn: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(isOn ? Color.appAccent : Color.appTextTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var repeatLabel: String {
        switch playerStore.repeatMode {
        case .off: return "Repeat"
        case .all: return "All"
        case .one: return "One"
        }
    }

    /// "23m" for a deadline, "End" for end-of-track, nothing when off. Reads
    /// `now` so the SwiftUI dependency on the 1s ticker is explicit.
    private var sleepTimerLabel: String? {
        switch playerStore.sleepTimer {
        case .off:
            return nil
        case .endOfTrack:
            return "End"
        case .at(let deadline):
            let minutes = max(0, Int((deadline.timeIntervalSince(now) / 60).rounded(.up)))
            return "\(minutes)m"
        }
    }

    /// `Swift.max` doesn't reliably reject a `NaN` operand, and a range whose
    /// upper bound is `NaN` is not a valid range at all.
    private var scrubUpperBound: Double {
        guard let duration = playerStore.duration, duration.isFinite, duration > 0 else { return 1 }
        return duration
    }

    private var canGoBack: Bool {
        playerStore.hasPrevious || playerStore.currentSeconds > 3
    }
}

/// The sleep timer options.
///
/// This was a `confirmationDialog`, which tints every button with the app accent
/// — six identical lime rows with no indication of which one was running. A
/// sheet can show the active option and the time left, and keeps the
/// destructive "off" action visually separate.
private struct SleepTimerSheet: View {
    let current: SleepTimer
    let remainingLabel: String?
    let onSelect: (SleepTimer) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.appBorder)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            VStack(spacing: 4) {
                Text("Sleep timer")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text(current.isActive
                     ? "Stops in \(remainingLabel ?? "a moment")"
                     : "Stop playback automatically")
                    .font(.footnote)
                    .foregroundStyle(current.isActive ? Color.appAccent : Color.appTextSecondary)
            }
            .padding(.top, 18)
            .padding(.bottom, 18)

            VStack(spacing: 0) {
                ForEach(SleepTimer.presetMinutes, id: \.self) { minutes in
                    row(title: "\(minutes) minutes", option: .minutes(minutes))
                    Divider().overlay(Color.appBorder)
                }
                row(title: "End of this track", option: .endOfTrack)
            }
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 18)

            if current.isActive {
                Button {
                    onSelect(.off)
                    dismiss()
                } label: {
                    Text("Turn off")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.appDanger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity)
        .themedScreen()
        .presentationDetents([.height(current.isActive ? 432 : 360)])
        #if os(iOS)
        .presentationBackground(Color.appBackground)
        #endif
    }

    private func row(title: String, option: SleepTimer) -> some View {
        Button {
            onSelect(option)
            dismiss()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                if isSelected(option) {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Only end-of-track is checkable: a running timer is stored as an absolute
    /// deadline (`SleepTimer.at`), so which preset started it isn't recoverable
    /// once any time has passed. The header carries the remaining time instead.
    private func isSelected(_ option: SleepTimer) -> Bool {
        current == .endOfTrack && option == .endOfTrack
    }
}
