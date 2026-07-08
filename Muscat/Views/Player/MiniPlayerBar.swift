import MuscatKit
import SwiftUI

/// Floating glass pill above the tab bar with a hairline progress indicator along its
/// bottom edge. Tap anywhere (outside the transport buttons) to open Now Playing.
///
/// Uses `.ultraThinMaterial` rather than the iOS 26 `glassEffect()` API — the latter
/// needs the iOS 26 SDK to even compile, and this environment can't confirm which
/// Xcode/SDK the project builds against, so a guaranteed-available frosted-glass look
/// is the safer bet. Visually it's the same "translucent, blurred, thin light rim"
/// language as the system's Liquid Glass tab bar; matching outer corner radius +
/// horizontal margin (see `MainTabView.tabBarMargin`) is what actually keeps the two
/// bars visually unified.
struct MiniPlayerBar: View {
    @Environment(PlayerStore.self) private var playerStore
    let onTap: () -> Void

    static let cornerRadius: CGFloat = 24

    private var progress: Double {
        guard let duration = playerStore.duration, duration > 0 else { return 0 }
        return min(max(playerStore.currentSeconds / duration, 0), 1)
    }

    var body: some View {
        if let track = playerStore.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RemoteArtworkView(artworkId: track.artworkId, cornerRadius: 10)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                        Text(track.displayArtist)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Button {
                        playerStore.togglePlayPause()
                    } label: {
                        Image(systemName: playerStore.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        playerStore.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(playerStore.hasNext ? Color.appTextPrimary : Color.appTextTertiary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!playerStore.hasNext)
                }
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 8)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }
}
