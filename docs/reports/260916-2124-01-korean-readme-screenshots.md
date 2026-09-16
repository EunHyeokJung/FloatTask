# 작업 기록 - 한국어 README 전용 스크린샷

- 일시: 2026-09-16 21:24 (KST)
- 작성자: Austin 요청
- 에이전트: Codex
- 작업 유형: 문서화

## 요약

- 한국어 README가 영어 프로젝트·Task가 들어간 이미지를 재사용하지 않도록 한국어 샘플로 다시 촬영했습니다.
- 기존 문서·시각 기준을 유지하고 모든 앱 화면 참조를 `-ko.jpg`로 분리했습니다. 영문 README와 영문 이미지는 변경하지 않았습니다.

## 변경 범위

- 샘플 프로젝트: 제품 출시, 디자인 스튜디오, 일상.
- 한국어 Task 목록·추가 결과, 완료 목록 전체·프로젝트 필터, 고정·크기 조절 창을 새로 촬영했습니다.
- 실제 Codex에 한국어로 출시 안내문 추가와 체크리스트 완료를 요청하고 반영된 대화를 촬영했습니다.
- 한국어 답변이 선택된 Settings를 촬영했습니다.
- 본문의 프로젝트명, 이미지 대체 텍스트, 사용 예시도 새 화면에 맞췄습니다.
- 앱은 현재 고정 UI가 영어이므로 Settings·필터·날짜·입력 안내는 번역하거나 합성하지 않았습니다. 이 경계를 상단 캡션에 명시했습니다.

## 주요 변경 파일

- `README.ko.md`
- `docs/01-folder-architecture.md`
- `docs/assets/chat-ko.jpg`, `docs/assets/settings-ko.jpg`
- `docs/assets/workspace-ko.jpg`, `docs/assets/window-wide-ko.jpg`
- `docs/assets/task-collapsed-ko.jpg`, `docs/assets/task-entry-ko.jpg`
- `docs/assets/completed-all-ko.jpg`, `docs/assets/completed-project-ko.jpg`

## 리스크/이슈

- 촬영 앱의 번들 ID, UserDefaults, Task 저장소를 운영 앱과 분리했습니다. 데이터 생성·변경은 공용 CLI 또는 실제 Chat을 통해 수행했습니다.
- Task 추가 결과 화면은 CLI로 준비했으며 키보드 입력 과정을 촬영했다고 설명하지 않습니다.
- 국문 README의 이미지 13개 중 앱 화면 참조 12개가 모두 한국어 전용 파일인지 확인했습니다. 누락된 파일은 없습니다.
- GitHub Markdown API 렌더링의 상단·Chat 배치를 실제 브라우저에서 확인했습니다. 이미지 로드 실패와 가로 넘침이 없으며 390px 화면에서도 이미지가 넘치지 않습니다.
- `git diff --check` 통과. 소스 변경이 없어 빌드·런타임 테스트는 재실행하지 않았습니다.
- 실제 사용자 데이터·앱 설정과 GitHub 공개 범위는 변경하지 않았습니다.

## 다음 작업

- 이번 문서 요청에 따른 추가 작업은 없습니다. 앱 고정 UI의 다국어 지원은 이번 범위에 포함하지 않았습니다.

## 참고

- 관련 문서: `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- https://github.com/EunHyeokJung/FloatTask/blob/main/README.ko.md
