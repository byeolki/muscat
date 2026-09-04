<h1 align="center">Muscat</h1>

<p align="center">
  <b>The native iPhone and Mac client for <a href="https://github.com/byeolki/podo">Podo</a>.</b><br />
  One SwiftUI codebase, two platforms, your own server.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white" alt="iOS 17+" />
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/SwiftUI-Observation-0071e3" alt="SwiftUI + Observation" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT" /></a>
</p>

---

Point it at your [Podo](https://github.com/byeolki/podo) server, log in, and your
library is on your phone — with the things a music app is actually judged on:
background playback, lock-screen and Control Center transport, a Live Activity in
the Dynamic Island, and artwork on the lock screen.

The whole thing is one SwiftUI target compiled for both platforms, plus a local
Swift package (`MuscatKit`) that holds everything that isn't a view.

## What's in it

- **Playback** — queue, repeat off/all/one, per-track scrubbing, background audio,
  `MPRemoteCommandCenter` transport, `MPNowPlayingInfoCenter` metadata + artwork
- **Live Activity / Dynamic Island** — title, artist, play state and progress on
  the lock screen, updated on every transport change
- **Library** — browse, sort and filter, track detail with tags, per-language
  synced lyrics with a language picker
- **Playlists** — create, edit, reorder by drag, delete, set a cover image, and
  mint public radio URLs for anyone to stream
- **Favorites, search** (tracks / artists / albums), **artist-seeded radio**
- **Uploads** — send files from Files/iCloud, rename and delete your own
- **Admin** — invite codes, user list, storage usage, library roots and scans
- **Music videos** — plays a track's video source when it has one
- **Loudness** — per-track normalization toggle that reloads the stream in place

## Build

There's no `.xcodeproj` in the repo — it's generated from `project.yml`, so it
never shows up in a diff.

```bash
brew install xcodegen
git clone https://github.com/byeolki/muscat && cd muscat
xcodegen generate
open Muscat.xcodeproj
```

Set a signing Team on `Muscat-iOS`, `Muscat-macOS` and `MuscatWidgetsExtension`
in Signing & Capabilities, then run. Re-run `xcodegen generate` after changing
`project.yml` or adding files.

To check a change without opening Xcode:

```bash
# MuscatKit alone — fast, and runs the unit tests
cd Packages/MuscatKit && swift build && swift test

# both app targets, no signing needed
xcodebuild -project Muscat.xcodeproj -scheme Muscat-macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Muscat.xcodeproj -scheme Muscat-iOS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Targets

| Target | Platform | Notes |
|---|---|---|
| `Muscat-iOS` | iOS 17+ | Embeds `MuscatWidgetsExtension` |
| `Muscat-macOS` | macOS 14+ | App Sandbox + network client entitlement |
| `MuscatWidgetsExtension` | iOS 17+ | Live Activity / Dynamic Island only |

## Project structure

```
Muscat/              app target — views only, no business logic
MuscatWidgets/       Live Activity / Dynamic Island widget extension
Packages/MuscatKit/  local Swift package — networking, auth, player, models
```

`MuscatKit` has no view code and is shared by the app and the widget extension.

## Architecture

- **APIClient** (`MuscatKit/Networking`) — an actor, snake_case JSON throughout to
  match the server. A 401 triggers a single coalesced refresh (concurrent requests
  share one in-flight refresh) and one retry; refresh failure clears the session
  and signals the app to log out.
- **TrackDisplayable** (`MuscatKit/Models`) — the server returns five track shapes
  (library list, detail, favorites, playlist entries, album entries) because each
  endpoint wraps the row differently. They all conform to one protocol, so artist,
  duration and artwork resolution — and the single `TrackRowContent` list row —
  are written once instead of five times.
- **QueueTrack** (`MuscatKit/Player`) — the playback queue deals only in this thin
  type; any `TrackDisplayable` converts with `QueueTrack(_:)`.
- **AVPlayer, not AVAudioEngine** — `AVAudioEngine` can't consume a network stream
  directly (buffers and files only), and EQ over a live stream needs
  `MTAudioProcessingTap`. `AVPlayer` handles streaming and decoding today; a tap
  on `AVPlayerItem` is the extension point when EQ lands.
- **Keychain-backed auth** — tokens never touch UserDefaults; only the server URL
  does, which isn't sensitive.
- **@Observable stores** (`AuthStore`, `PlayerStore`) injected with
  `.environment(...)`, read with `@Environment(Type.self)`.
- **LoadableState** (`MuscatKit/UI`) — the loading/error/do-catch trio every
  fetching view would otherwise hand-roll.

### Artwork resolution

`GET /artwork/:id` resolves whatever id it's handed against albums, then
playlists, then track thumbnails — purely by id. It has no way to know an album id
was meant to be "the" artwork for a track, so an album with no cover file on disk
404s rather than falling back. Every track shape therefore carries both
`artworkId` and `fallbackArtworkId`, and `RemoteArtworkView` retries with the
fallback when the first image fails.

## Known limitations

Worth knowing before you file an issue — these are deliberate, not oversights:

- Audio always requests `format=aac` so `AVPlayer` is guaranteed a codec it can
  decode, which means the server transcodes even when the original would have
  played as-is. Video is passthrough.
- No offline downloads. Everything streams.
- The Live Activity is text plus a progress bar, no artwork — ActivityKit's
  content-state size limit makes image payloads unreliable — and it updates on
  play/pause/track-change, not once a second.
- Search results play as a single-track queue with no artwork or duration; the
  search endpoint returns hits, not full track rows.
- Admin covers users, invites, storage and library scans. No yt-dlp download UI,
  duplicate review or mapping queue — use the web dashboard for those.
- Tests cover `MuscatKit`'s JSON coding only; the views have none.

## Contributing

Issues and pull requests welcome. Please make sure `swift build`, `swift test` and
both `xcodebuild` commands above pass — they're the whole gate right now.

## License

[MIT](LICENSE) — do what you like with it, including shipping a fork to the App
Store.

Note that the server it talks to, [Podo](https://github.com/byeolki/podo), is
AGPL-3.0. The two are separate programs communicating over HTTP, so the server's
copyleft doesn't reach this client; a permissive license here is what keeps
building your own client (or forking this one) worth doing.
