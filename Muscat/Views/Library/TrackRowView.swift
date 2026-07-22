import MuscatKit
import SwiftUI

struct TrackRowView: View {
    let track: Track

    var body: some View {
        TrackRowContent(
            title: track.title,
            artist: track.displayArtist,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            isCover: track.isCover,
            originalArtist: track.override?.originalArtist,
            duration: track.durationSeconds,
            hasVideo: track.hasVideo,
            isFavorited: track.isFavorited
        )
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
