# Muscat

Native iOS/macOS client for [Podo](https://github.com/byeolki/podo), a self-hosted music streaming server. SwiftUI, multiplatform, one codebase.

This was written without a working Xcode/Swift toolchain — **it has never been compiled.** Expect a few build errors on first open; report them and they'll get fixed.

## Build

```bash
brew install xcodegen
cd muscat
xcodegen generate
open Muscat.xcodeproj
```

Set a signing Team on each target (`Muscat-iOS`, `Muscat-macOS`, `MuscatWidgetsExtension`) in Signing & Capabilities, then run the `Muscat-iOS` or `Muscat-macOS` scheme. Re-run `xcodegen generate` after any change to `project.yml` or the source folders — the `.xcodeproj` is a generated artifact and isn't committed.

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
- **AVPlayer, not AVAudioEngine** — the spec called for `AVAudioEngine` for EQ/crossfade, but it can't consume a network stream directly (buffers/files only). EQ on a live stream needs `MTAudioProcessingTap`, which wasn't worth writing blind. `AVPlayer` handles streaming/decoding now; a tap on `AVPlayerItem` is the extension point for EQ later.
- **QueueTrack** (`MuscatKit/Player`) — every endpoint that returns tracks uses a different shape (library list, playlist/favorites raw rows with no override resolution, album entries, search hits, radio). The playback queue only deals in this one thin type; each source converts into it via `QueueTrack(_:)`.
- **Keychain-backed auth** — tokens never touch UserDefaults; only the server URL does (not sensitive).
- **@Observable stores** (`AuthStore`, `PlayerStore`) injected via `.environment(...)`, consumed with `@Environment(Type.self)`.

## Feature coverage

- Onboarding (server URL + health check), login/register with invite codes
- Library browse/sort/filter, track detail, lyrics, tags
- Playback: queue, lock screen / Control Center controls, background audio, Live Activity / Dynamic Island
- Favorites, search (tracks/artists/albums), playlists (CRUD, reorder, cover image, radio broadcast URLs)
- Music video playback
- File upload ("My Files"), artist-seeded radio stations
- Admin: invite generation, user list, storage stats, library root/scan management

## Known limitations

- Streaming always requests `format=aac` for audio (guarantees a codec `AVPlayer` can decode); video requests no `format` (passthrough only, avoids transcoding).
- `POST /upload`'s response doesn't include the new `source_id`/`track_id` (server-side gap) — the client re-fetches `GET /upload/files` to resolve them.
- Live Activity shows text + a progress bar, no artwork (ActivityKit's content-state size limit makes image payloads unreliable), and updates only on play/pause/track-change, not every second.
- Admin screens cover users/invites/storage/library scan only — no download (yt-dlp), duplicate-group review, or mapping-queue UI.
