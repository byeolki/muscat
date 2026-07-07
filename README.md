# Podo — iOS/macOS 네이티브 클라이언트

자체 호스팅 음악 스트리밍 서버 [Podo](/home/admin/podo)의 SwiftUI 멀티플랫폼(iOS+macOS) 클라이언트. Phase 1(MVP)부터 Phase 3(업로드/라디오/관리자/Live Activity)까지 전체 범위를 구현했습니다.

이 코드는 Linux 환경에서 Xcode 없이 작성되었습니다 — **한 번도 컴파일된 적이 없습니다.** Mac에서 처음 열었을 때 사소한 빌드 에러(오타, import 누락 등)가 있을 수 있으니, 발견되는 대로 알려주시면 바로 고치겠습니다.

## 프로젝트 구조

```
muscat/
├── project.yml              # XcodeGen 스펙 — .xcodeproj를 여기서 생성 (앱 2개 + 위젯 익스텐션 1개)
├── Entitlements/
│   └── Podo-macOS.entitlements
├── Podo/                    # 앱 타겟 소스 (iOS/macOS 공유, #if os(iOS)로 분기)
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
├── PodoWidgets/              # Live Activity / Dynamic Island 위젯 익스텐션 (iOS 전용)
│   ├── PodoWidgetsBundle.swift
│   └── PlaybackLiveActivityWidget.swift
└── Packages/PodoKit/         # 로컬 Swift Package — 순수 로직 (뷰 없음), 앱+위젯 익스텐션이 공유
    └── Sources/PodoKit/
        ├── Models/           # Codable 모델 (실제 서버 소스로 필드 검증 완료)
        ├── Networking/       # APIClient(actor), 401 자동 refresh, 도메인별 확장(Auth/Tracks/Streaming/Playlists/Favorites/Search/Albums/Upload/Radio/Admin)
        ├── Auth/             # KeychainStore, AuthStore (@Observable)
        ├── Player/           # PlaybackQueue, AudioPlayerEngine(AVPlayer), NowPlayingCenter, LiveActivityController, PlayerStore
        └── Support/          # AppEnvironment (composition root)
```

### 왜 `.xcodeproj`를 직접 만들지 않았나

`project.pbxproj`는 사람이 손으로 정확히 작성하기엔 너무 깨지기 쉬운 포맷이고(UUID 참조, 빌드 phase 등), 이 환경에서는 실제로 열어서 검증할 방법이 없습니다. 대신 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 `project.yml`(사람이 읽기 쉬운 YAML)에서 프로젝트를 생성하는 방식을 택했습니다. Xcode/Swift 툴체인이 있는 Mac에서 한 번 명령어를 실행하면 됩니다. 타겟은 `Podo-iOS`, `Podo-macOS`, `PodoWidgetsExtension`(iOS 앱에만 임베드) 세 개입니다.

### 오디오 엔진: `AVAudioEngine` 대신 `AVPlayer`를 쓴 이유

원래 스펙은 `AVAudioEngine`(EQ/크로스페이드용)이었지만, `AVAudioEngine`은 네트워크 스트림 URL을 직접 재생할 수 없습니다(디코딩된 버퍼/파일만 받음). 실시간 스트림에 EQ를 걸려면 `MTAudioProcessingTap`같은 low-level C 콜백 코드가 필요한데, 컴파일 검증이 불가능한 상태에서 이런 코드를 작성하는 건 위험도가 너무 높다고 판단했습니다.

그래서 `AVPlayer`(`PodoKit/Player/AudioPlayerEngine.swift`)로 스트리밍/재생을 구현했고, EQ/크로스페이드는 이후 단계에서 `AVPlayerItem`에 탭을 붙이는 방식으로 확장할 수 있도록 여지를 남겨뒀습니다. 이 부분이 원래 스펙과 다른 유일한 아키텍처 결정입니다.

### 재생 큐: `Track` 대신 `QueueTrack`

라이브러리 목록(`Track`), 플레이리스트/즐겨찾기(`RawTrack`/`PlaylistTrackEntry`, override 미병합·`artists` 배열 없음), 앨범(`AlbumTrackEntry`), 검색 결과, 라디오 추천 등 트랙을 내려주는 엔드포인트마다 응답 shape이 달라서, 재생 큐 자체는 `PodoKit/Player/QueueTrack.swift`의 얇고 소스 독립적인 타입을 씁니다. 각 소스 타입에서 `QueueTrack(_:)` 이니셜라이저로 변환해서 큐에 넣습니다.

## 시작하기 (Mac에서)

```bash
# 1. XcodeGen 설치 (한 번만)
brew install xcodegen

# 2. 프로젝트 생성
cd /path/to/muscat
xcodegen generate

# 3. 열기
open Podo.xcodeproj
```

Xcode에서:
1. 프로젝트 네비게이터에서 `Podo` 프로젝트 선택 → 각 타겟(`Podo-iOS`, `Podo-macOS`, `PodoWidgetsExtension`)의 **Signing & Capabilities**에서 본인 Team을 선택하세요 (자동 서명 실패 시 `project.yml`의 `PRODUCT_BUNDLE_IDENTIFIER`를 고유한 값으로 바꾸고 `xcodegen generate` 재실행 — 세 타겟 모두 같은 접두사로 바꿔야 앱이 익스텐션을 올바르게 임베드합니다).
2. 스킴을 `Podo-iOS`(시뮬레이터/기기) 또는 `Podo-macOS`로 선택 후 Run. `PodoWidgetsExtension`은 `Podo-iOS`에 자동 임베드되므로 따로 실행할 필요 없습니다.

`project.yml`이나 `Podo/`, `PodoWidgets/`, `Packages/PodoKit/`의 폴더 구조를 바꿀 때마다 `xcodegen generate`를 다시 실행해야 `.xcodeproj`에 반영됩니다. `.xcodeproj`와 `Generated/` 폴더는 `.gitignore`에 포함되어 있습니다 (project.yml에서 재생성 가능한 산출물이므로).

## 수동 테스트 체크리스트

**핵심 (Phase 1)**
- [ ] **온보딩**: 서버 URL 입력 → `GET /health` 검증 → 저장. 잘못된 URL/도달 불가 서버 입력 시 에러 메시지 확인.
- [ ] **로그인 / 회원가입**: 유효/잘못된 자격증명, 초대코드 있음/없음 케이스.
- [ ] **라이브러리**: 목록 로드, 정렬/필터 전환, pull-to-refresh, 트랙 상세(아트워크·태그·가사).
- [ ] **재생**: 재생 시작 → 미니 플레이어 → 다음/이전 → 곡 종료 시 자동 다음 곡 → 풀스크린 스크러버 탐색.
- [ ] **잠금화면/제어센터**: 곡 정보·아트워크·재생/일시정지/다음/이전/탐색 컨트롤.
- [ ] **백그라운드 재생**: 잠금 상태에서도 재생 유지.
- [ ] **토큰 자동 갱신**: 15분 이상 방치 후 요청 시 자동 refresh (`APIClient.executeWithAuthRetry`), refresh 실패 시 자동 로그아웃.

**Phase 2**
- [ ] **즐겨찾기**: 트랙 상세의 하트 토글, 즐겨찾기 탭 목록/재생/해제.
- [ ] **검색**: 트랙/아티스트/앨범 탭별 결과, 아티스트 탭 시 이름으로 재검색, 앨범 탭 시 앨범 트랙 시트.
- [ ] **플레이리스트**: 생성, 내 목록/공개 목록, 트랙 추가(피커), 드래그 재정렬, 스와이프 삭제(오너만), 편집(이름/설명/공개여부), 커버 이미지 업로드/삭제, 플레이리스트 삭제.
- [ ] **뮤직비디오**: `has_video` 트랙에서 비디오 아이콘 → `AVPlayer` 영상 재생, 열리면 오디오 재생 일시정지.

**Phase 3**
- [ ] **내 파일**: 오디오/영상 파일 업로드(파일 피커), 목록 확인(서버가 진행 중 파일 스캔이 끝나야 응답), 이름 변경, 삭제.
- [ ] **라디오**: 아티스트 이름으로 스테이션 시작 → 전체 재생 / 플레이리스트로 저장. 플레이리스트 상세 메뉴에서 라디오 URL 발급/폐기(발급된 URL은 VLC 등 외부 플레이어에서 재생 가능).
- [ ] **관리자** (관리자 계정만 계정 탭에 노출): 초대코드 생성, 사용자 목록, 저장소 사용량, 라이브러리 루트 추가/스캔 시작/스캔 기록.
- [ ] **Live Activity / 다이나믹 아일랜드**: 재생 시작 시 잠금화면·다이나믹 아일랜드에 곡 정보 표시, 재생/일시정지 시 갱신 확인 (실기기 또는 다이나믹 아일랜드 지원 시뮬레이터 필요, Live Activities는 설정에서 허용되어 있어야 함).

## 알려진 단순화/주의사항

- `APIClient`, `AuthStore`, `PlayerStore`는 모두 `PodoKit` 패키지 안에 있고 `@MainActor` + `@Observable`로 SwiftUI에 주입됩니다. `APIClient` 자체는 `actor`라서 네트워크 I/O는 메인 스레드를 막지 않습니다.
- 스트리밍 URL은 오디오 재생 시 항상 `format=aac`로 강제 요청합니다(`PlayerStore.loadAndPlay`) — 원본 포맷이 뭐든 `AVPlayer`가 확실히 디코딩할 수 있는 코덱으로 통일하기 위함입니다. 뮤직비디오는 반대로 `format`을 지정하지 않고 원본 컨테이너를 그대로 요청합니다(비디오 트랜스코딩 회피).
- 재생 큐의 스트림 URL은 각 트랙을 재생하기 직전에 그때그때 새로 발급받습니다 (access token이 15분 만료라, 미리 큐 전체의 URL을 구워두면 나중 트랙은 만료된 토큰을 물고 있을 수 있어서).
- `POST /upload` 응답에는 서버 코드상 실제로 `source_id`/`track_id`가 오지 않아서(구현 자체의 한계), 업로드 후 `GET /upload/files`를 다시 불러오는 방식으로 처리했습니다.
- Live Activity는 텍스트 정보 + 진행률 바만 표시하고 앨범 아트는 넣지 않았습니다 — ActivityKit의 콘텐츠 상태 크기 제한(수 KB) 때문에 이미지 데이터를 안전하게 실어 보내기 어렵고, 원래 요청사항도 "진행률 정지 이미지" 형태였습니다. 또한 매초 갱신하는 대신 재생/일시정지/트랙 전환 시점에만 갱신합니다(연속 틱 업데이트는 배터리·레이트리밋 관점에서 비효율적).
- 관리자 화면은 사용자 목록/초대코드/저장소 통계/라이브러리 스캔만 다루고, 다운로드(yt-dlp)·중복 그룹 검토·매핑 큐 관리 등은 포함하지 않았습니다 (서버 쪽에서도 전부 admin 전용이며 원 문서에서 "관리 기능, MVP 후순위"로 분류된 항목).
