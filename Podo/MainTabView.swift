import PodoKit
import SwiftUI

struct MainTabView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            TrackListView()
                .tabItem { Label("라이브러리", systemImage: "music.note.list") }

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
