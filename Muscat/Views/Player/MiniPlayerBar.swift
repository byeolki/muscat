import MuscatKit
import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlayerStore.self) private var playerStore
    let onTap: () -> Void

    var body: some View {
        if let track = playerStore.currentTrack {
            HStack(spacing: 12) {
                RemoteArtworkView(artworkId: track.albumVersionId)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(track.displayArtist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    playerStore.togglePlayPause()
                } label: {
                    Image(systemName: playerStore.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button {
                    playerStore.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(!playerStore.hasNext)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }
}
