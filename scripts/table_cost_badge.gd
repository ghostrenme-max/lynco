extends Control

var value: String = "—"
var dark := false
var pulse: Tween
var pulse_index := -1
var revealed_count := -1
var pulse_scale := 1.0:
 set(next):
  pulse_scale=next
  queue_redraw()

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE

func cube_count() -> int:
 return clampi(int(value),0,5) if value.is_valid_int() else 0

func stop_pulse() -> void:
 if pulse and pulse.is_valid():pulse.kill()
 pulse_index=-1
 revealed_count=-1
 pulse_scale=1.0

func replay_count(target: String, quick: bool = false) -> void:
 stop_pulse()
 value=target
 tooltip_text="투자 비용 미정" if not target.is_valid_int() or int(target)<0 else "투자 비용 · 큐브 %s개" % target
 queue_redraw()
 var count:=cube_count()
 revealed_count=0
 if count==0:return
 pulse=create_tween()
 pulse.tween_interval(0.05)
 for i in range(count):
  pulse.tween_callback(func():
   pulse_index=i
   revealed_count=i+1
   queue_redraw())
  pulse.tween_property(self,"pulse_scale",1.08 if quick else 2.0,0.05 if quick else 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  pulse.tween_property(self,"pulse_scale",1.0,0.05 if quick else 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
  pulse.tween_interval(0.05)
 pulse.tween_callback(func():pulse_index=-1)

func _draw() -> void:
 var count:=cube_count()
 var edge:=minf(size.y*0.48,size.x/8.4)
 var gap:=edge*1.6
 for i in range(count if revealed_count<0 else mini(count,revealed_count)):
  var center:=Vector2(size.x-edge-gap*(count-1-i),size.y*0.5)
  var radius:=edge*0.5*(pulse_scale if i==pulse_index else 1.0)
  var points:=PackedVector2Array()
  for j in range(6):points.append(center+Vector2.from_angle(PI/3*j-PI/2)*radius)
  var ink:=Color("dec5ff") if dark else Color("62349a")
  draw_colored_polygon(points,Color("a76de0") if dark else Color("b98ce5"))
  points.append(points[0])
  draw_polyline(points,ink,1.0,true)
  for j in [1,3,5]:draw_line(center,points[j],ink,1.0,true)
