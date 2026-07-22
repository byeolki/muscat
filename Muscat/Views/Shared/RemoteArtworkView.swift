import MuscatKit
import SwiftUI

/// Resolves an artwork id (`album_version_id`, playlist id, or track id — the server's
/// `GET /artwork/:id` checks all three) to a URL asynchronously (the API client is an
/// actor, so URL-building isn't free) and displays it, falling back to a placeholder.
///
/// `fallbackArtworkId` covers a real gap in the server endpoint: it resolves whatever
/// id it's given against albums, then playlists, then track thumbnails — it has no
/// idea `artworkId` was "the" artwork for this track, so if a track belongs to an
/// album that has no artwork file on disk, that lookup 404s instead of trying the
/// track's own generated thumbnail. When the primary image fails to load, this view
/// retries with `fallbackArtworkId` (see `Track.fallbackArtworkId` and friends).
struct RemoteArtworkView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let artworkId: String?
    var fallbackArtworkId: String? = nil
    var cornerRadius: CGFloat = 6
    /// See `cacheBusted(_:)`.
    var cacheBust: Int = 0

    @State private var primaryURL: URL?
    @State private var fallbackURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.appSurfaceRaised)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.appBorder, lineWidth: 1)

            if let primaryURL {
                AsyncImage(url: primaryURL) { phase in
                    if let image = phase.image {
                        styledImage(image)
                    } else if phase.error != nil {
                        fallbackOrPlaceholder
                    } else {
                        Color.clear
                    }
                }
            } else {
                fallbackOrPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: "\(artworkId ?? "")#\(cacheBust)") {
            guard let artworkId else {
                primaryURL = nil
                return
            }
            guard let base = await appEnvironment.apiClient.artworkURL(id: artworkId) else {
                primaryURL = nil
                return
            }
            primaryURL = cacheBusted(base)
        }
        .task(id: "\(fallbackArtworkId ?? "")#\(cacheBust)") {
            guard let fallbackArtworkId else {
                fallbackURL = nil
                return
            }
            guard let base = await appEnvironment.apiClient.artworkURL(id: fallbackArtworkId) else {
                fallbackURL = nil
                return
            }
            fallbackURL = cacheBusted(base)
        }
    }

    /// Bump `cacheBust` after uploading/removing artwork for this id to defeat the
    /// server's 24h `Cache-Control` on `/artwork/:id` (the URL is otherwise identical,
    /// so `AsyncImage` would keep showing the stale cached image).
    private func cacheBusted(_ url: URL) -> URL {
        guard cacheBust != 0 else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "v", value: String(cacheBust))]
        return components?.url ?? url
    }

    @ViewBuilder
    private var fallbackOrPlaceholder: some View {
        if let fallbackURL {
            AsyncImage(url: fallbackURL) { phase in
                if let image = phase.image {
                    styledImage(image)
                } else {
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    /// `aspectRatio(.fill)` alone lets a non-square source grow past its container in
    /// one dimension; pin it back to the proposed size before clipping, or it spills
    /// outside the rounded frame.
    private func styledImage(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .foregroundStyle(Color.appTextTertiary)
    }
}
