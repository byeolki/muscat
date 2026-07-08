import MuscatKit
import SwiftUI

struct MainTabView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            tab(TrackListView(), label: Label("Library", systemImage: "music.note.list"))
            tab(SearchView(), label: Label("Search", systemImage: "magnifyingglass"))
            tab(FavoritesListView(), label: Label("Favorites", systemImage: "heart"))
            tab(PlaylistListView(), label: Label("Playlists", systemImage: "rectangle.stack"))
            tab(AccountView(), label: Label("Account", systemImage: "person.circle"))
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
        }
        .themedScreen()
    }

    /// Attaching `.safeAreaInset` to the `TabView` itself makes the mini player float
    /// *behind*/overlap the tab bar instead of above it — the fix is to give each tab's
    /// own content the inset, which correctly reserves space above the tab bar.
    @ViewBuilder
    private func tab(_ content: some View, label: Label<Text, Image>) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if playerStore.currentTrack != nil {
                    MiniPlayerBar(onTap: { showNowPlaying = true })
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                }
            }
            .tabItem { label }
    }
}
