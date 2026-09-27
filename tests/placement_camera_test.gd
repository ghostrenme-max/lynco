extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(40).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var t=ui.table
 var cam=t.placement_camera
 var original: Transform3D=t.camera.transform
 var state:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 var uid: int=ui.model.hand[0].uid
 ui._select_card(uid)
 ui._test_pointer(t.screen_position(Vector2i(3,2)))
 await create_timer(0.3).timeout
 check(not cam.active and t.camera.transform.is_equal_approx(original),"selected hand hover does not zoom")
 var view=ui.views[uid]
 ui._test_drag(view.rest_position+ui.Card.CARD_SIZE*0.5,t.screen_position(Vector2i(3,2)),false)
 check(ui.drag_uid==uid,"real held-button input starts drag")
 await create_timer(0.5).timeout
 check(cam.active and t.camera.position.distance_to(original.origin)>2.0,"drag zoom activates")
 for other_uid in ui.views:
  if other_uid!=uid:
   var other=ui.views[other_uid]
   check(other.drag_retracted and other.position.y>other.rest_position.y+180,"other hand cards retract below board")
   check(not other.contains_hand_point(other.rest_position),"retracted cards do not intercept pointer")
 var first: Vector3=t.camera.position
 var motion:=InputEventMouseMotion.new()
 motion.position=cam.pointer+Vector2(140,0)
 motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(motion,true)
 await create_timer(0.6).timeout
 check(t.camera.position.x>first.x,"drag follows mouse right")
 var stable: Transform3D=t.camera.transform
 await create_timer(0.6).timeout
 check(t.camera.position.distance_to(stable.origin)<0.02,"stationary pointer settles without drift")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/drag_camera.png")
 ui._cancel_drag()
 check(not cam.active and t.camera.transform.is_equal_approx(original),"release restores exact previous view")
 await create_timer(0.25).timeout
 for other in ui.views.values():
  check(not other.drag_retracted and other.position.y<other.rest_position.y+2,"cancel restores hand")
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"camera leaves model and RNG unchanged")
 ui._test_drag(view.rest_position+ui.Card.CARD_SIZE*0.5,t.screen_position(Vector2i(3,2)),false)
 await create_timer(0.35).timeout
 var cell: Vector2i=t.cell_at(ui.stage.get_global_transform_with_canvas().affine_inverse()*cam.pointer)
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.position=cam.pointer;release.pressed=false
 root.push_input(release,true)
 await create_timer(0.4).timeout
 check(not cam.active and ui.drag_uid==-1,"button release ends camera mode")
 check(t.cards.has(cell),"drop uses cell under zoomed cursor")
 print("PLACEMENT_CAMERA_PASS checks=",checks)
 quit()
