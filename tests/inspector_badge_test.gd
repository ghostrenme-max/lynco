extends SceneTree
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(30).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var state:=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state])
 ui._test_inspect_card(int(ui.model.hand[0].uid))
 check(ui.inspector_open,"right click opens inspector")
 var badge=ui.inspector_score
 check(badge.position==Vector2(285,28),"cubes at upper right")
 check(not badge.get_child(0).visible,"numeric badge hidden")
 badge.replay_count("3")
 check(badge.revealed_count==0,"starts with zero visible cubes")
 for i in range(1,4):
  await create_timer(0.31 if i==1 else 0.55).timeout
  check(badge.cube_count()==3 and badge.pulse_index==i-1,"sequential cubes")
  check(badge.revealed_count==i and badge.pulse_scale>1.4,"each cube enlarges to 1.5 with sequential reveal")
 await create_timer(0.42).timeout
 check(is_equal_approx(badge.pulse_scale,1.0),"returns to original scale")
 badge.replay_count("5");await create_timer(0.1).timeout
 badge.replay_count("1");await create_timer(0.8).timeout
 check(badge.cube_count()==1 and badge.pulse_index==-1,"replay replaces previous animation")
 badge.replay_count("0");await create_timer(0.35).timeout
 check(badge.cube_count()==0 and badge.pulse_index==-1,"zero has no cubes")
 badge.replay_count("—")
 check(badge.cube_count()==0 and badge.pulse_index==-1,"unknown score is not invented")
 ui._close_inspector();ui._test_inspect_card(int(ui.model.hand[0].uid))
 await create_timer(0.31).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/inspector_badge_pulse.png")
 ui._close_inspector()
 check(badge.scale==Vector2.ONE,"closing cancels pulse")
 check(state==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state]),"presentation only")
 print("INSPECTOR_BADGE_PASS checks=",checks)
 quit()
