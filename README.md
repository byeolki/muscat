# Muscat

Native iOS/macOS client for [Podo](https://github.com/byeolki/podo), a self-hosted music streaming server. SwiftUI, multiplatform, one codebase.

## Build

```bash
brew install xcodegen
cd muscat
xcodegen generate
open Muscat.xcodeproj
```

Set a signing Team on each target (`Muscat-iOS`, `Muscat-macOS`, `MuscatWidgetsExtension`) in Signing & Capabilities, then run the `Muscat-iOS` or `Muscat-macOS` scheme. Re-run `xcodegen generate` after any change to `project.yml` or the source folders — the `.xcodeproj` is a generated artifact and isn't committed.

To check a change without opening Xcode:

```bash
# MuscatKit on its own (fast; also runs the unit tests)
cd Packages/MuscatKit && swift build && swift test

# whole app, no signing required
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
Muscat/            app target — views only, no business logic
MuscatWidgets/     Live Activity / Dynamic Island widget extension
Packages/MuscatKit/  local Swift package — networking, auth, player, models
```

`MuscatKit` has no view code and is shared by both `Muscat` and `MuscatWidgets`.

## Architecture

- **APIClient** (`MuscatKit/Networking`) — actor-isolated, snake_case JSON throughout to match the server. A 401 triggers a single coalesced refresh (concurrent requests share one in-flight refresh call) and one retry per request; refresh failure clears the session and signals the app to log out.
- **TrackDisplayable** (`MuscatKit/Models`) — the server returns five different track shapes (library list, detail, favorites, playlist entries, album entries) because each endpoint wraps and enriches the row differently. They all conform to this protocol, so artist/duration/artwork resolution — and the single `TrackRowContent` list row — are written once rather than per shape.
- **QueueTrack** (`MuscatKit/Player`) — the playback queue deals only in this thin type; any `TrackDisplayable` converts with `QueueTrack(_:)`.
- **AVPlayer, not AVAudioEngine** — the spec called for `AVAudioEngine` for EQ/crossfade, but it can't consume a network stream directly (buffers/files only). EQ on a live stream needs `MTAudioProcessingTap`, which wasn't worth writing blind. `AVPlayer` handles streaming/decoding now; a tap on `AVPlayerItem` is the extension point for EQ later.
- **Keychain-backed auth** — tokens never touch UserDefaults; only the server URL does (not sensitive).
- **@Observable stores** (`AuthStore`, `PlayerStore`) injected via `.environment(...)`, consumed with `@Environment(Type.self)`.
- **LoadableState** (`MuscatKit/UI`) — replaces the hand-rolled `isLoading` + `errorMessage` + `do/catch` trio in views that fetch.

### Artwork resolution

`GET /artwork/:id` resolves whatever id it's given against albums, then playlists,
then track thumbnails — purely by id. It has no idea an album id was meant to be
"the" artwork for a track, so an album with no cover file on disk 404s rather than
falling back. Every track shape therefore exposes both `artworkId` and
`fallbackArtworkId`, and `RemoteArtworkView` retries with the fallback when the
first image fails to load.

## Feature coverage

- Onboarding (server URL + health check), login/register with invite codes
- Library browse/sort/filter, track detail, lyrics, tags
- Playback: queue, lock screen / Control Center controls, background audio, Live Activity / Dynamic Island
- Favorites, search (tracks/artists/albums), playlists (CRUD, reorder, cover image, radio broadcast URLs)
- Music video playback
- File upload ("My Files"), artist-seeded radio stations
- Admin: invite generation, user list, storage stats, library root/scan management

## Known limitations

- Streaming always requests `format=aac` for audio (guarantees a codec `AVPlayer` can decode), which means the server transcodes even when the original would have played; video requests no `format` (passthrough only).
- `POST /upload`'s response doesn't include the new `source_id`/`track_id` (server-side gap) — the client re-fetches `GET /upload/files` to resolve them.
- Live Activity shows text + a progress bar, no artwork (ActivityKit's content-state size limit makes image payloads unreliable), and updates only on play/pause/track-change, not every second.
- Search results play as a single-track queue with no artwork or duration — the search endpoint returns hits, not full track rows.
- Admin screens cover users/invites/storage/library scan only — no download (yt-dlp), duplicate-group review, or mapping-queue UI.
- Test coverage is limited to `MuscatKit`'s JSON coding; the views have none.
