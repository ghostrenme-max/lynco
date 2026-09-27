extends Control

const DirectionDiagram = preload("res://scripts/direction_diagram.gd")
const Directions = preload("res://scripts/direction_preview.gd")

const Symbols = preload("res://scripts/card_symbols.gd")

const Model = preload("res://scripts/table_battle_model.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Card = preload("res://scripts/card_view.gd")
const Table = preload("res://scripts/table_view.gd")
const INK := Color("171a17")
const MUTED := Color("606460")
const YELLOW := Color("f5d335")
const DECK_ORIGIN := Vector2(44, 655)
const DISCARD_ORIGIN := Vector2(1432, 665)
# Card center aligns with the left deck center (66 + 83 / 2).
# Rise vertically above that deck, then deal rightward into the hand.
const DRAW_STACK := Vector2(28.5, 450)
const STACK_CARD_STEP := Vector2(26, -12)
const STACK_FIRST_ANGLE: float = -8.0
const STACK_ANGLE_STEP: float = 4.0
const LIFT_TIME: float = 0.17
const LIFT_GAP: float = 0.028
const STACK_BEAT: float = 0.045
const FAN_TIME: float = 0.23
const FAN_GAP: float = 0.040

var model := Model.new()
var table: LyncoTableView
var drag_uid: int = -1
var press_uid: int = -1
var looking: bool = false
var look_pointer := Vector2.ZERO
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var press_point := Vector2.ZERO
var stage: Control
var hand_layer: Control
var views: Dictionary = {}
var textures: Dictionary = {}
var dark_ink: ShaderMaterial
var light_ink: ShaderMaterial
var busy: bool = true
var selected_uid: int = -1
var hovered_uid: int = -1
var deal_phase: String = "idle"
var inspect_uid: int = -1
var deck_label: Label
var discard_label: Label
var exhaust_label: Label
var hand_label: Label
var hand_hint: Label
var preview_icon: TextureRect
var preview_title: Label
var preview_cost: Label
var preview_text: Label
var preview_kind: Label
var preview_effect: Label
var inspector_layer: CanvasLayer
var inspector_root: Control
var inspector_card: Panel
var inspector_styles: Dictionary = {}
var inspector_open: bool = false
var hover_direction: Control
var hover_direction_timer: Timer
var hover_direction_tween: Tween
var direction_hover_uid: int = -1
var direction_hover_cell := Vector2i(-1,-1)
var inspector_demo: Panel
var inspector_diagram: Control
var direction_note: Label
var fill_button: Button
var shift_button: Button
var identity_counter: Panel
var king_count: Label
var joker_count: Label
var shuffle_phase: String = "idle"
var menu_button: Button
var leaving_battle: bool = false
var end_button: Button
var reset_button: Button
var draw_button: Button
var seed_box: LineEdit
var seed_label: Label
var toast_label: Label
var toast_tween: Tween
var result_panel: Panel
var result_title: Label
var result_body: Label
var help_panel: Panel
var performance_label: Label
var performance_timer: Timer
var show_performance: bool = false
var frame_samples: Array[float] = []
var measure_frames: bool = false
var verify_mode: bool = false
var reduced_motion: bool = false
var motion_toggle: CheckButton
var last_sample_us: int = 0

func _ready() -> void:
 verify_mode = OS.get_cmdline_user_args().has("--verify")
 Engine.max_fps=120
 var font := SystemFont.new()
 font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
 font.allow_system_fallback = true
 var ui_theme := Theme.new()
 ui_theme.default_font = font
 ui_theme.default_font_size = 18
 theme = ui_theme
 for key in ["enemy", "eye", "void", "guard", "memory", "cycle", "link"]:
  textures[key] = load("res://assets/icons/%s.png" % key)
 textures["back_white"] = load("res://asset/front_logo_white.png")
 textures["back_black"] = load("res://asset/black_back_logo_red.png")
 textures["shift_reverse"] = load("res://assets/icons/shift_reverse.png")
 # Measure visible artwork once; share the normalized logo across all back views.
 for back_key in ["back_white", "back_black"]:
  var logo_image:Image=textures[back_key].get_image()
  var logo_bounds:Rect2=Rect2(logo_image.get_used_rect())
  var logo_size:Vector2=Vector2(logo_image.get_size())
  var back_material:ShaderMaterial=Card.BACK_MATERIAL if back_key=="back_white" else Card.BLACK_BACK_MATERIAL
  if logo_bounds.has_area():
   back_material.set_shader_parameter("logo_region",Vector4(logo_bounds.position.x/logo_size.x,logo_bounds.position.y/logo_size.y,logo_bounds.size.x/logo_size.x,logo_bounds.size.y/logo_size.y))
 var shader := Shader.new()
 shader.code = "shader_type canvas_item; uniform vec4 ink : source_color = vec4(0.08,0.09,0.08,1.0); varying vec4 tint; void vertex(){tint=COLOR;} void fragment(){ vec4 t = texture(TEXTURE,UV); COLOR = vec4(ink.rgb, t.a * ink.a) * tint; }"
 dark_ink = ShaderMaterial.new(); dark_ink.shader = shader; dark_ink.set_shader_parameter("ink", INK)
 light_ink = ShaderMaterial.new(); light_ink.shader = shader; light_ink.set_shader_parameter("ink", Color.WHITE)
 var overlay:=CanvasLayer.new();add_child(overlay)
 stage = Control.new(); stage.size = Vector2(1600, 900); stage.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(stage)
 table=get_parent().get_node("TableWorld")
 table.ui_stage=stage
 table.placement_camera=preload("res://scripts/placement_camera.gd").new()
 table.placement_camera.ui=self
 add_child(table.placement_camera)
 _build_ui()
 resized.connect(_fit_stage)
 _fit_stage()
 set_process(false)
 await _prepare_table_cards()
 if OS.get_cmdline_user_args().has("--verify-inspector"):
  call_deferred("_verify_inspector")
 elif OS.get_cmdline_user_args().has("--verify-look"):
  call_deferred("_verify_look")
 elif OS.get_cmdline_user_args().has("--verify-table"):
  call_deferred("_verify_table")
 elif OS.get_cmdline_user_args().has("--verify-motion"):
  call_deferred("_verify_motion")
 elif verify_mode:
  call_deferred("_verify")
 else:
  call_deferred("_restart", 20260926)

func _fit_stage() -> void:
 var ratio: float = minf(size.x / 1600.0, size.y / 900.0)
 stage.scale = Vector2.ONE * ratio
 stage.position = (size - Vector2(1600, 900) * ratio) * 0.5

func _style(bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
 var style := StyleBoxFlat.new()
 style.bg_color = bg; style.set_corner_radius_all(radius); style.corner_detail = 10
 style.border_color = border; style.set_border_width_all(width)
 return style

func _panel(parent: Node, pos: Vector2, box: Vector2, bg: Color, radius: int = 10, border: Color = Color.TRANSPARENT) -> Panel:
 var panel := Panel.new(); panel.position = pos; panel.size = box
 panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_theme_stylebox_override("panel", _style(bg, radius, border, 1 if border.a > 0 else 0))
 parent.add_child(panel)
 return panel

func _label(parent: Node, text: String, pos: Vector2, box: Vector2, font_size: int = 18, color: Color = INK) -> Label:
 var label := preload("res://scripts/rolling_number_label.gd").new(); label.text = text; label.position = pos; label.size = box
 label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color)
 if parent==stage:
  label.add_theme_color_override("font_color",Color("e0e2e4"))
  label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
  label.add_theme_constant_override("shadow_offset_x",1)
  label.add_theme_constant_override("shadow_offset_y",1)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(label)
 return label

func _button(parent: Node, text: String, pos: Vector2, box: Vector2, black: bool = false) -> Button:
 var button := Button.new(); button.text = text; button.position = pos; button.size = box
 button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 button.add_theme_font_size_override("font_size", 17)
 button.add_theme_color_override("font_color", Color.WHITE if black else INK)
 button.add_theme_color_override("font_hover_color", INK)
 button.add_theme_color_override("font_pressed_color", INK)
 button.add_theme_color_override("font_disabled_color", Color("989d93"))
 button.add_theme_stylebox_override("normal", _style(INK if black else Color("ffffff"), 10, Color("d9ddd2"), 0 if black else 1))
 button.add_theme_stylebox_override("hover", _style(YELLOW, 10))
 button.add_theme_stylebox_override("pressed", _style(Color("e1bd24"), 10))
 button.add_theme_stylebox_override("disabled", _style(Color("e9ece3"), 10))
 button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 10, Color("bfa124"), 2))
 parent.add_child(button)
 return button

func _icon(parent: Node, key: String, pos: Vector2, box: Vector2, white: bool = false) -> TextureRect:
 var icon := TextureRect.new(); icon.position = pos; icon.size = box
 icon.texture = textures[key]; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
 icon.material = light_ink if white else dark_ink
 parent.add_child(icon)
 return icon

var inspector_score: Control
var table_status: Label
var garnet_label: Label
var turn_board: Panel
var hud_values: Dictionary = {}
var turn_motion: Tween
var turn_track: Control
var turn_caption: Label
var camera_keys: Dictionary = {}
var inventory_layer: CanvasLayer
func _build_ui() -> void:
 turn_board=_panel(stage,Vector2(600,20),Vector2(970,156),Color("171a18"),20)
 turn_board.mouse_filter=Control.MOUSE_FILTER_STOP
 turn_caption=_label(turn_board,"",Vector2(28,14),Vector2(710,32),22,Color("eeeee5"))
 table_status=_label(turn_board,"",Vector2(28,114),Vector2(700,25),16,Color("c4c7bd"))
 _label(table_status,"행동력",Vector2.ZERO,Vector2(58,25),16,Color("c4c7bd"))
 hud_values.energy=_label(table_status,"",Vector2(62,0),Vector2(24,25),16,Color("eeeee5"))
 _label(table_status,"/ 3",Vector2(90,0),Vector2(36,25),16,Color("c4c7bd"))
 _label(table_status,"점수",Vector2(152,0),Vector2(40,25),16,Color("c4c7bd"))
 hud_values.player_score=_label(table_status,"",Vector2(196,0),Vector2(48,25),16,Color("eeeee5"))
 _label(table_status,":",Vector2(246,0),Vector2(10,25),16,Color("c4c7bd"))
 hud_values.opponent_score=_label(table_status,"",Vector2(266,0),Vector2(48,25),16,Color("eeeee5"))
 _label(table_status,"배치",Vector2(344,0),Vector2(40,25),16,Color("c4c7bd"))
 hud_values.placed=_label(table_status,"",Vector2(392,0),Vector2(30,25),16,Color("eeeee5"))
 _label(table_status,"/ %d" % Model.CAPACITY,Vector2(426,0),Vector2(45,25),16,Color("c4c7bd"))
 turn_track=preload("res://scripts/turn_track.gd").new()
 turn_track.position=Vector2(26,52);turn_track.size=Vector2(714,52)
 turn_track.mouse_filter=Control.MOUSE_FILTER_IGNORE
 turn_board.add_child(turn_track)
 var garnet_icon:=Polygon2D.new()
 garnet_icon.position=Vector2(53,47)
 var hex_points:=PackedVector2Array()
 for i in range(6):
  var angle: float=float(i)*TAU/6.0-PI*0.5
  hex_points.append(Vector2(cos(angle),sin(angle))*22)
 garnet_icon.polygon=hex_points
 garnet_icon.color=Color("303733");stage.add_child(garnet_icon)
 garnet_label=_label(stage,"0",Vector2(89,25),Vector2(180,45),30,Color("252c28"))
 garnet_label.tooltip_text="큐브 가넷 · 현재 보유 재화"
 _panel(stage,Vector2(37,91),Vector2(29,42),Color("303733"),3)
 _build_card_inspector()
 hover_direction = DirectionDiagram.new()
 hover_direction.size = Vector2(176,152)
 hover_direction.z_index = 160
 stage.add_child(hover_direction)
 hover_direction.hide()
 hover_direction_timer = Timer.new()
 hover_direction_timer.wait_time = 0.5
 hover_direction_timer.one_shot = true
 hover_direction_timer.timeout.connect(_show_hover_direction)
 add_child(hover_direction_timer)
 fill_button = _button(stage,"E · 5장 보충",Vector2(34,82),Vector2(170,42))
 fill_button.tooltip_text = "확인용 기능 · 비용과 횟수 제한은 아직 미정"
 fill_button.pressed.connect(_fill_requested)
 shift_button = _button(stage,"Shift · 가림 셔플",Vector2(218,24),Vector2(240,42))
 shift_button.tooltip_text = "손패의 고유 뒷면을 가리고 섞습니다 · 현재는 정체 공개만 동작"
 shift_button.pressed.connect(_shift_requested)
 identity_counter = _panel(stage,Vector2(345,550),Vector2(280,48),Color("181a19"),10)
 identity_counter.hide()
 for i in range(2):
  var symbol := TextureRect.new()
  symbol.position=Vector2(14+i*140,11);symbol.size=Vector2(26,26)
  symbol.texture=preload("res://assets/icons/count_king.svg") if i==0 else preload("res://assets/icons/count_joker.svg")
  symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity_counter.add_child(symbol)
 king_count=_label(identity_counter,"킹 0",Vector2(48,10),Vector2(84,29),20,Color("f6f6f2"))
 joker_count=_label(identity_counter,"조커 0",Vector2(188,10),Vector2(84,29),20,Color("f6f6f2"))
 menu_button = _button(stage,"← 메인으로",Vector2(34,24),Vector2(170,42))
 menu_button.tooltip_text = "현재 전투를 종료합니다. 진행은 저장되지 않습니다."
 menu_button.pressed.connect(_return_to_main)

 end_button = _button(turn_board,"턴 종료 →",Vector2(767,87),Vector2(178,47),true)
 end_button.pressed.connect(_end_turn)


 hand_label = _label(stage,"0 / 0",Vector2(89,88),Vector2(210,45),28,Color("252c28"))
 hand_label.tooltip_text="현재 손패 / 전체 내 카드 수"
 for count_label in [garnet_label,hand_label]:
  count_label.add_theme_color_override("font_color",Color("252c28"))
  count_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

 hand_hint = _label(stage,"우클릭 상세 · 드래그 배치",Vector2(805,612),Vector2(410,24),13,MUTED)
 hand_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 hand_layer = Control.new(); hand_layer.size=Vector2(1600,900); hand_layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
 stage.add_child(hand_layer)
 _build_pile(DECK_ORIGIN, false)
 _build_pile(DISCARD_ORIGIN, true)
 deck_label = _label(stage,"덱 18",Vector2(45,844),Vector2(142,26),16)
 deck_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 discard_label = _label(stage,"버림 0",Vector2(1424,844),Vector2(140,26),16)
 discard_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 exhaust_label = _label(stage,"소멸 0",Vector2(1282,796),Vector2(120,24),13,MUTED)
 draw_button = _button(stage,"드로우 시연",Vector2(199,777),Vector2(128,38))
 draw_button.tooltip_text="전투 규칙 외 시연 기능 · 덱에서 카드 1장을 뽑습니다."
 draw_button.pressed.connect(_demo_draw)

 toast_label = _label(stage,"",Vector2(345,110),Vector2(330,65),16)
 toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 toast_label.z_index=70
 seed_label = _label(stage,"SEED",Vector2(1260,686),Vector2(55,22),12,MUTED)
 seed_box=LineEdit.new(); seed_box.position=Vector2(1322,680); seed_box.size=Vector2(140,34)
 seed_box.text="20260926"; seed_box.max_length=10; seed_box.add_theme_font_size_override("font_size",14)
 seed_box.add_theme_color_override("font_color",INK)
 seed_box.add_theme_color_override("font_uneditable_color",MUTED)
 seed_box.add_theme_color_override("caret_color",INK)
 seed_box.add_theme_stylebox_override("normal",_style(Color.WHITE,6,Color("d8ddd1"),1))
 stage.add_child(seed_box)
 reset_button=_button(stage,"↻",Vector2(1475,680),Vector2(45,34))
 reset_button.tooltip_text="같은 시드로 전투 다시 시작"
 reset_button.pressed.connect(_reset_requested)
 var help_button := _button(stage,"?",Vector2(1529,680),Vector2(37,34))
 help_button.pressed.connect(func(): help_panel.visible=not help_panel.visible;_hide_hover_direction())
 motion_toggle=CheckButton.new(); motion_toggle.text="간결한 연출"; motion_toggle.position=Vector2(1260,737); motion_toggle.size=Vector2(158,36)
 motion_toggle.add_theme_font_size_override("font_size",13)
 motion_toggle.add_theme_color_override("font_color",Color("e0e2e4"))
 motion_toggle.add_theme_color_override("font_hover_color",Color.WHITE)
 motion_toggle.toggled.connect(_set_reduced_motion)
 stage.add_child(motion_toggle)
 performance_label=_label(stage,"F3 · 성능 표시",Vector2(34,873),Vector2(900,20),11,MUTED)

 _build_overlays()
 # Secondary controls live in the help panel, leaving the tabletop HUD clear.
 menu_button.position=Vector2(32,153);menu_button.text="←";menu_button.size=Vector2(43,34)
 menu_button.hide();help_button.hide()
 var secondary_controls: Array[Control]=[fill_button,shift_button,draw_button,seed_label,seed_box,reset_button,motion_toggle]
 for control in secondary_controls:
  control.reparent(help_panel)
 fill_button.position=Vector2(28,356);fill_button.size=Vector2(165,36)
 shift_button.position=Vector2(208,356);shift_button.size=Vector2(216,36)
 draw_button.position=Vector2(439,356)
 seed_label.position=Vector2(28,414)
 seed_box.position=Vector2(88,408)
 reset_button.position=Vector2(241,408)
 motion_toggle.position=Vector2(320,407)
 motion_toggle.add_theme_color_override("font_color",INK)
 seed_label.add_theme_color_override("font_color",INK)
 help_panel.size.y=482
 for label in [hand_hint,deck_label,discard_label,exhaust_label,performance_label]:label.hide()
 toast_label.position=Vector2(325,185);toast_label.size=Vector2(650,45)
 performance_timer=Timer.new(); performance_timer.wait_time=0.5
 performance_timer.timeout.connect(_update_performance); add_child(performance_timer)

func _build_pile(pos: Vector2, black: bool) -> void:
 for i in range(3,-1,-1):
  _panel(stage,pos+Vector2(-i*4,i*4),Vector2(124,172),INK if black else Color("8c2633"),9,Color("848b7c") if black else Color("b9c1b0"))
 var back := TextureRect.new()
 back.position=pos; back.size=Vector2(124,172)
 back.texture=textures["back_black" if black else "back_white"]
 back.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 back.stretch_mode=TextureRect.STRETCH_SCALE
 back.material=Card.BLACK_BACK_MATERIAL if black else Card.BACK_MATERIAL
 back.mouse_filter=Control.MOUSE_FILTER_IGNORE
 stage.add_child(back)

func _build_overlays() -> void:
 result_panel=_panel(stage,Vector2(470,234),Vector2(660,350),Color("fafbf6"),18,Color("c8cfbd"))
 result_panel.z_index=100; result_panel.mouse_filter=Control.MOUSE_FILTER_STOP
 result_title=_label(result_panel,"승리",Vector2(30,38),Vector2(600,62),42)
 result_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 result_body=_label(result_panel,"",Vector2(30,125),Vector2(600,92),20,MUTED)
 result_body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var again := _button(result_panel,"같은 시드로 다시 시작",Vector2(166,265),Vector2(330,49),true)
 again.pressed.connect(_reset_requested)
 result_panel.hide()
 help_panel=_panel(stage,Vector2(420,210),Vector2(760,430),Color("fafbf6"),16,Color("c8cfbd"))
 help_panel.z_index=110; help_panel.mouse_filter=Control.MOUSE_FILTER_STOP
 _label(help_panel,"플레이 안내",Vector2(32,27),Vector2(640,47),28)
 _label(help_panel,"손패 클릭 / 숫자 1–7    선택 · 우클릭    상세\n더블클릭 / Enter / 드래그    카드 사용\nE    손패 5장 보충 / Shift    가림 셔플\n가린 카드 클릭    정체 공개 (효과·비용 미정)\nWASD    이동 / 우클릭 드래그    둘러보기 / R    중앙\nSpace    턴 종료 / Esc    선택 해제 · 안내 닫기\nF3    FPS · 프레임 · 드로우 콜 표시\n테이블 카드 클릭    영향 대상 표시 / 우클릭    상세\n휠 클릭    탑뷰 / 휠    확대·축소 / L    전체화면",Vector2(33,93),Vector2(694,265),19)
 var close := _button(help_panel,"닫기",Vector2(579,362),Vector2(148,42),true)
 close.pressed.connect(func():help_panel.hide())
 help_panel.hide()

func _restart(new_seed: int) -> void:
 if busy and not views.is_empty(): return
 _close_inspector();_stop_look();table.reset_look();stage.show()
 table.clear_cards();press_uid=-1;drag_uid=-1
 busy=true; selected_uid=-1; inspect_uid=-1; hovered_uid=-1
 result_panel.hide(); help_panel.hide()
 for view in views.values():
  view.stop_motion(); view.queue_free()
 views.clear()
 model.reset(new_seed)
 table.show_opponent_hand(5)
 var drawn: Array = model.fill_hand().drawn
 _sync_ui()
 await _animate_draw(drawn)
 busy=false; _sync_ui()
 _toast("카드를 선택해 전투를 시작하세요")

func _reset_requested() -> void:
 if busy or drag_uid>=0: return
 var text := seed_box.text.strip_edges()
 if not text.is_valid_int():
  _toast("시드는 숫자로 입력해 주세요")
  return
 _restart(int(text))

func _spawn(entry: Dictionary) -> LyncoCardView:
 var view := Card.new()
 view.reduced_motion=reduced_motion
 var definition: Dictionary=Catalog.table_card(entry.id)
 hand_layer.add_child(view)
 view.setup(entry,definition,Symbols.texture_for(definition, textures.get(definition.icon)),light_ink if bool(definition.dark) else dark_ink,textures["back_black" if bool(definition.dark) else "back_white"])
 view.chosen.connect(_select_card)
 view.activated.connect(_activate_card)
 view.focus_changed.connect(_focus_card)
 views[int(entry.uid)]=view
 return view

func _poses() -> void:
 var count: int=model.hand.size()
 var gap: float=minf(173.0,850.0 / maxf(1.0,float(count-1)))
 for i in range(count):
  var uid: int=int(model.hand[i].uid)
  if not views.has(uid): continue
  var view: LyncoCardView=views[uid]
  var offset: float=float(i)-float(count-1)*0.5
  var normalized: float=offset/maxf(float(count-1)*0.5,1.0)
  view.rest_position=Vector2(800+offset*gap-79,632+normalized*normalized*17)
  view.rest_rotation=deg_to_rad(normalized*6.0)

func _animate_draw(drawn: Array) -> void:
 # Phase 1: rapid successive lifts into a raised packet. Phase 2 begins only
 # after the last card arrives, then deals the packet into the hand in order.
 _clear_hand_focus()
 var new_ids: Dictionary={}
 for entry in drawn:
  var view:=_spawn(entry)
  view.set_face_up(false)
  view.position=DECK_ORIGIN-Card.CARD_SIZE*0.24
  view.scale=Vector2(0.52,0.52); view.rotation=-0.12
  view.modulate.a=0.0; view.locked=true
  new_ids[int(entry.uid)]=true
 _poses()
 for view in views.values():
  view.stop_motion(); view.locked=true; view.set_selected(false)
 if not drawn.is_empty():
  deal_phase="lift"
  var lift:=create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
  for index in range(drawn.size()):
   var view: LyncoCardView=views[int(drawn[index].uid)]
   var delay:float=index*(0.01 if reduced_motion else LIFT_GAP)
   var lift_duration:float=0.09 if reduced_motion else LIFT_TIME
   view.z_index=60+index
   lift.tween_property(view,"position",DRAW_STACK+STACK_CARD_STEP*index,lift_duration).set_delay(delay)
   lift.tween_property(view,"rotation",deg_to_rad(STACK_FIRST_ANGLE+index*STACK_ANGLE_STEP),lift_duration).set_delay(delay)
   lift.tween_property(view,"scale",Vector2(0.84,0.84),lift_duration).set_delay(delay)
   lift.tween_property(view,"modulate:a",1.0,0.045).set_delay(delay)
  await lift.finished
  deal_phase="stack"
  await get_tree().create_timer(0.015 if reduced_motion else STACK_BEAT).timeout
 deal_phase="fan" if not drawn.is_empty() else "reflow"
 var duration: float=0.10 if reduced_motion else FAN_TIME
 var interval: float=0.014 if reduced_motion else FAN_GAP
 var tween:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 var deal_index: int=0
 for entry in model.hand:
  var uid: int=int(entry.uid)
  var view: LyncoCardView=views[uid]
  var delay: float=interval*deal_index if new_ids.has(uid) else 0.0
  tween.tween_property(view,"position",view.rest_position,duration).set_delay(delay)
  tween.tween_property(view,"rotation",view.rest_rotation,duration).set_delay(delay)
  if new_ids.has(uid):
   # Reveal during the existing deal interval; the approved motion timing stays unchanged.
   var midpoint:float=duration*0.45
   tween.tween_property(view,"scale",Vector2(0.02,0.94),midpoint).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
   tween.tween_callback(view.set_face_up.bind(true)).set_delay(delay+midpoint)
   tween.tween_property(view,"scale",Vector2.ONE,duration-midpoint).from(Vector2(0.02,0.94)).set_delay(delay+midpoint)
   deal_index+=1
  else:
   tween.tween_property(view,"scale",Vector2.ONE,duration)
 if model.hand.is_empty():
  tween.kill()
 else:
  await tween.finished
 for view in views.values():
  view.locked=false; view.z_index=0
 deal_phase="idle"

func _select_card(uid: int) -> void:
 if inspector_open or busy or model.finished or help_panel.visible:return
 selected_uid=uid
 for id in views:views[id].set_selected(id==uid)
 _inspect(uid)

func _focus_card(uid: int, inside: bool) -> void:
 if inspector_open or looking or busy or drag_uid>=0 or model.finished or help_panel.visible:return
 if inside:
  hovered_uid=uid
  _inspect(uid)
 elif hovered_uid==uid:
  hovered_uid=-1
  if selected_uid>=0:_inspect(selected_uid)
 else:return
 for view in views.values():
  view.focus_offset=signf(view.rest_position.x-views[hovered_uid].rest_position.x)*10.0 if views.has(hovered_uid) else 0.0
  view.set_hand_focus(hovered_uid)
 _schedule_hover_direction()

func _clear_hand_focus() -> void:
 _hide_hover_direction()
 hovered_uid=-1
 for view in views.values():view.set_hand_focus(-1,false)

func _inspect(uid: int, populate: bool = false) -> void:
 var index:=model.find_card(uid)
 if index<0:return
 if bool(model.hand[index].get("concealed", false)): return
 inspect_uid=uid
 # Hidden details need only remember the card; populate from live state on open.
 if not populate and not inspector_open:return
 var data: Dictionary=Catalog.table_card(model.hand[index].id)
 preview_title.text=str(data.name)
 preview_cost.text=str(data.cost)
 preview_cost.tooltip_text="행동력 비용 %d" % int(data.cost)
 preview_kind.text="%s · 테이블 배치" % str(data.kind)
 preview_icon.texture=Symbols.texture_for(data, textures.get(data.icon))
 preview_text.text=str(data.detail)
 var reason:=model.unavailable_reason(uid)
 preview_effect.text=model.preview(uid) if reason.is_empty() else reason
 preview_effect.add_theme_color_override("font_color",Color("e0e2e4"))

func _use_selected() -> void:
 if selected_uid>=0:_activate_card(selected_uid)

func _activate_card(uid: int, cell: Vector2i = Table.INVALID) -> void:
 if inspector_open or busy or drag_uid>=0 or help_panel.visible:return
 var reason:=model.unavailable_reason(uid)
 if not reason.is_empty():_toast(reason);return
 if cell==Table.INVALID and model.is_concealed(uid):
  _select_card(uid)
  return
 if cell==Table.INVALID:cell=table.next_cell()
 if not table.free_cell(cell):_toast("빈 테이블 칸에 놓아주세요");return
 table.select_influence(Table.INVALID)
 busy=true
 _clear_hand_focus()
 selected_uid=-1
 var result: Dictionary=model.play(uid)
 if not bool(result.ok):busy=false;_sync_ui();return
 var view: LyncoCardView=views[uid]
 if bool(result.get("reverse", false)):
  var revealed := Card.new()
  var definition: Dictionary = Catalog.back_card(str(result.entry.id))
  hand_layer.add_child(revealed)
  revealed.setup(result.entry,definition,Symbols.texture_for(definition),light_ink if bool(definition.dark) else dark_ink,textures["back_black" if bool(definition.dark) else "back_white"])
  revealed.reduced_motion=reduced_motion
  revealed.position=view.position;revealed.rotation=view.rotation;revealed.scale=view.scale
  view.stop_motion();view.queue_free();view=revealed
 views.erase(uid); view.stop_motion(); view.locked=true; view.z_index=55
 for other in views.values():other.locked=true
 _sync_ui()
 var is_attack: bool=int(result.damage)>0
 var target:Vector2=table.screen_position(cell)-Card.CARD_SIZE*0.5
 var duration: float=0.09 if reduced_motion else 0.17
 var use:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 use.tween_property(view,"position",target,duration)
 use.tween_property(view,"rotation",0.0,duration)
 use.tween_property(view,"scale",Vector2(0.67,0.67),duration)
 await use.finished
 table.place(str(result.entry.id),cell,reduced_motion,bool(result.get("reverse",false)))
 table.mark_owner(cell,"player")
 if str(result.effect)=="table":
  _toast("테이블 +%d · %s" % [int(result.score),Catalog.table_effect_text(str(result.entry.id))])
 elif str(result.effect)=="pending_back":
  _toast("%s 공개 · 효과와 비용 미정" % str(view.data.name))
 elif is_attack:
  _toast("피해 %d%s" % [int(result.damage),"  +  연계 피해 %d" % int(result.extra) if int(result.extra)>0 else ""])
 else:
  _toast("%s  ·  %s" % [str(view.data.name),"방어 +7" if str(result.effect)=="guard" else "효과 발동"])
 var exit_motion:=create_tween()
 exit_motion.tween_property(view,"modulate:a",0.0,0.07)
 await exit_motion.finished
 view.queue_free()
 await _animate_draw(result.drawn)
 busy=false; _sync_ui(); _check_end()

func _end_turn() -> void:
 if inspector_open or looking or busy or drag_uid>=0 or model.finished or help_panel.visible:return
 busy=true;selected_uid=-1
 _clear_hand_focus()
 _sync_ui()
 if not views.is_empty():
  var tween:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
  var index:int=0
  for view in views.values():
   view.stop_motion();view.locked=true
   var delay:float=index*0.018
   tween.tween_property(view,"position",DISCARD_ORIGIN,0.12 if reduced_motion else 0.2).set_delay(delay)
   tween.tween_property(view,"scale",Vector2(0.4,0.4),0.2).set_delay(delay)
   tween.tween_property(view,"modulate:a",0.0,0.2).set_delay(delay)
   index+=1
  await tween.finished
 for view in views.values():view.queue_free()
 views.clear()
 var result: Dictionary=model.end_turn()
 table.show_opponent_hand(int(result.hand_count))
 _hide_hover_direction();camera_keys.clear()
 await table.set_opponent_view(true,reduced_motion)
 for record in result.placements:
  var cell: Vector2i = table.next_cell()
  _toast("상대 · %s" % str(Catalog.card(record.entry.id).name))
  await table.play_opponent(str(record.entry.id),cell,int(record.hand_before),int(record.hand_after),reduced_motion)
 table.show_opponent_hand(0)
 await get_tree().create_timer(0.06 if reduced_motion else 0.18).timeout
 await table.set_opponent_view(false,reduced_motion)
 if not model.finished:table.show_opponent_hand(5)
 _sync_ui()
 _toast("상대 %d장 배치 · %s" % [result.placements.size(),"판정" if model.finished else "내 차례"])
 await _animate_draw(result.drawn)
 busy=false;_sync_ui();_check_end()

func _demo_draw() -> void:
 if inspector_open or busy or drag_uid>=0 or model.finished:return
 if model.hand.size()>=int(Catalog.CHARACTER.hand_limit):_toast("손패는 최대 7장입니다");return
 busy=true;selected_uid=-1;_sync_ui()
 var drawn:=model.draw_cards(1)
 if drawn.is_empty():_toast("덱과 버림패가 비어 있습니다")
 await _animate_draw(drawn)
 busy=false;_sync_ui()

func _set_hud_value(key: String, value: int) -> void:
 var label: Label=hud_values[key]
 label.text=str(value)

func _sync_ui() -> void:
 if is_instance_valid(table_status):
  _set_hud_value("energy",model.energy)
  _set_hud_value("player_score",model.player_score)
  _set_hud_value("opponent_score",model.opponent_score)
  _set_hud_value("placed",model.placed.size())
  var previous_caption: String=turn_caption.text
  turn_caption.text="%02d 턴   ·   %s" % [model.turn,"판정 완료" if model.finished else ("진행 중" if busy else "내 차례")]
  if previous_caption!=turn_caption.text:
   if turn_motion and turn_motion.is_valid():turn_motion.kill()
   turn_caption.position=Vector2(28,14)
   if not reduced_motion and not previous_caption.is_empty():
    turn_caption.position.x+=10
    turn_motion=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    turn_motion.tween_property(turn_caption,"position:x",28.0,0.2)
  turn_track.set_progress(model.placed.size(),Model.CAPACITY)
  garnet_label.text=str(preload("res://scripts/collection_session.gd").gold)
 if busy or model.finished: _hide_hover_direction()
 deck_label.text="덱  %d" % model.deck.size()
 discard_label.text="버림  %d" % model.discard.size()
 exhaust_label.text="소멸  %d" % model.exhausted.size()
 hand_label.text="%d / %d" % [model.hand.size(),model.total_cards]
 hand_hint.text="가린 카드 선택 후 빈 칸 클릭 · 드래그 배치" if model.hand.any(func(entry):return bool(entry.get("concealed",false))) else "우클릭 상세 · 드래그 배치"
 _sync_identity_counter()
 fill_button.disabled=busy or model.finished or model.hand.size()>=5
 shift_button.disabled=busy or model.finished or model.hand.is_empty()
 menu_button.disabled=busy or leaving_battle
 end_button.disabled=busy or model.finished
 end_button.text="연출 진행 중…" if busy else "턴 종료    →"
 reset_button.disabled=busy;draw_button.disabled=busy or model.finished or model.hand.size()>=7
 seed_box.editable=not busy
 for uid in views:
  var reason:=model.unavailable_reason(uid)
  views[uid].set_available(reason.is_empty(),reason)
  views[uid].locked=busy or model.finished
 if inspect_uid>=0 and model.find_card(inspect_uid)>=0:_inspect(inspect_uid)
 elif not model.hand.is_empty():_inspect(int(model.hand[0].uid))
 elif inspector_open:
  preview_title.text="손패가 비었습니다";preview_cost.text="—";preview_kind.text="다음 턴에 다시 드로우"
  preview_text.text="턴을 종료해\n새 카드를 뽑으세요.";preview_effect.text=""

func _sync_identity_counter() -> void:
 # Aggregate hand counts only: never disclose the identity of a hidden slot.
 identity_counter.visible = not model.finished and (shuffle_phase != "idle" or model.hand.any(func(entry):return bool(entry.get("concealed",false))))
 if not identity_counter.visible: return
 var counts: Dictionary = model.identity_counts()
 king_count.text="킹 %d" % int(counts.king)
 joker_count.text="조커 %d" % int(counts.joker)

func _toast(message: String) -> void:
 if toast_tween and toast_tween.is_valid():toast_tween.kill()
 toast_label.text=message;toast_label.modulate.a=1.0
 toast_tween=create_tween()
 toast_tween.tween_interval(1.65)
 toast_tween.tween_property(toast_label,"modulate:a",0.0,0.2)

func _check_end() -> void:
 if not model.finished:return
 var reward: int = model.claim_reward()
 result_title.text="승리" if model.winner=="player" else ("무승부" if model.winner=="draw" else "패배")
 result_body.text="테이블 판정  %d : %d\n획득 골드 +%d · 상점에서 덱 해금\n%d턴 · 시드 %d" % [model.player_score,model.opponent_score,reward,model.turn,model.seed_value]
 result_panel.show()
 _sync_ui()

func _unhandled_key_input(event: InputEvent) -> void:
 if is_instance_valid(inventory_layer):return
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_F1:
  help_panel.visible=not help_panel.visible
  _hide_hover_direction()
  get_viewport().set_input_as_handled();return
 if event.keycode==KEY_F3:
  show_performance=not show_performance
  performance_label.visible=show_performance
  if show_performance:performance_timer.start();_update_performance()
  else:performance_timer.stop();performance_label.text="F3 · 성능 표시"
  get_viewport().set_input_as_handled();return
 if event.keycode==KEY_ESCAPE:
  table.select_influence(Table.INVALID)
  _close_inspector()
  _stop_look()
  _cancel_drag()
  help_panel.hide();selected_uid=-1
  for view in views.values():view.set_selected(false)
  get_viewport().set_input_as_handled();return
 if inspector_open or looking or busy or drag_uid>=0 or model.finished or help_panel.visible:return
 if event.keycode==KEY_E:
  _fill_requested();get_viewport().set_input_as_handled();return
 if event.keycode==KEY_SHIFT:
  _shift_requested();get_viewport().set_input_as_handled();return
 if event.keycode==KEY_R:
  table.reset_look();get_viewport().set_input_as_handled();return
 if event.keycode>=KEY_1 and event.keycode<=KEY_7:
  var index:int=event.keycode-KEY_1
  if index<model.hand.size():_select_card(int(model.hand[index].uid))
 elif event.keycode==KEY_ENTER:_use_selected()
 elif event.keycode==KEY_SPACE:_end_turn()
 else:return
 get_viewport().set_input_as_handled()

func _update_performance() -> void:
 performance_label.text="%d FPS  ·  엔진 프레임 %.2f ms  ·  드로우 콜 %d  ·  노드 %d" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]

func _process(_delta: float) -> void:
 if not camera_keys.is_empty():
  if _hand_action_blocked() or not get_window().has_focus():
   camera_keys.clear()
  else:
   var movement := Vector2(float(camera_keys.has(KEY_D))-float(camera_keys.has(KEY_A)),float(camera_keys.has(KEY_S))-float(camera_keys.has(KEY_W)))
   table.pan_by(movement,_delta)
   _hide_hover_direction()
  if camera_keys.is_empty() and not measure_frames: set_process(false)
 if measure_frames:
  var now:int=Time.get_ticks_usec()
  if last_sample_us>0:frame_samples.append(float(now-last_sample_us)/1000.0)
  last_sample_us=now

func _test_pointer(point: Vector2, click: bool = false) -> void:
 # Send real viewport GUI events, so hit testing and mouse enter/exit run too.
 var screen_point:Vector2=stage.get_global_transform_with_canvas()*point
 var motion:=InputEventMouseMotion.new()
 motion.position=screen_point;motion.global_position=screen_point
 get_viewport().push_input(motion,true)
 if click:
  for pressed in [true,false]:
   var button:=InputEventMouseButton.new()
   button.position=screen_point;button.global_position=screen_point
   button.button_index=MOUSE_BUTTON_LEFT;button.pressed=pressed
   get_viewport().push_input(button,true)

func _verify_motion() -> void:
 var output_dir:String=ProjectSettings.globalize_path("res://test-results")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var ignore:=FileAccess.open(output_dir+"/.gdignore",FileAccess.WRITE);ignore.close()
 var movie:bool=OS.get_cmdline_user_args().has("--movie-preview")
 if not movie:
  # Capture both actual back materials, without touching front-face definitions.
  var samples:Array[LyncoCardView]=[]
  for index in range(2):
   var definition:Dictionary=Catalog.table_card("guard" if index==0 else "strike")
   var sample:=Card.new();stage.add_child(sample)
   sample.setup({"uid":-100-index},definition,Symbols.texture_for(definition, textures.get(definition.icon)),dark_ink if index==0 else light_ink,textures["back_white" if index==0 else "back_black"])
   sample.position=Vector2(550+index*330,320);sample.scale=Vector2(1.5,1.5);sample.z_index=90;sample.locked=true
   sample.set_face_up(false);samples.append(sample)
   assert((sample.back_logo.position+sample.back_logo.size*0.5).is_equal_approx(Card.CARD_SIZE*0.5))
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output_dir+"/card_backs.png")
  for sample in samples:sample.queue_free()
  await get_tree().process_frame
 _test_pointer(Vector2(350,105))
 await get_tree().create_timer(0.15).timeout
 _restart(20260926)
 assert(deal_phase=="lift" and busy)
 # The fan must not begin until every new card is visibly in the raised packet.
 while deal_phase=="lift":await get_tree().process_frame
 assert(deal_phase=="stack")
 for i in range(model.hand.size()):
  var view:LyncoCardView=views[int(model.hand[i].uid)]
  assert(view.position.distance_to(DRAW_STACK+STACK_CARD_STEP*i)<0.5)
  assert(absf(view.rotation-deg_to_rad(STACK_FIRST_ANGLE+i*STACK_ANGLE_STEP))<0.001)
  if i>0:
   var previous:LyncoCardView=views[int(model.hand[i-1].uid)]
   assert(view.position.x-previous.position.x>=26.0-0.5,"Lifted cards collapsed into one stack")
  assert(view.scale.is_equal_approx(Vector2(0.84,0.84)))
  assert(not view.face_up and view.back_logo.visible)
  assert(view.back_logo.texture==textures["back_black" if bool(view.data.dark) else "back_white"])
 if not movie:
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output_dir+"/motion_stack.png")
 while busy:await get_tree().process_frame
 assert(deal_phase=="idle")
 for view in views.values():
  assert(view.position.distance_to(view.rest_position)<0.5)
  assert(view.scale.is_equal_approx(Vector2.ONE))
  assert(view.face_up and not view.back_logo.visible)
 await get_tree().create_timer(0.35).timeout
 var middle_uid:int=int(model.hand[2].uid)
 var middle:LyncoCardView=views[middle_uid]
 _test_pointer(middle.rest_position+Card.CARD_SIZE*0.5,true)
 await get_tree().create_timer(0.22).timeout
 assert(hovered_uid==middle_uid and selected_uid==middle_uid,"Viewport hover/click did not reach the card")
 for uid in views:
  assert(absf(views[uid].scale.x-(Card.HOVER_SCALE if uid==middle_uid else Card.PEER_SCALE))<0.001)
 if not movie:
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output_dir+"/motion_hover.png")
 # An unmoving pointer must not trigger shrink/expand oscillation.
 for _i in range(15):
  await get_tree().process_frame
  assert(hovered_uid==middle_uid)
 if not movie:
  # Sweep all neutral slots with actual pointer events, including shrunk cards.
  for entry in model.hand:
   var view:LyncoCardView=views[int(entry.uid)]
   _test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await get_tree().create_timer(0.25).timeout
   assert(hovered_uid==int(entry.uid))
   assert(absf(view.scale.x-Card.HOVER_SCALE)<0.001)
   for uid in views:
    if uid!=int(entry.uid):assert(absf(views[uid].scale.x-Card.PEER_SCALE)<0.001)
 else:
  for index in [0,3,4]:
   var view:LyncoCardView=views[int(model.hand[index].uid)]
   _test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await get_tree().create_timer(0.45).timeout
 _test_pointer(Vector2(350,105))
 await get_tree().create_timer(0.22).timeout
 assert(hovered_uid==-1)
 for view in views.values():assert(view.scale.is_equal_approx(Vector2.ONE))
 if not movie:
  await _demo_draw();await _demo_draw()
  assert(model.hand.size()==7 and model.conserved())
  for entry in model.hand:
   var view:LyncoCardView=views[int(entry.uid)]
   _test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await get_tree().create_timer(0.17).timeout
   assert(hovered_uid==int(entry.uid))
  _test_pointer(Vector2(350,105))
  await get_tree().create_timer(0.2).timeout
  for view in views.values():assert(view.scale.is_equal_approx(Vector2.ONE))
  await _end_turn()
  assert(model.conserved() and hovered_uid==-1)
 var result:Dictionary={"two_phase_draw":true,"hover_viewport_events":true,"neutral_hit_slots":true,"stationary_hover_stable":true,"hover_scale":Card.HOVER_SCALE,"other_card_scale":Card.PEER_SCALE,"lift_seconds":LIFT_TIME,"lift_gap_seconds":LIFT_GAP,"stack_pause_seconds":STACK_BEAT,"fan_seconds":FAN_TIME,"fan_gap_seconds":FAN_GAP,"five_card_draw_seconds":LIFT_TIME+4*LIFT_GAP+STACK_BEAT+FAN_TIME+4*FAN_GAP}
 var file:=FileAccess.open(output_dir+"/motion_test.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("LYNCO_MOTION_TEST_PASS "+JSON.stringify(result))
 await get_tree().create_timer(0.25).timeout
 get_tree().quit()

func _verify() -> void:
 reduced_motion=true
 await _restart(20260926)
 await get_tree().process_frame
 var baseline: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 for i in range(16):
  await _restart(20260926)
  await get_tree().process_frame
  assert(model.conserved() and table.cards.is_empty())
 assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==baseline)
 for i in range(100):
  if model.finished:break
  var uid: int = -1
  for entry in model.hand:
   if model.unavailable_reason(entry.uid).is_empty():uid=int(entry.uid);break
  if uid>=0:await _activate_card(uid)
  else:await _end_turn()
  assert(model.conserved() and table.cards.size()==model.placed.size())
 assert(model.finished and result_panel.visible and table.cards.size()==Model.CAPACITY)
 var snapshot: String=JSON.stringify([model.hand,model.placed,model.energy])
 await _end_turn();await _demo_draw();await _fill_requested();await _shift_requested()
 assert(snapshot==JSON.stringify([model.hand,model.placed,model.energy]))
 assert(model.claim_reward()==0)
 print("LYNCO_TABLE_VERIFY_PASS 16_restarts nodes=",baseline,"/",baseline," full_match finished_input_guard reward_once")
 get_tree().quit()

func _prepare_table_cards() -> void:
 # Bake each definition once; all placed instances share its texture/material.
 var pending:Dictionary={}
 var bake_ids: Array = Catalog.CARDS.keys()
 for front_id in Catalog.CARDS: bake_ids.append("reverse:" + str(front_id))
 for front_id in Catalog.CARDS: bake_ids.append("opponent:" + str(front_id))
 bake_ids.append_array(["back_white","back_black"])
 for id in bake_ids:
  var canvas:=SubViewport.new();canvas.size=Vector2i(316,456)
  canvas.transparent_bg=true;canvas.disable_3d=true
  canvas.render_target_update_mode=SubViewport.UPDATE_ONCE
  add_child(canvas)
  var definition:Dictionary=Catalog.back_card(str(id).trim_prefix("reverse:")) if str(id).begins_with("reverse:") else Catalog.table_card(("guard" if id=="back_white" else "strike") if str(id).begins_with("back_") else str(id).trim_prefix("opponent:"))
  var sample:=Card.new();sample.theme=theme;canvas.add_child(sample)
  sample.setup({"uid":-1},definition,Symbols.texture_for(definition, textures.get(definition.icon)),light_ink if bool(definition.dark) else dark_ink,textures["back_black" if bool(definition.dark) else "back_white"])
  sample.pivot_offset=Vector2.ZERO;sample.scale=Vector2(2,2);sample.locked=true
  sample.set_face_up(not str(id).begins_with("back_"))
  sample.outline_style.shadow_size=0
  if str(id).begins_with("opponent:"):
   sample.outline_style.bg_color=Color("101211") if bool(definition.dark) else Color("c8cac4")
  pending[id]=canvas
 await RenderingServer.frame_post_draw
 for id in pending:
  var canvas:SubViewport=pending[id]
  var pixels:=canvas.get_texture().get_image()
  pixels.generate_mipmaps()
  if str(id).begins_with("back_"):table.set_back_texture(id,ImageTexture.create_from_image(pixels))
  else:table.set_card_texture(id,ImageTexture.create_from_image(pixels))
  canvas.queue_free()
 # Warm texture uploads and shader variants before interactive play begins.

 var index:int=0
 for id in Catalog.CARDS:
  table.place(id,Vector2i(index,0),true)
  index+=1
 await get_tree().create_timer(0.15).timeout
 await RenderingServer.frame_post_draw
 table.clear_cards()
 await get_tree().process_frame


func _input(event: InputEvent) -> void:
 if get_node("/root/WindowControls").handle_shortcut(event):return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_KP_0 or event.keycode==KEY_KP_0:
   preload("res://scripts/collection_session.gd").add_preview_items()
   if is_instance_valid(inventory_layer):inventory_layer.get_child(0).refresh()
   else:_toast("임시 아이템 6개 준비 · F로 확인")
   get_viewport().set_input_as_handled();return
  if event.physical_keycode==KEY_F or event.keycode==KEY_F:
   _toggle_inventory();get_viewport().set_input_as_handled();return
  if is_instance_valid(inventory_layer) and event.keycode==KEY_ESCAPE:
   _toggle_inventory();get_viewport().set_input_as_handled();return
 if is_instance_valid(inventory_layer):return
 if is_instance_valid(table) and (table.card_focus_active or table.card_focus_returning) and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  table.dismiss_card_focus()
  press_uid=-1
  get_viewport().set_input_as_handled()
  return
 if is_instance_valid(table) and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and event.pressed:
  if not busy and not inspector_open and drag_uid<0 and press_uid<0 and not help_panel.visible:
   _stop_look();_hide_hover_direction();camera_keys.clear()
   table.set_top_view(not table.top_view)
   stage.visible=not table.top_view
   get_viewport().set_input_as_handled()
  return
 if is_instance_valid(table) and table.top_view:
  if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_R]:
   table.set_top_view(false);stage.show()
  elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   table.zoom_top_view((1.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.0)*maxf(event.factor,1.0),event.position)
  elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
   table.click_influence(table.cell_at(stage.get_global_transform_with_canvas().affine_inverse()*event.position))
  get_viewport().set_input_as_handled()
  return
 if event is InputEventKey:
  var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
  if key in [KEY_W,KEY_A,KEY_S,KEY_D] and not event.pressed:
   camera_keys.erase(key)
   if camera_keys.is_empty() and not measure_frames: set_process(false)
  elif key in [KEY_W,KEY_A,KEY_S,KEY_D] and not event.echo and is_instance_valid(seed_box) and not _hand_action_blocked():
   camera_keys[key] = true; set_process(true)
   _clear_hand_focus(); get_viewport().set_input_as_handled(); return
 if not is_instance_valid(table) or not is_instance_valid(stage):return
 if not inspector_open and event is InputEventMouseButton:
  var hud_point: Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
  if turn_board.get_rect().has_point(hud_point) or (menu_button.visible and menu_button.get_rect().has_point(hud_point)):return
 if inspector_open:
  if event is InputEventMouseButton:
   if event.pressed and (event.button_index==MOUSE_BUTTON_RIGHT or (event.button_index==MOUSE_BUTTON_LEFT and not inspector_card.get_global_rect().has_point(event.position) and not inspector_demo.get_global_rect().has_point(event.position))):
    _close_inspector()
   get_viewport().set_input_as_handled();return
  if event is InputEventMouseMotion:
   get_viewport().set_input_as_handled();return
  if event is InputEventKey and event.pressed:
   if event.keycode==KEY_ESCAPE:_close_inspector()
   get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:
  if not event.pressed:
   if looking:_stop_look();get_viewport().set_input_as_handled()
   return
  if busy or drag_uid>=0 or press_uid>=0 or help_panel.visible or model.finished:return
  var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
  var hand_uid:int=_hand_card_at(point)
  if hand_uid>=0:
   if model.is_concealed(hand_uid):
    _toast("가려진 카드입니다 · 배치하면 정체가 공개됩니다")
    get_viewport().set_input_as_handled();return
   _inspect(hand_uid,true)
   _show_inspector(Catalog.table_card(model.hand[model.find_card(hand_uid)].id))
   get_viewport().set_input_as_handled();return
  var placed_cell: Vector2i=table.cell_at(point)
  if table.cards.has(placed_cell):
   var holder: Node3D=table.cards[placed_cell]
   _inspect_placed(str(holder.get_meta("card_id")),bool(holder.get_meta("reverse",false)),str(holder.get_meta("owner","player")))
   get_viewport().set_input_as_handled();return
  if not Rect2(20,180,1560,450).has_point(point):return
  looking=true;look_pointer=get_viewport().get_mouse_position()
  previous_mouse_mode=Input.mouse_mode
  Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
  _clear_hand_focus();table.hide_preview()
  get_viewport().set_input_as_handled();return
 if looking:
  if event is InputEventMouseMotion:
   table.look_by(event.screen_relative)
   get_viewport().set_input_as_handled();return
  if event is InputEventMouseButton:
   get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   press_uid=-1
   if inspector_open or busy or model.finished or help_panel.visible:return
   press_point=stage.get_global_transform_with_canvas().affine_inverse()*event.position
   press_uid=_hand_card_at(press_point)
   if press_uid<0:
    var cell:Vector2i=table.cell_at(press_point)
    if cell!=Table.INVALID:
     _hide_hover_direction()
     if table.cards.has(cell):
      selected_uid=-1
      for view in views.values():view.set_selected(false)
      table.click_influence(cell)
     elif selected_uid>=0:
      _activate_card(selected_uid,cell)
     else:table.click_influence(cell)
     get_viewport().set_input_as_handled()
  else:
   press_uid=-1
   if drag_uid>=0:
    var uid:int=drag_uid
    var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
    var cell:Vector2i=table.cell_at(point)
    var reason:String=model.unavailable_reason(uid)
    var allowed:bool=table.free_cell(cell) and reason.is_empty()
    _cancel_drag()
    get_viewport().set_input_as_handled()
    if allowed:_activate_card(uid,cell)
    else:_toast(reason if not reason.is_empty() else "빈 테이블 칸에 놓아주세요")
 elif event is InputEventMouseMotion:
  if press_uid<0 and drag_uid<0:
   _hover_placed_direction(stage.get_global_transform_with_canvas().affine_inverse()*event.position)
   return
  var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
  if press_uid>=0 and drag_uid<0 and event.button_mask&MOUSE_BUTTON_MASK_LEFT and point.distance_to(press_point)>8:
   if busy or model.finished or help_panel.visible or not views.has(press_uid):return
   drag_uid=press_uid
   _clear_hand_focus()
   for other_uid in views:
    if other_uid!=drag_uid:
     views[other_uid].drag_retracted=true
     views[other_uid].update_pose()
   var view:LyncoCardView=views[drag_uid]
   view.stop_motion();view.locked=true;view.z_index=150
   view.rotation=0;view.scale=Vector2.ONE*Card.HOVER_SCALE
   _inspect(drag_uid)
  if drag_uid>=0:
   var view:LyncoCardView=views[drag_uid]
   var target: Vector2=point-Vector2(Card.CARD_SIZE.x*0.5,Card.CARD_SIZE.y*0.9)
   view.rotation=clampf((target.x-view.position.x)*0.0012,-0.075,0.075) if not reduced_motion else 0.0
   view.position=target
   var cell: Vector2i=table.preview(point,model.unavailable_reason(drag_uid).is_empty())
   if cell!=Table.INVALID and table.preview_allowed and not reduced_motion:
    var snap: Vector2=table.screen_position(cell)
    if point.distance_to(snap)<45:view.position+=0.22*(snap-point)
   get_viewport().set_input_as_handled()

func _cancel_drag() -> void:
 if table and table.placement_camera:table.placement_camera.restore()
 for hand_view in views.values():
  if hand_view.drag_retracted:
   hand_view.drag_retracted=false
   hand_view.update_pose()
 press_uid=-1
 if drag_uid>=0 and views.has(drag_uid):
  var view:LyncoCardView=views[drag_uid]
  view.locked=false;view.update_pose()
 drag_uid=-1
 if table:table.hide_preview()

func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
  camera_keys.clear()
  if not measure_frames: set_process(false)
  _hide_hover_direction()
  _close_inspector()
  _stop_look(false)
  if drag_uid>=0:_cancel_drag()

func _stop_look(restore_pointer: bool = true) -> void:
 if not looking:return
 looking=false
 Input.mouse_mode=previous_mouse_mode
 if restore_pointer and previous_mouse_mode==Input.MOUSE_MODE_VISIBLE:
  get_viewport().warp_mouse(look_pointer)

func _verify_table() -> void:
 var output:String=ProjectSettings.globalize_path("res://test-results")
 await _restart(20260926)
 await get_tree().process_frame
 var uid:int=int(model.hand[0].uid)
 var view:LyncoCardView=views[uid]
 var start:Vector2=view.rest_position+Card.CARD_SIZE*0.5
 var cell:=Vector2i(2,1)
 var end:Vector2=table.screen_position(cell)
 assert(table.cell_at(end)==cell)
 _test_drag(start,end)
 while busy:await get_tree().process_frame
 await get_tree().create_timer(0.3).timeout
 assert(model.find_card(uid)<0 and table.cards.has(cell) and model.conserved())
 assert(table.cards[cell].get_node("Body").cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
 assert(absf(table.cards[cell].position.y-table.cell_position(cell).y)<0.001)
 var initial:String=JSON.stringify([model.energy,model.hand,model.discard])
 view=views[int(model.hand[0].uid)]
 _test_drag(view.rest_position+Card.CARD_SIZE*0.5,end)
 await get_tree().create_timer(0.2).timeout
 assert(initial==JSON.stringify([model.energy,model.hand,model.discard]))
 _test_drag(view.rest_position+Card.CARD_SIZE*0.5,Vector2(1580,20))
 await get_tree().create_timer(0.2).timeout
 assert(initial==JSON.stringify([model.energy,model.hand,model.discard]))
 # Escape cancels a held card without changing ownership or resources.
 _test_drag(view.rest_position+Card.CARD_SIZE*0.5,end,false)
 assert(drag_uid>=0)
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 get_viewport().push_input(escape,true)
 assert(drag_uid==-1 and not table.hint.visible)
 assert(initial==JSON.stringify([model.energy,model.hand,model.discard]))
 await get_tree().create_timer(0.2).timeout
 for hand_view in views.values():assert(hand_view.scale.is_equal_approx(Vector2.ONE))
 _test_pointer(end,true)
 assert(table.card_focus_active and not inspector_open)
 table.dismiss_card_focus()
 await get_tree().create_timer(0.24).timeout
 # Use an attack via the keyboard/button path, retaining existing combat effects.
 for entry in model.hand.duplicate():
  if str(Catalog.table_card(entry.id).effect)=="damage":
   await _activate_card(entry.uid)
   break
 await get_tree().create_timer(0.3).timeout
 _test_pointer(Vector2(350,105))
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/table_scene_1440.png")
 get_window().size=Vector2i(1280,720)
 await get_tree().create_timer(0.2).timeout
 # Same projection and hit testing after resizing.
 var resized_point:Vector2=table.screen_position(Vector2i(4,1))
 assert(table.cell_at(resized_point)==Vector2i(4,1))
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/table_scene_1280.png")
 model.energy=0;_sync_ui()
 for entry in model.hand:
  if int(Catalog.table_card(entry.id).cost)>0:
   view=views[entry.uid]
   initial=JSON.stringify([model.energy,model.hand,model.discard])
   _test_drag(view.rest_position+Card.CARD_SIZE*0.5,resized_point)
   await get_tree().create_timer(0.2).timeout
   assert(initial==JSON.stringify([model.energy,model.hand,model.discard]))
   break
 await _end_turn()
 assert(table.cards.size()==model.placed.size() and table.cards.size()>0 and model.conserved())
 await _restart(20260926)
 assert(table.cards.is_empty())
 print("LYNCO_TABLE_TEST_PASS drag_snap occupied_outside_rejected energy_rejected escape_cancel placed_inspector shadow landing resize turn_persists_restart_clear")
 get_tree().quit()

func _test_drag(start: Vector2, end: Vector2, finish: bool = true) -> void:
 _test_pointer(start)
 var transform:Transform2D=stage.get_global_transform_with_canvas()
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 press.position=transform*start;press.global_position=press.position
 get_viewport().push_input(press,true)
 var motion:=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 motion.position=transform*end;motion.global_position=motion.position
 get_viewport().push_input(motion,true)
 if not finish:return
 var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 release.position=transform*end;release.global_position=release.position
 get_viewport().push_input(release,true)

func _inspect_placed(id: String, reverse: bool = false, owner: String = "player") -> void:
 selected_uid=-1;inspect_uid=-1
 for view in views.values():view.set_selected(false)
 var data:Dictionary=Catalog.back_card(id) if reverse else Catalog.table_card(id)
 preview_cost.tooltip_text="비용 미정" if reverse else "행동력 비용 %d" % int(data.cost)
 preview_title.text=str(data.name);preview_cost.text=str(data.get("cost_label",data.cost))
 preview_icon.texture=Symbols.texture_for(data, textures.get(data.icon))
 preview_kind.text="%s · 정체 공개 / 효과 미정" % str(data.kind) if reverse else "%s · 테이블에 배치됨" % str(data.kind)
 preview_kind.text=("상대 카드 · " if owner=="opponent" else "내 카드 · ")+preview_kind.text
 preview_text.text=str(data.detail)
 preview_effect.text="효과·비용·점수 미정" if reverse else "최종 판정까지 테이블에 유지"
 preview_effect.add_theme_color_override("font_color",Color("e0e2e4"))
 _show_inspector(data)

func _test_look_mouse(pressed: bool, relative: Vector2 = Vector2.ZERO) -> void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
 event.position=stage.get_global_transform_with_canvas()*Vector2(800,320)
 get_viewport().push_input(event,true)
 if pressed and relative!=Vector2.ZERO:
  var motion:=InputEventMouseMotion.new()
  motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
  motion.relative=relative;motion.screen_relative=relative
  get_viewport().push_input(motion,true)

func _verify_look() -> void:
 var output:String=ProjectSettings.globalize_path("res://test-results")
 await _restart(20260926)
 var original:Vector3=table.camera.rotation
 var original_ui:Transform2D=stage.get_global_transform_with_canvas()
 _test_look_mouse(true,Vector2(10000,-10000))
 assert(looking)
 assert(is_equal_approx(table.look_offset.x,-deg_to_rad(12.0)))
 assert(is_equal_approx(table.look_offset.y,deg_to_rad(7.0)))
 _test_look_mouse(false)
 assert(not looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 var held:Vector3=table.camera.rotation
 await get_tree().create_timer(0.15).timeout
 assert(table.camera.rotation.is_equal_approx(held))
 assert(stage.get_global_transform_with_canvas().is_equal_approx(original_ui))
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/look_right.png")
 _test_look_mouse(true,Vector2(-20000,20000))
 _test_look_mouse(false)
 assert(is_equal_approx(table.look_offset.x,deg_to_rad(12.0)))
 assert(is_equal_approx(table.look_offset.y,-deg_to_rad(7.0)))
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/look_left.png")
 # Drag at a rotated camera must target the same 3D cell.
 var cell:=Vector2i(2,1)
 var end:Vector2=table.screen_position(cell)
 assert(table.cell_at(end)==cell)
 var uid:int=int(model.hand[0].uid)
 var view:LyncoCardView=views[uid]
 _test_drag(view.rest_position+Card.CARD_SIZE*0.5,end,false)
 assert(drag_uid==uid and table.hint.visible)
 _test_look_mouse(true)
 assert(not looking and table.camera.rotation.is_equal_approx(original+Vector3(-deg_to_rad(7.0),deg_to_rad(12.0),0)))
 _test_look_mouse(false)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/placement_glow.png")
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 release.position=stage.get_global_transform_with_canvas()*end
 get_viewport().push_input(release,true)
 while busy:await get_tree().process_frame
 assert(table.cards.has(cell) and model.find_card(uid)<0 and model.conserved())
 assert(not table.hint.visible)
 _test_look_mouse(true,Vector2(20,20))
 _notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 _test_look_mouse(true)
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 get_viewport().push_input(escape,true)
 assert(not looking)
 var reset:=InputEventKey.new();reset.keycode=KEY_R;reset.pressed=true
 get_viewport().push_input(reset,true)
 assert(table.camera.rotation.is_equal_approx(original))
 table.preview(table.screen_position(Vector2i(3,1)),true)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/table_dark_glow.png")
 table.hide_preview()
 get_window().size=Vector2i(1280,720)
 await get_tree().create_timer(0.2).timeout
 assert(table.cell_at(table.screen_position(Vector2i(3,1)))==Vector2i(3,1))
 print("LYNCO_LOOK_TEST_PASS limits release focus_escape reset rotated_drag drag_exclusion ui_fixed resize glow")
 get_tree().quit()
func _build_card_inspector() -> void:
 inspector_layer=CanvasLayer.new();inspector_layer.layer=30;add_child(inspector_layer)
 inspector_root=Control.new();inspector_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 inspector_layer.add_child(inspector_root)
 var copy:=BackBufferCopy.new();copy.copy_mode=BackBufferCopy.COPY_MODE_VIEWPORT
 inspector_root.add_child(copy)
 var backdrop:=ColorRect.new()
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var blur:=ShaderMaterial.new();blur.shader=preload("res://asset/card_inspector_blur.gdshader")
 backdrop.material=blur;inspector_root.add_child(backdrop)
 inspector_card=_panel(inspector_root,Vector2.ZERO,Vector2(440,620),Color.WHITE,24)
 inspector_styles[false]=_style(Color("fefefb"),24,Color("c5c8c1"),1)
 inspector_styles[true]=_style(Color("181a19"),24,Color("454943"),1)
 preview_cost=_label(inspector_card,"",Vector2(24,24),Vector2(50,58),42)
 preview_title=_label(inspector_card,"",Vector2(87,30),Vector2(320,48),32)
 preview_kind=_label(inspector_card,"",Vector2(87,84),Vector2(322,28),18)
 preview_icon=_icon(inspector_card,"eye",Vector2(130,145),Vector2(180,180))
 preview_text=_label(inspector_card,"",Vector2(30,358),Vector2(380,152),23)
 preview_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 preview_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 preview_effect=_label(inspector_card,"",Vector2(24,529),Vector2(316,52),19)
 preview_effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 preview_effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 inspector_score=preload("res://scripts/table_cost_badge.gd").new()
 inspector_score.position=Vector2(363,527);inspector_score.size=Vector2(54,54)
 inspector_card.add_child(inspector_score)
 var hint:=_label(inspector_card,"우클릭 · Esc · 바깥 클릭으로 닫기",Vector2(20,587),Vector2(400,24),14)
 hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 hint.name="CloseHint"
 inspector_demo=_panel(inspector_root,Vector2.ZERO,Vector2(350,386),Color("202322"),18)
 _label(inspector_demo,"방향 시연",Vector2(24,20),Vector2(302,36),24,Color("f6f6f2"))
 inspector_diagram=DirectionDiagram.new()
 inspector_diagram.position=Vector2(35,70);inspector_diagram.size=Vector2(280,242)
 inspector_demo.add_child(inspector_diagram)
 direction_note=_label(inspector_demo,"",Vector2(22,326),Vector2(306,46),16,Color("c5c8c1"))
 direction_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 get_viewport().size_changed.connect(_fit_inspector)
 _fit_inspector();inspector_root.hide()

func _fit_inspector() -> void:
 if not is_instance_valid(inspector_card):return
 var viewport_size:Vector2=get_viewport_rect().size
 var ratio:float=minf(viewport_size.x/1600.0,viewport_size.y/900.0)
 inspector_card.scale=Vector2.ONE*ratio
 inspector_card.position=(viewport_size-inspector_card.size*ratio)*0.5
 inspector_demo.scale=Vector2.ONE*ratio
 inspector_demo.position=viewport_size*0.5+Vector2(260,-193)*ratio

func _show_inspector(data: Dictionary) -> void:
 _stop_look();_clear_hand_focus();press_uid=-1;table.hide_preview()
 var dark:bool=bool(data.dark)
 var ink:Color=Color("f6f6f2") if dark else INK
 var secondary:Color=Color("bfc2ba") if dark else MUTED
 inspector_card.add_theme_stylebox_override("panel",inspector_styles[dark])
 for label in [preview_title,preview_cost,preview_text]:label.add_theme_color_override("font_color",ink)
 for label in [preview_kind,preview_effect,inspector_card.get_node("CloseHint")]:label.add_theme_color_override("font_color",secondary)
 preview_icon.material=Symbols.material_for(data, light_ink if dark else dark_ink)
 inspector_diagram.configure(data,reduced_motion)
 direction_note.text="임시 방향 · 시각적 시연\n전투 효과는 적용하지 않습니다" if not Directions.for_definition(data).is_empty() else "이 카드의 방향은 미정입니다"
 inspector_score.dark=dark
 inspector_score.get_child(0).text=str(data.get("table_cost","—"))
 inspector_score.get_child(0).add_theme_color_override("font_color",ink)
 inspector_score.get_child(0).add_theme_font_size_override("font_size",23)
 inspector_score.queue_redraw()
 inspector_open=true;inspector_root.show()

func _close_inspector() -> void:
 if not inspector_open:return
 inspector_open=false;inspector_root.hide();press_uid=-1
 _clear_hand_focus()

func _hand_card_at(point: Vector2) -> int:
 var found:int=-1
 var top_z:int=-999
 for uid in views:
  var view:LyncoCardView=views[uid]
  if view.contains_hand_point(point) and view.z_index>=top_z:
   found=int(uid);top_z=view.z_index
 return found

func _test_inspect_card(uid: int) -> void:
 var view:LyncoCardView=views[uid]
 var point:Vector2=stage.get_global_transform_with_canvas()*(view.rest_position+Card.CARD_SIZE*0.5)
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;event.position=point
 get_viewport().push_input(event,true)
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=point
 get_viewport().push_input(event,true)

func _verify_inspector() -> void:
 await _restart(20260926)
 var output:String=ProjectSettings.globalize_path("res://test-results")
 var baseline_nodes:int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 var state:String=JSON.stringify([model.hand,model.energy,model.turn,model.discard])
 var original:Vector3=table.camera.rotation
 for dark in [false,true]:
  var uid:int=-1
  for entry in model.hand:
   if bool(Catalog.table_card(entry.id).dark)==dark:uid=int(entry.uid);break
  assert(uid>=0)
  _test_inspect_card(uid)
  assert(inspector_open and not looking and drag_uid<0)
  assert(inspector_card.get_global_rect().get_center().distance_to(get_viewport_rect().size*0.5)<1)
  var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true
  get_viewport().push_input(key,true)
  key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
  get_viewport().push_input(key,true)
  assert(state==JSON.stringify([model.hand,model.energy,model.turn,model.discard]))
  assert(table.camera.rotation.is_equal_approx(original))
  await get_tree().create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(output+("/inspector_black.png" if dark else "/inspector_white.png"))
  key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true
  get_viewport().push_input(key,true)
  assert(not inspector_open)
 for i in range(8):
  _test_inspect_card(int(model.hand[0].uid));assert(inspector_open)
  _test_pointer(Vector2(100,100),true);assert(not inspector_open)
 _test_inspect_card(int(model.hand[0].uid))
 get_window().size=Vector2i(1280,720)
 await get_tree().create_timer(0.2).timeout
 assert(inspector_card.get_global_rect().get_center().distance_to(get_viewport_rect().size*0.5)<1)
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(output+"/inspector_1280.png")
 _notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not inspector_open)
 await get_tree().process_frame
 assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==baseline_nodes)
 _test_look_mouse(true,Vector2(30,20));assert(looking)
 _test_look_mouse(false);assert(not looking)
 assert(state==JSON.stringify([model.hand,model.energy,model.turn,model.discard]))
 print("LYNCO_INSPECTOR_TEST_PASS right_click center dark_white modal_input close resize nodes_stable camera")
 get_tree().quit()
# Leave only between animations so no suspended combat continuation outlives its scene.
func _return_to_main() -> void:
 if leaving_battle or busy or inspector_open or looking or drag_uid >= 0 or press_uid >= 0 or help_panel.visible: return
 leaving_battle = true
 menu_button.disabled = true
 _close_inspector()
 _stop_look(false)
 _cancel_drag()
 var error: Error = get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
 if error != OK:
  leaving_battle = false
  _sync_ui()
  _toast("메인 화면을 열지 못했습니다")

func _hand_action_blocked() -> bool:
 return inspector_open or looking or busy or drag_uid>=0 or press_uid>=0 or model.finished or help_panel.visible or leaving_battle or seed_box.has_focus()

func _fill_requested() -> void:
 if _hand_action_blocked(): return
 busy=true;selected_uid=-1;_sync_ui()
 var result: Dictionary = model.fill_hand()
 if not result.drawn.is_empty(): await _animate_draw(result.drawn)
 busy=false;_sync_ui()
 _toast(str(result.reason) if not str(result.reason).is_empty() else "손패를 5장으로 보충했습니다")

func _shift_requested() -> void:
 if _hand_action_blocked() or model.hand.is_empty(): return
 busy=true;selected_uid=-1;inspect_uid=-1;_clear_hand_focus();table.hide_preview();_sync_ui()
 shuffle_phase="gather"
 _sync_identity_counter()
 # Input is locked for this entire animation; keep one stable view list.
 var shuffled_views: Array = views.values()
 var center := Vector2(800,450) - Card.CARD_SIZE * 0.5
 var last_flip: Tween
 var flip_index:=0
 for view in shuffled_views:
  view.stop_motion();view.locked=true;view.set_selected(false)
  var ink: ShaderMaterial=light_ink if bool(view.data.dark) else dark_ink
  if reduced_motion:
   view.conceal(textures["shift_reverse"],ink)
  else:
   var flip:=create_tween()
   flip.tween_interval(flip_index*0.018)
   flip.tween_property(view,"scale",Vector2(0.04,1.0),0.065).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
   flip.tween_callback(view.conceal.bind(textures["shift_reverse"],ink))
   flip.tween_property(view,"scale",Vector2.ONE,0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
   last_flip=flip
  flip_index+=1
 if last_flip:await last_flip.finished
 var gather := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 for view in shuffled_views:
  view.z_index=90
  gather.tween_property(view,"position",center,0.10 if reduced_motion else 0.16)
  gather.tween_property(view,"rotation",0.0,0.1)
  gather.tween_property(view,"scale",Vector2.ONE,0.1)
 await gather.finished
 if not reduced_motion:await get_tree().create_timer(0.035).timeout
 shuffle_phase="shuffle"
 for pass_index in range(2):
  var cut := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
  var index: int = 0
  for view in shuffled_views:
   var side: float = -1.0 if (index+pass_index)%2==0 else 1.0
   view.z_index=90+(index+pass_index)%shuffled_views.size()
   cut.tween_property(view,"position",center+Vector2(side*38,side*7),0.06 if reduced_motion else 0.12)
   index+=1
  await cut.finished
 # Hide tracking continuity before seeded reordering and distribution.
 for view in shuffled_views: view.position=center;view.rotation=0.0
 model.conceal_and_shuffle()
 _poses()
 shuffle_phase="deal"
 var deal := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 for i in range(model.hand.size()):
  var view: LyncoCardView = views[int(model.hand[i].uid)]
  view.z_index=90+i
  deal.tween_property(view,"position",view.rest_position,0.1 if reduced_motion else 0.20).set_delay(i*(0.012 if reduced_motion else 0.025))
  deal.tween_property(view,"rotation",view.rest_rotation,0.1 if reduced_motion else 0.20).set_delay(i*(0.012 if reduced_motion else 0.025))
  view.back_logo.pivot_offset=view.back_logo.size*0.5
  view.back_logo.scale=Vector2.ONE if reduced_motion else Vector2.ONE*0.88
  deal.tween_property(view.back_logo,"scale",Vector2.ONE,0.1 if reduced_motion else 0.18).set_trans(Tween.TRANS_BACK).set_delay(i*(0.012 if reduced_motion else 0.025))
 await deal.finished
 for view in shuffled_views: view.locked=false;view.z_index=0
 shuffle_phase="idle";busy=false;_sync_ui()
 _toast("가린 카드 선택 후 빈 칸 클릭 · 드래그 배치")


func _hide_hover_direction() -> void:
 if is_instance_valid(table):table.set_hover_card(Table.INVALID)
 direction_hover_uid=-1
 direction_hover_cell=Table.INVALID
 if is_instance_valid(hover_direction_timer):hover_direction_timer.stop()
 if hover_direction_tween and hover_direction_tween.is_valid():hover_direction_tween.kill()
 if is_instance_valid(hover_direction):hover_direction.hide()

func _schedule_hover_direction() -> void:
 if direction_hover_uid==hovered_uid:return
 _hide_hover_direction()
 if hovered_uid<0 or model.is_concealed(hovered_uid):return
 direction_hover_uid=hovered_uid
 hover_direction_timer.start()

func _show_hover_direction() -> void:
 if direction_hover_cell!=Table.INVALID:
  if busy or inspector_open or looking or model.finished or help_panel.visible or not table.cards.has(direction_hover_cell):
   _hide_hover_direction()
   return
  var holder:Node3D=table.cards[direction_hover_cell]
  var id:String=str(holder.get_meta("card_id"))
  var data:Dictionary=Catalog.back_card(id) if bool(holder.get_meta("reverse",false)) else Catalog.table_card(id)
  if Directions.for_definition(data).is_empty():
   _hide_hover_direction()
   return
  var top:Vector3=table.cell_position(direction_hover_cell)+Vector3(0,0.08,-Table.CARD_METRES.y*0.5)
  var anchor:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*table.camera.unproject_position(top)
  _reveal_direction_diagram(data,anchor)
  return
 var uid:int=direction_hover_uid
 if uid<0 or uid!=hovered_uid or not views.has(uid) or busy or inspector_open or looking or drag_uid>=0 or model.finished or help_panel.visible or model.is_concealed(uid):
  _hide_hover_direction()
  return
 var index:int=model.find_card(uid)
 if index<0:return
 var view:LyncoCardView=views[uid]
 _reveal_direction_diagram(Catalog.table_card(model.hand[index].id),view.position+Vector2(Card.CARD_SIZE.x*0.5,-16))

func _reveal_direction_diagram(data: Dictionary, anchor: Vector2) -> void:
 hover_direction.configure(data,reduced_motion)
 hover_direction.position=Vector2(clampf(anchor.x-hover_direction.size.x*0.5,8,1592-hover_direction.size.x),maxf(8,anchor.y-hover_direction.size.y-12))
 hover_direction.modulate.a=0.0
 hover_direction.show()
 hover_direction_tween=create_tween()
 hover_direction_tween.tween_property(hover_direction,"modulate:a",1.0,0.18)

func _hover_placed_direction(point: Vector2) -> void:
 var cell:Vector2i=table.cell_at(point)
 if busy or inspector_open or looking or model.finished or help_panel.visible or not table.cards.has(cell):
  if direction_hover_cell!=Table.INVALID:_hide_hover_direction()
  return
 if direction_hover_cell==cell:return
 _hide_hover_direction()
 direction_hover_cell=cell
 table.set_hover_card(cell)
 hover_direction_timer.start()


func _set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 preload("res://scripts/rolling_number_label.gd").reduced_motion=value
 turn_track.reduced_motion=value
 turn_track.queue_redraw()
 table.reduced_motion=value
 table.select_influence(Table.INVALID)
 for view in views.values():
  view.reduced_motion=value
  if not view.locked:view.update_pose()
 for label in get_tree().get_nodes_in_group("rolling_number_labels"):label.finish_rolls()
 if turn_motion and turn_motion.is_valid():turn_motion.kill()
 turn_caption.position=Vector2(28,14)
 hover_direction.set_reduced_motion(value)
 inspector_diagram.set_reduced_motion(value)
 table.direction_material.set_shader_parameter("reduced_motion",value)


func _toggle_inventory() -> void:
 if is_instance_valid(inventory_layer):
  inventory_layer.queue_free();inventory_layer=null
  return
 _stop_look();_cancel_drag();_hide_hover_direction();camera_keys.clear()
 _close_inspector();help_panel.hide()
 inventory_layer=CanvasLayer.new();inventory_layer.layer=50
 add_child(inventory_layer)
 var inventory:=preload("res://scripts/inventory_panel.gd").new()
 inventory.theme=theme
 inventory_layer.add_child(inventory)
