extends Control

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
 var pale := Color("e8eae3")
 for center in [Vector2(674, 215), Vector2(926, 215), Vector2(674, 515), Vector2(926, 515)]:
  draw_line(center - Vector2(68, 0), center + Vector2(68, 0), pale, 10.0, true)
  draw_line(center - Vector2(0, 65), center + Vector2(0, 65), pale, 10.0, true)
 draw_line(Vector2(340, 102), Vector2(1210, 102), Color("e2e5dc"), 1.0)
 draw_line(Vector2(340, 605), Vector2(1210, 605), Color("e2e5dc"), 1.0)
 draw_line(Vector2(32, 890), Vector2(1568, 890), Color("e0e3da"), 1.0)
