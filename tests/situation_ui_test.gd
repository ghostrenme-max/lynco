extends SceneTree

var ui: Control
var output := "res://test-results/"

func _initialize() -> void:
 call_deferred("run")

func check(value: bool, description: String) -> void:
 if not value:
  push_error(description)
  quit(1)
  assert(value,description)

func capture(filename: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+filename+".png")

func run() -> void:
 if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 create_timer(55).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 await create_timer(1).timeout
 check(ui.hud_values.placed.text==str(ui.model.placed.size()),"table aggregate")
 check(ui.remaining_label.text=="%02d" % int(ui.model.rules.max_turns),"remaining turns, not energy")
 check(ui.round_badge.text=="R1","first round")
 check(ui.turn_caption.text.contains("내 차례"),"player state")
 check(ui.hud_values.energy.text=="%02d" % ui.model.energy,"energy remains available")
 root.size=Vector2i(1600,900)
 await create_timer(0.4).timeout
 await capture("situation_1600")
 root.size=Vector2i(1280,720)
 await create_timer(0.4).timeout
 await capture("situation_1280")
 var turn: int=ui.model.turn
 var point: Vector2=ui.end_button.get_global_rect().get_center()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
  root.push_input(event,true)
 await process_frame
 check(ui.busy,"circle click starts turn")
 check(not ui.situation_symbols.compressions.is_empty(),"end-turn click starts compression immediately")
 check(ui.model.turn==turn and not ui.opponent_turn_active,"burst precedes model advance")
 ui._end_turn()
 var burst_frames:=0
 while ui.situation_symbols.is_burst_active():
  check(ui.model.turn==turn and ui.discard_phase=="idle","battle and cards wait for burst completion")
  burst_frames+=1
  await process_frame
 check(burst_frames>1,"burst has a visible pre-transition interval")
 while not ui.opponent_turn_active:await process_frame
 check(ui.turn_caption.text.contains("상대 차례"),"opponent state")
 check(ui.end_button.disabled,"duplicate input disabled")
 await capture("situation_opponent")
 while ui.busy:await process_frame
 check(ui.model.turn==turn+1,"turn advances once")
 check(ui.turn_track.occupied==ui.model.turn-1,"track follows turns")
 check(ui.hud_values.placed.text==str(ui.model.placed.size()),"placement aggregate refreshes")
 check(ui.remaining_label.text=="%02d" % (int(ui.model.rules.max_turns)-ui.model.turn+1),"remaining refreshes")
 await create_timer(0.4).timeout
 await capture("situation_next_turn")
 ui.model.finished=true;ui._sync_ui()
 check(ui.end_button.disabled and ui.remaining_label.text=="00","finished state")
 ui.situation_symbols.set_turns(30,30)
 ui.turn_track.reduced_motion=true
 ui.turn_track.set_progress(29,30)
 check(ui.turn_track.impact==0.0,"reduced motion disables impact")
 await capture("situation_30_turns")
 print("SITUATION_UI_PASS")
 quit()
