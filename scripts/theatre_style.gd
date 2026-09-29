extends RefCounted
# Screen-only art system. Battle UI and card rendering keep their own styles.
const Base = preload("res://scripts/screen_style.gd")
const INK := Color("17130f")
const PAPER := Color("eddfbd")
const MUTED := Color("756446")
const YELLOW := Color("dfb864")
const RED := Color("882d22")
const SOFT := Color("beae8c")

static func make_theme() -> Theme:
 return Base.make_theme()

static func style(color: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 3) -> StyleBoxFlat:
 return Base.style(color,border,width,radius)

static func panel(parent: Node, rect: Rect2, color: Color) -> Panel:
 var node := Base.panel(parent,rect,color)
 node.add_theme_stylebox_override("panel",style(color,YELLOW.darkened(0.35),1))
 return node

static func label(parent: Node, text: String, rect: Rect2, font_size: int = 20, color: Color = INK) -> Label:
 return Base.label(parent,text,rect,font_size,color)

static func button(parent: Node, text: String, rect: Rect2, primary: bool = false) -> Button:
 var node := Base.button(parent,text,rect,primary)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
  node.add_theme_color_override(state,YELLOW if primary else PAPER)
 node.add_theme_color_override("font_disabled_color",SOFT.darkened(0.15))
 node.add_theme_stylebox_override("normal",style(RED.darkened(0.35) if primary else Color("1b1712"),YELLOW.darkened(0.3),1))
 node.add_theme_stylebox_override("hover",style(RED,YELLOW,2))
 node.add_theme_stylebox_override("pressed",style(RED.darkened(0.3),PAPER,2))
 node.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,YELLOW,2))
 node.add_theme_stylebox_override("disabled",style(Color("28251f"),Color("5a5142"),1))
 return node

static func ink_material(white: bool = false) -> ShaderMaterial:
 var result := Base.ink_material(white)
 result.set_shader_parameter("ink",PAPER if white else INK)
 return result

static func background(parent: Control, _main: bool = false) -> void:
 var fill := ColorRect.new()
 fill.color=INK
 fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fill.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(fill)

static func art(parent: Control, main: bool = false) -> void:
 var picture := TextureRect.new()
 picture.texture=load("res://assets/theatre/main_stage.png" if main else "res://assets/theatre/browse_stage.png")
 picture.size=Vector2(1600,900)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_SCALE
 picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(picture)

static func rule(parent: Node, rect: Rect2) -> void:
 var line := ColorRect.new()
 line.position=rect.position;line.size=rect.size;line.color=YELLOW.darkened(0.35)
 line.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(line)

static func title(parent: Node, text: String, rect: Rect2, font_size: int) -> Label:
 var node := label(parent,text,rect,font_size,PAPER)
 var font := SystemFont.new()
 font.font_names=PackedStringArray(["Georgia","Batang","Malgun Gothic"])
 node.add_theme_font_override("font",font)
 return node

static func symbol(parent: Node, texture: Texture2D, rect: Rect2, light: bool = false) -> TextureRect:
 var node := TextureRect.new()
 node.position=rect.position;node.size=rect.size
 node.texture=texture;node.material=ink_material(light)
 node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(node)
 return node