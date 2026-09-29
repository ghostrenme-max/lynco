extends Control

const Symbols = preload("res://scripts/card_symbols.gd")

const UI = preload("res://scripts/theatre_style.gd")
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


# Additional view state (kept before method declarations).
var owner_panel: Panel

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
 UI.background(self)
 stage = Control.new()
 stage.size = Vector2(1600, 900)
 add_child(stage)
 UI.art(stage,not card_book)
 resized.connect(_fit)
 _fit()
 if card_book: _build_book()
 else: _build_main()

func _fit() -> void:
 if not is_instance_valid(stage): return
 UI.Base.fit_stage(stage,size)

func _build_main() -> void:
 var logo := UI.title(stage,"LYNCO",Rect2(370,22,860,177),145)
 logo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var subtitle := UI.title(stage,"린 코",Rect2(650,189,300,48),30)
 subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 UI.rule(stage,Rect2(515,214,100,1));UI.rule(stage,Rect2(985,214,100,1))
 action_buttons.start=_main_button("게임 시작",Rect2(540,774,520,96),true)
 action_buttons.start.add_theme_font_size_override("font_size",34)
 action_buttons.start.pressed.connect(_navigate.bind("res://scenes/battle.tscn"))
 action_buttons.book=_main_button("카드북",Rect2(130,790,355,76),false,"book")
 action_buttons.book.pressed.connect(_navigate.bind("res://scenes/card_book.tscn"))
 action_buttons.shop=_main_button("덱 상점",Rect2(1115,790,355,76),false,"shop")
 action_buttons.shop.pressed.connect(_navigate.bind("res://scenes/shop.tscn"))
 action_buttons.quit=_main_button("종료",Rect2(1486,851,104,40))
 action_buttons.quit.pressed.connect(func():get_tree().quit())
 action_buttons.start.grab_focus()
func _main_button(caption: String, rect: Rect2, primary: bool=false, emblem: String="") -> Button:
 var button:=preload("res://scripts/main_card_button.gd").new()
 button.configure(caption,rect,primary,emblem)
 stage.add_child(button)
 return button
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



func _build_book() -> void:
 idle_card_style=UI.style(Color.TRANSPARENT)
 hover_card_style=UI.style(Color.TRANSPARENT,UI.PAPER,2)
 selected_card_style=UI.style(Color.TRANSPARENT,UI.YELLOW,3)
 light_detail_style=UI.style(UI.PAPER,UI.YELLOW,1)
 dark_detail_style=UI.style(UI.INK,UI.YELLOW,1)
 UI.title(stage,"LYNCO  /  카드북",Rect2(120,35,880,76),48)
 action_buttons.back=UI.button(stage,"← 메인으로",Rect2(1270,48,210,52))
 action_buttons.back.pressed.connect(_navigate.bind("res://scenes/main_menu.tscn"))
 UI.rule(stage,Rect2(120,122,1360,1))
 UI.label(stage,"카드 목록",Rect2(120,140,420,35),22,UI.PAPER)
 detail_panel=UI.panel(stage,Rect2(1010,154,470,660),UI.PAPER)
 selected_label=UI.label(detail_panel,"선택한 카드",Rect2(30,22,410,28),18,UI.MUTED)
 detail_title=UI.title(detail_panel,"",Rect2(30,63,410,56),38)
 detail_meta=UI.label(detail_panel,"",Rect2(30,127,410,32),19)
 detail_icon=UI.symbol(detail_panel,null,Rect2(155,186,160,160))
 UI.rule(detail_panel,Rect2(30,376,410,1))
 detail_body=UI.label(detail_panel,"",Rect2(30,399,410,148),20)
 detail_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 detail_note=UI.label(detail_panel,"",Rect2(30,552,410,28),16)
 var owner_button:=UI.button(detail_panel,"덱 주인 확인",Rect2(30,592,410,46))
 owner_button.pressed.connect(_show_owners)
 UI.label(stage,"카드 효과와 수치는 테스트용 임시 규칙입니다.",Rect2(1010,829,470,30),17,UI.SOFT)
 gallery=Control.new();stage.add_child(gallery)
 page_label=UI.label(stage,"",Rect2(400,813,250,42),20,UI.PAPER)
 page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var previous:=UI.button(stage,"←",Rect2(297,811,70,44))
 var next:=UI.button(stage,"→",Rect2(683,811,70,44))
 previous.disabled=Catalog.runtime_ids().size()<=page_size
 next.disabled=previous.disabled
 previous.pressed.connect(_page_by.bind(-1));next.pressed.connect(_page_by.bind(1))
 _fill_page()
 _select_card(str(Catalog.runtime_ids()[0]))
 card_buttons[selected_id].grab_focus()
func _fill_page() -> void:
 for child in gallery.get_children():
  gallery.remove_child(child);child.queue_free()
 card_buttons.clear();selected_id=""
 var ids: Array=Catalog.runtime_ids()
 var first: int=page*page_size
 for index in range(first,mini(first+page_size,ids.size())):
  var id: String=str(ids[index])
  var data: Dictionary=Catalog.table_card(id)
  var slot: int=index-first
  var pos:=Vector2(120+(slot%3)*286,190+floori(float(slot)/3.0)*306)
  var dark: bool=bool(data.dark)
  var ink: Color=UI.PAPER if dark else UI.INK
  var card:=UI.panel(gallery,Rect2(pos,Vector2(256,282)),UI.INK if dark else UI.PAPER)
  UI.symbol(card,Symbols.texture_for(data),Rect2(65,24,126,126),dark)
  var name_label:=UI.label(card,str(data.name),Rect2(12,166,232,38),24,ink)
  name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  UI.rule(card,Rect2(22,211,212,1))
  var effect:=UI.label(card,str(data.text),Rect2(18,223,220,52),18,ink)
  effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  var button:=UI.button(gallery,"",Rect2(pos,Vector2(256,282)))
  button.tooltip_text=str(data.name)+" · 상세 보기"
  button.add_theme_stylebox_override("normal",idle_card_style)
  button.add_theme_stylebox_override("hover",hover_card_style)
  button.add_theme_stylebox_override("pressed",selected_card_style)
  button.pressed.connect(_select_card.bind(id))
  card_buttons[id]=button
 page_label.text="%d–%d / %d" % [first+1,mini(first+page_size,ids.size()),ids.size()]
func _page_by(delta: int) -> void:
 var pages: int = ceili(float(Catalog.runtime_ids().size()) / page_size)
 page = posmod(page + delta, pages)
 _fill_page()
 _select_card(str(Catalog.runtime_ids()[page * page_size]))
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
 detail_meta.text = "행동 %d / 투자 큐브 %d / %s" % [int(data.cost),int(data.table_cost),str(data.kind)]
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
  var data: Dictionary = session.DECKS[id].duplicate(true)
  data.cards=session.deck_cards(id)
  if selected_id in data.cards: text += "%s — 주인: %s (%s)\n" % [data.name,data.owner,"해금됨" if id in session.unlocked else "미해금"]
 UI.label(owner_panel,text,Rect2(35,98,830,215),24)
 var shop := UI.button(owner_panel,"상점으로",Rect2(35,344,385,58),true)
 shop.pressed.connect(_navigate.bind("res://scenes/shop.tscn"))
 var close := UI.button(owner_panel,"닫기",Rect2(470,344,385,58))
 close.pressed.connect(func(): owner_panel.hide())
