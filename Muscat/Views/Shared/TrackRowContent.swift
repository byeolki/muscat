import MuscatKit
import SwiftUI

/// The one list row for every track-shaped response: artwork, title, artist line,
/// and trailing video/favorite badges plus duration.
///
/// `TrackRowDisplayable` is what makes this single view work across the library
/// list, favorites and playlist entries — those endpoints wrap the row
/// differently but carry the same displayable fields.
struct TrackRowContent: View {
    @Environment(PlayerStore.self) private var playerStore

    let title: String
    let artist: String
    let artworkId: String?
    let fallbackArtworkId: String?
    let isCover: Bool
    /// Who performed this version, when it's a cover — `nil` when that would just
    /// repeat the lead artist.
    let performers: String?
    let duration: Double?
    let hasVideo: Bool
    let isFavorited: Bool
    /// Lets the row recognise itself as the one the player is on. Optional
    /// because `AlbumTrackEntry` rows are built from the field-by-field init.
    let trackId: String?

    init(track: some TrackRowDisplayable) {
        trackId = track.id
        title = track.title
        artist = track.displayArtist
        artworkId = track.artworkId
        fallbackArtworkId = track.fallbackArtworkId
        isCover = track.isCover
        performers = track.coverPerformers
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
        performers: String? = nil,
        duration: Double?,
        hasVideo: Bool = false,
        isFavorited: Bool = false,
        trackId: String? = nil
    ) {
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.artworkId = artworkId
        self.fallbackArtworkId = fallbackArtworkId
        self.isCover = isCover
        self.performers = performers
        self.duration = duration
        self.hasVideo = hasVideo
        self.isFavorited = isFavorited
    }

    /// True when the player is on this exact track — whether or not it is
    /// currently paused.
    private var isCurrent: Bool {
        guard let trackId else { return false }
        return playerStore.currentTrack?.id == trackId
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: artworkId, fallbackArtworkId: fallbackArtworkId, cornerRadius: 8)
                .frame(width: 48, height: 48)
                .overlay {
                    if isCurrent {
                        ZStack {
                            Color.black.opacity(0.55)
                            NowPlayingBars(isAnimating: playerStore.isPlaying)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Color.appAccent : Color.appTextPrimary)
                    .lineLimit(1)
                artistLineText(
                    artist: artist,
                    isCover: isCover,
                    performers: performers
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
                        // Fixed width so the times form a straight column
                        // instead of shifting with each row's badge count.
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [title, artist.isEmpty ? "Unknown Artist" : artist]
        if isCover {
            parts.append(performers.map { "covered by \($0)" } ?? "cover")
        }
        if isFavorited { parts.append("favorited") }
        if isCurrent { parts.append(playerStore.isPlaying ? "now playing" : "paused") }
        return parts.joined(separator: ", ")
    }
}
