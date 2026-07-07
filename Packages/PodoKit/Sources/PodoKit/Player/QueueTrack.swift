import Foundation

/// Minimal, source-agnostic view of a track for playback purposes. `Track` (library
/// list), `RawTrack`/`PlaylistTrackEntry` (playlists, favorites), and future sources
/// (radio, search) all carry enough to build one, so the player queue only ever deals
/// with this instead of being tied to one endpoint's response shape.
public struct QueueTrack: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let displayArtist: String
    public let albumVersionId: String?
    public let duration: Double?

    public init(id: String, title: String, displayArtist: String, albumVersionId: String?, duration: Double?) {
        self.id = id
        self.title = title
        self.displayArtist = displayArtist
        self.albumVersionId = albumVersionId
        self.duration = duration
    }
}

public extension QueueTrack {
    init(_ track: Track) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            albumVersionId: track.albumVersionId,
            duration: track.duration
        )
    }

    init(_ track: TrackDetail) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            albumVersionId: track.albumVersionId,
            duration: track.duration
        )
    }

    init(_ track: RawTrack) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.artist ?? "",
            albumVersionId: track.albumVersionId,
            duration: track.canonicalDuration
        )
    }

    init(_ track: PlaylistTrackEntry) {
        self.init(
            id: track.id,
            title: track.title,
            displayArtist: track.displayArtist,
            albumVersionId: track.albumVersionId,
            duration: track.canonicalDuration
        )
    }
}
