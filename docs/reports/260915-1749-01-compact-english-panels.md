# 작업 기록 - 영어 UI·간결한 완료 패널·동시 패널 표시

- 일시: 2026-09-15 17:49 (Asia/Seoul)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: UI 개선/기능 수정

## 요약

- 앱 제공 문구와 채팅 응답을 영어로 통일하고 사용자 프로젝트명·Task 제목은 그대로 유지했습니다.
- `완료 N`을 체크 원 아이콘과 실제 개수로 교체하고 완료 패널의 불필요한 제목·날짜 접두어를 제거했습니다.
- 네이티브 Picker 대신 프로젝트 텍스트 버튼·정렬 아이콘과 커스텀 선택 목록을 구현했습니다.
- 채팅과 완료 패널을 동시에 열고 독립적으로 닫을 수 있도록 변경했습니다.

## 변경 범위

- 완료 패널 헤더를 48pt 한 줄로 축소: 체크 원·개수·프로젝트 필터·정렬·닫기.
- 완료 행은 제목과 프로젝트/약식 날짜의 두 줄로 구성합니다. 전체 시각과 의미는 영어 툴팁·접근성 레이블로 제공합니다.
- 선택 목록은 36pt 항목·선택 체크·얕은 강조 표면을 사용합니다. 마우스 Hover와 키보드 선택 인덱스를 분리해 포인터가 방향키 선택을 되돌리지 않도록 했습니다.
- 팝오버의 키보드 입력을 AppKit responder에 연결하고 선택·취소 후 원래 패널로 포커스를 복구합니다. 다른 창 클릭으로 닫힌 경우에는 포커스를 빼앗지 않습니다.
- 채팅 안내·placeholder·상태·활동 접근성 문구·검증된 액션 결과·빈 응답 fallback을 영어로 변경했습니다. 에이전트에는 영어 응답과 사용자 콘텐츠 원문 보존을 지시합니다.
- 한글 삭제 의도 인식은 유지합니다. JSON 모델과 CLI 출력 계약은 변경하지 않았습니다.
- 두 패널은 기존 패널을 닫거나 이동하지 않고 빈 왼쪽/오른쪽 공간을 찾아 8pt 간격으로 추가됩니다. 좁은 화면은 상하 공간을 시도하고 모두 불가능할 때 겹침을 최소화하며 화면 안에 유지합니다.

## 주요 변경 파일

- `Sources/FloatTask/CompletedTasksPanel.swift`
- `Sources/FloatTask/PanelChoiceMenu.swift`
- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/SidePanelStyle.swift`
- `Sources/FloatTask/DesignTokens.swift`
- `Sources/FloatTask/ChatPanel.swift`, `Sources/FloatTask/BloubAgentAvatar.swift`
- `Sources/FloatTaskCore/CodexTaskAgent.swift`
- `Tests/FloatTaskCoreTests/FloatTaskCoreTests.swift`
- `Packaging/Info.plist`
- `docs/01-folder-architecture.md`, `docs/02-specs.md`, `design-system/floattask/MASTER.md`

## 검증

- `swift test`: 최종 14개 테스트 통과. 영어 결과 문자열, 빈 응답, 한글 사용자 제목 보존 및 에이전트 영어 지시문을 검증했습니다.
- `./scripts/build-app.sh`, `codesign --verify --deep --strict dist/FloatTask.app`: 통과.
- 격리 JSON 저장소로 CLI 생성 → 완료 → 재개 왕복을 실행해 기존 필드와 한글 제목 보존을 확인했습니다.
- 실제 검증 앱의 화면·접근성 트리에서 체크 원 개수, 단일 헤더, 두 줄 완료 행, 영어 채팅 안내·입력, 영어 빈 완료 상태를 확인했습니다.
- 커스텀 선택 목록의 마우스 프로젝트 선택, 방향키·Enter 정렬 변경, Escape 및 선택 후 포커스 복귀를 확인했습니다. 메뉴 항목은 AX로 확인했으며 윈도 단위 화면 캡처에는 별도 팝오버가 포함되지 않았습니다.
- 채팅을 연 채 완료 패널을 추가하고 완료 패널만 닫은 뒤에도 기존 채팅이 유지되는 것을 확인했습니다.
- 임시 순수 배치 검증에서 왼쪽·오른쪽·양쪽 분산·상하·음수 좌표 화면의 5가지 두 패널 배치가 화면 안에 있고 서로 겹치지 않는지 확인했습니다.
- 새로운 모션을 추가하지 않았으며 기존 모션 감소 분기를 유지했습니다. 이번 변경에서는 OS 접근성 설정을 변경하지 않았습니다.
- 최종 실제 앱을 정상 재실행하고 채팅과 새 완료 패널을 함께 열었습니다. 사용자 Task 데이터는 변경하지 않았습니다.

## 리스크/이슈

- 화면 자체가 세 패널을 담을 수 없으면 완전한 비겹침을 보장할 수 없습니다. 이때 기존 창 위치를 보존하면서 겹치는 면적을 최소화합니다.
- 실제 VoiceOver 음성 낭독과 다중 모니터 Space 전환은 이번 검증 범위에 포함하지 않았습니다.

## 다음 작업

- 없음. 기존 Google OAuth TODO는 변경하지 않았습니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
- 이전 완료 패널 기록의 상호 배타적 열기 정책은 이번 동시 표시 정책으로 대체합니다.
