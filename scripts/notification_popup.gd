extends Control
## Short battle notifications. Geometry stays a rounded parallelogram throughout motion.
const UI = preload("res://scripts/screen_style.gd")
var caption: Label
var motion: Tween
var extent := Vector2(10,28)
var expanded := Vector2(640,52)
var reduced_motion := false
var phase := "hidden"
var content: Control

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=90
 if size==Vector2.ZERO:size=Vector2(640,96)
 content=Control.new();content.size=size;content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(content)
 caption=Label.new();caption.position=Vector2(38,14);caption.size=size-Vector2(76,28)
 caption.theme=UI.make_theme();caption.add_theme_font_size_override("font_size",24)
 caption.add_theme_color_override("font_color",UI.INK)
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

func _draw() -> void:
 var points:=outline()
 draw_colored_polygon(points,Color.WHITE)
 points.append(points[0])
 draw_polyline(points,Color.WHITE,1.0,true)

func _shape(value: Vector2) -> void:
 extent=value
 queue_redraw()

func clear() -> void:
 if motion and motion.is_valid():motion.kill()
 phase="hidden";hide()

func present(message: String) -> void:
 if message.strip_edges().is_empty():return
 clear()
 caption.text=message
 # Keep a fixed center above the hand, with 8px vertical text padding.
 var font:=caption.get_theme_font("font")
 var lines:=font.get_multiline_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,size.x-76,24,-1,TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND).y
 expanded=Vector2(size.x,52 if lines<font.get_height(24)*1.5 else 78)
 caption.position=Vector2(38,(size.y-expanded.y)*0.5+8)
 caption.size=Vector2(size.x-76,expanded.y-16)
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
