extends SceneTree
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(35).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface");var t=ui.table
 while ui.busy:await process_frame
 t.place("guard",Vector2i(2,2),true)
 var origin: Transform3D=t.camera.transform
 var fov: float=t.camera.fov
 t.pan_by(Vector2.RIGHT,0.2)
 check(is_equal_approx(t.camera.position.x-origin.origin.x,1.8),"WASD moves at 9 units per second")
 t.camera.transform=origin
 var state:=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state])
 for quick in [false,true]:
  ui._set_reduced_motion(quick)
  t.set_top_view(true,true);ui.stage.hide()
  check(t.top_transitioning and t.camera.transform.is_equal_approx(origin),"entry starts at current pose without jump")
  await create_timer(0.06 if quick else 0.23).timeout
  check(t.top_transitioning and not t.camera.transform.is_equal_approx(origin),"intermediate pose exists")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/camera_blend_mid_"+str(quick)+".png")
  while t.top_transitioning:await process_frame
  check(t.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(t.camera.rotation.x,-PI/2),"entry ends at orthographic overhead")
  t.zoom_top_view(1,Vector2(600,300))
  var top: Transform3D=t.camera.transform
  t.set_top_view(false,true);ui.stage.show()
  check(t.top_transitioning and t.camera.transform.is_equal_approx(top),"zoomed exit starts at current pose")
  while t.top_transitioning:await process_frame
  check(t.camera.transform.is_equal_approx(origin) and is_equal_approx(t.camera.fov,fov),"exit restores exact pose and lens")
 t.set_top_view(true,true)
 await create_timer(0.04).timeout
 await ui._restart(20260926)
 check(not t.top_transitioning and not t.top_view and t.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"restart cancels transition and restores perspective")
 check(t.camera.transform.is_equal_approx(origin),"restart is not overwritten by old tween")
 check(state==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state]),"camera does not alter seeded battle")
 print("CAMERA_TRANSITION_PASS checks=",checks)
 quit()
