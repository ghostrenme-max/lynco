extends SceneTree

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var battle:Node=load("res://scenes/battle.tscn").instantiate()
 root.add_child(battle)
 var ui=battle.get_node("Interface")
 # Startup includes baking and warmup before its deferred initial hand.
 while ui.views.is_empty() or ui.busy:await process_frame
 ui._test_pointer(Vector2(350,105))
 await create_timer(0.2).timeout
 var uid:int=int(ui.model.hand[0].uid)
 var data:Dictionary=ui.Catalog.table_card(ui.model.hand[0].id)
 var energy:int=ui.model.energy
 ui._test_inspect_card(uid)
 assert(ui.inspector_open and ui.preview_title.text==str(data.name))
 assert(ui.preview_text.text==str(data.detail))
 assert(ui.preview_effect.text==ui.model.preview(uid))
 ui._close_inspector()
 # Reopening must refresh live affordability, despite skipped hidden updates.
 ui.model.energy=0;ui._sync_ui();ui._test_inspect_card(uid)
 assert(ui.inspector_open)
 assert(ui.preview_effect.text==ui.model.unavailable_reason(uid))
 ui._close_inspector()
 ui.model.energy=energy;ui._sync_ui();ui._test_inspect_card(uid)
 assert(ui.preview_effect.text==ui.model.preview(uid))
 ui._close_inspector()
 # Cached preview must update for state changes within the same grid cell.
 var cell:=Vector2i(2,1)
 var point:Vector2=ui.table.screen_position(cell)
 ui.table.preview(point,true)
 var allowed:Color=ui.table.hint_material.get_shader_parameter("tint")
 ui.table.preview(point,false)
 var rejected:Color=ui.table.hint_material.get_shader_parameter("tint")
 assert(allowed!=rejected and ui.table.hint.visible)
 ui.table.preview(point,true)
 assert(ui.table.hint_material.get_shader_parameter("tint")==allowed)
 ui.table.place(str(ui.model.hand[0].id),cell,true)
 ui.table.preview(point,true)
 assert(ui.table.hint_material.get_shader_parameter("tint")==rejected)
 ui.table.clear_cards();ui.table.preview(point,true)
 assert(ui.table.hint_material.get_shader_parameter("tint")==allowed)
 ui.table.hide_preview();assert(not ui.table.hint.visible)
 # Compare old local-space picking with the stage-space fast path across an
 # expanded fan, including the hovered area outside the neutral hand slots.
 var middle:int=int(ui.model.hand[2].uid)
 ui._test_pointer(ui.views[middle].rest_position+ui.Card.CARD_SIZE*0.5)
 await create_timer(0.2).timeout
 var rng:=RandomNumberGenerator.new();rng.seed=20260926
 for _i in range(2000):
  var sample:=Vector2(rng.randf_range(320,1240),rng.randf_range(580,890))
  for view in ui.views.values():
   assert(view.contains_hand_point(sample)==view._has_point(view.get_transform().affine_inverse()*sample))
 assert(ui.model.conserved())
 print("LYNCO_OPTIMIZATION_TEST_PASS live_inspector same_cell_state occupancy_reset hand_hit_parity")
 quit()
