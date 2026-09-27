extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func click(point: Vector2) -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
  root.push_input(event,true)
func run() -> void:
 create_timer(45).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var t=ui.table
 var cell:=Vector2i(3,1)
 t.place("observe",cell,true);t.mark_owner(cell,"opponent")
 await create_timer(0.2).timeout
 var state:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 for viewport_size in [Vector2i(1280,720),Vector2i(1600,900)]:
  root.size=viewport_size;await process_frame
  t.pan_by(Vector2(0.5,0),0.3)
  var original: Transform3D=t.camera.transform
  ui._test_pointer(t.screen_position(cell),true)
  await create_timer(0.22).timeout
  check(t.card_focus_active,"card click focuses camera")
  var center: Vector2=root.get_visible_rect().size*0.5
  check(t.camera.unproject_position(t.cell_position(cell)).distance_to(center)<2.0,"selected card centered")
  check(t.camera.position.distance_to(t.cell_position(cell))<original.origin.distance_to(t.cell_position(cell)),"camera zooms closer")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/card_focus_"+str(viewport_size.x)+".png")
  click(Vector2(8,8))
  check(not t.card_focus_active and t.camera.transform.is_equal_approx(original),"outside board restores exact original view")
  ui._test_pointer(t.screen_position(cell),true)
  click(Vector2(8,8))
  await create_timer(0.22).timeout
  check(t.camera.transform.is_equal_approx(original),"early cancel kills focus tween")
  ui._select_card(int(ui.model.hand[0].uid))
  ui._test_pointer(t.screen_position(cell),true)
  check(t.card_focus_active and ui.selected_uid==-1,"placed card focus takes priority over hand selection")
  var turn_before: int=ui.model.turn
  click(ui.stage.get_global_transform_with_canvas()*ui.turn_board.get_rect().get_center())
  check(not t.card_focus_active and ui.model.turn==turn_before and not ui.busy,"HUD click only dismisses focus")
 t.set_top_view(true);ui.stage.hide()
 t.zoom_top_view(2)
 var top_transform: Transform3D=t.camera.transform
 var top_size: float=t.camera.size
 var top_zoom: float=t.top_zoom
 click(t.camera.unproject_position(t.cell_position(cell)))
 await create_timer(0.22).timeout
 check(t.card_focus_active and t.camera.size<top_size,"top view focuses and zooms")
 click(t.camera.unproject_position(t.cell_position(cell)))
 check(t.camera.transform.is_equal_approx(top_transform) and is_equal_approx(t.camera.size,top_size) and is_equal_approx(t.top_zoom,top_zoom),"same card restores previous top zoom")
 click(t.camera.unproject_position(t.cell_position(cell)))
 t.set_top_view(false);ui.stage.show()
 check(not t.card_focus_active,"MMB transition clears focus")
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"camera leaves model and random state unchanged")
 print("CARD_FOCUS_PASS checks=",checks)
 quit()
