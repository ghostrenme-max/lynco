extends SceneTree
const Session = preload("res://scripts/collection_session.gd")
var checks := 0
func check(value: bool, message: String) -> void:
 if not value:
  push_error(message); quit(1); assert(value,message)
 checks += 1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for i in range(5): await process_frame
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/table_game_"+name+".png")
func click(button: Control) -> void:
 var point := button.get_global_rect().get_center()
 for down in [true,false]:
  var event := InputEventMouseButton.new()
  event.position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
  root.push_input(event,true)
 await settle()
func key(code: Key, down: bool) -> void:
 var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down
 root.push_input(event,true)
func run() -> void:
 var watchdog := Timer.new(); watchdog.wait_time=100; watchdog.one_shot=true
 root.add_child(watchdog); watchdog.timeout.connect(func(): push_error("timeout");quit(1));watchdog.start()
 change_scene_to_file("res://scenes/main_menu.tscn"); await settle()
 await capture("main")
 await click(current_scene.action_buttons.start)
 await settle()
 var ui = current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty(): await process_frame
 ui.reduced_motion=true
 root.size=Vector2i(1280,720); await settle()
 var initial: Vector3 = ui.table.camera.position
 key(KEY_D,true); await create_timer(0.2).timeout; key(KEY_D,false)
 check(ui.table.camera.position.x>initial.x,"WASD moves camera")
 key(KEY_R,true); key(KEY_R,false)
 check(ui.table.camera.position.is_equal_approx(initial),"R recenters camera")
 var uid: int = ui.model.hand[0].uid
 ui._inspect(uid,true); ui._show_inspector(ui.Catalog.table_card(ui.model.hand[0].id))
 key(KEY_D,true); await create_timer(0.1).timeout; key(KEY_D,false)
 check(ui.table.camera.position.is_equal_approx(initial),"inspector blocks camera")
 await capture("inspector")
 ui._close_inspector()
 for i in range(30):
  if ui.model.finished: break
  var chosen := -1
  for entry in ui.model.hand:
   if ui.model.unavailable_reason(entry.uid).is_empty(): chosen=entry.uid;break
  if chosen>=0: await ui._activate_card(chosen)
  else: await ui._end_turn()
  check(ui.table.cards.size()==ui.model.placed.size(),"board view/model agree")
  if ui.model.placed.size()>=7 and ui.model.placed.size()<=10: await capture("board")
 check(ui.model.finished and ui.result_panel.visible,"match reaches verdict")
 check(ui.table.cards.size()==18,"18 cards remain visible")
 var enemy_count := 0
 for holder in ui.table.cards.values():
  if holder.get_meta("owner")=="opponent":enemy_count+=1
 check(enemy_count>0,"opponent owns cards")
 var gold: int=Session.gold
 check(gold>0,"match earns gold")
 await capture("verdict")
 ui._return_to_main();await settle()
 await click(current_scene.action_buttons.shop)
 check(current_scene.name=="Shop" and Session.gold==gold,"shop preserves session currency")
 check(current_scene.buttons.remnant.disabled,"insufficient gold disabled")
 Session.gold=60;current_scene._refresh()
 await click(current_scene.buttons.remnant)
 check("remnant" in Session.unlocked and Session.gold==0,"purchase through UI")
 await click(current_scene.buttons.remnant)
 check(Session.selected=="remnant","equip through UI")
 await capture("shop")
 change_scene_to_file("res://scenes/card_book.tscn");await settle()
 current_scene._show_owners();await settle()
 check(current_scene.owner_panel.visible,"book magnifier shows deck owners")
 await capture("owners")
 key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
 check(not current_scene.owner_panel.visible,"owner panel closes first")
 print("TABLE GAME UI PASS: ",checks," checks")
 quit()
