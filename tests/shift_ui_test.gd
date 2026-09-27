extends SceneTree
var ui: Control

func _initialize() -> void:
 call_deferred("_run")

func _key(code: Key) -> void:
 var key := InputEventKey.new()
 key.keycode=code;key.pressed=true
 root.push_input(key,true)
 key=InputEventKey.new();key.keycode=code;key.pressed=false
 root.push_input(key,true)

func _idle() -> void:
 while ui.busy: await process_frame
 await create_timer(0.16).timeout

func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://test-results/"+name+".png") == OK)

func _run() -> void:
 var watchdog := Timer.new()
 watchdog.wait_time=75;watchdog.one_shot=true
 watchdog.timeout.connect(func():push_error("Shift UI timeout");quit(1))
 root.add_child(watchdog);watchdog.start()
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.views.is_empty() or ui.busy: await process_frame
 assert(ui.model.hand.size()==5)
 assert(not ui.identity_counter.visible)
 await _capture("counts_front_hidden")
 ui.seed_box.grab_focus()
 _key(KEY_SHIFT)
 assert(not ui.busy and ui.shuffle_phase=="idle")
 ui.seed_box.release_focus()
 var initial: Array = ui.model.hand.map(func(entry):return entry.uid)
 _key(KEY_SHIFT)
 assert(ui.busy and ui.shuffle_phase=="gather")
 assert(ui.identity_counter.visible)
 _key(KEY_SHIFT);_key(KEY_E)
 assert(ui.model.hand.size()==5)
 while ui.shuffle_phase=="gather":await process_frame
 await _capture("shift_center")
 await _idle()
 var shuffled: Array=ui.model.hand.map(func(entry):return entry.uid)
 initial.sort();shuffled.sort();assert(initial==shuffled)
 for view in ui.views.values():
  assert(view.concealed and not view.face_up)
  assert(view.back_logo.texture==ui.textures.back_black)
  assert(view.outline_style.bg_color==Color("181a19"))
  assert(view.reason_label.text.is_empty())
  for item in view.face_nodes:assert(not item.visible)
 await _capture("shift_hidden_1440")
 var uid: int=int(ui.model.hand[0].uid)
 ui._test_inspect_card(uid)
 assert(not ui.inspector_open)
 assert(ui.identity_counter.visible)
 assert(ui.identity_counter.position==Vector2(345,550))
 assert(ui.identity_counter.get_child(0).texture.resource_path.ends_with("count_king.svg"))
 assert(ui.identity_counter.get_child(1).texture.resource_path.ends_with("count_joker.svg"))
 assert(ui.king_count.text=="킹 %d" % int(ui.model.identity_counts().king))
 assert(ui.joker_count.text=="조커 %d" % int(ui.model.identity_counts().joker))
 var resources: Array=[ui.model.energy,ui.model.health,ui.model.enemy_health,ui.model.block]
 var point: Vector2=ui.views[uid].rest_position+ui.Card.CARD_SIZE*0.5
 ui._test_pointer(point,true)
 await _idle()
 assert(ui.model.find_card(uid)<0 and ui.model.hand.size()==4)
 assert(resources==[ui.model.energy,ui.model.health,ui.model.enemy_health,ui.model.block])
 assert(ui.table.cards.size()==1)
 assert(ui.king_count.text=="킹 %d" % int(ui.model.identity_counts().king))
 assert(ui.joker_count.text=="조커 %d" % int(ui.model.identity_counts().joker))
 var holder: Node=ui.table.cards.values()[0]
 assert(holder.get_meta("reverse"))
 ui._inspect_placed(str(holder.get_meta("card_id")),true)
 assert(ui.inspector_open)
 assert(ui.preview_text.text.contains("효과와 비용은 적용하지 않습니다"))
 await _capture("shift_revealed")
 _key(KEY_E);_key(KEY_SHIFT)
 assert(ui.model.hand.size()==4 and ui.inspector_open)
 ui._close_inspector()
 var old_ids: Array=ui.model.hand.map(func(entry):return entry.uid)
 _key(KEY_E)
 await _idle()
 assert(ui.model.hand.size()==5 and ui.model.conserved())
 var counts: Dictionary=ui.model.identity_counts()
 assert(int(counts.king)+int(counts.joker)>=1)
 for entry in ui.model.hand:
  assert(ui.model.is_concealed(entry.uid)==old_ids.has(entry.uid))
  assert(ui.views[entry.uid].face_up==not old_ids.has(entry.uid))
 var snapshot: String=JSON.stringify([ui.model.hand,ui.model.deck])
 _key(KEY_E);await _idle()
 assert(snapshot==JSON.stringify([ui.model.hand,ui.model.deck]))
 await _capture("shift_refill_mixed")
 root.size=Vector2i(1280,720)
 await create_timer(0.2).timeout
 _key(KEY_SHIFT);await _idle()
 await _capture("shift_hidden_1280")
 for identity in ["king","joker"]:
  var special_uid: int=-1
  for entry in ui.model.hand:
   if ui.Catalog.back_identity(entry.id)==identity: special_uid=int(entry.uid);break
  assert(special_uid>=0)
  point=ui.views[special_uid].rest_position+ui.Card.CARD_SIZE*0.5
  ui._test_pointer(point,true)
  await _idle()
  var placed: Node=ui.table.cards.values()[-1]
  assert(ui.Catalog.back_identity(str(placed.get_meta("card_id")))==identity)
  ui._inspect_placed(str(placed.get_meta("card_id")),true)
  assert(ui.preview_icon.texture==ui.Symbols.SPECIAL[identity][1])
  assert(ui.preview_icon.material==null)
  await _capture("shift_"+identity+"_revealed")
  ui._close_inspector()
 await ui._end_turn()
 assert(ui.model.hand.size()==5)
 for entry in ui.model.hand:assert(not ui.model.is_concealed(entry.uid))
 assert(not ui.identity_counter.visible)
 await _capture("counts_next_turn_hidden")
 # Count panel disappears when the last hidden card is revealed.
 _key(KEY_SHIFT);await _idle()
 while not ui.model.hand.is_empty():
  await ui._activate_card(int(ui.model.hand[0].uid))
 assert(not ui.identity_counter.visible)
 _key(KEY_E);await _idle()
 assert(not ui.identity_counter.visible)
 _key(KEY_SHIFT);await _idle()
 assert(ui.identity_counter.visible)
 ui.model.finished=true;ui._sync_ui()
 assert(not ui.identity_counter.visible)
 snapshot=JSON.stringify([ui.model.hand,ui.model.deck])
 _key(KEY_E);_key(KEY_SHIFT)
 assert(snapshot==JSON.stringify([ui.model.hand,ui.model.deck]))
 print("LYNCO_SHIFT_UI_PASS keyboard_E_Shift center_shuffle common_cover no_inspection_leak single_click_reveal pending_effects_noop refill_mixed resizing turn_cleanup finished_guard")
 quit()
