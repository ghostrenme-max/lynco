extends SceneTree

var ui: Control
var checks: int = 0

func _initialize() -> void:
 call_deferred("_run")

func check(ok: bool, message: String) -> void:
 if not ok:
  push_error("DIRECTION TEST FAILED: "+message)
  quit(1)
  assert(ok,message)
 checks+=1

func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/"+name+".png")==OK,"capture")

func _run() -> void:
 create_timer(70).timeout.connect(func():push_error("Direction test timeout");quit(1))
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 ui._test_pointer(Vector2(350,105))
 await create_timer(0.2).timeout
 check(not ui.hover_direction.visible and not ui.hover_direction.is_processing(),"idle hidden/inactive")
 var uid:int=int(ui.model.hand[1].uid)
 var point:Vector2=ui.views[uid].rest_position+ui.Card.CARD_SIZE*0.5
 ui._test_pointer(point)
 await create_timer(0.3).timeout
 check(not ui.hover_direction.visible,"no early hover")
 ui._test_pointer(Vector2(350,105))
 await create_timer(0.3).timeout
 check(not ui.hover_direction.visible,"leave cancels delay")
 ui._test_pointer(point)
 await create_timer(0.54).timeout
 check(ui.hover_direction.visible,"visible after 0.5 seconds")
 check(ui.hover_direction.modulate.a>0 and ui.hover_direction.modulate.a<1,"fade in")
 await create_timer(0.2).timeout
 check(is_equal_approx(ui.hover_direction.modulate.a,1.0),"fade complete")
 var phase:float=ui.hover_direction.phase
 await create_timer(0.1).timeout
 check(ui.hover_direction.phase!=phase,"outward animation")
 await capture("direction_hover_1440")
 var snapshot:String=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.turn,ui.model.discard,ui.model.rng.state])
 ui._test_inspect_card(uid)
 check(ui.inspector_open and not ui.hover_direction.visible,"inspector cancels hover")
 check(ui.inspector_card.get_global_rect().get_center().distance_to(root.get_visible_rect().size*0.5)<1,"card stays centered")
 check(ui.inspector_demo.get_global_rect().position.x>ui.inspector_card.get_global_rect().end.x,"demo right of card")
 check(ui.inspector_diagram.is_processing(),"demo animated")
 await capture("direction_inspector_1440")
 # Clicking within the demo must neither close the modal nor play a card.
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
 event.position=ui.inspector_demo.get_global_rect().get_center()
 root.push_input(event,true)
 check(ui.inspector_open,"demo click preserves modal")
 event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
 root.push_input(event,true)
 root.size=Vector2i(1280,720)
 await create_timer(0.2).timeout
 check(root.get_visible_rect().encloses(ui.inspector_demo.get_global_rect()),"demo fits minimum size")
 await capture("direction_inspector_1280")
 ui._close_inspector()
 check(not ui.inspector_diagram.is_processing(),"hidden demo stops")
 check(snapshot==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.turn,ui.model.discard,ui.model.rng.state]),"preview changes no rules or RNG")
 ui.reduced_motion=true
 ui._test_inspect_card(uid)
 check(not ui.inspector_diagram.is_processing(),"reduced motion respected")
 ui._close_inspector();ui.reduced_motion=false
 await ui._shift_requested()
 uid=int(ui.model.hand[0].uid)
 ui._test_pointer(ui.views[uid].rest_position+ui.Card.CARD_SIZE*0.5)
 await create_timer(0.8).timeout
 check(not ui.hover_direction.visible,"concealed direction does not leak")
 ui._test_pointer(Vector2(350,105))
 # Render-only placements verify shared materials, direction orientation and cleanup.
 ui.table.clear_cards()
 ui.table.place("observe",Vector2i(2,1))
 ui.table.place("link",Vector2i(4,1))
 await create_timer(0.3).timeout
 var holder:Node3D=ui.table.cards[Vector2i(2,1)]
 check(holder.has_node("Direction_up") and holder.has_node("Direction_right"),"table directions")
 check(is_equal_approx(holder.get_node("Direction_right").rotation.y,-PI*0.5),"right arrow orientation")
 check(holder.get_node("Direction_right").material_override==ui.table.direction_material,"shared material")
 ui.motion_toggle.button_pressed=true
 check(ui.table.direction_material.get_shader_parameter("reduced_motion"),"live motion toggle")
 ui.motion_toggle.button_pressed=false
 check(not ui.table.direction_material.get_shader_parameter("reduced_motion"),"live motion resumes")
 ui.table.preview(ui.table.screen_position(Vector2i(3,1)),true)
 check(ui.table.hint_material.get_shader_parameter("tint")==Color(1.0,0.84,0.26,1.0),"yellow placement preserved")
 await capture("direction_table_1280")
 ui._test_pointer(ui.table.screen_position(Vector2i(2,1)))
 await create_timer(0.75).timeout
 check(ui.hover_direction.visible,"placed-card hover")
 await capture("direction_placed_hover_1280")
 ui._test_pointer(Vector2(350,105))
 check(not ui.hover_direction.visible,"placed-card hover exit")
 ui.table.clear_cards()
 await process_frame
 check(ui.table.cards.is_empty() and not is_instance_valid(holder),"direction nodes cleaned with cards")
 check(ui.Directions.OFFSETS.size()==8,"four cardinal and four diagonal endpoints")
 var definition: Dictionary=ui.Catalog.CARDS.observe.duplicate(true)
 definition["directions"]=ui.Directions.OFFSETS.keys()
 check(ui.Directions.for_definition(definition).size()==8,"definitions accept all eight directions")
 ui.table.place("observe",Vector2i(2,2),true)
 for offset in ui.Directions.OFFSETS.values():ui.table.place("guard",Vector2i(2,2)+Vector2i(offset),true)
 await create_timer(0.3).timeout
 ui.table.selected_cell=Vector2i(2,2)
 for key in ui.Directions.for_definition(definition):
  var neighbor: Vector2i=Vector2i(2,2)+Vector2i(ui.Directions.OFFSETS[key])
  ui.table.influence_range.append(neighbor)
  ui.table.influenced_cells.append(neighbor)
 ui.table._show_influence_links()
 ui.table._refresh_battle_grid()
 check(ui.table.influence_range.size()==8 and ui.table.influenced_cells.size()==8,"all diagonal neighbors supported")
 check(ui.table.influence_links.filter(func(link):return link.visible).size()==16,"eight directions on both tables")
 ui.table.clear_cards()
 ui.turn_track.wave_clock=0.6
 ui.turn_track.set_progress(12,30)
 check(is_equal_approx(ui.turn_track.wave_clock,0.6),"counter changes do not restart five-second wave")
 await capture("turn_wave_mid")
 ui.turn_track.wave_clock=4.99
 ui.turn_track._process(0.02)
 check(is_equal_approx(ui.turn_track.wave_clock,0.01),"wave repeats after five seconds")
 ui._set_reduced_motion(true)
 check(ui.turn_track.reduced_motion,"reduced motion suppresses decorative wave")
 print("LYNCO_DIRECTION_UI_PASS checks=%d delay_fade_cancel hidden_guard center_right_demo resizing animation_pause unchanged_rules yellow_placement magenta_directions cleanup" % checks)
 quit()
