# 작업 기록 - 메뉴 막대 직접 창 표시 전환

- 일시: 2026-09-16 18:27 (KST)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: UI 동작 변경/검증

## 요약

- 메뉴 막대 아이콘의 드롭다운 메뉴를 제거하고 클릭 즉시 메인 Task 창을 표시/숨김 전환하도록 변경했습니다.
- Settings는 자동으로 열리지 않습니다. 기존 창 안의 gear와 `⌘,` 진입점은 유지합니다.
- 단순 숨김은 앱 종료나 패널 닫기가 아니며, 창 크기·위치와 열려 있던 보조 패널·입력 내용을 보존합니다.

## 변경 범위

- NSStatusItem에 메뉴를 연결하지 않고 버튼 target/action을 직접 연결했습니다. 클릭 한 번당 전환 한 번이며 접근성 레이블/툴팁은 `Show or hide FloatTask`입니다.
- MainWindowVisibilityController를 추가해 메인과 열린 채팅·완료·Settings 패널을 한 번에 숨기고 같은 인스턴스로 복원합니다.
- AppKit의 orderOut은 자식 창 연결을 해제하므로, 보조 창과 기존 연결 순서를 보관하고 복원 시 다시 연결합니다. 닫는 중인 패널은 isClosing 상태로 구분해 다시 열지 않습니다.
- 메인 뷰가 화면에서 사라질 때 패널을 파괴하던 정리를 앱 종료 알림으로 옮겼습니다. 숨기기/다시 표시하기가 채팅 세션이나 입력 상태를 초기화하지 않습니다.
- Dock 등으로 다시 여는 동작은 숨긴 창들을 복원합니다. 메인이 숨겨진 상태에서 Settings를 요청하거나 메뉴 막대 아이콘을 비활성화하면 메인을 먼저 복원해 접근 경로를 유지합니다.
- 기존 메인 X 버튼의 앱 종료 동작, UI 설정, Task 모델/JSON/CLI는 변경하지 않았습니다. Google OAuth TODO는 이번 범위와 무관해 유지했습니다.

## 주요 변경 파일

- `Sources/FloatTask/MenuBarController.swift`
- `Sources/FloatTask/MainWindowVisibilityController.swift`
- `Sources/FloatTask/FloatTaskApp.swift`
- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/SidePanelStyle.swift`
- `Sources/FloatTask/ChatPanel.swift`
- `Sources/FloatTask/CompletedTasksPanel.swift`
- `Sources/FloatTask/SettingsPanel.swift`
- `Tests/FloatTaskUITests/AppPreferencesTests.swift`
- `Tests/FloatTaskUITests/MainWindowVisibilityTests.swift`
- `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- `design-system/floattask/MASTER.md`

## 리스크/이슈

- `swift test` 29개 통과. 실제 NSStatusBarButton의 performClick으로 메뉴 미연결과 직접 콜백을 검증하고, 일반/고정 창에서 반복 클릭에 따른 메인·보조 창 표시 전환, 창 인스턴스/크기/위치/입력 보존을 확인했습니다.
- 첫 테스트에서 AppKit이 자식 창 연결을 해제하는 동작을 발견해 복원 로직을 보완했습니다. 반복 hide가 기존 상태를 덮어쓰지 않는지, 닫는 중인 패널은 다시 열리지 않는지도 검증했습니다.
- `./scripts/build-app.sh`, `codesign --verify --deep --strict dist/FloatTask.app` 통과.
- 격리된 앱/Task 파일/설정 도메인으로 실제 메인·Settings 접근성 트리와 메뉴 막대 표시 설정 on/off를 확인했습니다. 현재 화면 도구가 macOS 상태 영역을 노출하지 않아 메뉴 막대 아이콘의 포인터 클릭은 직접 관찰하지 못했고, 동일 버튼의 실제 AppKit 액션 호출로 대체 검증했습니다.
- 실제 실행 앱의 채팅이 비어 있고 진행 중 응답·미전송 입력이 없음을 확인한 후 최신 dist 번들로 재시작했습니다. 기존 Task 목록과 메뉴 막대 표시 켜짐 상태가 유지됐습니다. 재시작 전후 Task 파일의 SHA-256도 동일합니다.
- 새로운 장식/배지/헤딩 없이 기존 시스템 아이콘 외형을 유지했으며, 표시 전환에 추가 애니메이션을 적용하지 않아 모션 감소 상태에서도 즉시 동작합니다.
- 검증용 프로세스만 종료하고 임시 파일은 `~/.Trash/FloatTask-menubar-toggle-AHT5fk`로 이동해 복구 가능하게 보관했습니다. 실제 최신 앱은 실행 중입니다.

## 다음 작업

- 이번 요청의 필수 후속 작업 없음.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
- 이전 Settings·언어·호버·창 크기 조절 수정도 이번 실제 앱 재시작에 함께 반영됐습니다.
