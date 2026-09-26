extends Control

const UI = preload("res://scripts/screen_style.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Card = preload("res://scripts/card_view.gd")
@export var card_book: bool = false
var stage: Control
var navigating: bool = false
var action_buttons: Dictionary = {}
var card_buttons: Dictionary = {}
var selected_id: String = ""
var detail_panel: Panel
var detail_title: Label
var detail_meta: Label
var detail_body: Label
var detail_note: Label
var detail_icon: TextureRect
var selected_label: Label
var page_label: Label
var page: int = 0
var page_size: int = 6
var dark_ink: ShaderMaterial
var light_ink: ShaderMaterial
var gallery: Control

func _ready() -> void:
 # Existing command-line battle checks keep their original entry point.
 if not card_book:
  for flag in ["--verify", "--verify-motion", "--verify-table", "--verify-look", "--verify-inspector"]:
   if OS.get_cmdline_user_args().has(flag):
    call_deferred("_navigate", "res://scenes/battle.tscn")
    return
 Engine.max_fps = 120
 theme = UI.make_theme()
 dark_ink = UI.ink_material()
 light_ink = UI.ink_material(true)
 var background := ColorRect.new()
 background.color = UI.PAPER
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(background)
 stage = Control.new()
 stage.size = Vector2(1600, 900)
 add_child(stage)
 resized.connect(_fit)
 _fit()
 if card_book: _build_book()
 else: _build_main()

func _fit() -> void:
 if not is_instance_valid(stage): return
 var ratio: float = minf(size.x / 1600.0, size.y / 900.0)
 stage.scale = Vector2.ONE * ratio
 stage.position = (size - Vector2(1600, 900) * ratio) * 0.5

func _build_main() -> void:
 UI.label(stage, "LYNCO   /   린코", Rect2(88, 54, 600, 40), 25)
 UI.label(stage, "카드를 잇고, 나만의 공연을 만들다.", Rect2(92, 194, 680, 44), 24, UI.MUTED)
 UI.label(stage, "LYNCO", Rect2(80, 235, 760, 156), 120)
 UI.label(stage, "제스터 린코의 카드 실험", Rect2(92, 405, 640, 46), 32)
 UI.label(stage, "같은 카드도 이어 쓰는 순서에 따라 달라집니다.", Rect2(94, 469, 710, 36), 22, UI.MUTED)
 action_buttons.start = UI.button(stage, "게임 시작    →", Rect2(92, 570, 510, 66), true)
 action_buttons.start.pressed.connect(_navigate.bind("res://scenes/battle.tscn"))
 action_buttons.book = UI.button(stage, "수집 카드북", Rect2(92, 653, 330, 62))
 action_buttons.book.pressed.connect(_navigate.bind("res://scenes/card_book.tscn"))
 action_buttons.quit = UI.button(stage, "종료", Rect2(440, 653, 162, 62))
 action_buttons.quit.pressed.connect(func(): get_tree().quit())
 UI.label(stage, "현재 구현된 전투로 시작합니다. 진행은 저장되지 않습니다.", Rect2(94, 742, 720, 34), 18, UI.MUTED)
 UI.panel(stage, Rect2(909, 149, 603, 606), Color("eeeee7"))
 _card(stage, "observe", Vector2(958, 243), 1.65, -0.12)
 _card(stage, "strike", Vector2(1210, 321), 1.65, 0.13)
 UI.label(stage, "관측  →  공허의 일격", Rect2(994, 784, 485, 38), 24)
 UI.label(stage, "카드 조합 · 전투 프로토타입", Rect2(92, 836, 780, 30), 17, UI.MUTED)
 action_buttons.start.grab_focus()

func _card(parent: Node, id: String, pos: Vector2, zoom: float, angle: float = 0.0) -> Control:
 var data: Dictionary = Catalog.card(id)
 var node := Card.new()
 parent.add_child(node)
 node.setup({"uid":-1}, data, load("res://assets/icons/%s.png" % data.icon), light_ink if bool(data.dark) else dark_ink, null)
 node.pivot_offset = Vector2.ZERO
 node.position = pos
 node.scale = Vector2.ONE * zoom
 node.rotation = angle
 node.locked = true
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.outline_style.shadow_size = 0
 return node

func _build_book() -> void:
 UI.label(stage, "LYNCO   /   수집 카드북", Rect2(76, 45, 1000, 55), 36)
 action_buttons.back = UI.button(stage, "←  메인으로", Rect2(1288, 48, 236, 52))
 action_buttons.back.pressed.connect(_navigate.bind("res://scenes/main_menu.tscn"))
 UI.label(stage, "기존 카드 %d종 열람 · 수집 해금과 영구 저장은 아직 적용되지 않았습니다." % Catalog.CARDS.size(), Rect2(78, 121, 1440, 36), 20, UI.MUTED)
 UI.label(stage, "카드 목록", Rect2(78, 181, 410, 34), 23)
 detail_panel = UI.panel(stage, Rect2(946, 202, 578, 602), Color.WHITE)
 selected_label = UI.label(detail_panel, "선택한 카드", Rect2(38, 28, 470, 30), 18, UI.MUTED)
 detail_title = UI.label(detail_panel, "", Rect2(38, 79, 510, 60), 37)
 detail_meta = UI.label(detail_panel, "", Rect2(38, 143, 510, 35), 21)
 detail_icon = TextureRect.new()
 detail_icon.position = Vector2(216, 209)
 detail_icon.size = Vector2(146, 146)
 detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 detail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 detail_panel.add_child(detail_icon)
 detail_body = UI.label(detail_panel, "", Rect2(38, 389, 502, 116), 25)
 detail_note = UI.label(detail_panel, "", Rect2(38, 536, 502, 37), 18)
 UI.label(stage, "카드 효과와 수치는 현재 전투의 임시 규칙입니다.", Rect2(946, 827, 602, 34), 18, UI.MUTED)
 gallery = Control.new()
 stage.add_child(gallery)
 page_label = UI.label(stage, "", Rect2(690, 181, 220, 32), 18, UI.MUTED)
 if Catalog.CARDS.size() > page_size:
  var previous := UI.button(stage, "←", Rect2(78, 845, 70, 42))
  var next := UI.button(stage, "→", Rect2(164, 845, 70, 42))
  previous.pressed.connect(_page_by.bind(-1))
  next.pressed.connect(_page_by.bind(1))
 _fill_page()
 _select_card(str(Catalog.CARDS.keys()[0]))
 card_buttons[selected_id].grab_focus()

func _fill_page() -> void:
 for child in gallery.get_children():
  gallery.remove_child(child)
  child.queue_free()
 card_buttons.clear()
 var ids: Array = Catalog.CARDS.keys()
 var first: int = page * page_size
 for index in range(first, mini(first + page_size, ids.size())):
  var id: String = str(ids[index])
  var slot: int = index - first
  var pos := Vector2(88 + (slot % 3) * 282, 240 + (slot / 3) * 304)
  _card(gallery, id, pos, 1.2)
  var button := UI.button(gallery, "", Rect2(pos - Vector2(9, 9), Vector2(208, 292)))
  button.tooltip_text = str(Catalog.card(id).name) + " · 상세 보기"
  button.add_theme_stylebox_override("normal", UI.style(Color.TRANSPARENT))
  button.add_theme_stylebox_override("hover", UI.style(Color.TRANSPARENT, UI.INK, 2))
  button.add_theme_stylebox_override("pressed", UI.style(Color.TRANSPARENT, UI.YELLOW, 3))
  button.pressed.connect(_select_card.bind(id))
  card_buttons[id] = button
 page_label.text = "%d–%d / %d" % [first + 1, mini(first + page_size, ids.size()), ids.size()]

func _page_by(delta: int) -> void:
 var pages: int = ceili(float(Catalog.CARDS.size()) / page_size)
 page = posmod(page + delta, pages)
 _fill_page()
 _select_card(str(Catalog.CARDS.keys()[page * page_size]))
 card_buttons[selected_id].grab_focus()

func _select_card(id: String) -> void:
 selected_id = id
 var data: Dictionary = Catalog.card(id)
 var dark: bool = bool(data.dark)
 var ink: Color = Color.WHITE if dark else UI.INK
 var muted: Color = Color("c4c7c0") if dark else UI.MUTED
 detail_panel.add_theme_stylebox_override("panel", UI.style(UI.INK if dark else Color.WHITE))
 selected_label.text = "선택됨   /   " + ("검정 카드" if dark else "흰색 카드")
 selected_label.add_theme_color_override("font_color", muted)
 detail_title.text = str(data.name)
 detail_meta.text = "행동력 %d   /   %s" % [int(data.cost), str(data.kind)]
 detail_body.text = str(data.detail)
 detail_note.text = "사용 후 전투 내 소멸" if bool(data.get("exhaust", false)) else "현재 전투의 카드 정의"
 for label in [detail_title, detail_meta, detail_body]: label.add_theme_color_override("font_color", ink)
 detail_note.add_theme_color_override("font_color", muted)
 detail_icon.texture = load("res://assets/icons/%s.png" % data.icon)
 detail_icon.material = light_ink if dark else dark_ink
 for key in card_buttons:
  card_buttons[key].add_theme_stylebox_override("normal", UI.style(Color.TRANSPARENT, UI.YELLOW if key == id else Color.TRANSPARENT, 3 if key == id else 0))
  card_buttons[key].add_theme_stylebox_override("hover", UI.style(Color.TRANSPARENT, UI.YELLOW if key == id else UI.INK, 3 if key == id else 2))

func _navigate(path: String) -> void:
 if navigating: return
 navigating = true
 var error: Error = get_tree().change_scene_to_file(path)
 if error != OK:
  navigating = false
  push_error("화면 이동 실패: %s (%s)" % [path, error])

func _unhandled_key_input(event: InputEvent) -> void:
 if card_book and event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  _navigate("res://scenes/main_menu.tscn")
