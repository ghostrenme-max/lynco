extends Control

var value: String = "—"
var dark: bool = false

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var label := preload("res://scripts/rolling_number_label.gd").new()
 label.text = value
 label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 label.add_theme_font_size_override("font_size", 15)
 label.add_theme_color_override("font_color", Color.WHITE if dark else Color("171a17"))
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(label)

func _draw() -> void:
 # Quadratic corner rounding on a regular hexagon, sampled once per redraw.
 var vertices: Array[Vector2] = []
 var points := PackedVector2Array()
 var center := size * 0.5
 var radius := minf(size.x,size.y) * 0.46
 for i in range(6): vertices.append(center + Vector2.from_angle(PI / 3.0 * i - PI / 2.0) * radius)
 for i in range(6):
  var corner: Vector2 = vertices[i]
  var a: Vector2 = corner.lerp(vertices[posmod(i-1,6)], 0.18)
  var b: Vector2 = corner.lerp(vertices[(i+1)%6], 0.18)
  for j in range(6):
   var t: float = float(j)/5.0
   points.append(a.lerp(corner,t).lerp(corner.lerp(b,t),t))
 draw_colored_polygon(points,Color("343735") if dark else Color("e5e7e0"))
 points.append(points[0])
 draw_polyline(points,Color("bfc4bc") if dark else Color("686d64"),1.0,true)
