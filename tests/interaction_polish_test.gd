extends SceneTree
var checks := 0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
 if not ok:
  push_error(message)
  quit(1)
  assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(40).timeout.connect(func():push_error("POLISH_TIMEOUT");quit(1))
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var t=ui.table
 var original: Vector3=t.camera.rotation
 var state:=JSON.stringify([ui.model.hand,ui.model.deck,ui.model.energy,ui.model.rng.state])
 check(t.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"perspective retained")
 var near_count:=0
 var far_count:=0
 for prop in t.get_node("TheatreRoom").get_children():
  if not prop is Node3D:continue
  if is_equal_approx(prop.position.z,-1.8):
   check(prop.scale.is_equal_approx(Vector3.ONE*1.25),"near chair enlarged")
   near_count+=1
  elif is_equal_approx(prop.position.z,-20.3):
   check(prop.scale.is_equal_approx(Vector3.ONE),"far chair unchanged")
   far_count+=1
 check(near_count==2 and far_count==2,"both chair pairs found")
 ui._test_look_mouse(true,Vector2(220,-45))
 check(ui.looking,"right drag starts")
 var held: Vector3=t.camera.rotation
 # Releasing over the HUD must still end captured look and start delayed return.
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_RIGHT
 release.pressed=false
 release.position=Vector2(20,20)
 root.push_input(release,true)
 check(not ui.looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"release over HUD restores pointer")
 await create_timer(.30).timeout
 check(t.camera.rotation.is_equal_approx(held),"camera holds for first 0.3 seconds")
 await create_timer(.40).timeout
 check(not t.camera.rotation.is_equal_approx(held) and not t.camera.rotation.is_equal_approx(original),"smooth return has intermediate pose")
 await create_timer(.60).timeout
 check(t.camera.rotation.is_equal_approx(original) and t.look_offset.is_zero_approx(),"camera returns exactly")
 ui._test_look_mouse(true,Vector2(-140,30))
 ui._test_look_mouse(false)
 await create_timer(.20).timeout
 ui._test_look_mouse(true)
 held=t.camera.rotation
 await create_timer(1.1).timeout
 check(t.camera.rotation.is_equal_approx(held),"re-grab cancels pending return without snapping")
 ui._test_look_mouse(false)
 await create_timer(.70).timeout
 ui._test_look_mouse(true)
 held=t.camera.rotation
 await create_timer(.60).timeout
 check(t.camera.rotation.is_equal_approx(held),"re-grab cancels active return")
 ui._test_look_mouse(false)
 t.set_top_view(true)
 var top: Transform3D=t.camera.transform
 await create_timer(1.2).timeout
 check(t.camera.transform.is_equal_approx(top),"return cannot overwrite top view")
 t.set_top_view(false)
 t.reset_look()
 t.look_by(Vector2(300,-35))
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://test-results/near_chair_enlarged.png")
 t.reset_look()
 var popup=ui.notification_popup
 popup.clear()
 popup.present("첫 번째 알림")
 await create_timer(.55).timeout
 var old=popup.latest
 popup.present("두 번째 알림")
 check(is_equal_approx(old.modulate.a,.5),"old bar becomes 50 percent immediately")
 await create_timer(.25).timeout
 check(old.position.y<0 and old.modulate.a<.5,"old bar rises and keeps fading")
 var alpha: float=old.modulate.a
 popup.present("세 번째 알림")
 check(old.modulate.a<=alpha,"another notice does not restart old fade")
 popup.present("네 번째 알림")
 check(popup.active.size()==3 and popup.pool.size()==3,"fourth notice evicts oldest")
 await create_timer(.5).timeout
 await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://test-results/notification_stack_three.png")
 for i in range(30):popup.present("연속 알림 %d"%i)
 check(popup.active.size()==3 and popup.get_child_count()==3,"rapid notifications reuse exactly three bars")
 check(popup.caption.text=="연속 알림 29","newest notice stays current")
 popup.clear()
 await create_timer(2.0).timeout
 check(not popup.visible and popup.active.is_empty(),"clear kills all old bar animations")
 check(state==JSON.stringify([ui.model.hand,ui.model.deck,ui.model.energy,ui.model.rng.state]),"presentation changes preserve battle state")
 print("INTERACTION_POLISH_PASS checks=",checks)
 quit()
