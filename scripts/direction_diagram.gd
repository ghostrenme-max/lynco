extends Control

const Directions = preload("res://scripts/direction_preview.gd")
const Symbols = preload("res://scripts/card_symbols.gd")
const UI = preload("res://scripts/screen_style.gd")
var directions: Array = []
var phase: float = 0.0
var reduced_motion: bool = false
var miniature_style: StyleBoxFlat
var panel_style: StyleBoxFlat
var symbol: TextureRect
var dark_ink: ShaderMaterial
var light_ink: ShaderMaterial

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel_style = UI.style(Color("202322"), Color("515651"), 1, 12)
 miniature_style = UI.style(Color("f6f6f2"), Color("969b94"), 1, 5)
 dark_ink = UI.ink_material()
 light_ink = UI.ink_material(true)
 symbol = TextureRect.new()
 symbol.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 symbol.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(symbol)
 resized.connect(_layout)
 visibility_changed.connect(_visibility_changed)
 _layout()
 _visibility_changed()

func configure(data: Dictionary, simple_motion: bool = false) -> void:
 directions = Directions.for_definition(data)
 reduced_motion = simple_motion
 phase = 0.0
 var dark: bool = bool(data.get("dark", false))
 miniature_style.bg_color = Color("181a19") if dark else Color("f6f6f2")
 symbol.texture = Symbols.texture_for(data)
 symbol.material = Symbols.material_for(data, light_ink if dark else dark_ink)
 _visibility_changed()
 queue_redraw()

func _layout() -> void:
 if not is_instance_valid(symbol): return
 symbol.size = Vector2(24, 24)
 symbol.position = size * 0.5 - symbol.size * 0.5
 queue_redraw()

func _visibility_changed() -> void:
 set_process(is_visible_in_tree() and not reduced_motion and not directions.is_empty())

func _process(delta: float) -> void:
 phase = fmod(phase + delta * 0.7, 1.0)
 queue_redraw()

func _draw() -> void:
 if panel_style == null: return
 draw_style_box(panel_style, Rect2(Vector2.ZERO, size))
 var center: Vector2 = size * 0.5
 var reach: float = minf(size.x, size.y) * 0.39
 for key in Directions.OFFSETS:
  var direction: Vector2 = Directions.OFFSETS[key]
  draw_line(center, center + direction * reach, Color("535851"), 1.0, true)
 for key in directions:
  var direction: Vector2 = Directions.OFFSETS[key]
  var start: float = 34.0 if direction.y != 0 else 26.0
  for i in range(2):
   var progress: float = fmod(phase + i * 0.5, 1.0)
   var point: Vector2 = center + direction * lerpf(start, reach, progress)
   var side := Vector2(-direction.y, direction.x)
   var color: Color = Directions.MAGENTA
   color.a = 1.0 if reduced_motion else sin(progress * PI) * 0.75 + 0.25
   draw_polyline(PackedVector2Array([point-direction*6+side*5, point, point-direction*6-side*5]), color, 2.6, true)
 draw_style_box(miniature_style, Rect2(center-Vector2(20,28), Vector2(40,56)))


func set_reduced_motion(value: bool) -> void:
 reduced_motion=value
 _visibility_changed()
 queue_redraw()
