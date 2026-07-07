import PodoKit
import SwiftUI

struct MainTabView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            TrackListView()
                .tabItem { Label("라이브러리", systemImage: "music.note.list") }

            SearchView()
                .tabItem { Label("검색", systemImage: "magnifyingglass") }

            FavoritesListView()
                .tabItem { Label("즐겨찾기", systemImage: "heart") }

            PlaylistListView()
                .tabItem { Label("플레이리스트", systemImage: "rectangle.stack") }

            AccountView()
                .tabItem { Label("계정", systemImage: "person.circle") }
        }
        .safeAreaInset(edge: .bottom) {
            if playerStore.currentTrack != nil {
                MiniPlayerBar(onTap: { showNowPlaying = true })
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
    }
}
