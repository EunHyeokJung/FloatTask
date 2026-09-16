# 작업 기록 - README 기능별 실제 화면 갤러리

- 일시: 2026-09-16 21:15 (KST)
- 작성자: Austin 요청
- 에이전트: Codex
- 작업 유형: 문서화

## 요약

- 영문·국문 README를 Chat 중심의 기능별 화면 갤러리로 개편했습니다.
- 격리된 샘플 프로젝트로 실제 앱 화면 11개를 촬영했습니다. 사용자 기본 Task 저장소는 사용하지 않았습니다.
- 문서 구조와 시각 기준에 맞춰 두 언어의 섹션 순서, 이미지 크기, 짧은 설명을 통일했습니다.

## 변경 범위

- 상단: 완료 목록·Chat·메인 Task 창을 나란히 배치했습니다.
- Chat: 실제 Codex로 영어 Task 추가·완료, 한국어 남은 Task·완료 개수 조회를 수행했습니다. 응답은 합성하지 않았습니다.
- Task: 긴 제목의 단어 단위 축약과 Enter 입력으로 추가한 Task를 보여줍니다.
- 완료 목록: 전체 프로젝트와 Product launch 필터 결과를 비교합니다.
- Settings: 메뉴바, 고정, 답변 언어 설정을 메인 창과 함께 보여줍니다. 영어 화면은 고정 켜짐, 한국어 화면은 고정 꺼짐 상태를 일치시켰습니다.
- 창: 기본 360×500에서 380×560으로 크기를 조절한 고정 창을 보여줍니다.
- 각 이미지는 실제 네이티브 창의 개별 캡처이며, README에서 나란히 배치한 것임을 명시했습니다.

## 주요 변경 파일

- `README.md`, `README.ko.md`
- `docs/01-folder-architecture.md`
- `docs/assets/chat-en.jpg`, `docs/assets/chat-ko.jpg`
- `docs/assets/workspace.jpg`, `docs/assets/workspace-pinned.jpg`
- `docs/assets/task-collapsed.jpg`, `docs/assets/task-entry.jpg`
- `docs/assets/completed-all.jpg`, `docs/assets/completed-project.jpg`
- `docs/assets/settings.jpg`, `docs/assets/settings-ko.jpg`
- `docs/assets/window-wide.jpg`

## 리스크/이슈

- 각 README의 로컬 참조 21개가 모두 존재하는지 확인했습니다.
- GitHub Markdown API 결과를 로컬 브라우저에서 렌더링해 상단, Chat, Settings 배치를 검토했습니다. 두 언어 모두 이미지 13개가 정상 로드되었고 국문 페이지에 가로 넘침이 없었습니다.
- `git diff --check`를 통과했습니다. 앱 코드 변경이 없어 빌드·런타임 테스트는 재실행하지 않았습니다.
- 호버 애니메이션 자체와 선택 메뉴 팝오버는 캡처하지 않았습니다. 관련 이미지를 호버 전후 또는 메뉴 펼침 화면으로 설명하지 않습니다.
- 촬영 환경에서 앱별 외관 강제가 적용되지 않아 다크 모드 캡처는 포함하지 않았습니다. 운영체제의 전역 외관 설정은 변경하지 않았습니다.
- Google Tasks는 CLI 전용 기능임을 명시하고 존재하지 않는 앱 내 화면을 만들지 않았습니다.
- 저장소 공개 범위는 기존 Private 상태를 유지합니다.

## 다음 작업

- 이번 요청에 따른 추가 구현 작업은 없습니다. Google OAuth TODO는 범위 밖으로 유지합니다.

## 참고

- 관련 문서: `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- GitHub: https://github.com/EunHyeokJung/FloatTask
