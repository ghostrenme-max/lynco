extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui:=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 assert(not ui.table_status.is_visible_in_tree())
 ui.capacity_hint._process(0.0)
 assert(not ui.capacity_hint.visible)
 ui.table.set_top_view(true)
 ui.stage.hide()
 ui.capacity_hint._process(0.0)
 assert(ui.capacity_hint.is_visible_in_tree())
 assert(ui.capacity_hint.caption.text=="배치 0 / 30")
 ui.table.set_top_view(false);ui.stage.show()
 for i in range(27):ui.model.placed.append({})
 ui.capacity_hint._process(0.0)
 assert(ui.capacity_hint.visible and ui.capacity_hint.caption.text=="배치 27 / 30 · 3칸 남음")
 ui.model.placed.clear()
 ui.capacity_hint._process(0.0)
 assert(not ui.capacity_hint.visible)
 print("CAPACITY_HINT_PASS")
 quit()
