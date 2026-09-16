# FloatTask Design System

자동 추천안의 단일 컬럼·저분산·고밀도 방향은 유지하고, 웹 랜딩 페이지용 서체와 골드 강조색은 Google Tasks에 가까운 macOS 유틸리티 문맥에 맞게 조정합니다.

## Visual language

- 표면: 시스템 material 위 반투명 단일 패널
- 구조: 프로젝트 제목 아래 한 줄 작업 목록
- 장식: 별도 카드 중첩, 배지, 오버라인 없음
- 아이콘: SF Symbols outline 계열
- 앱 아이콘: 차콜 rounded square, 흰색 task circle/line, system blue checkmark의 단일 심볼
- 서체: SF Pro 시스템 폰트, 프로젝트 15pt semibold, 작업 14pt regular
- 헤더: 왼쪽 pin/pin.fill, 오른쪽 채팅·프로젝트 추가·완료 체크·설정·닫기
- 완료 요약: 프로젝트명 오른쪽 체크 원 아이콘과 실제 개수만 표시하는 12pt secondary 버튼. 배지나 상태 점 없음
- 완료 목록 패널: 채팅과 같은 336 × 500pt borderless material 패널과 열기·닫기 모션. 48pt 한 줄 헤더에 체크 원·실제 개수·프로젝트 필터·정렬·닫기만 표시. 프로젝트 텍스트 필터와 정렬 아이콘 버튼은 폼 형태의 네이티브 select 대신 커스텀 선택 목록을 엽니다. 행은 작업명과 한 줄의 프로젝트/날짜만 표시하고 전체 날짜는 툴팁으로 제공합니다. 체크 버튼으로 재개. 채팅과 독립적으로 동시에 열고 화면의 빈 옆 공간에 8pt 간격으로 배치
- 언어: 앱 제공 UI 문구는 간결한 영어. 봇 답변은 채팅 설정의 Korean / English를 따르며 기본값은 Korean. 사용자 콘텐츠는 입력한 언어를 유지
- Settings: 메인과 채팅 리셋 옆의 32pt gearshape 아이콘이 같은 336 × 252pt material 패널을 엽니다. 헤더에 Settings·닫기, 본문에 Show in menu bar·Keep on top·Reply language 세 행만 표시합니다. 첫 두 행은 작은 스위치, 언어는 현재 값·chevron과 커스텀 선택 메뉴. 추가 카드·설명문·오버라인·Save 버튼 없음
- 메뉴 막대: 체크 원 아이콘을 클릭하면 드롭다운 없이 기존 Task 창과 열린 보조 패널을 즉시 표시/숨김. 창 크기·위치·콘텐츠를 보존하며 추가 장식이나 Settings 자동 열기 없음

## Semantic colors

- Accent: system blue
- Primary text: `labelColor`
- Secondary text: `secondaryLabelColor`
- Surface: `windowBackgroundColor` + material
- Hover: `quaternaryLabelColor` 저농도
- Divider: `separatorColor`
- Destructive: `systemRed`

## Spacing

- 기본 단위: 4pt
- 패널 인셋: 16pt
- 메인 창: 기본 360 × 500pt, 최소 320 × 280pt. 네이티브 테두리 리사이즈를 사용하고 내용 폭·스크롤 높이만 유연하게 조절하며 헤더 버튼과 간격은 유지
- 프로젝트 간격: 20pt
- 행 높이: 기본 40pt, 긴 작업명 Hover 확장 시 콘텐츠 높이에 맞춰 아래로 증가
- 긴 작업명 줄바꿈: Hover 전후 같은 가용 너비와 단어 줄바꿈 규칙을 사용하고 접힌 상태는 마지막 온전한 단어 뒤에서 말줄임
- 아이콘 시각 크기: 16–18pt, 클릭 영역 32–36pt

## Motion

- 삽입: opacity + 8pt y 이동, spring 260ms
- 완료: 기본 목록에서 행 제거 + 완료 개수 갱신, spring 240ms. 완료 목록에서 재개 시 반대로 반영
- 삭제: opacity + 0.98 scale, ease-in 160ms
- hover: 삭제 컨트롤 opacity 140ms, 긴 작업명 배경·행·텍스트를 동일 트랜잭션에서 매 프레임 함께 다시 그리는 spring 160ms 확장. 텍스트는 전체 확장 높이로 레이아웃하고 현재 높이로 클리핑해 다음 줄을 즉시 부분 노출
- 모션 감소: transition을 opacity 또는 즉시 전환으로 축소
- 에이전트 아바타: 대기 눈동자/눈깜빡임, Thinking 점 파동, Comet 고정 중심점과 궤적, Wide Eyes 시선 이동
- 에이전트 아바타 상태 전환: ease-out 200ms, 연속 모션 30fps, 모션 감소 시 정지 프레임

## Accessibility

- 모든 아이콘 버튼에 명시적 accessibility label 적용
- 키보드: ⌘N 작업 추가, ⇧⌘N 프로젝트 추가, ⌘, 설정, Escape 입력 취소/설정 닫기
- 완료 상태는 색상뿐 아니라 체크 심볼과 취소선으로 표현
- 시스템 밝은/어두운 외관 토큰을 그대로 사용
