LYNCO 카드 편집기

LYNCO_Card_Editor.exe를 실행하세요. 별도 설치가 필요 없는 Windows .NET Framework 프로그램입니다.
기본 카드 12개로 시작합니다. 기존 편집은 JSON 열기로 불러오세요.
JSON 저장은 편집 원본을 저장하며 HTML 저장은 현재 목록의 독립형 문서를 만듭니다.
행동 비용과 점수 -1은 미정이며 0과 다릅니다.
큐브 개수는 기존 테이블 가치이며 0~5개입니다. -1은 미정 상태만 의미합니다.
연쇄의 가치는 5개입니다. 게임 배지에는 숫자 대신 보라색 큐브 개수가 표시됩니다.
화살표는 인접 8방향입니다. 보드의 칸을 누르면 기준 위치가 바뀝니다.

Godot 내보내기는 선택한 위치 아래 새 날짜 폴더를 만듭니다.
그 안의 lynco_cards 폴더를 Godot 프로젝트 루트로 복사하세요.
cards/*.tres에서 카드 이름, 설명, 비용, 방향을 Inspector로 확인할 수 있습니다.

사용 예:
var loader = preload("res://lynco_cards/lynco_card_loader.gd")
var cards = loader.load_cards()
var data = cards["strike"].as_dictionary()
var cells = cards["strike"].target_cells(Vector2i(2, 2))

설명과 효과 ID는 데이터입니다. 효과 설명을 입력한다고 전투 코드가 자동 생성되지는 않습니다.
현재 LYNCO 게임의 내장 Catalog를 자동으로 덮어쓰거나 연결하지 않습니다.
전투 로직 연결은 별도 작업입니다. 기존 체력 전투 설명은 HTML의 이전 설명에 분리되어 있습니다.
implemented는 현재 구현 상태를 기록하는 메타데이터이며 실행 코드 검증을 의미하지 않습니다.

소스: tools/card_editor/Program.cs
빌드: powershell -ExecutionPolicy Bypass -File tools/card_editor/build.ps1
