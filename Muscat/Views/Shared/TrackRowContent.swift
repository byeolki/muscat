import MuscatKit
import SwiftUI

/// Shared row layout for both enriched (`Track`) and raw (`RawTrack`/`PlaylistTrackEntry`)
/// track shapes: artwork, title, artist line, and trailing badges/duration.
/// `TrackRowView` and `RawTrackRowView` are thin wrappers that each pass what their
/// underlying model actually has — raw shapes have no `artists` array or
/// favorite/video flags, so those simply default to absent.
struct TrackRowContent: View {
    let title: String
    let artist: String
    let artworkId: String?
    let isCover: Bool
    let originalArtist: String?
    let duration: Double?
    let hasVideo: Bool
    let isFavorited: Bool

    init(
        title: String,
        artist: String,
        artworkId: String?,
        isCover: Bool,
        originalArtist: String? = nil,
        duration: Double?,
        hasVideo: Bool = false,
        isFavorited: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.artworkId = artworkId
        self.isCover = isCover
        self.originalArtist = originalArtist
        self.duration = duration
        self.hasVideo = hasVideo
        self.isFavorited = isFavorited
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: artworkId, cornerRadius: 8)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                artistLineText(
                    artist: artist,
                    isCover: isCover,
                    originalArtist: originalArtist
                )
                .font(.caption)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if hasVideo {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextTertiary)
                }
                if isFavorited {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.appAccent)
                }
                if let duration {
                    Text(TrackRowView.formatted(duration))
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
