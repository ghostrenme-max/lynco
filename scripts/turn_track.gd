extends Control
var occupied: int = 0
var capacity: int = 30
func set_progress(value: int, maximum: int) -> void:
 occupied=value;capacity=maximum;queue_redraw()
func _draw() -> void:
 var start:=Vector2(14,size.y*0.5)
 var finish:=Vector2(size.x-14,start.y)
 draw_line(start,finish,Color("535651"),3,true)
 var ratio: float=float(occupied)/maxf(float(capacity),1.0)
 draw_line(start,start.lerp(finish,ratio),Color("d0d1c5"),3,true)
 for i in range(capacity+1):
  var p: Vector2=start.lerp(finish,float(i)/float(capacity))
  var radius: float=6.0 if i%3==0 else 3.8
  draw_circle(p,radius,Color("d0d1c5") if i<=occupied else Color("535651"),true,-1,true)
 var current: Vector2=start.lerp(finish,ratio)
 draw_arc(current,12,0,TAU,48,Color("e8e8de"),2,true)
 draw_arc(current,17,0,TAU,48,Color(0.8,0.82,0.78,0.22),3,true)
