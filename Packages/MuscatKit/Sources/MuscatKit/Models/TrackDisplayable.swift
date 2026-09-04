import Foundation

/// Common surface of every track-shaped response the server returns: the library
/// list (`Track`), the detail view (`TrackDetail`), favorites (`RawTrack`),
/// playlist entries (`PlaylistTrackEntry`) and album entries (`AlbumTrackEntry`).
///
/// Those five types exist because the endpoints wrap and enrich the row
/// differently, not because the display logic differs — so title/artist/artwork
/// resolution lives here once instead of being copy-pasted onto each model.
public protocol TrackDisplayable {
    var id: String { get }
    var title: String { get }
    var albumVersionId: String? { get }
    var thumbnailPath: String? { get }
    /// Override-resolved artist names, already split by the server.
    var artists: [ArtistRef] { get }
    var isCover: Bool { get }
    /// Duration as the server stores it: milliseconds. Named explicitly because
    /// the endpoints disagree on whether the field is `duration` or
    /// `canonical_duration`.
    var durationMilliseconds: Double? { get }
}

public extension TrackDisplayable {
    /// Comma-joined, override-resolved artist names — safe for display.
    var displayArtist: String {
        artists.map(\.name).joined(separator: ", ")
    }

    var durationSeconds: Double? {
        durationMilliseconds.map { $0 / 1000 }
    }

    /// Best id to pass to `GET /artwork/:id`: album artwork first, else the
    /// track's own id when it has a generated thumbnail.
    var artworkId: String? {
        albumVersionId ?? (thumbnailPath != nil ? id : nil)
    }

    /// Used only if `artworkId` turns out to have no artwork file on disk. The
    /// server resolves whatever id it's given against albums, then playlists,
    /// then track thumbnails, purely by id — it has no idea `albumVersionId` was
    /// meant to be "the" artwork, so an album with no art on disk 404s instead of
    /// silently trying the track's own thumbnail. Only meaningful when it differs
    /// from `artworkId`.
    var fallbackArtworkId: String? {
        guard albumVersionId != nil, thumbnailPath != nil else { return nil }
        return id
    }
}

/// A `TrackDisplayable` that also carries the per-user/per-source flags a list row
/// renders — everything except `AlbumTrackEntry`, which the album endpoint returns
/// without override or favorite data.
public protocol TrackRowDisplayable: TrackDisplayable {
    /// Who originally performed the song, when this track is a cover of it.
    var originalArtist: String? { get }
    var hasVideo: Bool { get }
    var isFavorited: Bool { get }
}
