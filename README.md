# Podo — iOS/macOS 네이티브 클라이언트

자체 호스팅 음악 스트리밍 서버 [Podo](/home/admin/podo)의 SwiftUI 멀티플랫폼(iOS+macOS) 클라이언트, Phase 1(MVP) 구현.

이 코드는 Linux 환경에서 Xcode 없이 작성되었습니다 — **한 번도 컴파일된 적이 없습니다.** Mac에서 처음 열었을 때 사소한 빌드 에러(오타, import 누락 등)가 있을 수 있으니, 발견되는 대로 알려주시면 바로 고치겠습니다.

## 프로젝트 구조

```
muscat/
├── project.yml              # XcodeGen 스펙 — .xcodeproj를 여기서 생성
├── Entitlements/
│   └── Podo-macOS.entitlements
├── Podo/                    # 앱 타겟 소스 (iOS/macOS 공유, #if os(iOS)로 분기)
│   ├── App/PodoApp.swift
│   ├── RootView.swift
│   ├── MainTabView.swift
│   ├── Views/
│   │   ├── Onboarding/ServerURLView.swift
│   │   ├── Auth/{LoginView,RegisterView}.swift
│   │   ├── Account/AccountView.swift
│   │   ├── Library/{TrackListView,TrackRowView,TrackDetailView}.swift
│   │   ├── Player/{MiniPlayerBar,NowPlayingView}.swift
│   │   └── Shared/RemoteArtworkView.swift
│   └── Resources/Assets.xcassets
└── Packages/PodoKit/         # 로컬 Swift Package — 순수 로직 (뷰 없음)
    └── Sources/PodoKit/
        ├── Models/           # Codable 모델 (스펙은 아래 "API 계약" 참고)
        ├── Networking/       # APIClient(actor), 401 자동 refresh, 엔드포인트별 확장
        ├── Auth/             # KeychainStore, AuthStore (@Observable)
        ├── Player/           # PlaybackQueue, AudioPlayerEngine(AVPlayer), NowPlayingCenter, PlayerStore
        └── Support/          # AppEnvironment (composition root)
```

### 왜 `.xcodeproj`를 직접 만들지 않았나

`project.pbxproj`는 사람이 손으로 정확히 작성하기엔 너무 깨지기 쉬운 포맷이고(UUID 참조, 빌드 phase 등), 이 환경에서는 실제로 열어서 검증할 방법이 없습니다. 대신 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 `project.yml`(사람이 읽기 쉬운 YAML)에서 프로젝트를 생성하는 방식을 택했습니다. Xcode/Swift 툴체인이 있는 Mac에서 한 번 명령어를 실행하면 됩니다.

### 오디오 엔진: `AVAudioEngine` 대신 `AVPlayer`를 쓴 이유

원래 스펙은 `AVAudioEngine`(EQ/크로스페이드용)이었지만, `AVAudioEngine`은 네트워크 스트림 URL을 직접 재생할 수 없습니다(디코딩된 버퍼/파일만 받음). 실시간 스트림에 EQ를 걸려면 `MTAudioProcessingTap`같은 low-level C 콜백 코드가 필요한데, 컴파일 검증이 불가능한 상태에서 이런 코드를 작성하는 건 위험도가 너무 높다고 판단했습니다.

그래서 Phase 1은 `AVPlayer`(`PodoKit/Player/AudioPlayerEngine.swift`)로 스트리밍/재생을 구현했고, EQ/크로스페이드는 이후 단계에서 `AVPlayerItem`에 탭을 붙이는 방식으로 확장할 수 있도록 여지를 남겨뒀습니다. 이 부분이 원래 스펙과 다른 유일한 아키텍처 결정이니 참고해주세요.

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
1. 프로젝트 네비게이터에서 `Podo` 프로젝트 선택 → 각 타겟(`Podo-iOS`, `Podo-macOS`)의 **Signing & Capabilities**에서 본인 Team을 선택하세요 (자동 서명 실패 시 `project.yml`의 `PRODUCT_BUNDLE_IDENTIFIER`를 고유한 값으로 바꾸고 `xcodegen generate` 재실행).
2. 스킴을 `Podo-iOS`(시뮬레이터/기기) 또는 `Podo-macOS`로 선택 후 Run.

`project.yml`이나 `Podo/`, `Packages/PodoKit/`의 폴더 구조를 바꿀 때마다 `xcodegen generate`를 다시 실행해야 `.xcodeproj`에 반영됩니다. `.xcodeproj`와 `Generated/` 폴더는 `.gitignore`에 포함되어 있습니다 (project.yml에서 재생성 가능한 산출물이므로).

## Phase 1 수동 테스트 체크리스트

- [ ] **온보딩**: 서버 URL 입력 → `GET /health` 검증 → 저장. 잘못된 URL/도달 불가 서버 입력 시 에러 메시지 확인.
- [ ] **로그인**: 유효/잘못된 자격증명 모두 테스트.
- [ ] **회원가입**: 초대코드 있음/없음 케이스.
- [ ] **라이브러리**: 목록 로드, 정렬(`최신순/오래된순/인기순/재생순`)·필터(`전체/내가 추가한/즐겨찾기`) 전환, pull-to-refresh.
- [ ] **트랙 상세**: 아트워크, 태그, 가사(있는 트랙/없는 트랙 모두) 표시 확인.
- [ ] **재생**: 목록에서 재생 시작 → 미니 플레이어 표시 → 다음/이전 곡 이동 → 곡 종료 시 자동으로 다음 곡.
- [ ] **풀스크린 플레이어**: 스크러버 드래그로 탐색(seek), 재생/일시정지.
- [ ] **잠금화면/제어센터**: 재생 중 잠금화면에 곡 정보·아트워크 표시, 거기서 재생/일시정지/다음/이전/탐색 컨트롤 동작 확인.
- [ ] **백그라운드 재생**: 앱을 백그라운드로 보내거나 기기를 잠가도 재생이 끊기지 않는지 확인 (iOS 백그라운드 오디오 모드).
- [ ] **토큰 자동 갱신**: 로그인 상태로 15분 이상 방치 후 아무 요청이나 실행 — access token이 만료되어도 자동으로 refresh 후 정상 동작해야 함 (401 → refresh → 재시도는 `APIClient.executeWithAuthRetry`에서 처리).
- [ ] **강제 로그아웃**: refresh token이 무효화된 상태(예: 다른 기기에서 로그아웃)에서 요청 시 로그인 화면으로 자동 전환되는지 확인.
- [ ] **로그아웃**: 계정 탭에서 로그아웃 → 온보딩을 다시 거치지 않고 로그인 화면으로 돌아오는지 확인 (서버 URL은 유지됨).

## Phase 1 스코프 밖 (의도적으로 미구현)

플레이리스트 CRUD, 즐겨찾기 토글 UI, 검색, 뮤직비디오 재생, 업로드, 라디오, Live Activity/다이나믹 아일랜드, 관리자 화면 — 원래 문서의 Phase 2/3 항목입니다. `is_favorited`/`favorite_count`/`has_video` 필드는 모델에 이미 있고 목록에 표시만 되므로, 다음 단계에서 상호작용을 붙이면 됩니다.

## 알려진 단순화/주의사항

- `APIClient`, `AuthStore`, `PlayerStore`는 모두 `PodoKit` 패키지 안에 있고 `@MainActor` + `@Observable`로 SwiftUI에 주입됩니다. `APIClient` 자체는 `actor`라서 네트워크 I/O는 메인 스레드를 막지 않습니다.
- 스트리밍 URL은 항상 `format=aac`로 강제 요청합니다(`PlayerStore.loadAndPlay`) — 원본 포맷이 뭐든 `AVPlayer`가 확실히 디코딩할 수 있는 코덱으로 통일하기 위함입니다. 무손실 재생이 필요해지면 이 부분을 트랙의 `sources[].format`을 보고 조건부로 바꾸면 됩니다.
- 재생 큐는 `Track`(목록 응답) 배열 기반이며, 스트림 URL은 각 트랙을 재생하기 직전에 그때그때 새로 발급받습니다 (access token이 15분 만료라, 미리 큐 전체의 URL을 구워두면 나중 트랙은 만료된 토큰을 물고 있을 수 있어서).
