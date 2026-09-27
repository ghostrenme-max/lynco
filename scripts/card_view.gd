class_name LyncoCardView
extends Control

const Symbols = preload("res://scripts/card_symbols.gd")

signal chosen(uid: int)
signal activated(uid: int)
signal focus_changed(uid: int, inside: bool)

const CARD_SIZE := Vector2(158, 228)
const BACK_MATERIAL = preload("res://asset/card_back.tres")
const BLACK_BACK_MATERIAL = preload("res://asset/card_back_black.tres")
const HOVER_SCALE: float = 1.10
const PEER_SCALE: float = 1.0 / 1.5
var uid: int = -1
var data: Dictionary = {}
var rest_position := Vector2.ZERO
var drag_retracted := false
var rest_rotation: float = 0.0
var selected: bool = false
var hover: bool = false
var diminished: bool = false
var locked: bool = false
var available: bool = true
var movement: Tween
var background: Panel
var title_label: Label
var reason_label: Label
var outline_style: StyleBoxFlat
var face_up: bool = true
var concealed: bool = false
var reduced_motion := false
var focus_offset := 0.0
var face_nodes: Array[CanvasItem] = []
var back_logo: TextureRect

func setup(entry: Dictionary, definition: Dictionary, icon: Texture2D, material_override: ShaderMaterial, back_texture: Texture2D) -> void:
 uid = int(entry.uid)
 data = definition
 size = CARD_SIZE
 pivot_offset = CARD_SIZE * 0.5
 mouse_filter = Control.MOUSE_FILTER_STOP
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 var dark: bool = bool(data.dark)
 var ink := Color.WHITE if dark else Color("171817")
 outline_style = StyleBoxFlat.new()
 outline_style.bg_color = Color("181a19") if dark else Color("fefefb")
 outline_style.border_color = Color("383b37") if dark else Color("c5c8c1")
 outline_style.set_border_width_all(1)
 outline_style.set_corner_radius_all(13)
 outline_style.corner_detail = 10
 outline_style.shadow_color = Color(0.04, 0.05, 0.03, 0.12)
 outline_style.shadow_size = 5
 outline_style.shadow_offset = Vector2(0, 3)
 background = Panel.new()
 background.size = CARD_SIZE
 background.mouse_filter = Control.MOUSE_FILTER_IGNORE
 background.add_theme_stylebox_override("panel", outline_style)
 add_child(background)
 var cost := _label(str(data.get("cost_label", data.cost)), Vector2(12, 10), Vector2(28, 30), 23, ink)
 cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title_label = _label(str(data.name), Vector2(44, 13), Vector2(106, 24), 17, ink)
 _label(str(data.kind), Vector2(45, 38), Vector2(102, 18), 11, Color("bcbfb4") if dark else Color("777b72"))
 var picture := TextureRect.new()
 picture.position = Vector2(38, 62)
 picture.size = Vector2(82, 82)
 picture.texture = Symbols.texture_for(data, icon)
 picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
 picture.material = Symbols.material_for(data, material_override)
 add_child(picture)
 var separator := ColorRect.new()
 separator.position = Vector2(16, 153); separator.size = Vector2(126, 1)
 separator.color = Color("454941") if dark else Color("e2e4dc")
 separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(separator)
 var body := _label(str(data.text), Vector2(9, 162), Vector2(140, 30), 15, ink)
 body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 var badge := preload("res://scripts/table_cost_badge.gd").new()
 badge.position = Vector2(117,190); badge.size = Vector2(34,34)
 badge.value = str(data.get("table_cost","—")); badge.dark = dark
 add_child(badge)
 reason_label = _label("", Vector2(6,201), Vector2(110,22), 10, Color("b87230"))
 reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 for child in get_children():
  if child != background and child is CanvasItem: face_nodes.append(child)
 back_logo = TextureRect.new()
 back_logo.size = CARD_SIZE
 back_logo.position = (CARD_SIZE - back_logo.size) * 0.5
 back_logo.texture = back_texture
 back_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 back_logo.stretch_mode = TextureRect.STRETCH_SCALE
 back_logo.material = BLACK_BACK_MATERIAL if dark else BACK_MATERIAL
 back_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(back_logo)
 back_logo.hide()
 mouse_entered.connect(_entered)
 mouse_exited.connect(_exited)
 gui_input.connect(_input_card)

func set_face_up(value: bool) -> void:
 if face_up == value: return
 face_up = value
 for item in face_nodes: item.visible = value
 back_logo.visible = not value

func _label(text: String, pos: Vector2, box: Vector2, font_size: int, color: Color) -> Label:
 var label := preload("res://scripts/rolling_number_label.gd").new()
 label.text = text; label.position = pos; label.size = box
 label.add_theme_font_size_override("font_size", font_size)
 label.add_theme_color_override("font_color", color)
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(label)
 return label

func _input_card(event: InputEvent) -> void:
 if locked: return
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
  accept_event()
  if event.double_click:
   activated.emit(uid)
  else:
   chosen.emit(uid)

func _entered() -> void:
 if locked: return
 focus_changed.emit(uid, true)

func _exited() -> void:
 focus_changed.emit(uid, false)

func _has_point(point: Vector2) -> bool:
 if locked or drag_retracted: return false
 # Keep each card's neutral slot clickable when its visual shrinks. The hit
 # region must not shrink away from the pointer and repeatedly toggle hover.
 var in_slot: bool = Rect2(rest_position, CARD_SIZE).has_point(get_transform() * point)
 return in_slot or (hover and Rect2(Vector2.ZERO, CARD_SIZE).has_point(point))

func contains_hand_point(point: Vector2) -> bool:
 if locked or drag_retracted: return false
 if Rect2(rest_position, CARD_SIZE).has_point(point): return true
 return hover and Rect2(Vector2.ZERO, CARD_SIZE).has_point(get_transform().affine_inverse() * point)

func set_hand_focus(focused_uid: int, animate: bool = true) -> void:
 var next_hover: bool = focused_uid == uid
 var next_diminished: bool = focused_uid >= 0 and not next_hover
 if next_hover == hover and next_diminished == diminished: return
 hover = next_hover
 diminished = next_diminished
 if animate and not locked: update_pose()

func set_selected(value: bool) -> void:
 if selected == value: return
 selected = value
 outline_style.border_color = Color("d9b91b") if selected else (Color("383b37") if bool(data.dark) else Color("c5c8c1"))
 outline_style.set_border_width_all(2 if selected else 1)
 if not locked: update_pose()

func set_available(value: bool, reason: String) -> void:
 var next_reason: String = "" if value else reason
 if available == value and reason_label.text == next_reason: return
 available = value
 reason_label.text = next_reason
 mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_FORBIDDEN

func update_pose(duration: float = 0.13) -> void:
 if movement and movement.is_valid(): movement.kill()
 var target_scale: float = HOVER_SCALE if hover else (PEER_SCALE if diminished else 1.0)
 var lift: float = -32.0 if hover else (CARD_SIZE.y * (1.0 - PEER_SCALE) * 0.5 if diminished else (-16.0 if selected else 0.0))
 if drag_retracted:
  target_scale=1.0
  lift=200.0
 z_index = 80 if hover else (40 if selected and not diminished else 0)
 movement = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 var settle_time: float=0.07 if reduced_motion else maxf(duration,0.18)
 var delay: float=0.025 if diminished and not reduced_motion else 0.0
 movement.tween_property(self, "position", rest_position + Vector2(focus_offset if diminished and not reduced_motion else 0.0, lift), settle_time).set_delay(delay)
 movement.tween_property(self, "rotation", 0.0 if hover or (selected and not diminished) else rest_rotation, settle_time).set_delay(delay)
 var pop=movement.tween_property(self, "scale", Vector2.ONE * target_scale, settle_time).set_delay(delay)
 if not reduced_motion and (hover or selected):pop.set_trans(Tween.TRANS_BACK)

func stop_motion() -> void:
 if movement and movement.is_valid(): movement.kill()


func conceal(common_texture: Texture2D, ink_material: ShaderMaterial) -> void:
 concealed = true
 # Keep card colour visible while concealing its name, cost and reverse identity.
 back_logo.texture = common_texture
 back_logo.material = ink_material
 back_logo.size = Vector2(123,123)
 back_logo.position = (CARD_SIZE-back_logo.size)*0.5
 back_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 outline_style.bg_color = Color("181a19") if bool(data.dark) else Color("fefefb")
 outline_style.border_color = Color("383b37") if bool(data.dark) else Color("c5c8c1")
 outline_style.set_border_width_all(1)
 set_face_up(false)
 set_available(true, "")
