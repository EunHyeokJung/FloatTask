# 작업 기록 - Task 단어 단위 말줄임

- 일시: 2026-09-15 16:06 (Asia/Seoul)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 버그 수정

## 요약

- 접힌 Task 제목의 말줄임표를 마지막 온전한 단어 뒤에 표시하도록 변경했습니다.
- Hover 전후에 동일한 단어 줄바꿈을 사용해 첫 줄의 단어가 다음 줄로 이동하지 않도록 했습니다.

## 변경 범위

- 비편집 Task 제목을 주어진 폭에 맞춰 직접 그리는 표시 전용 AppKit 뷰를 추가했습니다.
- 접힌 상태는 폭에 들어가는 마지막 단어까지 측정해 말줄임표를 붙이고, 펼친 상태는 원문을 한글 단어 우선 규칙으로 표시합니다.
- 폭보다 긴 단일 단어는 문자 단위 말줄임으로 안전하게 대체합니다.
- 저장되는 제목, 편집 필드 값, 접근성 값에는 표시용 가공을 적용하지 않습니다.
- 제품 스펙과 디자인 시스템의 줄바꿈 규칙을 단어 기준으로 갱신했습니다.

## 주요 변경 파일

- `Sources/FloatTask/OverlayView.swift`
- `docs/02-specs.md`
- `design-system/floattask/MASTER.md`

## 검증

- `swift test`: 12개 테스트 통과
- `./scripts/build-app.sh`: release 앱과 CLI 빌드 통과
- `codesign --verify --deep --strict dist/FloatTask.app`: 서명 검증 통과
- 동일한 긴 제목을 접힘·펼침 상태로 나란히 렌더링해 두 상태 모두 첫 줄이 `터치할 때마다 좌측 슬라이드 리스트가`로 유지되는 것을 확인했습니다.
- 접힌 상태는 `리스트가…`, 펼친 상태의 둘째 줄은 `움직이는 현상`으로 표시되는 것을 확인했습니다.
- 접근성 트리에는 가공하지 않은 원래 Task 제목 전체가 유지되는 것을 확인했습니다.

## 리스크/이슈

- 공백 없이 한 행보다 긴 단일 단어는 온전한 단어를 표시할 수 없어 문자 단위 말줄임을 사용합니다.

## 다음 작업

- 없음

## 참고

- 관련 문서: `docs/reports/260915-1050-01-task-hover-expand.md`, `docs/reports/260915-1530-01-task-hover-lineflow.md`, `docs/02-specs.md`, `design-system/floattask/MASTER.md`
