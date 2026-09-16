# 작업 기록 - 완료 Task 옆 패널과 프로젝트별 완료 개수

- 일시: 2026-09-15 17:25 (Asia/Seoul)
- 작성자: Austin Jung
- 에이전트: Codex
- 작업 유형: 기능 추가/UI 개선

## 요약

- 헤더 왼쪽의 장식용 체크를 제거하고 실제 고정 버튼을 이동했습니다.
- 완료한 Task는 기본 목록에서 사라지고 프로젝트명 오른쪽에 `완료 N`으로 집계됩니다.
- 기존 고정 버튼 자리의 체크는 완료 목록을 엽니다. 사용자의 추가 설명에 따라 일반 시스템 창 대신 채팅과 같은 borderless 옆 패널로 구현했습니다.

## 변경 범위

- 완료 목록은 전체/프로젝트 필터, 최근 완료순(완료 시각 내림차순)·추가한순(생성 시각 오름차순), 체크 버튼을 통한 재개를 제공합니다.
- 완료 시각이 없는 기존 항목은 최근 완료순에서 마지막에 두고 `완료 시각 없음`으로 표시합니다. 동일 시각은 UUID로 정렬을 안정화합니다.
- 프로젝트의 `완료 N`은 해당 프로젝트로 필터된 패널을 엽니다. 0개는 숨기며 모든 Task가 완료되어도 프로젝트 헤더는 유지합니다.
- 채팅과 완료 패널은 표면·336 × 500pt 크기·18pt 모서리·배치·내부 헤더 및 열기 280ms/닫기 170ms 모션을 공유합니다. 같은 자리에 교대로 열리고 채팅 세션은 유지합니다.
- 완료 패널은 헤더 체크로 토글하며 `⌘⇧C`로 전체 목록을 열고 패널 닫기·Escape로 닫습니다.
- 같은 TaskViewModel을 관찰하므로 CLI의 완료 변경도 열린 패널과 프로젝트 개수에 반영됩니다.
- Core 모델·JSON 스키마·CLI 출력은 변경하지 않았습니다. 저장은 기존 TaskFileStore.update 경로를 유지합니다.

## 주요 변경 파일

- `Sources/FloatTask/OverlayView.swift`
- `Sources/FloatTask/CompletedTasksPanel.swift`
- `Sources/FloatTask/SidePanelStyle.swift`
- `Sources/FloatTask/ChatPanel.swift`
- `Sources/FloatTask/DesignTokens.swift`
- `Sources/FloatTask/FloatTaskApp.swift`
- `docs/01-folder-architecture.md`, `docs/02-specs.md`, `docs/03-product-plan.md`
- `design-system/floattask/MASTER.md`

## 검증

- `swift test`: 12개 테스트 통과.
- `./scripts/build-app.sh`: 최종 release 앱·CLI 빌드 통과.
- `codesign --verify --deep --strict dist/FloatTask.app`: 통과.
- 격리된 FLOATTASK_DATA_FILE과 별도 번들 ID의 앱에서 실제 접근성 트리·화면을 확인했습니다.
- 완료 후 기본 목록 숨김·개수 증가, 재개 후 복귀·개수 감소, 0개 개수 숨김, 프로젝트의 모든 Task가 완료된 상태를 확인했습니다.
- 전체/프로젝트 필터, 두 정렬 순서, 완료 시각 없는 항목의 위치·문구, 빈 완료 목록을 확인했습니다.
- 프로젝트 개수 버튼 진입, 패널 닫기 및 재열기, Escape, `⌘⇧C`, 채팅에서 완료 패널로 전환을 확인했습니다.
- 완료·재개 버튼과 프로젝트/정렬 Picker의 VoiceOver용 레이블을 접근성 트리에서 확인했습니다. 실제 VoiceOver 음성 낭독 테스트는 수행하지 않았습니다.
- 격리 저장소에 CLI로 Task를 완료한 뒤 열린 완료 패널의 개수·목록 갱신을 확인했습니다.
- 모션 감소는 임시 소스 복사본에서 reduceMotion=true 분기를 강제해 패널 열기·재개·Escape 닫기를 검증했습니다. OS 접근성 설정과 최종 소스는 변경하지 않았습니다.
- 최종 앱을 정상 재실행하고 실제 프로젝트별 완료 개수와 채팅 스타일의 완료 패널을 확인했습니다. 사용자 Task 데이터는 변경하지 않았습니다.

## 리스크/이슈

- 채팅·완료 패널은 동시에 표시하지 않습니다. 패널 전환으로 채팅 세션은 초기화하지 않습니다.
- 패널은 메인 창의 자식으로 등록해 창 레벨·Space 정책을 따릅니다. 여러 모니터/Space 이동 조합은 이번 실제 화면 검증 범위에 포함하지 않았습니다.

## 다음 작업

- 없음. 기존 Google OAuth TODO는 이번 범위와 무관하여 변경하지 않았습니다.

## 참고

- 관련 문서: `docs/02-specs.md`, `design-system/floattask/MASTER.md`
