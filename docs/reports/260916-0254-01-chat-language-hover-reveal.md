# 작업 기록 - 봇 답변 언어 설정과 Hover 텍스트 지연 수정

- 일시: 2026-09-16 02:54 (KST)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 기능 추가/버그 수정/검증

## 요약

- 채팅 헤더의 리셋 버튼 옆에 설정 아이콘을 추가했습니다. 작은 커스텀 선택 메뉴에서 `Korean` / `English` 답변 언어를 선택하며 기본값은 한국어입니다.
- 영어 UI와 봇 답변 언어를 분리했습니다. 설정은 재시작 후에도 유지되며 다음 요청부터 적용됩니다.
- Hover 확장 중 다음 줄 전체가 들어갈 높이를 기다리던 텍스트 레이아웃을 수정했습니다. 전체 높이로 텍스트를 배치하고 현재 행 높이로 픽셀을 잘라, 펼쳐지는 중에도 다음 줄이 드러납니다.

## 변경 범위

- 앱의 UserDefaults 설정을 요청 시작 시 캡처해 Core 프롬프트, 작업 결과 요약, 빈 응답 대체 문구와 응답 중지 문구에 전달합니다.
- 기존 대화의 영어 응답보다 현재 답변 언어 설정을 우선하도록 프롬프트에 명시했습니다. 프로젝트명과 Task 제목은 번역하지 않습니다.
- Core 공개 API의 기본값은 기존 영어를 유지해 기존 호출과 테스트의 동작을 보존했습니다. 앱은 한국어 기본 설정을 명시적으로 전달합니다.
- 기존 필터/정렬 메뉴에 선택적인 제목을 지원하도록 확장했습니다. 기본 native select는 추가하지 않았습니다.
- Hover 전후 폭, 단어 단위 말줄임, 기존 0.16초 확장 모션, 모션 감소 분기와 편집 동작은 유지했습니다.
- Task JSON 스키마, CLI 출력 형식, 실제 사용자 Task는 변경하지 않았습니다. Google OAuth TODO는 이번 요청과 무관해 유지했습니다.

## 주요 변경 파일

- `Sources/FloatTaskCore/ChatReplyLanguage.swift`
- `Sources/FloatTaskCore/CodexTaskAgent.swift`
- `Sources/FloatTask/ChatPanel.swift`
- `Sources/FloatTask/TaskViewModel.swift`
- `Sources/FloatTask/PanelChoiceMenu.swift`
- `Sources/FloatTask/OverlayView.swift`
- `Tests/FloatTaskCoreTests/FloatTaskCoreTests.swift`
- `Tests/FloatTaskUITests/TaskTitleTextViewTests.swift`
- `Package.swift`
- `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- `design-system/floattask/MASTER.md`

## 리스크/이슈

- 검증 통과: `swift test` 18개(Core 16개, 실제 AppKit 텍스트 렌더러 2개), `./scripts/build-app.sh`, `codesign --verify --deep --strict dist/FloatTask.app`.
- 격리된 CLI 저장소에서 프로젝트/Task 생성 → 완료 → 재개 → 재조회 왕복을 통과했으며 한글 제목과 ID를 보존했습니다.
- 분리된 앱 번들/저장소와 네트워크를 사용하지 않는 모의 봇으로 기본 한국어, 영어 전환/응답, 재시작 후 영어 설정 보존, 한국어 전환/응답을 확인했습니다. 실제 봇 호출은 실행하지 않았습니다.
- 실제 앱 접근성 트리에서 `Chat Settings`의 현재 언어 값, `Reply language` 제목과 선택 상태를 확인했습니다. 위/아래 방향키와 Return을 개별 입력했을 때 선택 및 채팅 입력 포커스 복구가 동작했습니다. 최초 연속 키 입력에서는 선택 변경이 확인되지 않아 개별 입력으로 재검증했습니다.
- 채팅 헤더의 설정 아이콘 위치와 기존 최소 텍스트 스타일은 실제 화면에서 확인했습니다. 자동화 도구의 포인터 동작으로 Hover 상태를 유지하지 못했으므로, 애니메이션 체감은 화면 관찰로 확정하지 않았습니다. 실제 렌더러의 중간 높이 비트맵 회귀 테스트로 조기 텍스트 표시를 검증했습니다.
- 원인 재현: 전체 높이 34px인 제목에서 26px 높이에 기존 방식은 1,224개의 텍스트 픽셀만 그렸으나 전체 레이아웃 후 클리핑은 1,481개를 그렸습니다. 기존 방식은 34px이 되어야 다음 줄을 한꺼번에 그렸습니다.
- 현재 실행 중인 사용자의 앱은 이전 대화가 남아 있어 재시작 여부를 확인 중입니다. 새 배포 번들은 빌드되어 있으며, 확인 전에는 대화 기록을 초기화하지 않습니다.
- 기존 대화는 자동 번역하지 않습니다. 설정 변경 중 처리 중인 요청은 시작 시 선택한 언어를 유지하고 새 요청부터 변경 언어를 사용합니다. 오류 UI 문구는 기존 영어를 유지합니다.

## 다음 작업

- 사용자 확인 후 실행 중인 앱을 새 빌드로 재시작합니다. Task 데이터는 유지되지만 기존 메모리 내 대화는 초기화됩니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
