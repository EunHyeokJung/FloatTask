# Agent Working Agreement

이 저장소는 macOS 오버레이 태스크 앱 `FloatTask`와 에이전트용 CLI를 함께 관리합니다.
문서는 대화 기록보다 우선하는 프로젝트의 단일 실행 컨텍스트입니다.

## 반드시 읽기 (매 작업 전)

- `docs/01-folder-architecture.md`
- `docs/02-specs.md`
- `docs/03-product-plan.md`
- `docs/todo/00-todo-list.md`

## 작업 전 체크리스트

- 위 필수 문서와 현재 요청에 관련된 TODO 문서를 읽었는지 확인합니다.
- 작업이 `Project → Task` 중심의 개인용 macOS 태스크 패널 범위를 벗어나지 않는지 확인합니다.
- `FloatTaskCore → FloatTask/FloatTaskCLI` 의존 방향을 지키는지 확인합니다.
- UI, CLI, JSON 저장소가 동일한 도메인 모델을 사용하는지 확인합니다.
- 기존 JSON 스키마와 CLI 출력을 깨뜨리는 변경인지 확인합니다.
- macOS 14 이상 및 Swift 6.1 빌드 환경을 유지합니다.
- UI 변경은 키보드 접근, VoiceOver 레이블, 모션 감소 설정을 함께 검증합니다.
- 관련 TODO가 현재 요청과 이어질 수 있으면 내용을 요약해 알리고 이번 범위에 포함할지 확인한 뒤 진행합니다.

## 코드 규칙

- 공용 모델과 저장 로직은 `Sources/FloatTaskCore`에만 둡니다.
- 앱과 CLI가 각자 파일을 직접 파싱하거나 별도 저장 형식을 만들지 않습니다.
- 모든 변경은 `TaskFileStore.update`를 통해 원자적으로 기록합니다.
- 새 외부 서비스는 Core의 어댑터로 격리합니다.
- UI의 색상, 간격, 모션은 `DesignTokens.swift`의 의미 기반 토큰을 사용합니다.
- 장식용 상태 배지, 헤딩 위 오버라인, 대화체 UI 문구를 추가하지 않습니다.
- 사용자 데이터와 무관한 검증에는 `--data-file` 또는 `FLOATTASK_DATA_FILE`로 격리된 저장소를 사용합니다.

## 검증 규칙

- Core·CLI 변경은 `swift test`와 관련 CLI 왕복을 실행합니다.
- 앱 변경은 `./scripts/build-app.sh`와 `codesign --verify --deep --strict dist/FloatTask.app`을 실행합니다.
- UI 동작 변경은 실제 앱에서 접근성 트리와 화면 상태를 확인합니다.

## 문서 업데이트 규칙

- 코드와 문서가 다르면 구현 전에 `docs/01`, `docs/02`, `docs/03` 중 해당 문서를 먼저 갱신합니다.
- 중요한 완료 작업은 `docs/reports/yymmdd-HHMM-NN-작업키워드.md`에 기록하고 `docs/reports/_template.md`을 따릅니다.
- 지금 처리하지 못하지만 반드시 이어가야 하는 작업은 `docs/todo`에 문서를 만들고 `docs/todo/00-todo-list.md`에 한 줄 요약을 함께 추가합니다.
- TODO 완료 시 해당 TODO 문서와 인덱스 항목을 제거하고 완료 내용을 `docs/reports`에 기록합니다.
- 사용자가 관련 TODO를 현재 요청과 분리하면 요청 범위만 처리하고 TODO는 변경하지 않습니다.

## 참고

- 이 문서는 간결하게 유지하며 세부 구조·스펙·제품 범위는 `docs/01`, `docs/02`, `docs/03`을 우선합니다.
