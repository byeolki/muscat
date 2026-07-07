import PodoKit
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
        duration = track.canonicalDuration
    }

    init(entry: PlaylistTrackEntry) {
        title = entry.title
        artist = entry.artist
        albumVersionId = entry.albumVersionId
        isCover = entry.isCover
        duration = entry.canonicalDuration
    }

    var body: some View {
        HStack(spacing: 12) {
            RemoteArtworkView(artworkId: albumVersionId)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.body)
                        .lineLimit(1)
                    if isCover {
                        Text("COVER")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Text((artist?.isEmpty == false ? artist : nil) ?? "알 수 없는 아티스트")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let duration {
                Text(TrackRowView.formatted(duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .contentShape(Rectangle())
    }
}
