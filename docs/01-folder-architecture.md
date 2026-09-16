# 1) 폴더 아키텍처

FloatTask는 공용 코어, macOS 앱, 에이전트 CLI를 분리한 Swift Package입니다. 이 문서는 저장소 구조와 각 경로의 책임을 정의합니다.

```text
FloatTask
├─ AGENTS.md
├─ README.md                      # English
├─ README.ko.md                   # 한국어
├─ .gitignore
├─ Package.swift
├─ Assets
│  └─ AppIcon.png
├─ Packaging
│  └─ Info.plist
├─ Sources
│  ├─ FloatTaskCore
│  │  ├─ Models.swift
│  │  ├─ TaskFileStore.swift
│  │  ├─ CodexTaskAgent.swift
│  │  ├─ ChatReplyLanguage.swift
│  │  └─ GoogleTasksClient.swift
│  ├─ FloatTask
│  │  ├─ FloatTaskApp.swift
│  │  ├─ TaskViewModel.swift
│  │  ├─ ChatPanel.swift
│  │  ├─ CompletedTasksPanel.swift
│  │  ├─ SidePanelStyle.swift
│  │  ├─ PanelChoiceMenu.swift
│  │  ├─ AppPreferences.swift
│  │  ├─ SettingsPanel.swift
│  │  ├─ MenuBarController.swift
│  │  ├─ MainWindowVisibilityController.swift
│  │  ├─ BloubAgentAvatar.swift
│  │  ├─ OverlayView.swift
│  │  └─ DesignTokens.swift
│  └─ FloatTaskCLI
│     └─ CLI.swift
├─ Tests
│  ├─ FloatTaskCoreTests
│  │  └─ FloatTaskCoreTests.swift
│  └─ FloatTaskUITests
│     ├─ TaskTitleTextViewTests.swift
│     ├─ AppPreferencesTests.swift
│     └─ MainWindowVisibilityTests.swift
├─ design-system
│  └─ floattask
│     └─ MASTER.md
├─ docs
│  ├─ 01-folder-architecture.md
│  ├─ 02-specs.md
│  ├─ 03-product-plan.md
│  ├─ assets                      # README용 실제 앱 화면 (샘플 데이터)
│  ├─ reports
│  │  ├─ _template.md
│  │  └─ yymmdd-HHMM-NN-작업키워드.md
│  └─ todo
│     ├─ 00-todo-list.md
│     ├─ _template.md
│     └─ google-oauth.md
├─ scripts
│  └─ build-app.sh
├─ THIRD_PARTY_NOTICES.md
├─ .build                         # SwiftPM 생성물
└─ dist                           # 배포 생성물
```

## 책임과 의존 방향

- `README.md`와 `README.ko.md`: 영어·한국어 제품 소개와 설치·사용·개발 안내. 서로 같은 기능 범위를 안내합니다.
- `docs/assets`: 격리된 샘플 데이터로 촬영한 기능별 README 화면. 메인·채팅·완료·Settings 등 실제 네이티브 창을 각각 촬영하고 README에서 나란히 배치해 보조 패널 관계를 보여줍니다. 채팅은 실제 요청·응답을 사용하며 실제 사용자 데이터나 생성한 UI 목업은 포함하지 않습니다.
- `FloatTaskCore`: 도메인 모델, 원자적 JSON 저장, Codex 작업 명령 검증, Google Tasks REST 어댑터
- `Sources/FloatTaskCore/ChatReplyLanguage.swift`: 봇 답변 언어와 언어별 결과 문구. UI 설정 저장은 앱에서 담당합니다.
- `FloatTask`: AppKit 메인/채팅 창 제어와 SwiftUI 인터페이스
- `Sources/FloatTask/CompletedTasksPanel.swift`: 같은 TaskViewModel을 관찰하는 완료 목록 자식 패널, 프로젝트 필터·정렬·재개 동작
- `Sources/FloatTask/SidePanelStyle.swift`: 채팅과 완료 목록이 공유하는 borderless 패널 표면, 크기·배치, 아이콘 버튼
- `Sources/FloatTask/PanelChoiceMenu.swift`: 간결한 필터/정렬 버튼에서 여는 키보드 접근 가능한 커스텀 선택 목록
- `Sources/FloatTask/AppPreferences.swift`: 메뉴 막대 표시·항상 위·답변 언어의 단일 UI 설정 상태와 UserDefaults 저장. 기존 키와 기본값을 보존합니다.
- `Sources/FloatTask/SettingsPanel.swift`: 메인·채팅·메뉴·단축키가 공유하는 작은 Settings 패널
- `Sources/FloatTask/MenuBarController.swift`: 설정에 따라 생성/제거하는 macOS 메뉴 막대 아이콘과 단일 클릭 표시/숨김 액션
- `Sources/FloatTask/MainWindowVisibilityController.swift`: 메인과 보조 패널의 비파괴적 숨김/복원. 대화·입력과 창 인스턴스를 보존합니다.
- `Assets/AppIcon.png`: macOS 앱 아이콘의 1024px 원본. 빌드 스크립트가 표준 iconset과 `.icns`를 생성합니다.
- `FloatTaskCLI`: 사람이 읽는 출력과 에이전트용 JSON 출력
- 앱과 CLI는 Core만 의존하며 서로 의존하지 않습니다.
- `Tests/FloatTaskCoreTests`: 저장소, 도메인 규칙, Google 동기화, Codex 작업 적용과 취소 동작을 검증합니다.
- `Tests/FloatTaskUITests`: 실제 앱의 텍스트 렌더러로 Hover 중간 높이 표시를 검증하고, UI 설정 저장·기존 설정 호환·메뉴 막대 아이콘 수명 주기·패널 배치를 검증합니다. 메뉴 막대 숨김은 AppKit 이벤트 루프와 실제 AppDelegate 종료 정책을 함께 실행해 지연된 자동 종료 요청도 검출합니다.
- `Packaging`과 `scripts`: 앱 번들 메타데이터와 재현 가능한 release 빌드를 담당합니다.
- `THIRD_PARTY_NOTICES.md`: Bloub와 Austin Docs Architecture 라이선스를 보존하며 앱 번들에도 복사됩니다.
- `design-system/floattask/MASTER.md`: UI 시각 언어와 토큰의 기준 문서입니다.
- `docs/reports`: 완료된 주요 작업의 검증·리스크·후속 맥락을 보존합니다.
- `docs/todo`: 현재 범위에서 완료할 수 없는 후속 작업을 단일 인덱스로 관리합니다.
- 런타임 데이터는 기본적으로 `~/Library/Application Support/FloatTask/tasks.json`에 저장됩니다.
- 테스트와 자동화에서는 `FLOATTASK_DATA_FILE`로 저장 경로를 바꿀 수 있습니다.

## 생성물과 런타임 경계

- `.build`와 `dist`는 생성물이므로 소스 구조의 기준으로 사용하지 않습니다.
- 앱과 CLI는 런타임 JSON을 직접 공유하되 모든 읽기·쓰기는 `TaskFileStore`를 통합니다.
- 새 외부 연동은 `FloatTaskCore`의 어댑터로 격리하고 UI나 CLI에 네트워크 구현을 두지 않습니다.
- Git에는 소스·테스트·제품 문서·원본 앱 아이콘과 샘플 화면만 포함합니다. 빌드 산출물, 로컬 작업 저장소, 인증 정보, 에디터 개인 상태는 `.gitignore`로 제외합니다.
