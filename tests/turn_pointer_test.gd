extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui:=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var prop: Node3D=ui.table.get_node("TheatreRoom/TurnPointerDummy")
 var base: Transform3D=prop.get_node("FixedBase").global_transform
 assert(is_equal_approx(prop.arm.rotation.z,prop.PLAYER_ANGLE))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/pointer_player.png")
 ui.opponent_turn_active=true;ui._sync_ui()
 await create_timer(0.55).timeout
 assert(prop.arm.rotation.z<prop.OPPONENT_ANGLE,"rebound lifts away from stop")
 await create_timer(0.6).timeout
 assert(is_equal_approx(prop.arm.rotation.z,prop.OPPONENT_ANGLE),"settles exactly")
 assert(prop.get_node("FixedBase").global_transform==base,"base stays fixed")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/pointer_opponent.png")
 ui.opponent_turn_active=false;ui._sync_ui()
 await create_timer(1.1).timeout
 assert(is_equal_approx(prop.arm.rotation.z,prop.PLAYER_ANGLE))
 prop.set_turn(true,true)
 assert(is_equal_approx(prop.arm.rotation.z,prop.OPPONENT_ANGLE),"reduced motion snaps")
 print("TURN_POINTER_PASS")
 quit()
