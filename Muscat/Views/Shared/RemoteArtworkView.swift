import MuscatKit
import SwiftUI

/// Resolves an artwork id (`album_version_id` OR a playlist id — the server's
/// `GET /artwork/:id` checks both) to a URL asynchronously (the API client is an actor,
/// so URL-building isn't free) and displays it, falling back to a placeholder.
struct RemoteArtworkView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let artworkId: String?
    var cornerRadius: CGFloat = 6

    @State private var resolvedURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.appSurfaceRaised)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.appBorder, lineWidth: 1)
            if let resolvedURL {
                AsyncImage(url: resolvedURL) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: artworkId) {
            guard let artworkId else {
                resolvedURL = nil
                return
            }
            resolvedURL = await appEnvironment.apiClient.artworkURL(id: artworkId)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .foregroundStyle(Color.appTextTertiary)
    }
}
