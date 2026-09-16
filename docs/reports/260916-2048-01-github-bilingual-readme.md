# 작업 기록 - GitHub 업로드와 영문·국문 README

- 일시: 2026-09-16 20:48 (KST)
- 작성자: Codex
- 에이전트: Codex
- 작업 유형: 문서화·저장소 초기화

## 요약

- `EunHyeokJung/FloatTask` GitHub 저장소를 생성하고 `main` 브랜치에 앱 소스·테스트·문서를 업로드했습니다.
- 영어 README를 기본으로 두고 같은 범위의 한국어 README와 언어 전환 링크를 추가했습니다.
- 공개 범위를 비동기로 확인했으나 업로드 시점까지 응답이 없어 비공개로 생성했습니다. 공개 전환은 사용자 선택에 따릅니다.

## 변경 범위

- 앱 아이콘, 실제 샘플 화면 두 장, 기능 요약, 빌드·설치, 단축키, Codex 채팅, 개인정보, CLI, Google Tasks 제한, 개발·크레딧을 두 언어로 정리했습니다.
- 스크린샷은 별도 앱 번들과 `FLOATTASK_DATA_FILE` 저장소에서 촬영했습니다. 실제 사용자 프로젝트·Task는 사용하지 않았습니다.
- `.gitignore`로 빌드 산출물, 런타임 데이터, 인증 파일과 로컬 개발 상태를 제외했습니다.
- 저장소 설명과 macos·swift·swiftui·task-manager·cli·codex 토픽을 설정했습니다.
- 초기 커밋의 whitespace 검사에서 발견한 기존 Swift 파일 끝 빈 줄과 문서 템플릿의 줄 끝 공백만 정리했습니다. 앱 동작·모델·저장 스키마는 바꾸지 않았습니다.
- `austins-docs`에 따라 기존 한국어 docs-first 구조와 고지를 유지했습니다. `austins-frontend-design` 기준으로 실제 화면과 간결한 제목을 사용하며 장식용 상태 배지·오버라인을 추가하지 않았습니다.

## 주요 변경 파일

- `README.md`, `README.ko.md`
- `docs/assets/tasks.jpg`, `docs/assets/completed.jpg`
- `.gitignore`, `docs/01-folder-architecture.md`
- 기존 Swift 파일 3개 및 문서 템플릿 2개의 공백 정리

## 리스크/이슈

- `swift test`: 30개 테스트 통과.
- release 앱 빌드와 strict codesign 검증 통과.
- 격리된 CLI 저장소에서 생성 → 완료 → 재개 → 한글 이름 변경 → 재조회와 `--data-file` 분리 동작 검증.
- README 각각 17개 링크·이미지 참조 검사. 영어·한국어 파일의 로컬 Git blob SHA와 GitHub contents SHA 일치 확인.
- GitHub Markdown API가 반환한 HTML을 로컬 미리보기에서 렌더링해 두 언어 표지·스크린샷·내용을 확인했습니다. 브라우저는 GitHub에 로그인되지 않아 비공개 저장소의 실제 페이지는 열지 못했고, 원격 파일과 브랜치는 인증된 GitHub CLI로 확인했습니다.
- 초기 업로드 커밋: `a17dcb130fc66cd0830893a01df7f95732b4feaa`. 원격 `main`과 일치 확인.
- 일반적인 자격 증명 패턴 검사에 매칭되는 파일이 없었습니다. 원격 트리에 `.build`, `dist`, Task JSON, `.env`가 포함되지 않았음을 확인했습니다. 전체 보안 감사는 수행하지 않았습니다.
- 별도 프로젝트 라이선스는 임의로 부여하지 않았습니다. README에서 기존 서드파티 고지의 적용 범위를 구분했습니다.
- GitHub Release나 서명·공증된 앱 배포본은 만들지 않았습니다. README는 소스 빌드 기준이며 현재 Codex 모델 요구사항과 수동 Google OAuth 제한을 명시합니다.

## 다음 작업

- 사용자 요청 시 저장소 공개 범위를 변경합니다.
- Google OAuth 후속 작업은 기존 TODO로 유지합니다.

## 참고

- 저장소: https://github.com/EunHyeokJung/FloatTask
- 관련 문서: `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/todo/00-todo-list.md`
