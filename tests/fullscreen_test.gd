extends SceneTree
func _initialize() -> void:call_deferred("run")
func press_l() -> void:
 for pressed in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=KEY_L;event.physical_keycode=KEY_L;event.pressed=pressed
  root.push_input(event,true)
func run() -> void:
 for scene in ["main_menu","card_book","shop"]:
  var path: String="res://scenes/"+scene+".tscn"
  if not ResourceLoader.exists(path):continue
  change_scene_to_file(path);await scene_changed
  press_l();await create_timer(0.15).timeout
  assert(root.mode==Window.MODE_FULLSCREEN,"fullscreen in "+scene)
  press_l();await create_timer(0.15).timeout
  assert(root.mode==Window.MODE_WINDOWED,"restore in "+scene)
  print("GLOBAL_FULLSCREEN_SCENE_PASS ",scene)
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var old_size: Vector2i=root.size
 var old_position: Vector2i=root.position
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state])
 press_l()
 await create_timer(0.3).timeout
 assert(root.mode==Window.MODE_FULLSCREEN)
 assert(root.size==DisplayServer.screen_get_size(root.current_screen))
 press_l()
 await create_timer(0.3).timeout
 assert(root.mode==Window.MODE_WINDOWED and root.size==old_size and root.position==old_position)
 ui.table.set_top_view(true);ui.stage.hide()
 press_l();await create_timer(0.2).timeout
 assert(root.mode==Window.MODE_FULLSCREEN and ui.table.top_view)
 press_l();await create_timer(0.2).timeout
 assert(root.mode==Window.MODE_WINDOWED and ui.table.top_view)
 assert(snapshot==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state]))
 print("FULLSCREEN_PASS monitor=",DisplayServer.screen_get_size(root.current_screen)," restored=",root.size," top_view_preserved")
 quit()
