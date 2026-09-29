extends Button
# Native buttons retain keyboard, focus and hit testing; ornament is presentation only.
var primary:=false
var emblem: String=""
const GOLD:=Color("c5a46b")
const PAPER:=Color("eddfbd")
const RED:=Color("812b24")
const INK:=Color("171410")
func configure(label_text: String, rect: Rect2, main_button: bool=false, emblem_kind: String="") -> void:
 text=label_text;position=rect.position;size=rect.size;primary=main_button;emblem=emblem_kind
 var lettering:=SystemFont.new();lettering.font_names=PackedStringArray(["Batang","Georgia","Malgun Gothic"])
 add_theme_font_override("font",lettering)
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:add_theme_color_override(state,Color.TRANSPARENT)
 mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
 focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
 button_down.connect(queue_redraw);button_up.connect(queue_redraw)
func frame(rect: Rect2, fill: Color, border: Color, width: int=1, radius: int=7) -> void:
 var box:=StyleBoxFlat.new();box.bg_color=fill;box.border_color=border
 box.set_border_width_all(width);box.set_corner_radius_all(radius)
 draw_style_box(box,rect)
func star(center: Vector2, radius: float, color: Color) -> void:
 var points:=PackedVector2Array()
 for i in range(8):
  var a: float=-PI/2+i*PI/4
  points.append(center+Vector2(cos(a),sin(a))*(radius if i%2==0 else radius*0.25))
 draw_colored_polygon(points,color)
func diamond(center: Vector2, extent: Vector2, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array([center+Vector2(0,-extent.y),center+Vector2(extent.x,0),center+Vector2(0,extent.y),center-Vector2(extent.x,0)]),color)
func _draw() -> void:
 var compact: bool=size.x<150
 var active: bool=is_hovered() or has_focus()
 var offset:=Vector2(0,2 if is_pressed() else (-2 if is_hovered() else 0))
 var rect:=Rect2(offset,size)
 var trim: Color=PAPER if active else GOLD
 if not compact:
  # Two slightly fanned card backs peek out around the face.
  for side in [-1,1]:
   draw_set_transform(Vector2(size.x*.5,size.y*.5+5),deg_to_rad(side*2.0))
   frame(Rect2(Vector2(-size.x*.5+side*10,-size.y*.5),size),RED.darkened(.25),GOLD.darkened(.3),2)
   frame(Rect2(Vector2(-size.x*.5+side*10+5,-size.y*.5+5),size-Vector2(10,10)),Color.TRANSPARENT,RED.lightened(.14))
  draw_set_transform(Vector2.ZERO)
 frame(rect,Color("f3e5c5") if primary and active else (PAPER if primary else INK.lightened(.05) if active else INK),trim,2,8)
 frame(rect.grow(-5),Color.TRANSPARENT,GOLD.darkened(.13),1,5)
 frame(rect.grow(-9),Color.TRANSPARENT,Color("c1a776") if primary else GOLD.darkened(.4),1,3)
 if primary:
  for side in [-1,1]:
   var x: float=27.0 if side==-1 else size.x-27.0
   for row in range(3):
    for col in range(2):
     diamond(Vector2(x+(col-.5)*17,16+row*(size.y-32)/2)+offset,Vector2(8,15),RED if (row+col)%2==0 else INK)
  star(Vector2(85,size.y*.5)+offset,12,RED)
  star(Vector2(size.x-85,size.y*.5)+offset,12,RED)
  if not compact:diamond(Vector2(size.x*.5,size.y+10)+offset,Vector2(7,12),GOLD)
 else:
  for x in [17.0,size.x-17]:star(Vector2(x,size.y*.5)+offset,6,GOLD)
  if not compact:
   for x in [13.0,size.x-13]:
    for y in [13.0,size.y-13]:star(Vector2(x,y)+offset,4,GOLD)
 if emblem!="" and not compact:
  var center:=Vector2(60,size.y*.5)+offset
  if emblem=="book":
   for i in range(2):
    frame(Rect2(center+Vector2(-14+i*7,-16-i*3),Vector2(24,33)),INK,GOLD,1,3)
   star(center+Vector2(5,-1),6,GOLD)
  else:
   for i in range(3):
    var y: float=center.y+9-i*7
    var points:=PackedVector2Array([Vector2(center.x-19,y-7),Vector2(center.x,y-15),Vector2(center.x+19,y-7),Vector2(center.x,y+1),Vector2(center.x-19,y-7)])
    draw_polyline(points,GOLD,1.8,true)
 var font: Font=get_theme_font("font")
 var font_size: int=35 if primary else (21 if compact else 25)
 var ink: Color=RED.darkened(.17) if primary else PAPER
 var text_size:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
 var center_x: float=size.x*.5+(16 if emblem!="" else 0)
 draw_string(font,Vector2(center_x-text_size.x*.5,(size.y-text_size.y)*.5+font.get_ascent(font_size))+offset,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
 if has_focus():
  for x in [size.x*.5-18,size.x*.5+18]:diamond(Vector2(x,size.y-5)+offset,Vector2(2,2),RED if primary else PAPER)