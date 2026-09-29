extends SceneTree
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func click(control: Control) -> void:
 var point:=control.get_global_rect().get_center()
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
 for i in range(5):await process_frame
func run() -> void:
 create_timer(70).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 ui._set_reduced_motion(true)
 check(ui.model.rules.starting_cubes==6,"new live model loaded")
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=resolution;await process_frame
  check(root.get_visible_rect().encloses(ui.linked_panel.get_global_rect()),"rule panel in viewport")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/linked_initial_"+str(resolution.x)+".png")
 var uid: int=ui.model.hand[0].uid
 ui.model.energy=20
 await ui._activate_card(uid,Vector2i(2,2))
 check(ui.model.cell_map.has(Vector2i(2,2)) and ui.table.cards.has(Vector2i(2,2)),"model and renderer share real cell")
 ui.table.click_influence(Vector2i(2,2));ui.linked_panel.refresh()
 var before: int=ui.model.cubes.player
 check(not ui.linked_panel.invest_button.disabled,"investment available on selected own card")
 await click(ui.linked_panel.invest_button)
 while ui.busy:await process_frame
 check(ui.model.cubes.player<before and ui.model.invested_total("player")>0,"real click invests without losing table selection")
 check(ui.table.cards[Vector2i(2,2)].get_node("InvestmentLabel").visible,"placed investment marker")
 check(ui.linked_panel.recover_button.disabled,"same-turn recovery disabled")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/linked_invested.png")
 await ui._end_turn()
 for cell in ui.table.cards:check(ui.model.cell_map.has(cell),"AI uses matching model/render coordinates")
 ui.table.click_influence(Vector2i(2,2));ui.linked_panel.refresh()
 check(not ui.linked_panel.recover_button.disabled,"next turn permits recovery")
 await click(ui.linked_panel.recover_button)
 while ui.busy:await process_frame
 check(ui.model.invested_total("player")==0,"real click recovers")
 for i in range(60):
  if ui.model.finished:break
  var playable:=-1
  for e in ui.model.hand:
   if ui.model.unavailable_reason(e.uid).is_empty():playable=e.uid;break
  if playable>=0:await ui._activate_card(playable)
  else:await ui._end_turn()
 check(ui.model.finished and ui.result_panel.visible,"actual match reaches weighted verdict")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/linked_result.png")
 await ui._restart(123)
 check(ui.model.invested_total("player")==0 and ui.model.cubes.player==6,"restart clears invested state")
 print("LINKED_UI_PASS checks=",checks)
 quit()
