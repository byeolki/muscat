import MuscatKit
import SwiftUI

struct MainTabView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            TrackListView()
                .tabItem { Label("Library", systemImage: "music.note.list") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            FavoritesListView()
                .tabItem { Label("Favorites", systemImage: "heart") }

            PlaylistListView()
                .tabItem { Label("Playlists", systemImage: "rectangle.stack") }

            AccountView()
                .tabItem { Label("Account", systemImage: "person.circle") }
        }
        .safeAreaInset(edge: .bottom) {
            if playerStore.currentTrack != nil {
                MiniPlayerBar(onTap: { showNowPlaying = true })
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
        .themedScreen()
    }
}
