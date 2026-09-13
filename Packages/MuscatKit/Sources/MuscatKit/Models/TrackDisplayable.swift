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
    /// Who originally performed the song, when this track is a cover of it.
    var originalArtist: String? { get }
    /// Duration as the server stores it: milliseconds. Named explicitly because
    /// the endpoints disagree on whether the field is `duration` or
    /// `canonical_duration`.
    var durationMilliseconds: Double? { get }
}

public extension TrackDisplayable {
    /// The people performing *this* recording — the `artist` override, which for a
    /// cover is whoever covered it.
    var performerNames: String {
        artists.map(\.name).joined(separator: ", ")
    }

    /// The artist a row leads with.
    ///
    /// For a cover that's the artist of the original song, not the performers of
    /// this version. In a library that is mostly covers, the song's own identity
    /// is what you scan a list for — "EXO" tells you which song this is, where
    /// the performers are the variable part and belong after the cover marker.
    var displayArtist: String {
        // A cover with no recorded original leads with nothing rather than with
        // the performer: falling back put whoever covered it in the artist slot,
        // so a track marked "cover, by 윤단" read as though 윤단 were the artist.
        if isCover { return originalArtist?.isEmpty == false ? originalArtist! : "" }
        return performerNames
    }

    /// The performers, but only when they add something the lead artist doesn't
    /// already say — otherwise a cover with no recorded original would render as
    /// "윤단 · covered by 윤단".
    var coverPerformers: String? {
        guard isCover else { return nil }
        let performers = performerNames
        guard !performers.isEmpty, performers != originalArtist else { return nil }
        return performers
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
    var hasVideo: Bool { get }
    var isFavorited: Bool { get }
}
