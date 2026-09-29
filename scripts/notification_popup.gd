extends Control
## Three reusable bars; newest stays at the original anchor and older bars rise.
const Bar = preload("res://scripts/notification_bar.gd")
const MAX_VISIBLE := 3
var reduced_motion := false
var pool: Array[Control] = []
var active: Array[Control] = []
var latest: Control
var caption: Label:
 get:return latest.caption
var content: Control:
 get:return latest.content
var extent: Vector2:
 get:return latest.extent
var expanded: Vector2:
 get:return latest.expanded
var phase: String:
 get:return latest.phase

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=90
 if size==Vector2.ZERO:size=Vector2(720,96)
 latest=_create_bar()
 hide()

func _create_bar() -> Control:
 var bar=Bar.new()
 bar.size=size
 add_child(bar)
 bar.z_index=0
 pool.append(bar)
 return bar

func outline() -> PackedVector2Array:
 return latest.outline()

func clear() -> void:
 for bar in pool:bar.clear()
 active.clear()
 hide()

func present(message: String) -> void:
 if message.strip_edges().is_empty():return
 active=active.filter(func(bar):return bar.visible)
 for bar in active:bar.retire()
 var next: Control
 if active.size()==MAX_VISIBLE:
  next=active.pop_front()
  next.clear()
 else:
  for bar in pool:
   if not bar.visible:
    next=bar
    break
  if next==null:next=_create_bar()
 next.position=Vector2.ZERO
 next.size=size
 next.reduced_motion=reduced_motion
 next.present(message)
 latest=next
 active.append(next)
 var offset := 0.0
 for i in range(active.size()-1,-1,-1):
  var bar=active[i]
  bar.z_index=i
  if i<active.size()-1:
   offset+=(active[i+1].expanded.y+bar.expanded.y)*0.5+12.0
   bar.move_in_stack(Vector2(0,-offset))
 show()
