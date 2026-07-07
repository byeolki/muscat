# Podo — iOS/macOS Native Client

A SwiftUI multiplatform (iOS+macOS) client for [Podo](/home/admin/podo), a self-hosted music streaming server. Covers the full scope from Phase 1 (MVP) through Phase 3 (uploads/radio/admin/Live Activity).

This code was written in a Linux environment without Xcode — **it has never been compiled.** There may be minor build errors (typos, missing imports, etc.) the first time you open it on a Mac; let me know as soon as you find any and I'll fix them right away.

## Project structure

```
muscat/
├── project.yml              # XcodeGen spec — generates the .xcodeproj (2 apps + 1 widget extension)
├── Entitlements/
│   └── Podo-macOS.entitlements
├── Podo/                    # App target sources (shared between iOS/macOS, branching with #if os(iOS))
│   ├── App/PodoApp.swift
│   ├── RootView.swift / MainTabView.swift
│   ├── Views/
│   │   ├── Onboarding/ServerURLView.swift
│   │   ├── Auth/{LoginView,RegisterView}.swift
│   │   ├── Account/AccountView.swift
│   │   ├── Library/{TrackListView,TrackRowView,TrackDetailView}.swift
│   │   ├── Favorites/FavoritesListView.swift
│   │   ├── Search/SearchView.swift
│   │   ├── Playlists/{PlaylistListView,PlaylistDetailView,CreatePlaylistView,EditPlaylistView,AddTracksToPlaylistView}.swift
│   │   ├── Radio/{RadioView,RadioTokensView}.swift
│   │   ├── Upload/MyFilesView.swift
│   │   ├── Admin/{AdminView,AdminUsersView,AdminStorageView,AdminLibraryView}.swift
│   │   ├── Player/{MiniPlayerBar,NowPlayingView,VideoPlayerView}.swift
│   │   └── Shared/{RemoteArtworkView,RawTrackRowView,AlbumTracksSheet}.swift
│   └── Resources/Assets.xcassets
├── PodoWidgets/              # Live Activity / Dynamic Island widget extension (iOS only)
│   ├── PodoWidgetsBundle.swift
│   └── PlaybackLiveActivityWidget.swift
└── Packages/PodoKit/         # Local Swift Package — pure logic (no views), shared by the app + widget extension
    └── Sources/PodoKit/
        ├── Models/           # Codable models (fields verified against the actual server source)
        ├── Networking/       # APIClient (actor), automatic 401 refresh, per-domain extensions (Auth/Tracks/Streaming/Playlists/Favorites/Search/Albums/Upload/Radio/Admin)
        ├── Auth/             # KeychainStore, AuthStore (@Observable)
        ├── Player/           # PlaybackQueue, AudioPlayerEngine (AVPlayer), NowPlayingCenter, LiveActivityController, PlayerStore
        └── Support/          # AppEnvironment (composition root)
```

### Why the `.xcodeproj` wasn't hand-written

`project.pbxproj` is too fragile a format to write correctly by hand (UUID references, build phases, etc.), and there's no way to open and verify it in this environment. Instead, this uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the project from `project.yml` (human-readable YAML). Run one command on a Mac with the Xcode/Swift toolchain. There are three targets: `Podo-iOS`, `Podo-macOS`, and `PodoWidgetsExtension` (embedded only in the iOS app).

### Audio engine: `AVPlayer` instead of `AVAudioEngine`

The original spec called for `AVAudioEngine` (for EQ/crossfade), but `AVAudioEngine` can't play a network stream URL directly (it only accepts decoded buffers/files). Doing EQ on a live stream would require hand-written, low-level `MTAudioProcessingTap` C-callback code, which felt too risky to write in a state where it can't be compiled and verified.

So streaming/playback is implemented with `AVPlayer` (`PodoKit/Player/AudioPlayerEngine.swift`), leaving room to add EQ/crossfade later via a tap on `AVPlayerItem`. This is the one architectural decision that differs from the original spec.

### Playback queue: `QueueTrack` instead of `Track`

Every endpoint that hands back tracks does so in a different shape — the library list (`Track`), playlists/favorites (`RawTrack`/`PlaylistTrackEntry`, no override-resolution or `artists` array), albums (`AlbumTrackEntry`), search results, and radio recommendations. Because of that, the playback queue itself is built on a thin, source-agnostic type in `PodoKit/Player/QueueTrack.swift`. Each source type converts into it via a `QueueTrack(_:)` initializer before being queued.

## Getting started (on a Mac)

```bash
# 1. Install XcodeGen (once)
brew install xcodegen

# 2. Generate the project
cd /path/to/muscat
xcodegen generate

# 3. Open it
open Podo.xcodeproj
```

In Xcode:
1. Select the `Podo` project in the navigator → for each target (`Podo-iOS`, `Podo-macOS`, `PodoWidgetsExtension`), go to **Signing & Capabilities** and pick your Team (if automatic signing fails, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to something unique and re-run `xcodegen generate` — change the prefix consistently across all three targets so the app embeds the extension correctly).
2. Pick the `Podo-iOS` (simulator/device) or `Podo-macOS` scheme and Run. `PodoWidgetsExtension` is auto-embedded into `Podo-iOS`, so there's no need to run it separately.

Re-run `xcodegen generate` any time you change `project.yml` or the folder structure under `Podo/`, `PodoWidgets/`, or `Packages/PodoKit/` — the `.xcodeproj` needs to be regenerated to pick it up. Both `.xcodeproj` and the `Generated/` folder are in `.gitignore` since they're artifacts reproducible from `project.yml`.

## Manual test checklist

**Core (Phase 1)**
- [ ] **Onboarding**: enter a server URL → validated via `GET /health` → saved. Check the error message for an invalid/unreachable URL.
- [ ] **Login / Register**: valid/invalid credentials, with/without an invite code.
- [ ] **Library**: list loads, sort/filter switching, pull-to-refresh, track detail (artwork, tags, lyrics).
- [ ] **Playback**: start playback → mini player → next/previous → auto-advance on track end → full-screen scrubber seeking.
- [ ] **Lock screen / Control Center**: track info, artwork, play/pause/next/previous/seek controls.
- [ ] **Background playback**: playback keeps going while locked.
- [ ] **Automatic token refresh**: after 15+ minutes idle, make any request — it should auto-refresh (`APIClient.executeWithAuthRetry`) and auto-log-out if the refresh itself fails.

**Phase 2**
- [ ] **Favorites**: heart toggle on track detail, Favorites tab list/play/remove.
- [ ] **Search**: results per track/artist/album tab, re-searching by name from an artist hit, album-tracks sheet from an album hit.
- [ ] **Playlists**: create, my/public lists, add tracks (picker), drag to reorder, swipe to delete (owner only), edit (name/description/public), cover image upload/remove, delete playlist.
- [ ] **Music video**: video icon on a `has_video` track → `AVPlayer` video playback, pausing audio playback while open.

**Phase 3**
- [ ] **My Files**: upload audio/video (file picker), check the list (the server only responds once the in-progress file scan finishes), rename, delete.
- [ ] **Radio**: start a station from an artist name → play all / save as playlist. Issue/revoke radio broadcast URLs from a playlist's detail menu (the issued URL can be played in an external player like VLC).
- [ ] **Admin** (only shown in the Account tab for admin accounts): generate invite codes, user list, storage usage, add a library root / start a scan / scan history.
- [ ] **Live Activity / Dynamic Island**: track info shown on the lock screen and Dynamic Island when playback starts, updates on play/pause (requires a real device or a Dynamic-Island-capable simulator, with Live Activities allowed in Settings).

## Known simplifications / caveats

- `APIClient`, `AuthStore`, and `PlayerStore` all live in the `PodoKit` package and are injected into SwiftUI as `@MainActor` + `@Observable`. `APIClient` itself is an `actor`, so network I/O never blocks the main thread.
- Streaming URLs always request `format=aac` for audio playback (`PlayerStore.loadAndPlay`) — this normalizes to a codec `AVPlayer` can reliably decode regardless of the source format. Music videos do the opposite: no `format` is specified, requesting the original container as-is (to avoid video transcoding).
- The playback queue resolves each track's stream URL right before it plays, not ahead of time — since access tokens expire after 15 minutes, baking URLs for the whole queue up front could leave later tracks holding an expired token.
- `POST /upload`'s response doesn't actually include `source_id`/`track_id` (a gap in the server implementation itself), so the client re-fetches `GET /upload/files` after uploading to resolve them.
- The Live Activity shows only text info and a progress bar, no album art — ActivityKit's content-state size limit (a few KB) makes it risky to ship image data safely, and the original spec also called for a "static progress readout" rather than live artwork. It also only updates on play/pause/track-change events rather than every second (continuous per-tick updates are wasteful from both a battery and rate-limit perspective).
- The admin screens cover user list/invite codes/storage stats/library scan only — no download (yt-dlp), duplicate-group review, or mapping-queue management (all admin-only server-side, and classified as lower-priority "admin features, post-MVP" in the original doc).
