# 작업 기록 - 메뉴 막대 숨김 시 앱 종료 수정

- 일시: 2026-09-16 19:03 (KST)
- 작성자: Codex
- 에이전트: Codex
- 작업 유형: 버그 수정

## 요약

- 메뉴 막대 아이콘으로 메인 창을 숨기면 앱까지 종료되던 회귀를 수정했습니다.
- 창 자동 종료 정책을 해제하고 명시적인 X·Quit 종료는 유지했습니다.

## 변경 범위

- `applicationShouldTerminateAfterLastWindowClosed`가 `false`를 반환하도록 변경했습니다. AppKit은 `orderOut`으로 마지막 표시 창을 숨긴 경우에도 이 정책을 확인합니다.
- 단순 `isVisible` 검사가 아닌 `NSApplication.run()` 이벤트 루프 회귀 테스트를 추가했습니다. 실제 상태 아이템 버튼 액션으로 일반/항상 위 모드에서 각각 두 번씩 숨김·복원을 반복하며 실제 AppDelegate 종료 정책을 사용합니다.
- 테스트의 종료 probe는 종료 요청을 기록하고 취소해 XCTest 자체가 종료되는 것을 방지합니다. 정책 호출 여부도 확인하므로 이벤트 루프가 실행되지 않아도 성공하는 테스트가 아닙니다.
- UI 문구·디자인·애니메이션·데이터 스키마는 변경하지 않았습니다. `austins-frontend-design` 기준을 확인했고 장식이나 문구를 추가하지 않았습니다.

## 주요 변경 파일

- `Sources/FloatTask/FloatTaskApp.swift`
- `Tests/FloatTaskUITests/MainWindowVisibilityTests.swift`
- `docs/01-folder-architecture.md`
- `docs/02-specs.md`

## 리스크/이슈

- 이전 검증은 창이 즉시 숨겨지는지만 확인해 이벤트 루프에서 뒤늦게 발생하는 자동 종료를 놓쳤습니다.
- 종료 전 시스템 로그(2026-09-16 18:57:16, PID 47995)에서 메뉴 액션 → 창 order out → `terminate:` → 종료 승인 → `Termination complete` 순서를 확인했습니다. 확인 범위에서 FloatTask 충돌 보고서는 없었습니다.
- 추가한 회귀 테스트는 수정 전 종료 요청 4회로 실패했고, 수정 후 0회로 통과했습니다.
- `swift test`: 30개 테스트 전체 통과. 기존 보조 패널/채팅 입력 보존 검사도 통과했습니다.
- `./scripts/build-app.sh`, `codesign --verify --deep --strict dist/FloatTask.app`: 통과했습니다.
- 갱신한 실제 앱을 실행하여 접근성 트리와 화면을 확인했습니다. 메뉴 막대 설정은 켜진 상태이며 프로세스 PID 48571로 실행 중입니다.
- 자동화 도구에 시스템 상태 아이콘이 노출되지 않아 물리적인 메뉴 막대 클릭 검증은 하지 않았습니다. 동일 버튼의 production target/action과 실제 AppKit 이벤트 루프에서 원인을 재현하고 수정 후 검증했습니다.
- 사용자 Task 데이터 SHA-256은 검증 전후 `be3b2f764f7088444de554d81ed6a5ba100fb876917f9e3e390c2aa1fd4ce37d`로 동일합니다. 회귀 테스트는 저장소를 만들지 않는 임시 창만 사용합니다.

## 다음 작업

- 없음. 관련 없는 Google OAuth TODO는 변경하지 않았습니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `docs/reports/260916-1827-01-menubar-window-toggle.md`
- [Apple: applicationShouldTerminateAfterLastWindowClosed](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldterminateafterlastwindowclosed(_:))
