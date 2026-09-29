# LYNCO 런타임 코드 점검 / 리팩토링 기록

## 범위와 보존

Godot 4.7.1 / GL Compatibility, Windows, GTX 1060 6GB에서 검증했습니다.
`scripts/`의 기존 게임 스크립트 36개, `effects/`의 런타임·데모·캡처·베이크 코드, 셰이더와 씬 참조를 읽고 점검했습니다. 카드 편집기 C# 및 Godot 내보내기 코드의 데이터 경계도 확인했습니다. 외부 편집기 UI나 Blender 제작 도구의 재설계는 하지 않았습니다.

작업 시작 시 미커밋 상태였던 최근 UI·의자·카메라·알림·촛불·커튼 작업을 보존했습니다. 리팩토링 직전 코드 사본과 SHA-256 목록은 작업·보관 폴더 `refactor-20260929/`에 저장했습니다. 보존 대상 114개 파일은 해당 시점과 바이트 단위로 동일합니다. 여기에는 커튼/불꽃 효과 전체, 셰이더, 씬, 규칙 데이터, 촛불·촛농·극장·실크·알림·배치 카메라 코드가 포함됩니다.

## 구조 변경

| 경계 | 변경 이유와 결과 |
| --- | --- |
| 전투 조정 / 검증 | `battle_ui.gd` 1686 → 1329줄. 5개 CLI 시나리오와 4개 입력 도우미를 `tests/support/battle_scenarios.gd`로 이동. 기존 함수는 위임하여 외부 테스트 호환 유지. 일반 실행에서는 검증 객체를 생성하지 않음. |
| 논리 좌표 | `board_geometry.gd`에서 열·행·용량·잘못된 좌표·8방향·행 우선 빈 칸 탐색 관리. 모델/테이블/방향 미리보기에서 공유. 3D 위치·메시·카메라 값은 표시 계층에 유지. |
| 표시 데이터 | `linked_rules.gd`에서 카드별 설명 문자열을 최초 요청 때만 구성. 캐시 반환값은 깊은 복사이므로 한 화면의 수정이 다른 화면을 오염시키지 않음. |
| 데이터 유효성 | 버전의 타입·정확한 값, 이름/분류/설명/아이콘의 타입, 색상 bool, 중복 방향을 경계에서 검증. 유효한 현재 데이터는 동일하게 처리. |
| 모델 / 테이블 연결 | 기존 `ui_stage.get_parent()`는 CanvasLayer를 반환하여 모델 연결 조건을 건너뜀. 모델의 `link_allowed_at()`을 Callable로 직접 주입하여 투자·소유 조건과 발광 대상 일치. 규칙 자체는 변경하지 않음. |
| 투자 표시 | 3D 라벨 생성·갱신을 테이블에 이동. 투자하지 않은 카드의 빈 Label3D를 만들지 않음. 회수 후 라벨 재사용. |
| 공통 표시 | 화면 크기 맞춤을 `screen_style.fit_stage()`로 공유. 중간에 흩어진 필드·상수 선언을 메서드 앞에 모음. |
| 반복 작업 | 카드 선택이 없을 때 투자 패널 raycast 생략, 동일한 턴 진행값의 redraw 생략, 베이크할 카드 ID 목록 한 번 조회. 시작 예열은 실제 카드 목록과 유효한 행·열을 사용. |

## 점검한 모듈

- 모델/정의: `battle_model`, `table_battle_model`, `linked_battle_model`, `linked_rules`, `catalog`, `collection_session`.
- 전투 연결/입력: `battle_ui`, `linked_battle_panel`, `table_view`, `placement_camera`, `window_controls`.
- 카드/설명/심볼: `card_view`, `card_inspector`, `card_texture_baker`, `card_symbols`, `card_symbol_preview`, `direction_preview`, `direction_diagram`, `table_cost_badge`.
- 화면: `library_screen`, `shop_screen`, `inventory_panel`, `main_card_button`, `screen_style`, `theatre_style`.
- 피드백: `notification_popup`, `notification_bar`, `rolling_number_label`, `turn_track`.
- 장식/효과: `table_decoration`, `theatre_room`, `silk_tablecloth`, `candle_animation`, `candle_wax`, 커튼 및 불꽃 효과 코드·셰이더.
- 보존한 구형 표시: `board`, `meter`. 상속과 기존 기준 검사에 쓰이는 구형 전투 모델도 임의 삭제하지 않음.

## 검증 방법

리팩토링 전 전체 38개 검사 중 37개 통과. 기존 theatre_room_test만 과거 광원 범위 1.4~1.8을 검사하여 실패했습니다. 승인된 촛불 기준은 1.10, 흔들림 상한은 ±10.7%이므로 검사만 0.9823~1.2177로 바로잡았습니다.

- 기존 256개 시드 / 20,480회 구형 모델 전이 기준 검사를 유지.
- 실제 연결 모델은 변경 전에 고정한 16개 시드·덱 조합 / 350개 상태의 SHA-256과 비교. 손패·덱·버림·배치·자원·점수·종료·RNG 순서를 포함.
- `link_binding_test`: 실제 씬에서 투자 전/후, 아군/적군 조건, 회수, 범위 밖 좌표, 라벨 지연 생성·재사용 검증.
- `structure_refactor_test`: 좌표 순서, 손상된 입력, 캐시 독립성과 제한된 캐시 크기 검증.
- `script_parse_test`: 런타임/효과/검증 도우미 50개 스크립트 로드 검사.
- `curtain_runtime_test`: 승인된 효과를 그대로 실행하여 중복 입력 차단, 1초 닫힘 대기, 씬 전환, 크기 변경, 일시정지 상태 재생 검증. 결과 이미지는 프로젝트의 test-results에 저장.
- `influence_top_test`는 모델 없는 표시 전용 fixture임을 명시하고 빈 콜백으로 실행. 실제 모델 연결은 별도 통합 검사에서 검증.
- `inspector_badge_test`의 좁은 확대 정점은 고정 시간 Tween 진행으로 검사하여 GPU 프레임 간격에 따른 우발 실패를 제거. 나머지 실제 실행 검사는 유지.

```powershell
./tests/run_suite.ps1 -Godot 'C:\path\Godot_v4.7.1-stable_win64_console.exe' -Label regression
# 단일 함수 처리 시간 비교 (전체 FPS 측정 아님)
Godot_v4.7.1-stable_win64_console.exe --headless --path D:\Lynco --script res://tests/definition_benchmark.gd
```

## 측정과 제한

동일한 6종 카드의 설명 12,000회 요청, 5회 중앙값: 재구성 266.653ms → 캐시 반환 59.335ms, 약 4.49배. 반환값의 내용은 동일하며 캐시도 변경 가능한 독립 복사본을 반환합니다. GPU FPS 개선 수치로 해석하면 안 됩니다.

전투 수치·규칙·랜덤 소비 순서, 커튼의 움직임·재질·대기 시간, 촛불/촛농, 카메라 복귀 시간, 알림 3개 규칙은 유지했습니다. 다른 OS/GPU, 장시간 수동 플레이 및 별도 EXE 카드 편집기의 전체 실행은 이번 검증 범위 밖입니다.

## 최종 실행 결과

최종 결과: **43/43 PASS**. 전체 실행(`audit-after`) 후 큐브 검사 수정분과 새 검사 2개를 `audit-final-checks`에서 실행했습니다. 같은 검사의 가장 최근 결과를 합친 목록은 `test-results/audit-final/summary.json`에 있으며 원본 로그 폴더도 각 행에 기록했습니다. 중간 실패 로그는 삭제하지 않았습니다.

실제 GL 실행: 카메라 복귀, 배치 시점, 알림, 영향 표시, 인벤토리, 카드 상세, 손패 셔플, 드로우/턴 전환, 조명, 커튼, 메뉴·카드북·상점 이동. 내장 검증의 16회 재시작에서 노드 수 **439 → 439**로 유지. 모델 기준 비교와 전체 파싱도 통과했습니다. 전투·커튼의 실행 캡처를 눈으로 확인했습니다.

| 검사 | 최종 결과 | 로그 폴더 |
| --- | --- | --- |
| camera_transition_test | PASS | audit-after |
| candle_integration_test | PASS | audit-after |
| card_focus_test | PASS | audit-after |
| curtain_runtime_test | PASS | audit-final-checks |
| direction_ui_test | PASS | audit-after |
| fullscreen_test | PASS | audit-after |
| hud_layout_test | PASS | audit-after |
| influence_top_test | PASS | audit-after |
| inspector_badge_test | PASS | audit-final-checks |
| inspector_flip_test | PASS | audit-after |
| interaction_polish_test | PASS | audit-after |
| inventory_test | PASS | audit-after |
| link_binding_test | PASS | audit-after |
| linked_model_parity_test | PASS | audit-after |
| linked_rules_test | PASS | audit-after |
| linked_ui_test | PASS | audit-after |
| mirror_ui_test | PASS | audit-after |
| model_test | PASS | audit-after |
| motion_feedback_test | PASS | audit-after |
| navigation_test | PASS | audit-after |
| notification_test | PASS | audit-after |
| optimization_model_parity_test | PASS | audit-after |
| optimization_resources_test | PASS | audit-after |
| optimization_test | PASS | audit-after |
| ownership_ui_test | PASS | audit-after |
| pile_turn_test | PASS | audit-after |
| placement_camera_test | PASS | audit-after |
| refactor_test | PASS | audit-after |
| rolling_number_test | PASS | audit-after |
| script_parse_test | PASS | audit-final-checks |
| shift_model_test | PASS | audit-after |
| shift_ui_test | PASS | audit-after |
| silk_tablecloth_test | PASS | audit-after |
| structure_refactor_test | PASS | audit-after |
| table_game_ui_test | PASS | audit-after |
| table_rules_test | PASS | audit-after |
| theatre_room_test | PASS | audit-after |
| theatre_ui_test | PASS | audit-after |
| verify | PASS | audit-after |
| verify-inspector | PASS | audit-after |
| verify-look | PASS | audit-after |
| verify-motion | PASS | audit-after |
| verify-table | PASS | audit-after |
