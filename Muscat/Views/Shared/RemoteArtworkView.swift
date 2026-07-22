import MuscatKit
import SwiftUI

/// Resolves an artwork id (`album_version_id` OR a playlist id — the server's
/// `GET /artwork/:id` checks both) to a URL asynchronously (the API client is an actor,
/// so URL-building isn't free) and displays it, falling back to a placeholder.
struct RemoteArtworkView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let artworkId: String?
    var cornerRadius: CGFloat = 6
    /// Bump after uploading/removing artwork for this id to defeat the server's
    /// 24h `Cache-Control` on `/artwork/:id` (the URL is otherwise identical, so
    /// `AsyncImage` would keep showing the stale cached image).
    var cacheBust: Int = 0

    @State private var resolvedURL: URL?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appSurfaceRaised)
                if let resolvedURL {
                    AsyncImage(url: resolvedURL) { phase in
                        if let image = phase.image {
                            // Non-square source art (e.g. widescreen video thumbnails) must be
                            // pinned to the exact square this view is given and cropped —
                            // .aspectRatio(.fill) alone only scales, it doesn't confine the
                            // result to our bounds, so without an explicit frame + clip here
                            // the wider dimension renders past the rounded frame.
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                        } else {
                            placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: "\(artworkId ?? "")#\(cacheBust)") {
            guard let artworkId else {
                resolvedURL = nil
                return
            }
            guard let base = await appEnvironment.apiClient.artworkURL(id: artworkId) else {
                resolvedURL = nil
                return
            }
            if cacheBust == 0 {
                resolvedURL = base
            } else {
                var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "v", value: String(cacheBust))]
                resolvedURL = components?.url ?? base
            }
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .foregroundStyle(Color.appTextTertiary)
    }
}
