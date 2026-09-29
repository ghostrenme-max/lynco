extends Control
## Short battle notifications. Geometry stays a rounded parallelogram throughout motion.
const UI = preload("res://scripts/screen_style.gd")
const PANEL_INK:=Color("131614")
const LETTERING:=Color("eddfbd")
const GOLD:=Color("c4a369")
const PATTERN_RED:=Color("aa3440")
const TEXT_INSET: float=80.0
var caption: Label
var motion: Tween
var extent := Vector2(10,28)
var expanded := Vector2(720,52)
var reduced_motion := false
var phase := "hidden"
var content: Control
var stack_motion: Tween
var retired := false

func retire() -> void:
 if retired:return
 retired=true
 if motion and motion.is_valid():motion.kill()
 _shape(expanded)
 content.modulate.a=1.0
 modulate.a=minf(modulate.a,0.5)
 phase="retiring"
 motion=create_tween()
 motion.tween_property(self,"modulate:a",0.0,1.8).set_trans(Tween.TRANS_LINEAR)
 motion.tween_callback(func():hide();phase="hidden")

func move_in_stack(target: Vector2) -> void:
 if stack_motion and stack_motion.is_valid():stack_motion.kill()
 stack_motion=create_tween()
 stack_motion.tween_property(self,"position",target,0.10 if reduced_motion else 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=90
 if size==Vector2.ZERO:size=Vector2(720,96)
 content=Control.new();content.size=size;content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(content)
 caption=Label.new();caption.position=Vector2(TEXT_INSET,14);caption.size=size-Vector2(TEXT_INSET*2,28)
 caption.theme=UI.make_theme();caption.add_theme_font_size_override("font_size",24)
 caption.add_theme_color_override("font_color",LETTERING)
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 caption.max_lines_visible=2
 caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 content.add_child(caption)
 hide()

func outline() -> PackedVector2Array:
 var w:=maxf(extent.x,6.0)
 var h:=maxf(extent.y,6.0)
 var skew:=minf(h*0.12,w*0.12)
 var origin:=(size-Vector2(w,h))*0.5
 var vertices: Array[Vector2]=[origin+Vector2(skew,0),origin+Vector2(w,0),origin+Vector2(w-skew,h),origin+Vector2(0,h)]
 var points:=PackedVector2Array()
 for i in range(4):
  var corner:=vertices[i]
  var before:=vertices[(i+3)%4]
  var after:=vertices[(i+1)%4]
  var radius:=minf(12.0,minf(corner.distance_to(before),corner.distance_to(after))*0.28)
  var start:=corner.move_toward(before,radius)
  var finish:=corner.move_toward(after,radius)
  for step in range(9):
   var t:=step/8.0
   points.append(start.lerp(corner,t).lerp(corner.lerp(finish,t),t))
 return points

func _pattern_opacity(inward: float) -> float:
 return 1.0-smoothstep(22.0,67.0,inward)

func _diamond(center: Vector2, half: Vector2, left_edge: float, right_edge: float, opacity: float) -> void:
 var points:=PackedVector2Array([center+Vector2(0,-half.y),center+Vector2(half.x,0),center+Vector2(0,half.y),center-Vector2(half.x,0)])
 var colors:=PackedColorArray()
 for point in points:
  var ink:=PATTERN_RED
  ink.a=opacity*_pattern_opacity(minf(point.x-left_edge,right_edge-point.x))
  colors.append(ink)
 draw_polygon(points,colors)

func _draw() -> void:
 var points:=outline()
 draw_colored_polygon(points,PANEL_INK)
 var w: float=maxf(extent.x,6.0)
 var h: float=maxf(extent.y,6.0)
 var center: Vector2=size*0.5
 var left: float=center.x-w*0.5
 var right: float=center.x+w*0.5
 # Ornament emerges only when there is room; never distorts or leaves the silhouette.
 var ornament_alpha: float=smoothstep(24.0,45.0,h)*smoothstep(200.0,400.0,w)
 if ornament_alpha>0.0:
  var row_pitch: float=minf(19.0,(h-18.0)/3.0)
  var half:=Vector2(4.0,minf(7.5,row_pitch*0.42))
  for row in range(3):
   for col in range(5):
    var inset: float=18.0+col*10.0
    var y: float=center.y+(row-1)*row_pitch
    _diamond(Vector2(left+inset,y),half,left,right,ornament_alpha)
    _diamond(Vector2(right-inset,y),half,left,right,ornament_alpha)
  for x in [left+70.0,right-70.0]:
   var c:=Vector2(x,center.y)
   draw_colored_polygon(PackedVector2Array([c+Vector2(0,-3),c+Vector2(3,0),c+Vector2(0,3),c-Vector2(3,0)]),Color(GOLD,ornament_alpha))
 points.append(points[0])
 draw_polyline(points,GOLD,1.2,true)
 if w>18.0 and h>14.0:
  var inner:=PackedVector2Array()
  for point in points:
   inner.append(center+(point-center)*Vector2((w-6.0)/w,(h-6.0)/h))
  draw_polyline(inner,Color("756343"),0.8,true)

func _shape(value: Vector2) -> void:
 extent=value
 queue_redraw()

func clear() -> void:
 if motion and motion.is_valid():motion.kill()
 if stack_motion and stack_motion.is_valid():stack_motion.kill()
 retired=false
 phase="hidden";hide()

func present(message: String) -> void:
 if message.strip_edges().is_empty():return
 clear()
 caption.text=message
 # Keep a fixed center above the hand, with 8px vertical text padding.
 var font:=caption.get_theme_font("font")
 var lines:=font.get_multiline_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,size.x-TEXT_INSET*2,24,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND).y
 expanded=Vector2(size.x,52 if lines<font.get_height(24)*1.5 else 78)
 caption.position=Vector2(TEXT_INSET,(size.y-expanded.y)*0.5+8)
 caption.size=Vector2(size.x-TEXT_INSET*2,expanded.y-16)
 caption.show()
 content.modulate.a=0.0
 modulate.a=1.0
 show();phase="opening"
 _shape(Vector2(10,28))
 motion=create_tween()
 if reduced_motion:
  _shape(expanded)
  motion.tween_property(content,"modulate:a",1.0,0.10)
 else:
  motion.tween_method(_shape,extent,Vector2(size.x,8),0.19).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
  motion.tween_method(_shape,Vector2(size.x,8),expanded,0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  motion.parallel().tween_property(content,"modulate:a",1.0,0.14).set_delay(0.12)
 motion.tween_callback(func():phase="holding")
 motion.tween_interval(clampf(1.6+message.length()*0.035,2.0,4.8))
 _append_close()

func _append_close() -> void:
 motion.tween_callback(func():phase="closing")
 motion.tween_property(content,"modulate:a",0.0,0.10)
 if not reduced_motion:
  motion.parallel().tween_method(_shape,expanded,Vector2(size.x,6),0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
  motion.tween_method(_shape,Vector2(size.x,6),Vector2(8,12),0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
 motion.tween_property(self,"modulate:a",0.0,0.08)
 motion.tween_callback(func():hide();phase="hidden")
