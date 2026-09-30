extends Control

var occupied: int = 0
var capacity: int = 8
var reduced_motion := false
var impact := 0.0

func _process(delta: float) -> void:
 if impact > 0.0:
  impact = maxf(0.0, impact - delta * 3.5)
  queue_redraw()

func set_progress(value: int, maximum: int) -> void:
 var next_value := clampi(value, 0, maximum)
 if occupied == next_value and capacity == maximum:return
 occupied = next_value
 capacity = maxi(1, maximum)
 impact = 0.0 if reduced_motion else 1.0
 queue_redraw()

func diamond(center: Vector2, radius: float, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array([center + Vector2(0,-radius),center + Vector2(radius,0),center + Vector2(0,radius),center + Vector2(-radius,0)]),color)

func _draw() -> void:
 var box := StyleBoxFlat.new()
 box.bg_color = Color("321923")
 box.border_color = Color("a38450")
 box.set_border_width_all(1)
 box.set_corner_radius_all(5)
 draw_style_box(box,Rect2(Vector2.ZERO,size))
 for y in range(5,int(size.y)-5,3):
  draw_line(Vector2(7,y),Vector2(size.x-7,y),Color(0.9,0.64,0.49,0.035),1)
 for x in range(18,int(size.x)-18,28):
  diamond(Vector2(x,size.y*0.5),16,Color(0.7,0.35,0.4,0.045))
 draw_line(Vector2(9,4),Vector2(size.x-9,4),Color(0.86,0.69,0.43,0.3),1,true)
 draw_line(Vector2(9,size.y-4),Vector2(size.x-9,size.y-4),Color(0.86,0.69,0.43,0.16),1,true)
 for x in [7.0,size.x-7.0]:
  diamond(Vector2(x,size.y*0.5),3,Color("b69559"))
 var start := Vector2(30,size.y*0.5)
 var finish := Vector2(size.x-30,start.y)
 draw_line(start,finish,Color("8f795c"),1.5,true)
 var current := start.lerp(finish,float(mini(occupied,capacity-1))/maxf(1.0,float(capacity-1)))
 draw_line(start,current,Color("f5e7c8"),2,true)
 # Size distinguishes the current position only; milestone rules remain undecided.
 for i in range(capacity):
  var point := start.lerp(finish,float(i)/maxf(1.0,float(capacity-1)))
  if i <= occupied:
   diamond(point,12.0 if i == occupied else 6.0,Color("b69559"))
   diamond(point,9.0 if i == occupied else 4.0,Color("f5e7c8"))
 if impact > 0.0 and not reduced_motion:
  diamond(current,12.0+10.0*(1.0-impact),Color(1.0,0.58,0.18,impact*0.35))
