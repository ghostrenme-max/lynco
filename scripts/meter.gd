extends Control

var max_value: float = 100.0
var value: float = 100.0:
 set(new_value):
  if is_equal_approx(value,new_value):return
  value=new_value
  queue_redraw()
var fill_color: Color=Color.WHITE
var background_style: StyleBoxFlat
var fill_style: StyleBoxFlat

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 background_style=StyleBoxFlat.new()
 background_style.bg_color=Color("e3e5e3")
 background_style.set_corner_radius_all(2)
 fill_style=StyleBoxFlat.new()
 fill_style.bg_color=fill_color
 fill_style.set_corner_radius_all(2)
 resized.connect(queue_redraw)

func _draw() -> void:
 if not background_style:return
 draw_style_box(background_style,Rect2(Vector2.ZERO,size))
 var fraction:float=clampf(value/maxf(max_value,1.0),0.0,1.0)
 if fraction>0:draw_style_box(fill_style,Rect2(Vector2.ZERO,Vector2(size.x*fraction,size.y)))
