extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
 create_timer(50).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 await create_timer(2.0).timeout
 root.size=Vector2i(1280,720);await process_frame
 check(ui.hand_label.text=="%d / %d" % [ui.model.hand.size(),ui.model.total_cards],"hand and total count")
 check(ui.garnet_label.text==str(preload("res://scripts/collection_session.gd").gold),"live currency")
 check(ui.end_button.get_parent()==ui.turn_board,"end turn in board")
 for label in [ui.hand_hint,ui.deck_label,ui.discard_label,ui.exhaust_label,ui.performance_label]:
  check(not label.visible,"bottom explanations hidden")
 check(not ui.seed_box.is_visible_in_tree() and ui.seed_box.get_parent()==ui.help_panel,"secondary controls moved to help")
 check(ui.table.get_node("GarnetCubes").get_child_count()==3,"three glass cubes")
 for cube in ui.table.get_node("GarnetCubes").get_children():
  var particles: CPUParticles3D=cube.get_node("CoreParticles")
  check(particles.amount==18 and particles.emitting,"small fixed particle pool")
  check(particles.gravity==Vector3.ZERO and particles.spread==180.0,"radial core emission")
  check(particles.emission_sphere_radius+particles.initial_velocity_max*particles.lifetime<0.4,"travel stays inside cube")
  check(particles.color_ramp.sample(1.0).a==0.0,"particles disappear at end of short travel")
 check(ui.turn_track.occupied==ui.model.placed.size(),"progress from model")
 check(not ui.menu_button.visible,"top left arrow removed")
 check(ui.table.COLS==6 and ui.table.ROWS==5 and ui.Model.CAPACITY==30,"6 by 5 wide playable board")
 check(not ui.table.black_market_open and not ui.table.get_node("Distributors/BlackMarket/ActiveLight").visible,"black market idle")
 for y in range(5):
  for x in range(6):
   var cell:=Vector2i(x,y)
   check(ui.table.cell_at(ui.table.screen_position(cell))==cell,"all thirty cells hit")
 await capture("hud_layout_1280")
 ui.table.set_black_market_open(true)
 check(ui.table.get_node("Distributors/BlackMarket/ActiveLight").visible,"black market opens red")
 await capture("black_market_open")
 ui.table.set_black_market_open(false)
 root.size=Vector2i(1600,900);await process_frame
 await capture("hud_layout_1600")
 root.size=Vector2i(1280,720);await process_frame
 var button_point: Vector2=ui.end_button.get_global_rect().get_center()
 var turn: int=ui.model.turn
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=button_point
  root.push_input(event,true)
 await process_frame
 check(ui.busy,"end turn actual click")
 while ui.busy:await process_frame
 check(ui.model.turn>turn and ui.turn_track.occupied==ui.model.placed.size(),"turn and progress updated")
 await create_timer(2).timeout
 await capture("hud_layout_played")
 ui.table.set_top_view(true)
 check(not ui.table.get_node("GarnetCubes").visible,"top view hides decorative currency")
 ui.table.set_top_view(false)
 check(ui.table.get_node("GarnetCubes").visible,"currency restored")
 ui.stage.hide()
 ui.table.camera.position=Vector3(6.4,2.3,6.7)
 ui.table.camera.look_at(Vector3(6.4,0.4,2.8))
 await create_timer(0.2).timeout
 await capture("garnet_particles_closeup")
 print("HUD_LAYOUT_PASS checks=",checks)
 quit()
