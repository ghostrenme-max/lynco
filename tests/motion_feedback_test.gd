extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(50).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.placed,ui.model.rng.state])
 var uid: int=ui.model.hand[0].uid
 var view=ui.views[uid]
 for reduced in [false,true]:
  ui._set_reduced_motion(reduced)
  ui._focus_card(uid,true)
  await create_timer(0.3).timeout
  check(view.scale.is_equal_approx(Vector2.ONE*ui.Card.HOVER_SCALE),"hover settles to exact size")
  check(ui.views.values().all(func(card):return card.reduced_motion==reduced),"motion mode reaches every hand card")
  ui._clear_hand_focus()
  await create_timer(0.3).timeout
  ui._test_drag(view.rest_position+ui.Card.CARD_SIZE*0.5,ui.table.screen_position(Vector2i(2,1)),false)
  check(ui.drag_uid==uid and absf(view.rotation)<=0.0751,"drag has bounded tilt")
  if reduced:check(is_zero_approx(view.rotation),"reduced drag has no tilt")
  check(ui.table.hint.visible,"valid drag shows landing preview")
  ui._cancel_drag()
  await create_timer(0.3).timeout
  check(view.position.is_equal_approx(view.rest_position+Vector2(0,-16 if view.selected else 0)) and view.scale.is_equal_approx(Vector2.ONE),"cancel returns selected hand pose")
  check(not ui.table.hint.visible,"cancel clears snap preview")
  ui._set_hud_value("energy",2)
  ui._set_hud_value("energy",1)
  ui._set_hud_value("energy",3)
  await create_timer(0.25).timeout
  check(ui.hud_values.energy.scale.is_equal_approx(Vector2.ONE) and ui.hud_values.energy.text=="3","rapid numeric updates settle")
  ui.table.place("observe",Vector2i(2,1),false)
  ui.table.mark_owner(Vector2i(2,1),"player")
  await create_timer(0.42).timeout
  check(ui.table.cards[Vector2i(2,1)].scale.is_equal_approx(Vector3.ONE),"landing compression finishes at exact size")
  ui.table.select_influence(Vector2i(2,1))
  if reduced:check(is_equal_approx(float(ui.table.battle_grid_material.get_shader_parameter("influence_reveal")),1.0),"reduced influence is immediate")
  await create_timer(0.3).timeout
  check(is_equal_approx(float(ui.table.battle_grid_material.get_shader_parameter("influence_reveal")),1.0),"influence reveal settles without looping")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/motion_feedback_"+str(reduced)+".png")
  ui.table.clear_cards()
  await process_frame
 check(snapshot==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.placed,ui.model.rng.state]),"feedback leaves combat and random state unchanged")
 print("MOTION_FEEDBACK_PASS checks=",checks)
 quit()
