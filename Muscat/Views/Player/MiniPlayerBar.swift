import MuscatKit
import SwiftUI

/// Floating card above the tab bar with a hairline progress indicator along its
/// bottom edge. Tap anywhere (outside the transport buttons) to open Now Playing.
struct MiniPlayerBar: View {
    @Environment(PlayerStore.self) private var playerStore
    let onTap: () -> Void

    private var progress: Double {
        guard let duration = playerStore.duration, duration > 0 else { return 0 }
        return min(max(playerStore.currentSeconds / duration, 0), 1)
    }

    var body: some View {
        if let track = playerStore.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    RemoteArtworkView(artworkId: track.artworkId, cornerRadius: 8)
                        .frame(width: 42, height: 42)

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
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        playerStore.skipToNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(playerStore.hasNext ? Color.appTextPrimary : Color.appTextTertiary)
                            .frame(width: 38, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!playerStore.hasNext)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.appBorder)
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }
}
