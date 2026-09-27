extends Control

const Symbols = preload("res://scripts/card_symbols.gd")

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
# Immutable per-screen styles; selection only switches references.
var idle_card_style: StyleBoxFlat
var hover_card_style: StyleBoxFlat
var selected_card_style: StyleBoxFlat
var light_detail_style: StyleBoxFlat
var dark_detail_style: StyleBoxFlat

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
 action_buttons.shop = UI.button(stage,"덱 상점",Rect2(92,728,510,58))
 action_buttons.shop.pressed.connect(_navigate.bind("res://scenes/shop.tscn"))
 action_buttons.quit = UI.button(stage, "종료", Rect2(440, 653, 162, 62))
 action_buttons.quit.pressed.connect(func(): get_tree().quit())
 UI.label(stage, "테이블 점수 대전 · 골드와 해금은 실행 중에만 유지됩니다.", Rect2(94, 794, 750, 34), 18, UI.MUTED)
 UI.panel(stage, Rect2(909, 149, 603, 606), Color("eeeee7"))
 _card(stage, "observe", Vector2(958, 243), 1.65, -0.12)
 _card(stage, "strike", Vector2(1210, 321), 1.65, 0.13)
 UI.label(stage, "관측  →  공허의 일격", Rect2(994, 784, 485, 38), 24)
 UI.label(stage, "카드 조합 · 전투 프로토타입", Rect2(92, 836, 780, 30), 17, UI.MUTED)
 action_buttons.start.grab_focus()

func _card(parent: Node, id: String, pos: Vector2, zoom: float, angle: float = 0.0) -> Control:
 var data: Dictionary = Catalog.table_card(id)
 var node := Card.new()
 parent.add_child(node)
 node.setup({"uid":-1}, data, Symbols.texture_for(data), light_ink if bool(data.dark) else dark_ink, null)
 node.pivot_offset = Vector2.ZERO
 node.position = pos
 node.scale = Vector2.ONE * zoom
 node.rotation = angle
 node.locked = true
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.outline_style.shadow_size = 0
 return node

var owner_panel: Panel

func _build_book() -> void:
 idle_card_style = UI.style(Color.TRANSPARENT)
 hover_card_style = UI.style(Color.TRANSPARENT, UI.INK, 2)
 selected_card_style = UI.style(Color.TRANSPARENT, UI.YELLOW, 3)
 light_detail_style = UI.style(Color.WHITE)
 dark_detail_style = UI.style(UI.INK)
 UI.label(stage, "LYNCO   /   수집 카드북", Rect2(76, 45, 1000, 55), 36)
 action_buttons.back = UI.button(stage, "←  메인으로", Rect2(1288, 48, 236, 52))
 action_buttons.back.pressed.connect(_navigate.bind("res://scenes/main_menu.tscn"))
 UI.label(stage, "카드 %d종 열람 · 돋보기로 덱 주인 확인 / 구매는 상점에서" % Catalog.CARDS.size(), Rect2(78, 121, 1440, 36), 20, UI.MUTED)
 UI.label(stage, "카드 목록", Rect2(78, 181, 410, 34), 23)
 var owner_button := UI.button(stage,"⌕ 덱 주인",Rect2(1050,121,215,48))
 owner_button.tooltip_text = "돋보기 · 선택한 카드가 포함된 덱과 주인 확인"
 owner_button.pressed.connect(_show_owners)
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
 selected_id = ""
 var ids: Array = Catalog.CARDS.keys()
 var first: int = page * page_size
 for index in range(first, mini(first + page_size, ids.size())):
  var id: String = str(ids[index])
  var slot: int = index - first
  var pos := Vector2(88 + (slot % 3) * 282, 240 + floori(float(slot) / 3.0) * 304)
  _card(gallery, id, pos, 1.2)
  var button := UI.button(gallery, "", Rect2(pos - Vector2(9, 9), Vector2(208, 292)))
  button.tooltip_text = str(Catalog.table_card(id).name) + " · 상세 보기"
  button.add_theme_stylebox_override("normal", idle_card_style)
  button.add_theme_stylebox_override("hover", hover_card_style)
  button.add_theme_stylebox_override("pressed", selected_card_style)
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
 if selected_id == id: return
 if card_buttons.has(selected_id):
  card_buttons[selected_id].add_theme_stylebox_override("normal", idle_card_style)
  card_buttons[selected_id].add_theme_stylebox_override("hover", hover_card_style)
 selected_id = id
 var data: Dictionary = Catalog.table_card(id)
 var dark: bool = bool(data.dark)
 var ink: Color = Color.WHITE if dark else UI.INK
 var muted: Color = Color("c4c7c0") if dark else UI.MUTED
 detail_panel.add_theme_stylebox_override("panel", dark_detail_style if dark else light_detail_style)
 selected_label.text = "선택됨   /   " + ("검정 카드" if dark else "흰색 카드")
 selected_label.add_theme_color_override("font_color", muted)
 detail_title.text = str(data.name)
 detail_meta.text = "행동 %d / 테이블 %d / %s" % [int(data.cost),int(data.table_cost),str(data.kind)]
 detail_body.text = str(data.detail)
 detail_note.text = "테이블에 유지 · 수치와 추가 효과는 시험 중"
 for label in [detail_title, detail_meta, detail_body]: label.add_theme_color_override("font_color", ink)
 detail_note.add_theme_color_override("font_color", muted)
 detail_icon.texture = Symbols.texture_for(data)
 detail_icon.material = Symbols.material_for(data, light_ink if dark else dark_ink)
 if card_buttons.has(id):
  card_buttons[id].add_theme_stylebox_override("normal", selected_card_style)
  card_buttons[id].add_theme_stylebox_override("hover", selected_card_style)

func _navigate(path: String) -> void:
 if navigating: return
 navigating = true
 var error: Error = get_tree().change_scene_to_file(path)
 if error != OK:
  navigating = false
  push_error("화면 이동 실패: %s (%s)" % [path, error])

func _unhandled_key_input(event: InputEvent) -> void:
 if is_instance_valid(owner_panel) and owner_panel.visible and event.is_action_pressed("ui_cancel"):
  owner_panel.hide(); get_viewport().set_input_as_handled(); return
 if card_book and event.is_action_pressed("ui_cancel"):
  get_viewport().set_input_as_handled()
  _navigate("res://scenes/main_menu.tscn")

func _show_owners() -> void:
 if is_instance_valid(owner_panel):
  stage.remove_child(owner_panel); owner_panel.queue_free()
 owner_panel = UI.panel(stage,Rect2(350,220,900,440),UI.PAPER)
 owner_panel.mouse_filter = Control.MOUSE_FILTER_STOP
 owner_panel.z_index = 100
 UI.label(owner_panel,"돋보기 / 덱 주인",Rect2(35,24,820,50),32)
 var text := "‘%s’이(가) 포함된 덱\n\n" % Catalog.card(selected_id).name
 var session = preload("res://scripts/collection_session.gd")
 for id in session.DECKS:
  var data: Dictionary = session.DECKS[id]
  if selected_id in data.cards: text += "%s — 주인: %s (%s)\n" % [data.name,data.owner,"해금됨" if id in session.unlocked else "미해금"]
 UI.label(owner_panel,text,Rect2(35,98,830,215),24)
 var shop := UI.button(owner_panel,"상점으로",Rect2(35,344,385,58),true)
 shop.pressed.connect(_navigate.bind("res://scenes/shop.tscn"))
 var close := UI.button(owner_panel,"닫기",Rect2(470,344,385,58))
 close.pressed.connect(func(): owner_panel.hide())
