# 작업 기록 - Task Hover 텍스트 타이밍 동기화

- 일시: 2026-09-15 16:13 (Asia/Seoul)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 버그 수정

## 요약

- 긴 Task의 Hover 확장에서 배경 행보다 다음 줄 텍스트가 늦게 나타나던 현상을 수정했습니다.
- 행 높이가 변하는 매 프레임 표시용 텍스트를 다시 그려 배경과 텍스트가 함께 확장되도록 했습니다.
- 배경의 별도 140ms 애니메이션을 제거하고 배경·행·텍스트를 같은 160ms 스프링으로 통일했습니다.

## 변경 범위

- 표시용 AppKit 텍스트 뷰의 크기가 변할 때마다 다시 그리기를 요청합니다.
- 레이어 콘텐츠 갱신 정책을 크기 변경 중 연속 다시 그리기로 설정했습니다.
- 상태 갱신 시 대기 중인 표시 변경을 즉시 반영합니다.
- 확장 스프링을 220ms에서 160ms로 단축하고 감쇠를 높였습니다.
- 단어 단위 말줄임과 모션 감소 동작은 유지합니다.

## 주요 변경 파일

- `Sources/FloatTask/OverlayView.swift`
- `docs/02-specs.md`
- `design-system/floattask/MASTER.md`

## 검증

- `swift test`: 12개 테스트 통과
- `./scripts/build-app.sh`: release 앱과 CLI 빌드 통과
- `codesign --verify --deep --strict dist/FloatTask.app`: 서명 검증 통과
- 격리된 `FLOATTASK_DATA_FILE`과 자동 Hover 검증 앱에서 확장 애니메이션을 재생했습니다.
- 18pt에서 34pt로 변하는 전체 높이 구간에서 각 프레임 변경 후 약 1ms 이내에 텍스트 다시 그리기가 이어지는 것을 확인했습니다.
- 160ms 스프링에서 둘째 줄을 표시할 수 있는 높이에 약 68ms 내 도달하는 것을 확인했습니다.
- 검증용 자동 재생 및 로깅 코드는 최종 소스에서 제거했습니다.

## 리스크/이슈

- Hover 중 텍스트를 매 프레임 다시 그리지만 작은 단일 행과 짧은 애니메이션에만 적용됩니다.

## 다음 작업

- 없음

## 참고

- 관련 문서: `docs/reports/260915-1606-01-task-word-truncation.md`, `docs/02-specs.md`, `design-system/floattask/MASTER.md`
