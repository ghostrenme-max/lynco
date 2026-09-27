extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func click_card() -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  event.position=ui.inspector_card.get_global_rect().get_center()
  root.push_input(event,true)
func run() -> void:
 create_timer(30).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var state:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 for entry in ui.model.hand:
  ui._test_inspect_card(int(entry.uid))
  var front: String=ui.preview_text.text
  click_card()
  check(ui.inspector_open and ui.inspector_reverse,"left click switches without closing")
  check(ui.preview_text.text==ui.Catalog.back_card(entry.id).detail,"correct back explanation")
  check(ui.inspector_score.cube_count()==0,"unknown back value not invented")
  ui._sync_ui()
  check(ui.inspector_reverse and ui.preview_text.text==ui.Catalog.back_card(entry.id).detail,"refresh preserves back")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/inspector_flip.png")
  click_card()
  check(not ui.inspector_reverse and ui.preview_text.text==front,"second click restores front")
  ui._close_inspector()
 ui._inspect_placed("guard",true,"opponent")
 click_card()
 check(not ui.inspector_reverse and ui.preview_title.text=="봉쇄","placed reverse can show front")
 click_card()
 check(ui.inspector_reverse and ui.preview_title.text=="킹","placed front returns to king")
 ui._close_inspector()
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"inspection does not flip actual cards")
 print("INSPECTOR_FLIP_PASS checks=",checks)
 quit()
