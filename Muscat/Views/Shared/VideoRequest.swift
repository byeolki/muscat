import Foundation

/// A track to open the video player for.
///
/// `sheet(item:)` needs something `Identifiable` and a track id is a bare
/// `String`, so this carries the id and the title the sheet's toolbar shows
/// rather than making the caller look the title up again.
struct VideoRequest: Identifiable, Hashable {
    let id: String
    let title: String
}
