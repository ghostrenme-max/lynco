extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(30).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var count:int=ui.model.hand.size()
 var base_count:int=ui.table.world.get_child_count()
 ui._end_turn()
 assert(ui.discard_phase=="gather" and ui.busy)
 while ui.discard_phase=="gather":await process_frame
 assert(ui.discard_phase=="flight")
 for view in ui.views.values():assert(not view.visible)
 assert(ui.table.world.get_child_count()==base_count+count)
 await create_timer(0.28).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/storage-flight.png")
 while ui.busy:await process_frame
 assert(ui.discard_phase=="idle" and ui.model.conserved())
 print("STORAGE_ANIMATION_PASS")
 quit()
