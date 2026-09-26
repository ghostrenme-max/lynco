extends RefCounted

const INK := Color("171a17")
const MUTED := Color("606460")
const PAPER := Color("f7f7f2")
const YELLOW := Color("f5d335")

static func make_theme() -> Theme:
 var font := SystemFont.new()
 font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
 font.allow_system_fallback = true
 var result := Theme.new()
 result.default_font = font
 result.default_font_size = 20
 return result

static func style(color: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 13) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color = color
 result.border_color = border
 result.set_border_width_all(width)
 result.set_corner_radius_all(radius)
 result.corner_detail = 10
 return result

static func panel(parent: Node, rect: Rect2, color: Color) -> Panel:
 var node := Panel.new()
 node.position = rect.position
 node.size = rect.size
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 node.add_theme_stylebox_override("panel", style(color))
 parent.add_child(node)
 return node

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 20, color: Color = INK) -> Label:
 var node := Label.new()
 node.text = text
 node.position = rect.position
 node.size = rect.size
 node.add_theme_font_size_override("font_size", font_size)
 node.add_theme_color_override("font_color", color)
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(node)
 return node

static func button(parent: Node, text: String, rect: Rect2, primary: bool = false) -> Button:
 var node := Button.new()
 node.text = text
 node.position = rect.position
 node.size = rect.size
 node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 node.add_theme_font_size_override("font_size", 22)
 node.add_theme_color_override("font_color", Color.WHITE if primary else INK)
 node.add_theme_color_override("font_hover_color", INK)
 node.add_theme_color_override("font_pressed_color", INK)
 node.add_theme_color_override("font_focus_color", Color.WHITE if primary else INK)
 node.add_theme_stylebox_override("normal", style(INK if primary else Color.WHITE, Color("d5d7d0"), 0 if primary else 1))
 node.add_theme_stylebox_override("hover", style(YELLOW))
 node.add_theme_stylebox_override("pressed", style(Color("e1bd24")))
 node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, YELLOW, 3))
 parent.add_child(node)
 return node

static func ink_material(white: bool = false) -> ShaderMaterial:
 var shader := Shader.new()
 shader.code = "shader_type canvas_item; uniform vec4 ink : source_color; void fragment(){COLOR = vec4(ink.rgb, texture(TEXTURE, UV).a * ink.a);}"
 var material := ShaderMaterial.new()
 material.shader = shader
 material.set_shader_parameter("ink", Color.WHITE if white else INK)
 return material
