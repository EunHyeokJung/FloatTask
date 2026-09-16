# TODO - Google OAuth 자동 로그인

- 등록 일시: 2026-09-14 14:40 (Asia/Seoul)
- 작성자: Codex
- 에이전트: Codex
- 진행 시점: 배포용 Google Cloud OAuth 클라이언트 ID 확정 시

## 목표

- CLI 토큰 전달 없이 앱에서 Google 계정을 연결하고 주기적으로 동기화합니다.

## 요구사항

- Authorization Code + PKCE
- 토큰 Keychain 저장
- 만료 토큰 자동 갱신
- 계정 연결 해제와 로컬 데이터 유지 선택

## 작업 요약

- 앱의 Google Tasks 동기화를 수동 access token 방식에서 브라우저 로그인과 자동 갱신 방식으로 확장합니다.

## 선행조건

- Google Cloud 프로젝트와 macOS 데스크톱 OAuth 클라이언트 ID
- OAuth 동의 화면 및 Tasks scope 승인

## 참고

- 관련 문서: `docs/02-specs.md`, `docs/03-product-plan.md`
- todo-list 한 줄 요약: Google Cloud OAuth 클라이언트 ID 확정 후 브라우저 로그인과 Keychain 기반 자동 토큰 갱신 구현
