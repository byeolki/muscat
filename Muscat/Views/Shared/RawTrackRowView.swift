import MuscatKit
import SwiftUI

/// Row for track lists backed by `RawTrack`/`PlaylistTrackEntry` (favorites, playlists)
/// — no `artists` array or favorite/video flags on these, unlike the library list.
struct RawTrackRowView: View {
    let title: String
    let artist: String?
    let artworkId: String?
    let isCover: Bool
    let duration: Double?

    init(track: RawTrack) {
        title = track.title
        artist = track.artist
        artworkId = track.artworkId
        isCover = track.isCover
        duration = track.durationSeconds
    }

    init(entry: PlaylistTrackEntry) {
        title = entry.title
        artist = entry.artist
        artworkId = entry.artworkId
        isCover = entry.isCover
        duration = entry.durationSeconds
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
                    artist: artist ?? "",
                    isCover: isCover,
                    originalArtist: nil
                )
                .font(.caption)
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
