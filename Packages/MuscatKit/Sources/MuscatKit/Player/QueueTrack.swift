import Foundation

/// Minimal, source-agnostic view of a track for playback purposes. `Track` (library
/// list), `RawTrack`/`PlaylistTrackEntry` (playlists, favorites), and future sources
/// (radio, search) all carry enough to build one, so the player queue only ever deals
/// with this instead of being tied to one endpoint's response shape.
public struct QueueTrack: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let displayArtist: String
    /// Who is performing *this* recording.
    ///
    /// Separate from `displayArtist` because the two answer different questions.
    /// A list leads with whose song it is — "EXO" tells you which song a row is.
    /// The lock screen is asking who you are listening to, and for a cover that is
    /// the person who covered it.
    public let performerArtist: String
    /// The full credit for a player screen: whose song it is and who covered it.
    /// A row has room for only one of those; a player has room for both.
    public let artistLine: String
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
        performerArtist: String? = nil,
        artistLine: String? = nil,
        artworkId: String?,
        fallbackArtworkId: String? = nil,
        duration: Double?
    ) {
        self.id = id
        self.title = title
        self.displayArtist = displayArtist
        self.performerArtist = performerArtist?.isEmpty == false ? performerArtist! : displayArtist
        self.artistLine = artistLine?.isEmpty == false ? artistLine! : displayArtist
        self.artworkId = artworkId
        self.fallbackArtworkId = fallbackArtworkId
        self.duration = duration
    }
}

public extension QueueTrack {
    /// Every track-shaped response converts the same way, so one initializer over
    /// `TrackDisplayable` covers the library list, detail, favorites, playlist and
    /// album shapes.
    init(_ track: some TrackDisplayable) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            performerArtist: track.nowPlayingArtist,
            artistLine: track.playerArtistLine,
            artworkId: track.artworkId,
            fallbackArtworkId: track.fallbackArtworkId,
            duration: track.durationSeconds
        )
    }
}
