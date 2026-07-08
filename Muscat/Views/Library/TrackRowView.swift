import MuscatKit
import SwiftUI

struct TrackRowView: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: track.artworkId, cornerRadius: 8)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                artistLineText(
                    artist: track.displayArtist,
                    isCover: track.isCover,
                    originalArtist: track.override?.originalArtist
                )
                .font(.caption)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if track.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextTertiary)
                }
                if track.isFavorited {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
                if let duration = track.durationSeconds {
                    Text(Self.formatted(duration))
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    static func formatted(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Small uppercase chip used for track markers (COVER, etc).
struct BadgeLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.appAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
