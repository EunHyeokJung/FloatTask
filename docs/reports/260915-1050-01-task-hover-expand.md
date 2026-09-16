# 작업 기록 - 긴 Task Hover 확장

- 일시: 2026-09-15 10:50 (Asia/Seoul)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 기능 추가

## 요약

- 한 줄에서 말줄임표로 표시되는 긴 Task 제목을 Hover하면 행이 아래로 확장되어 전체 제목을 여러 줄로 표시하도록 변경했습니다.
- 첫 줄 위치, 편집 동작, 완료 및 삭제 컨트롤의 위치를 유지하면서 후속 Task가 확장 높이에 맞춰 자연스럽게 이동하도록 구성했습니다.

## 변경 범위

- 비편집 Task 제목의 Hover 상태에서 줄 제한을 해제합니다.
- 기본 40pt 행 높이를 최소 높이로 전환해 긴 제목에 필요한 높이만큼 아래로 확장합니다.
- 220ms spring 확장 모션과 모션 감소 환경의 즉시 전환을 적용합니다.
- 기존 전체 제목 Hover 도움말은 인라인 확장 표시로 대체합니다.
- 제품 스펙과 디자인 시스템에 확장 동작 및 모션을 반영합니다.

## 주요 변경 파일

- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/DesignTokens.swift`
- `docs/02-specs.md`
- `design-system/floattask/MASTER.md`

## 검증

- `swift test`: 12개 테스트 통과
- `./scripts/build-app.sh`: release 앱과 CLI 빌드 통과
- `codesign --verify --deep --strict dist/FloatTask.app`: 서명 검증 통과
- 격리된 `FLOATTASK_DATA_FILE`과 별도 검증 앱에서 기본 말줄임 상태, 3줄 확장 상태, 후속 Task의 아래 이동을 화면으로 확인했습니다.
- 접근성 트리에서 전체 Task 제목 값과 완료·삭제 컨트롤 레이블을 확인했습니다.

## 리스크/이슈

- Hover가 없는 키보드 및 VoiceOver 환경에서는 기존 편집 진입점으로 전체 제목을 확인합니다.
- 확장 행이 패널의 가시 영역을 넘으면 기존 ScrollView 동작으로 접근합니다.

## 다음 작업

- 없음

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
