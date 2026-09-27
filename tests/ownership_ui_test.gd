extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/ownership_"+name+".png")==OK,"capture")
func run() -> void:
 create_timer(65).timeout.connect(func():push_error("ownership timeout");quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 check(not ui.table.battle_grid.visible and not ui.table.mirror_grid.visible,"idle table has no grid")
 ui.table.preview(ui.table.screen_position(Vector2i(2,1)),true)
 check(ui.table.battle_grid.visible,"placement preview reveals grid")
 ui.table.hide_preview()
 check(not ui.table.battle_grid.visible,"empty preview exit hides grid")
 ui.reduced_motion=true
 await ui._activate_card(ui.model.hand[0].uid,Vector2i(2,1))
 await ui._end_turn()
 await create_timer(0.2).timeout
 var table=ui.table
 var enemy_cell:=Vector2i(-1,-1)
 var own_cell:=Vector2i(-1,-1)
 for cell in table.cards:
  var holder: Node3D=table.cards[cell]
  var enemy: bool=holder.get_meta("owner")=="opponent"
  check(is_zero_approx(wrapf(holder.rotation.y,0,TAU)),"both owners readable upright")
  check(is_equal_approx(wrapf(table.mirror_cards[cell].rotation.y,0,TAU),PI),"mirror owner orientation")
  check(holder.get_node("OwnerMark").global_position.z>holder.global_position.z,"mark visible below both orientations")
  check(not holder.has_node("OwnerPlate"),"old owner frames removed")
  check(holder.get_node("OwnerMark").get_child_count()==(5 if enemy else 1),"opponent red dashes and side stripe or own solid mark")
  if enemy:
   check(holder.get_node("OwnerMark/OwnerSide").material_override==table.opponent_mark_material,"opponent stripe uses dedicated color")
  check(holder.get_node("Front").material_override.albedo_texture==table.mirror_cards[cell].get_node("Front").material_override.albedo_texture,"mirror material shared")
  if enemy and not ui.Catalog.card(holder.get_meta("card_id")).dark:enemy_cell=cell
  if not enemy:own_cell=cell
 check(enemy_cell!=table.INVALID and own_cell!=table.INVALID,"both owners present")
 check(table.get_node("Table/Tabletop").mesh.surface_get_material(0).albedo_color.a==1.0,"near table opaque")
 check(is_equal_approx(table.get_node("OpponentTable/Tabletop").material_override.albedo_color.a,0.84),"far table translucent")
 check(is_equal_approx(table.get_node("BetweenTablesShade").position.z,-8.9),"soft shade centered in gap")
 for cell in table.mirror_cards:
  check(is_equal_approx(table.mirror_cards[cell].get_node("Front").material_override.albedo_color.a,0.84),"far cards translucent")
  check(table.cards[cell].get_node("Front").material_override.albedo_color.a==1.0,"near cards remain opaque")
 var expected_mask:=0
 for cell in table.cards:
  if table.cards[cell].get_meta("owner")=="opponent":expected_mask |= 1 << (cell.y*table.COLS+cell.x)
 check(table.battle_grid_material.get_shader_parameter("opponent_mask")==expected_mask,"red cells match opponent occupancy")
 check(table.battle_grid.material_override==table.mirror_grid.material_override,"mirror grid shares logical occupancy")
 table.set_top_view(true)
 check(table.battle_grid.visible and not table.mirror_grid.visible,"top view grid without mirror")
 table.set_top_view(false)
 var id: String=table.cards[enemy_cell].get_meta("card_id")
 var normal: StandardMaterial3D=table.materials[id]
 var dim: StandardMaterial3D=table.materials["opponent:"+id]
 var original: Image=normal.albedo_texture.get_image()
 var darkened: Image=dim.albedo_texture.get_image()
 check(darkened.get_pixel(22,130).r<original.get_pixel(22,130).r,"background darker")
 var protected_pixels:=0
 var changed_ink:=0
 for y in range(24,380):
  for x in range(20,294):
   var ink: Color=original.get_pixel(x,y)
   if ink.a>0.99 and ink.r<0.12 and ink.g<0.12 and ink.b<0.12 and ink==original.get_pixel(x-1,y) and ink==original.get_pixel(x+1,y) and ink==original.get_pixel(x,y-1) and ink==original.get_pixel(x,y+1):
    var after: Color=darkened.get_pixel(x,y)
    if after.r>ink.r+0.004 or after.g>ink.g+0.004 or after.b>ink.b+0.004 or after.a<0.99:changed_ink+=1
    protected_pixels+=1
 print("INK_COMPARE interior=",protected_pixels," changed=",changed_ink)
 check(changed_ink==0,"foreground stays opaque and does not fade into background")
 check(protected_pixels>100,"text and symbol pixels checked")
 # The larger HUD covers some far-row cells. Use an exposed card for input,
 # while keeping the original texture fixture above for the pixel comparison.
 enemy_cell=table.INVALID
 for cell in table.cards:
  var candidate: Node3D=table.cards[cell]
  if candidate.get_meta("owner")=="opponent" and not ui.Catalog.card(candidate.get_meta("card_id")).dark and not ui.turn_board.get_rect().has_point(table.screen_position(cell)):
   enemy_cell=cell
 check(enemy_cell!=table.INVALID,"opponent input target is not behind HUD")
 id=str(table.cards[enemy_cell].get_meta("card_id"))
 normal=table.materials[id]
 dim=table.materials["opponent:"+id]
 var state: String=JSON.stringify([ui.model.placed,ui.model.energy,ui.model.player_score,ui.model.opponent_score,ui.model.rng.state])
 root.size=Vector2i(1280,720)
 await process_frame
 ui._test_pointer(Vector2(350,105));await create_timer(0.15).timeout
 await capture("board_1280")
 ui._test_pointer(table.screen_position(enemy_cell))
 await create_timer(0.1).timeout
 check(table.cards[enemy_cell].get_node("Front").material_override==normal,"mouse hover restores background")
 check(table.mirror_cards[enemy_cell].get_node("Front").material_override==table._far_material(normal),"mirror hover sync")
 await capture("hover_1280")
 ui._test_pointer(Vector2(350,105));await create_timer(0.1).timeout
 check(table.cards[enemy_cell].get_node("Front").material_override==dim,"leave restores dim")
 var detail_point: Vector2=ui.stage.get_global_transform_with_canvas()*table.screen_position(enemy_cell)
 var detail_event:=InputEventMouseButton.new()
 detail_event.button_index=MOUSE_BUTTON_RIGHT;detail_event.pressed=true;detail_event.position=detail_point
 root.push_input(detail_event,true)
 detail_event=InputEventMouseButton.new()
 detail_event.button_index=MOUSE_BUTTON_RIGHT;detail_event.position=detail_point
 root.push_input(detail_event,true)
 await process_frame
 check(ui.inspector_open and ui.preview_kind.text.begins_with("상대 카드"),"owner in inspector")
 check(is_zero_approx(ui.inspector_card.rotation),"inspector readable upright")
 await capture("inspector_1280")
 ui._close_inspector()
 check(state==JSON.stringify([ui.model.placed,ui.model.energy,ui.model.player_score,ui.model.opponent_score,ui.model.rng.state]),"display never mutates model")
 var nodes: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 for i in range(80):table.set_hover_card(enemy_cell);table.set_hover_card(table.INVALID)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"hover reuses nodes/materials")
 var holder: Node3D=table.cards[enemy_cell]
 var finish: Vector3=holder.position
 var start: Vector3=finish+Vector3(2,3,-5)
 var slide: Tween=table._slide_opponent(holder,start,finish,false)
 for child in holder.get_children():
  if str(child.name).begins_with("Direction_"):check(not child.visible,"directions hidden while opponent card flies")
 check(table.battle_grid.visible,"grid visible during delivery")
 var samples:=0
 while slide.is_running():
  check((holder.position-start).cross(finish-start).length()<0.0001,"strict straight path")
  check(holder.rotation.is_equal_approx(Vector3.ZERO),"upright throughout insertion")
  samples+=1
  await process_frame
 check(samples>3 and holder.position.is_equal_approx(finish),"fast insertion reaches target")
 check(table.battle_grid.visible,"grid remains after landing")
 check(holder.get_node("ContactShadow").visible and holder.get_node("OwnerMark").visible,"contact feedback at stop")
 for child in holder.get_children():
  if str(child.name).begins_with("Direction_"):check(child.visible,"directions appear after landing")
 var empty:=Vector2i(5,4)
 await create_timer(0.16).timeout
 check(holder.scale.is_equal_approx(Vector3.ONE),"opponent landing settles before next placement")
 table.place("guard",empty,false)
 check(table.mirror_cards[empty].position.is_equal_approx(table.mirror_position(empty)),"mirror copy appears immediately")
 check(table.animations.size()==1,"only own local landing is animated")
 await ui._restart(20260926)
 check(table.hovered_cell==table.INVALID and table.cards.is_empty() and table.mirror_cards.is_empty(),"reset cleanup")
 check(not table.battle_grid.visible and not table.mirror_grid.visible,"restart hides empty grid")
 print("OWNERSHIP_UI_PASS checks=",checks," protected_ink_pixels=",protected_pixels)
 quit()
