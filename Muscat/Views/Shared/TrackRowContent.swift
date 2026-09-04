import MuscatKit
import SwiftUI

/// The one list row for every track-shaped response: artwork, title, artist line,
/// and trailing video/favorite badges plus duration.
///
/// `TrackRowDisplayable` is what makes this single view work across the library
/// list, favorites and playlist entries — those endpoints wrap the row
/// differently but carry the same displayable fields.
struct TrackRowContent: View {
    let title: String
    let artist: String
    let artworkId: String?
    let fallbackArtworkId: String?
    let isCover: Bool
    let originalArtist: String?
    let duration: Double?
    let hasVideo: Bool
    let isFavorited: Bool

    init(track: some TrackRowDisplayable) {
        title = track.title
        artist = track.displayArtist
        artworkId = track.artworkId
        fallbackArtworkId = track.fallbackArtworkId
        isCover = track.isCover
        originalArtist = track.originalArtist
        duration = track.durationSeconds
        hasVideo = track.hasVideo
        isFavorited = track.isFavorited
    }

    /// For shapes that aren't full row models — e.g. `AlbumTrackEntry`, which the
    /// album endpoint returns without favorite/video state.
    init(
        title: String,
        artist: String,
        artworkId: String?,
        fallbackArtworkId: String? = nil,
        isCover: Bool,
        originalArtist: String? = nil,
        duration: Double?,
        hasVideo: Bool = false,
        isFavorited: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.artworkId = artworkId
        self.fallbackArtworkId = fallbackArtworkId
        self.isCover = isCover
        self.originalArtist = originalArtist
        self.duration = duration
        self.hasVideo = hasVideo
        self.isFavorited = isFavorited
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: artworkId, fallbackArtworkId: fallbackArtworkId, cornerRadius: 8)
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
                    Text(formattedDuration(duration))
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
