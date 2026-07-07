import PodoKit
import SwiftUI

struct TrackRowView: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(albumVersionId: track.albumVersionId)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)
                    if track.isCover {
                        Text("COVER")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(track.displayArtist.isEmpty ? "알 수 없는 아티스트" : track.displayArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if track.hasVideo {
                Image(systemName: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if track.isFavorited {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let duration = track.duration {
                Text(Self.formatted(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
    }

    static func formatted(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
