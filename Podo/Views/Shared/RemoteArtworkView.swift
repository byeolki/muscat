import PodoKit
import SwiftUI

/// Resolves an `album_version_id` to an artwork URL asynchronously (the API client is
/// an actor, so URL-building isn't free) and displays it, falling back to a placeholder.
struct RemoteArtworkView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let albumVersionId: String?
    var cornerRadius: CGFloat = 6

    @State private var resolvedURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.quaternary)
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
        .task(id: albumVersionId) {
            guard let albumVersionId else {
                resolvedURL = nil
                return
            }
            resolvedURL = await appEnvironment.apiClient.artworkURL(id: albumVersionId)
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "music.note")
            .foregroundStyle(.secondary)
    }
}
