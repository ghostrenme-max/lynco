extends SceneTree

const Model = preload("res://scripts/table_battle_model.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Session = preload("res://scripts/collection_session.gd")
var checks := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1

func run() -> void:
 create_timer(45).timeout.connect(func():quit(1))
 check(int(Catalog.CHARACTER.hand_limit)==7,"hand limit is seven")
 for deck_id in Session.DECKS:
  Session.selected=deck_id
  for seed_value in range(32):
   var model:=Model.new();model.reset(seed_value);model.fill_hand()
   check(model.hand.size()==5,"normal refill remains five")
   check(model.draw_cards(100).size()==2 and model.hand.size()==7,"large draw stops exactly at seven")
   var before:=JSON.stringify([model.hand,model.deck,model.discard,model.rng.state])
   check(model.draw_cards(100).is_empty() and model.fill_hand().drawn.is_empty(),"full hand cannot draw or refill")
   check(before==JSON.stringify([model.hand,model.deck,model.discard,model.rng.state]),"rejected draw preserves cards and RNG")
   model.conceal_and_shuffle()
   check(model.hand.size()==7 and model.conserved(),"shuffle preserves seven-card limit")
 Session.selected="starter"
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 check(ui.pile_views.size()==2,"two independent pile groups")
 for i in range(2):
  var pile: Control=ui.pile_views[i]
  check(pile.size.is_equal_approx(Vector2(124,197.8)),"pile height increased fifteen percent only")
  var face: TextureRect=pile.get_child(pile.get_child_count()-1)
  check(face.texture==ui.textures["back_white" if i==0 else "back_black"],"original logo textures retained")
  check(is_equal_approx(face.size.y/float(face.material.get_shader_parameter("logo_height_scale")),172.0),"logo height preserved without stretching")
 check(float(ui.Card.BACK_MATERIAL.get_shader_parameter("logo_height_scale"))==1.0,"hand and table logo materials untouched")
 for quick in [false,true]:
  root.size=Vector2i(1280,720) if not quick else Vector2i(1920,1080)
  await process_frame
  ui._set_reduced_motion(quick)
  await ui._restart(20260926)
  check(is_equal_approx(ui.table.get_node("TableSpot").light_energy,6.0) and is_zero_approx(ui.table.get_node("FarTableSpot").light_energy),"player table alone has active spotlight")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/piles_player_"+str(root.size.x)+".png")
  ui._end_turn()
  while not ui.table.opponent_view:await process_frame
  await ui.pile_motion.finished
  for i in range(2):
   check(ui.pile_views[i].position.is_equal_approx(ui.pile_positions[i]+ui.PILE_RETREAT+Vector2(ui.PILE_OUTWARD[i],0)),"both piles retreat toward player during opponent turn")
   check(is_equal_approx(ui.pile_views[i].modulate.a,0.45),"opponent piles fade to 45 percent")
   var rect: Rect2=ui.pile_views[i].get_global_rect()
   check(rect.intersects(root.get_visible_rect()) and rect.end.y>root.get_visible_rect().end.y,"near piles remain partly visible beyond bottom edge")
   check(ui.pile_views[i].scale.is_equal_approx(ui.PILE_NEAR_SCALE),"opponent view brings piles closer by uniform scale")
  check(is_equal_approx(ui.opponent_vignette.modulate.a,1.0),"opponent bottom shading shown")
  check(ui.opponent_vignette.mouse_filter==Control.MOUSE_FILTER_IGNORE,"vignette never intercepts input")
  if ui.table.turn_light_tween and ui.table.turn_light_tween.is_running():await ui.table.turn_light_tween.finished
  check(is_zero_approx(ui.table.get_node("TableSpot").light_energy) and is_equal_approx(ui.table.get_node("FarTableSpot").light_energy,6.0),"opponent table alone has active spotlight")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/piles_opponent_"+str(root.size.x)+".png")
  while ui.busy:await process_frame
  for i in range(2):check(ui.pile_views[i].position.is_equal_approx(ui.pile_positions[i]),"player turn restores exact pile positions")
  for pile in ui.pile_views:check(pile.scale.is_equal_approx(Vector2.ONE),"player turn restores pile scale")
  for pile in ui.pile_views:check(is_equal_approx(pile.modulate.a,1.0),"player turn restores opacity")
  check(is_zero_approx(ui.opponent_vignette.modulate.a),"player turn removes shading")
  check(ui.model.conserved(),"turn transition conserves cards")
 await ui._restart(20260926)
 await ui._demo_draw();await ui._demo_draw()
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.deck,ui.model.rng.state])
 await ui._demo_draw();await ui._fill_requested()
 check(ui.views.size()==7 and ui.model.hand.size()==7 and ui.draw_button.disabled,"UI cannot exceed seven")
 check(snapshot==JSON.stringify([ui.model.hand,ui.model.deck,ui.model.rng.state]),"repeated full-hand input is harmless")
 ui._set_piles_retracted(true)
 await create_timer(0.03).timeout
 await ui._restart(20260926)
 for i in range(2):check(ui.pile_views[i].position.is_equal_approx(ui.pile_positions[i]),"restart cancels pile motion")
 for pile in ui.pile_views:check(pile.scale.is_equal_approx(Vector2.ONE),"restart resets pile scale")
 for pile in ui.pile_views:check(is_equal_approx(pile.modulate.a,1.0),"restart restores opacity")
 check(is_zero_approx(ui.opponent_vignette.modulate.a),"restart clears shading")
 print("PILE_TURN_PASS checks=",checks)
 quit()
