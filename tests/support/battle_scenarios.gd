extends RefCounted
## Lazily loaded CLI scenarios; normal gameplay never constructs this harness.

const Symbols = preload("res://scripts/card_symbols.gd")
const Model = preload("res://scripts/linked_battle_model.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Card = preload("res://scripts/card_view.gd")
const Table = preload("res://scripts/table_view.gd")
var ui: Control

func _test_pointer(point: Vector2, click: bool = false) -> void:
 # Send real viewport GUI events, so hit testing and mouse enter/exit run too.
 var screen_point:Vector2=ui.stage.get_global_transform_with_canvas()*point
 var motion:=InputEventMouseMotion.new()
 motion.position=screen_point;motion.global_position=screen_point
 ui.get_viewport().push_input(motion,true)
 if click:
  for pressed in [true,false]:
   var button:=InputEventMouseButton.new()
   button.position=screen_point;button.global_position=screen_point
   button.button_index=MOUSE_BUTTON_LEFT;button.pressed=pressed
   ui.get_viewport().push_input(button,true)

func _verify_motion() -> void:
 var output_dir:String=ProjectSettings.globalize_path("res://test-results")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var ignore:=FileAccess.open(output_dir+"/.gdignore",FileAccess.WRITE);ignore.close()
 var movie:bool=OS.get_cmdline_user_args().has("--movie-preview")
 if not movie:
  # Capture both actual back materials, without touching front-face definitions.
  var samples:Array[LyncoCardView]=[]
  for index in range(2):
   var definition:Dictionary=Catalog.table_card("guard" if index==0 else "strike")
   var sample:=Card.new();ui.stage.add_child(sample)
   sample.setup({"uid":-100-index},definition,Symbols.texture_for(definition, ui.textures.get(definition.icon)),ui.dark_ink if index==0 else ui.light_ink,ui.textures["back_white" if index==0 else "back_black"])
   sample.position=Vector2(550+index*330,320);sample.scale=Vector2(1.5,1.5);sample.z_index=90;sample.locked=true
   sample.set_face_up(false);samples.append(sample)
   assert((sample.back_logo.position+sample.back_logo.size*0.5).is_equal_approx(Card.CARD_SIZE*0.5))
  await RenderingServer.frame_post_draw
  ui.get_viewport().get_texture().get_image().save_png(output_dir+"/card_backs.png")
  for sample in samples:sample.queue_free()
  await ui.get_tree().process_frame
 ui._test_pointer(Vector2(350,105))
 await ui.get_tree().create_timer(0.15).timeout
 ui._restart(20260926)
 assert(ui.deal_phase=="lift" and ui.busy)
 # The fan must not begin until every new card is visibly in the raised packet.
 while ui.deal_phase=="lift":await ui.get_tree().process_frame
 assert(ui.deal_phase=="stack")
 for i in range(ui.model.hand.size()):
  var view:LyncoCardView=ui.views[int(ui.model.hand[i].uid)]
  assert(view.position.distance_to(ui.DRAW_STACK+ui.STACK_CARD_STEP*i)<0.5)
  assert(absf(view.rotation-deg_to_rad(ui.STACK_FIRST_ANGLE+i*ui.STACK_ANGLE_STEP))<0.001)
  if i>0:
   var previous:LyncoCardView=ui.views[int(ui.model.hand[i-1].uid)]
   assert(view.position.x-previous.position.x>=26.0-0.5,"Lifted cards collapsed into one stack")
  assert(view.scale.is_equal_approx(Vector2(0.84,0.84)))
  assert(not view.face_up and view.back_logo.visible)
  assert(view.back_logo.texture==ui.textures["back_black" if bool(view.data.dark) else "back_white"])
 if not movie:
  await RenderingServer.frame_post_draw
  ui.get_viewport().get_texture().get_image().save_png(output_dir+"/motion_stack.png")
 while ui.busy:await ui.get_tree().process_frame
 assert(ui.deal_phase=="idle")
 for view in ui.views.values():
  assert(view.position.distance_to(view.rest_position)<0.5)
  assert(view.scale.is_equal_approx(Vector2.ONE))
  assert(view.face_up and not view.back_logo.visible)
 await ui.get_tree().create_timer(0.35).timeout
 var middle_uid:int=int(ui.model.hand[2].uid)
 var middle:LyncoCardView=ui.views[middle_uid]
 ui._test_pointer(middle.rest_position+Card.CARD_SIZE*0.5,true)
 await ui.get_tree().create_timer(0.22).timeout
 assert(ui.hovered_uid==middle_uid and ui.selected_uid==middle_uid,"Viewport hover/click did not reach the card")
 for uid in ui.views:
  assert(absf(ui.views[uid].scale.x-(Card.HOVER_SCALE if uid==middle_uid else Card.PEER_SCALE))<0.001)
 if not movie:
  await RenderingServer.frame_post_draw
  ui.get_viewport().get_texture().get_image().save_png(output_dir+"/motion_hover.png")
 # An unmoving pointer must not trigger shrink/expand oscillation.
 for _i in range(15):
  await ui.get_tree().process_frame
  assert(ui.hovered_uid==middle_uid)
 if not movie:
  # Sweep all neutral slots with actual pointer events, including shrunk cards.
  for entry in ui.model.hand:
   var view:LyncoCardView=ui.views[int(entry.uid)]
   ui._test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await ui.get_tree().create_timer(0.25).timeout
   assert(ui.hovered_uid==int(entry.uid))
   assert(absf(view.scale.x-Card.HOVER_SCALE)<0.001)
   for uid in ui.views:
    if uid!=int(entry.uid):assert(absf(ui.views[uid].scale.x-Card.PEER_SCALE)<0.001)
 else:
  for index in [0,3,4]:
   var view:LyncoCardView=ui.views[int(ui.model.hand[index].uid)]
   ui._test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await ui.get_tree().create_timer(0.45).timeout
 ui._test_pointer(Vector2(350,105))
 await ui.get_tree().create_timer(0.22).timeout
 assert(ui.hovered_uid==-1)
 for view in ui.views.values():assert(view.scale.is_equal_approx(Vector2.ONE))
 if not movie:
  await ui._demo_draw();await ui._demo_draw()
  assert(ui.model.hand.size()==7 and ui.model.conserved())
  for entry in ui.model.hand:
   var view:LyncoCardView=ui.views[int(entry.uid)]
   ui._test_pointer(view.rest_position+Card.CARD_SIZE*0.5)
   await ui.get_tree().create_timer(0.17).timeout
   assert(ui.hovered_uid==int(entry.uid))
  ui._test_pointer(Vector2(350,105))
  await ui.get_tree().create_timer(0.2).timeout
  for view in ui.views.values():assert(view.scale.is_equal_approx(Vector2.ONE))
  await ui._end_turn()
  assert(ui.model.conserved() and ui.hovered_uid==-1)
 var result:Dictionary={"two_phase_draw":true,"hover_viewport_events":true,"neutral_hit_slots":true,"stationary_hover_stable":true,"hover_scale":Card.HOVER_SCALE,"other_card_scale":Card.PEER_SCALE,"lift_seconds":ui.LIFT_TIME,"lift_gap_seconds":ui.LIFT_GAP,"stack_pause_seconds":ui.STACK_BEAT,"fan_seconds":ui.FAN_TIME,"fan_gap_seconds":ui.FAN_GAP,"five_card_draw_seconds":ui.LIFT_TIME+4*ui.LIFT_GAP+ui.STACK_BEAT+ui.FAN_TIME+4*ui.FAN_GAP}
 var file:=FileAccess.open(output_dir+"/motion_test.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("LYNCO_MOTION_TEST_PASS "+JSON.stringify(result))
 await ui.get_tree().create_timer(0.25).timeout
 ui.get_tree().quit()

func _verify() -> void:
 ui.reduced_motion=true
 await ui._restart(20260926)
 await ui.get_tree().process_frame
 var baseline: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 for i in range(16):
  await ui._restart(20260926)
  await ui.get_tree().process_frame
  assert(ui.model.conserved() and ui.table.cards.is_empty())
 assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==baseline)
 for i in range(100):
  if ui.model.finished:break
  var uid: int = -1
  for entry in ui.model.hand:
   if ui.model.unavailable_reason(entry.uid).is_empty():uid=int(entry.uid);break
  if uid>=0:await ui._activate_card(uid)
  else:await ui._end_turn()
  assert(ui.model.conserved() and ui.table.cards.size()==ui.model.placed.size())
 assert(ui.model.finished and ui.result_panel.visible and ui.table.cards.size()==Model.CAPACITY)
 var snapshot: String=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy])
 await ui._end_turn();await ui._demo_draw();await ui._fill_requested();await ui._shift_requested()
 assert(snapshot==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy]))
 assert(ui.model.claim_reward()==0)
 print("LYNCO_TABLE_VERIFY_PASS 16_restarts nodes=",baseline,"/",baseline," full_match finished_input_guard reward_once")
 ui.get_tree().quit()

func _verify_table() -> void:
 var output:String=ProjectSettings.globalize_path("res://test-results")
 await ui._restart(20260926)
 await ui.get_tree().process_frame
 var uid:int=int(ui.model.hand[0].uid)
 var view:LyncoCardView=ui.views[uid]
 var start:Vector2=view.rest_position+Card.CARD_SIZE*0.5
 var cell:=Vector2i(2,1)
 var end:Vector2=ui.table.screen_position(cell)
 assert(ui.table.cell_at(end)==cell)
 ui._test_drag(start,end)
 while ui.busy:await ui.get_tree().process_frame
 await ui.get_tree().create_timer(0.3).timeout
 assert(ui.model.find_card(uid)<0 and ui.table.cards.has(cell) and ui.model.conserved())
 assert(ui.table.cards[cell].get_node("Body").cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
 assert(absf(ui.table.cards[cell].position.y-ui.table.cell_position(cell).y)<0.001)
 var initial:String=JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard])
 view=ui.views[int(ui.model.hand[0].uid)]
 ui._test_drag(view.rest_position+Card.CARD_SIZE*0.5,end)
 await ui.get_tree().create_timer(0.2).timeout
 assert(initial==JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard]))
 ui._test_drag(view.rest_position+Card.CARD_SIZE*0.5,Vector2(1580,20))
 await ui.get_tree().create_timer(0.2).timeout
 assert(initial==JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard]))
 # Escape cancels a held card without changing ownership or resources.
 ui._test_drag(view.rest_position+Card.CARD_SIZE*0.5,end,false)
 assert(ui.drag_uid>=0)
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 ui.get_viewport().push_input(escape,true)
 assert(ui.drag_uid==-1 and not ui.table.hint.visible)
 assert(initial==JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard]))
 await ui.get_tree().create_timer(0.2).timeout
 for hand_view in ui.views.values():assert(hand_view.scale.is_equal_approx(Vector2.ONE))
 ui._test_pointer(end,true)
 assert(ui.table.card_focus_active and not ui.inspector_open)
 ui.table.dismiss_card_focus()
 await ui.get_tree().create_timer(0.24).timeout
 # Use an attack via the keyboard/button path, retaining existing combat effects.
 for entry in ui.model.hand.duplicate():
  if str(Catalog.table_card(entry.id).effect)=="damage":
   await ui._activate_card(entry.uid)
   break
 await ui.get_tree().create_timer(0.3).timeout
 ui._test_pointer(Vector2(350,105))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/table_scene_1440.png")
 ui.get_window().size=Vector2i(1280,720)
 await ui.get_tree().create_timer(0.2).timeout
 # Same projection and hit testing after resizing.
 var resized_point:Vector2=ui.table.screen_position(Vector2i(4,1))
 assert(ui.table.cell_at(resized_point)==Vector2i(4,1))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/table_scene_1280.png")
 ui.model.energy=0;ui._sync_ui()
 for entry in ui.model.hand:
  if int(Catalog.table_card(entry.id).cost)>0:
   view=ui.views[entry.uid]
   initial=JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard])
   ui._test_drag(view.rest_position+Card.CARD_SIZE*0.5,resized_point)
   await ui.get_tree().create_timer(0.2).timeout
   assert(initial==JSON.stringify([ui.model.energy,ui.model.hand,ui.model.discard]))
   break
 await ui._end_turn()
 assert(ui.table.cards.size()==ui.model.placed.size() and ui.table.cards.size()>0 and ui.model.conserved())
 await ui._restart(20260926)
 assert(ui.table.cards.is_empty())
 print("LYNCO_TABLE_TEST_PASS drag_snap occupied_outside_rejected energy_rejected escape_cancel placed_inspector shadow landing resize turn_persists_restart_clear")
 ui.get_tree().quit()

func _test_drag(start: Vector2, end: Vector2, finish: bool = true) -> void:
 ui._test_pointer(start)
 var transform:Transform2D=ui.stage.get_global_transform_with_canvas()
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 press.position=transform*start;press.global_position=press.position
 ui.get_viewport().push_input(press,true)
 var motion:=InputEventMouseMotion.new();motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 motion.position=transform*end;motion.global_position=motion.position
 ui.get_viewport().push_input(motion,true)
 if not finish:return
 var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 release.position=transform*end;release.global_position=release.position
 ui.get_viewport().push_input(release,true)

func _test_look_mouse(pressed: bool, relative: Vector2 = Vector2.ZERO) -> void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=pressed
 event.position=ui.stage.get_global_transform_with_canvas()*Vector2(800,320)
 ui.get_viewport().push_input(event,true)
 if pressed and relative!=Vector2.ZERO:
  var motion:=InputEventMouseMotion.new()
  motion.button_mask=MOUSE_BUTTON_MASK_RIGHT
  motion.relative=relative;motion.screen_relative=relative
  ui.get_viewport().push_input(motion,true)

func _verify_look() -> void:
 var output:String=ProjectSettings.globalize_path("res://test-results")
 await ui._restart(20260926)
 var original:Vector3=ui.table.camera.rotation
 var original_ui:Transform2D=ui.stage.get_global_transform_with_canvas()
 ui._test_look_mouse(true,Vector2(10000,-10000))
 assert(ui.looking)
 assert(is_equal_approx(ui.table.look_offset.x,-deg_to_rad(60.0)))
 assert(is_equal_approx(ui.table.look_offset.y,deg_to_rad(35.0)))
 ui._test_look_mouse(false)
 assert(not ui.looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 var held:Vector3=ui.table.camera.rotation
 await ui.get_tree().create_timer(0.15).timeout
 assert(ui.table.camera.rotation.is_equal_approx(held))
 assert(ui.stage.get_global_transform_with_canvas().is_equal_approx(original_ui))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/look_right.png")
 ui._test_look_mouse(true,Vector2(-20000,20000))
 ui._test_look_mouse(false)
 assert(is_equal_approx(ui.table.look_offset.x,deg_to_rad(60.0)))
 assert(is_equal_approx(ui.table.look_offset.y,-deg_to_rad(35.0)))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/look_left.png")
 # Check wide horizontal views, then return to a playable angle for card dragging.
 ui.table.reset_look()
 ui.table.look_by(Vector2(-10000,0))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/look_wide_left.png")
 ui.table.look_by(Vector2(20000,0))
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/look_wide_right.png")
 ui.table.reset_look()
 ui.table.look_by(Vector2(-deg_to_rad(12.0),deg_to_rad(7.0))/ui.table.look_sensitivity)
 # Drag at a rotated camera must target the same 3D cell.
 var cell:=Vector2i(2,1)
 var end:Vector2=ui.table.screen_position(cell)
 assert(ui.table.cell_at(end)==cell)
 var uid:int=int(ui.model.hand[0].uid)
 var view:LyncoCardView=ui.views[uid]
 ui._test_drag(view.rest_position+Card.CARD_SIZE*0.5,end,false)
 assert(ui.drag_uid==uid and ui.table.hint.visible)
 ui._test_look_mouse(true)
 assert(not ui.looking and ui.table.camera.rotation.is_equal_approx(original+Vector3(-deg_to_rad(7.0),deg_to_rad(12.0),0)))
 ui._test_look_mouse(false)
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/placement_glow.png")
 # Drag zoom can move the camera during frame capture; project the target again.
 end=ui.table.screen_position(cell)
 if ui.turn_board.get_rect().has_point(end):
  for row in range(Table.ROWS):
   var found := false
   for col in range(Table.COLS):
    var candidate := Vector2i(col,row)
    var point: Vector2=ui.table.screen_position(candidate)
    if ui.table.free_cell(candidate) and ui.table.cell_at(point)==candidate and not ui.turn_board.get_rect().has_point(point):
     cell=candidate;end=point;found=true;break
   if found:break
 assert(ui.table.cell_at(end)==cell)
 assert(not ui.turn_board.get_rect().has_point(end))
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false
 release.position=ui.stage.get_global_transform_with_canvas()*end
 ui.get_viewport().push_input(release,true)
 while ui.busy:await ui.get_tree().process_frame
 assert(ui.table.cards.has(cell) and ui.model.find_card(uid)<0 and ui.model.conserved())
 assert(not ui.table.hint.visible)
 ui._test_look_mouse(true,Vector2(20,20))
 ui._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not ui.looking and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 ui._test_look_mouse(true)
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
 ui.get_viewport().push_input(escape,true)
 assert(not ui.looking)
 var reset:=InputEventKey.new();reset.keycode=KEY_R;reset.pressed=true
 ui.get_viewport().push_input(reset,true)
 assert(ui.table.camera.rotation.is_equal_approx(original))
 ui.table.preview(ui.table.screen_position(Vector2i(3,1)),true)
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/table_dark_glow.png")
 ui.table.hide_preview()
 ui.get_window().size=Vector2i(1280,720)
 await ui.get_tree().create_timer(0.2).timeout
 assert(ui.table.cell_at(ui.table.screen_position(Vector2i(3,1)))==Vector2i(3,1))
 print("LYNCO_LOOK_TEST_PASS limits release focus_escape reset rotated_drag drag_exclusion ui_fixed resize glow")
 ui.get_tree().quit()

func _test_inspect_card(uid: int) -> void:
 var view:LyncoCardView=ui.views[uid]
 var point:Vector2=ui.stage.get_global_transform_with_canvas()*(view.rest_position+Card.CARD_SIZE*0.5)
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;event.position=point
 ui.get_viewport().push_input(event,true)
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.position=point
 ui.get_viewport().push_input(event,true)

func _verify_inspector() -> void:
 await ui._restart(20260926)
 var output:String=ProjectSettings.globalize_path("res://test-results")
 var baseline_nodes:int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 var state:String=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.turn,ui.model.discard])
 var original:Vector3=ui.table.camera.rotation
 for dark in [false,true]:
  var uid:int=-1
  for entry in ui.model.hand:
   if bool(Catalog.table_card(entry.id).dark)==dark:uid=int(entry.uid);break
  assert(uid>=0)
  ui._test_inspect_card(uid)
  assert(ui.inspector_open and not ui.looking and ui.drag_uid<0)
  assert(ui.inspector_card.get_global_rect().get_center().distance_to(ui.get_viewport_rect().size*0.5)<1)
  var key:=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true
  ui.get_viewport().push_input(key,true)
  key=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
  ui.get_viewport().push_input(key,true)
  assert(state==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.turn,ui.model.discard]))
  assert(ui.table.camera.rotation.is_equal_approx(original))
  await ui.get_tree().create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  ui.get_viewport().get_texture().get_image().save_png(output+("/inspector_black.png" if dark else "/inspector_white.png"))
  key=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true
  ui.get_viewport().push_input(key,true)
  assert(not ui.inspector_open)
 for i in range(8):
  ui._test_inspect_card(int(ui.model.hand[0].uid));assert(ui.inspector_open)
  ui._test_pointer(Vector2(100,100),true);assert(not ui.inspector_open)
 ui._test_inspect_card(int(ui.model.hand[0].uid))
 ui.get_window().size=Vector2i(1280,720)
 await ui.get_tree().create_timer(0.2).timeout
 assert(ui.inspector_card.get_global_rect().get_center().distance_to(ui.get_viewport_rect().size*0.5)<1)
 await RenderingServer.frame_post_draw
 ui.get_viewport().get_texture().get_image().save_png(output+"/inspector_1280.png")
 ui._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
 assert(not ui.inspector_open)
 await ui.get_tree().process_frame
 # Number labels allocate reusable reels on their first value change.
 var warmed_nodes: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 assert(warmed_nodes>=baseline_nodes)
 for repeat in range(3):
  ui._test_inspect_card(int(ui.model.hand[0].uid))
  ui._close_inspector()
  await ui.get_tree().process_frame
 assert(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==warmed_nodes)
 ui._test_look_mouse(true,Vector2(30,20));assert(ui.looking)
 ui._test_look_mouse(false);assert(not ui.looking)
 assert(state==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.turn,ui.model.discard]))
 print("LYNCO_INSPECTOR_TEST_PASS right_click center dark_white modal_input close resize nodes_stable camera")
 ui.get_tree().quit()
# Leave only between animations so no suspended combat continuation outlives its scene.
