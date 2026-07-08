import MuscatKit
import SwiftUI

/// Row for track lists backed by `RawTrack`/`PlaylistTrackEntry` (favorites, playlists)
/// — no `artists` array or favorite/video flags on these, unlike the library list.
struct RawTrackRowView: View {
    let title: String
    let artist: String?
    let albumVersionId: String?
    let isCover: Bool
    let duration: Double?

    init(track: RawTrack) {
        title = track.title
        artist = track.artist
        albumVersionId = track.albumVersionId
        isCover = track.isCover
        duration = track.durationSeconds
    }

    init(entry: PlaylistTrackEntry) {
        title = entry.title
        artist = entry.artist
        albumVersionId = entry.albumVersionId
        isCover = entry.isCover
        duration = entry.durationSeconds
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: albumVersionId, cornerRadius: 8)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    if isCover {
                        BadgeLabel(text: "COVER")
                    }
                }
                Text((artist?.isEmpty == false ? artist : nil) ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let duration {
                Text(TrackRowView.formatted(duration))
                    .font(.caption)
                    .foregroundStyle(Color.appTextTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
