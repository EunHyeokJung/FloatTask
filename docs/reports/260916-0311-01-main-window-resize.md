# 작업 기록 - 메인 창 크기 조절

- 일시: 2026-09-16 03:11 (KST)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 기능 추가/버그 수정/검증

## 요약

- 메인 Task 창에 네이티브 테두리/모서리 드래그 크기 조절을 추가했습니다. 기본 크기는 360 × 500pt, 최소 크기는 320 × 280pt입니다.
- 시스템 titlebar나 별도 핸들·설명문은 추가하지 않고 기존 material과 헤더 간격을 유지했습니다.
- 내용 영역이 창을 채우며 Task 말줄임은 변경된 실제 폭을 사용합니다. 마지막 창 위치와 크기를 함께 복원합니다.

## 변경 범위

- 적용 창을 질문하면서 답이 없으면 메인 Task 창부터 진행한다고 알렸으며, 이번 구현은 메인 창에 한정했습니다. 채팅·완료·Settings의 자체 크기 조절은 변경하지 않았습니다.
- NSWindow의 resizable 스타일을 활성화하고 고정 최대 크기 및 SwiftUI 루트의 고정 폭/높이를 제거했습니다.
- AppKit이 창 크기를 소유하도록 hosting view sizingOptions를 해제하고, 콘텐츠 연결 이후 최소 크기를 지정했습니다.
- 최소 크기 이하 드래그가 실제 UI 검증에서 재현되어 windowWillResize에서도 크기를 제한했습니다. 과거에 너무 작게 저장한 프레임은 복원 시 최소 크기로 보정합니다.
- 메인 창 크기 변경 때 열린 보조 패널은 크기/콘텐츠/세션을 보존하고 화면의 빈 옆 공간으로 재배치합니다. 보조 패널의 기본 높이는 가변 메인 높이가 아니라 기존 500pt를 사용하도록 수정했습니다.
- 도메인 모델, Task JSON, CLI, 사용자 설정 항목은 변경하지 않았습니다. Google OAuth TODO는 이번 범위와 무관하여 유지했습니다.

## 주요 변경 파일

- `Sources/FloatTask/FloatTaskApp.swift`
- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/SidePanelStyle.swift`
- `Sources/FloatTask/DesignTokens.swift`
- `Tests/FloatTaskUITests/AppPreferencesTests.swift`
- `docs/02-specs.md`, `docs/03-product-plan.md`
- `design-system/floattask/MASTER.md`

## 리스크/이슈

- `swift test` 27개 통과. 최소 크기 제한, 가변 메인 높이에서 보조 패널 크기 유지, 보조 패널 재배치 회귀 테스트를 추가했습니다.
- `./scripts/build-app.sh`, `codesign --verify --deep --strict dist/FloatTask.app` 통과.
- 격리된 번들/Task 파일/설정 도메인의 실제 앱에서 네이티브 드래그를 검증했습니다. 600 × 620pt 확대 시 긴 제목 전체 표시, 320 × 280pt 최소 크기에서 헤더/목록 유지, 최소 이하 추가 축소 차단을 확인했습니다.
- 일반 창과 항상 위 창에서 가로/세로 조절을 확인했습니다. 520 × 560pt로 조절한 후 프로세스를 재시작하여 동일 크기 복원을 실제 화면과 저장 프레임으로 확인했습니다.
- 메인 창을 확대해도 새 채팅 패널은 기존 336 × 500pt를 유지하며 입력창이 하단에 표시됩니다. 열린 보조 패널의 비겹침 재배치는 AppKit 창 테스트로 확인했습니다.
- 기존 접근성 레이블과 키보드 명령을 유지하며, 크기 변경 자체에는 추가 애니메이션을 적용하지 않습니다. 모션 감소 분기도 기존대로 유지합니다.
- UI 스킬의 최소 장식·시스템 토큰·중립 문구 기준을 유지했습니다. 새 헤딩·상태 배지·UI 문구를 추가하지 않았습니다.
- 실제 사용 중인 앱은 이전 대화 보존을 위해 재시작하지 않았습니다. 최신 배포 번들에 Settings와 언어/호버 수정이 함께 포함됩니다.

## 다음 작업

- 사용자 재시작 확인 후 최신 배포 번들을 실행합니다. Task 데이터는 유지되지만 현재 메모리 내 대화는 초기화됩니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
- 검증 임시 파일은 검증 종료 후 `~/.Trash/FloatTask-resize-qclC58`로 이동해 복구 가능하게 보관합니다.
