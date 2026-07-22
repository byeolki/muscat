import MuscatKit
import SwiftUI

/// Row for track lists backed by `RawTrack`/`PlaylistTrackEntry` (favorites, playlists).
struct RawTrackRowView: View {
    let title: String
    let artist: String
    let artworkId: String?
    let fallbackArtworkId: String?
    let isCover: Bool
    let originalArtist: String?
    let duration: Double?
    let hasVideo: Bool
    let isFavorited: Bool

    init(track: RawTrack) {
        title = track.title
        artist = track.displayArtist
        artworkId = track.artworkId
        fallbackArtworkId = track.fallbackArtworkId
        isCover = track.isCover
        originalArtist = track.override?.originalArtist
        duration = track.durationSeconds
        hasVideo = track.hasVideo
        isFavorited = track.isFavorited
    }

    init(entry: PlaylistTrackEntry) {
        title = entry.title
        artist = entry.displayArtist
        artworkId = entry.artworkId
        fallbackArtworkId = entry.fallbackArtworkId
        isCover = entry.isCover
        originalArtist = entry.override?.originalArtist
        duration = entry.durationSeconds
        hasVideo = entry.hasVideo
        isFavorited = entry.isFavorited
    }

    var body: some View {
        TrackRowContent(
            title: title,
            artist: artist,
            artworkId: artworkId,
            fallbackArtworkId: fallbackArtworkId,
            isCover: isCover,
            originalArtist: originalArtist,
            duration: duration,
            hasVideo: hasVideo,
            isFavorited: isFavorited
        )
    }
}
