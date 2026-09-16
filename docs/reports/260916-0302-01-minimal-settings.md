# 작업 기록 - 최소 Settings와 메뉴 막대 표시

- 일시: 2026-09-16 03:02 (KST)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 기능 추가/리팩터/검증

## 요약

- 메인 헤더에 설정 아이콘을 추가하고 채팅 설정·앱 메뉴·`⌘,`를 같은 Settings 패널로 통합했습니다.
- `Show in menu bar`, `Keep on top`, `Reply language` 세 항목만 제공합니다. 메뉴 막대는 기본 꺼짐이며 기존 핀/언어 값은 그대로 사용합니다.
- 기존 material, SF Symbols, 간결한 영문 레이블을 유지하고 별도 카드·설명문·native select·Save 버튼 없이 작은 스위치와 언어 선택 메뉴로 구성했습니다.

## 변경 범위

- `AppPreferences`가 세 UI 설정의 단일 상태를 소유하고 UserDefaults에 즉시 저장합니다. 메인 핀과 Settings 스위치가 서로 동기화되며, 언어 설정은 채팅의 다음 요청에 전달됩니다.
- 설정은 336 × 252pt borderless 패널이며 메인 옆 빈 공간에 위쪽을 맞춰 배치합니다. 반복 호출 시 이미 열린 패널을 재사용하고 채팅·완료 패널의 상태를 유지합니다.
- 패널 크기를 선택적으로 받을 수 있도록 기존 배치/표면 컴포넌트를 확장했습니다. 기존 336 × 500pt 패널의 기본값은 유지했습니다.
- `Show in menu bar`는 템플릿 체크 원 아이콘을 즉시 생성/제거합니다. 메뉴는 `Show FloatTask`, `Settings…`, `Quit FloatTask`만 제공합니다.
- 기존 메인 X 버튼의 앱 종료 동작은 변경하지 않았습니다. 자동 실행, 테마, 모델, 외부 연동 등의 설정은 추가하지 않았습니다.
- Settings 종료 후 메인 필드가 의도치 않게 편집 상태로 들어가지 않도록 포커스를 정리했습니다.
- Task JSON, Core와 CLI 출력, 실제 사용자 데이터는 변경하지 않았으며 Google OAuth TODO는 범위에서 제외했습니다.

## 주요 변경 파일

- `Sources/FloatTask/AppPreferences.swift`
- `Sources/FloatTask/SettingsPanel.swift`
- `Sources/FloatTask/MenuBarController.swift`
- `Sources/FloatTask/FloatTaskApp.swift`
- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/ChatPanel.swift`
- `Sources/FloatTask/SidePanelStyle.swift`
- `Sources/FloatTask/DesignTokens.swift`
- `Tests/FloatTaskUITests/AppPreferencesTests.swift`
- `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- `design-system/floattask/MASTER.md`

## 리스크/이슈

- `swift test`: 24개 통과. 기존 18개와 설정 기본값/복원, 기존 키 호환, 미지원 언어 fallback, 메뉴 막대 수명 주기, 작은 패널 배치, 기존 패널 크기 회귀 테스트 6개를 포함합니다.
- `./scripts/build-app.sh` 및 `codesign --verify --deep --strict dist/FloatTask.app` 통과.
- 격리된 앱 번들/Task 파일/설정 도메인으로 실제 화면과 접근성 트리를 확인했습니다. 메인 gear → Settings, 채팅 gear → 동일 Settings, `⌘,`, Escape, 닫기 후 편집 포커스 해제, 핀 설정 양방향 동기화, 세 설정 재시작 후 복원, 채팅·완료 패널 동시 유지가 확인됐습니다.
- 실제 봇을 호출하지 않는 모의 실행으로 Settings의 English 선택이 채팅 응답까지 전달되는 것을 확인했습니다.
- 아이콘 레이블, 언어 현재 값, 스위치 on/off는 접근성 트리에 노출됩니다. 스위치의 Tab 탐색은 macOS 키보드 탐색 설정을 따릅니다. OS 접근성/외관 설정은 변경하지 않았습니다.
- Settings는 이동 애니메이션 없이 열고 닫으므로 모션 감소 상태에서도 추가 움직임이 없습니다. 색상은 시스템 의미 토큰을 사용합니다.
- 화면 도구가 macOS 상태 영역을 직접 노출하지 않아 메뉴 막대 전체 화면/클릭은 확인하지 못했습니다. 실제 NSStatusItem의 표시 속성, 템플릿 이미지, 중복 생성 방지, 제거, 메뉴 제목과 target/action 연결은 AppKit 테스트로 검증했습니다.
- UI 스킬의 장식용 상태·오버라인·대화체 금지 기준을 새 코드와 실제 화면에서 확인했습니다.
- 현재 실행 중인 실제 사용자 앱은 이전 대화 보존을 위해 재시작하지 않았습니다. 최신 `dist/FloatTask.app`에는 이전 언어/호버 수정도 포함되어 있으며 재시작 시 함께 반영됩니다.
- 검증용 앱을 종료하고 임시 앱/fixture는 `~/.Trash/FloatTask-settings-Wx1vqI`로 이동했습니다. 필요하면 복구할 수 있습니다.

## 다음 작업

- 사용자 재시작 확인 후 최신 배포 번들을 실행합니다. Task는 유지되며 메모리 내 기존 대화는 초기화됩니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
- 이전 작업: `docs/reports/260916-0254-01-chat-language-hover-reveal.md`
