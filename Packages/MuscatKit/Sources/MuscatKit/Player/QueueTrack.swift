import Foundation

/// Minimal, source-agnostic view of a track for playback purposes. `Track` (library
/// list), `RawTrack`/`PlaylistTrackEntry` (playlists, favorites), and future sources
/// (radio, search) all carry enough to build one, so the player queue only ever deals
/// with this instead of being tied to one endpoint's response shape.
public struct QueueTrack: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let displayArtist: String
    /// Best available id to pass to `GET /artwork/:id` — album artwork if the track
    /// belongs to one, else the track's own id when it has a generated thumbnail
    /// (see each source type's `artworkId` computed property).
    public let artworkId: String?
    /// Used only if `artworkId` turns out to have no artwork file on disk (the server
    /// checks whatever id it's given against albums/playlists/track thumbnails purely
    /// by id, so an album with no art 404s instead of trying the track's thumbnail).
    public let fallbackArtworkId: String?
    public let duration: Double?

    public init(
        id: String,
        title: String,
        displayArtist: String,
        artworkId: String?,
        fallbackArtworkId: String? = nil,
        duration: Double?
    ) {
        self.id = id
        self.title = title
        self.displayArtist = displayArtist
        self.artworkId = artworkId
        self.fallbackArtworkId = fallbackArtworkId
        self.duration = duration
    }
}

public extension QueueTrack {
    init(_ track: Track) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            duration: track.durationSeconds
        )
    }

    init(_ track: TrackDetail) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            duration: track.durationSeconds
        )
    }

    init(_ track: RawTrack) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            duration: track.durationSeconds
        )
    }

    init(_ track: PlaylistTrackEntry) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            duration: track.durationSeconds
        )
    }
}
