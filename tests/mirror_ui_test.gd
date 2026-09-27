extends SceneTree
var ui: Control
var checks := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://test-results/mirror_"+name+".png")==OK,"capture")
func settle() -> void:
 for i in range(4):await process_frame
func run() -> void:
 create_timer(80).timeout.connect(func():push_error("mirror timeout");quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var table=ui.table
 check(is_equal_approx(table.get_node("OpponentTable").position.z,-17.8),"two separated tables")
 for prop in table.get_node("DummyProps").get_children():
  check(absf(prop.position.x)-prop.scale.x*0.5>11.25,"props outside table footprints")
 check(table.get_node("Table/Tabletop").mesh.size.x==22.5 and table.get_node("OpponentTable/Tabletop").mesh.size.x==22.5,"both tables 1.5x wide")
 check(table.opponent_fan.size()==7,"reusable fan pool")
 for card in table.opponent_fan:
  check(card.get_node("Front").material_override==table.opponent_back_material and table.opponent_back_material.albedo_texture==null and table.opponent_back_material.albedo_color==Color.BLACK,"common hidden hand")
 await capture("player_1440")
 root.size=Vector2i(1280,720);await settle()
 for y in range(5):
  for x in range(6):
   var cell:=Vector2i(x,y)
   check(table.cell_at(table.screen_position(cell))==cell,"all 30 cells project and hit")
 await capture("player_1280")
 var uid: int=ui.model.hand[0].uid
 var id: String=ui.model.hand[0].id
 var energy: int=ui.model.energy
 await ui._activate_card(uid,Vector2i(2,1))
 await create_timer(0.5).timeout
 check(ui.model.placed.size()==1 and table.cards.size()==1 and table.mirror_cards.size()==1,"one logical card two views")
 check(ui.model.player_score==int(ui.Catalog.TABLE_VALUES[id]),"score once")
 check(ui.model.energy==energy-int(ui.Catalog.card(id).cost)+(1 if id=="cycle" else 0),"cost once")
 var far=table.mirror_cards[Vector2i(2,1)]
 check(far.position.is_equal_approx(table.mirror_position(Vector2i(2,1))),"rotated mirror mapping")
 check(far.get_node("Front").material_override.albedo_texture==table.cards[Vector2i(2,1)].get_node("Front").material_override.albedo_texture,"shared textures")
 table.pan_by(Vector2(1,0),0.1)
 table.look_by(Vector2(6,3))
 var saved_position: Vector3=table.camera.position
 var saved_rotation: Vector3=table.camera.rotation
 ui._end_turn()
 while not table.opponent_view:await process_frame
 await create_timer(0.5).timeout
 check(ui.busy and table.opponent_view,"opponent turn camera")
 check(table.camera.position.is_equal_approx(table.opponent_camera_position),"opponent focus")
 check(table.cell_at(Vector2(800,350))==table.INVALID,"opponent view cannot place")
 await capture("opponent_1280")
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy])
 await ui._fill_requested();await ui._shift_requested();await ui._end_turn()
 check(snapshot==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy]),"input blocked during opponent turn")
 while ui.busy:await process_frame
 await create_timer(0.15).timeout
 check(not table.opponent_view and table.camera.position.is_equal_approx(saved_position) and table.camera.rotation.is_equal_approx(saved_rotation),"restore player custom view")
 check(table.cards.size()==table.mirror_cards.size() and table.cards.size()==ui.model.placed.size(),"all opponent placements mirrored")
 for cell in table.cards:
  check(table.cards[cell].get_meta("owner")==table.mirror_cards[cell].get_meta("owner"),"same ownership")
 table.reset_look()
 await capture("returned_1280")
 ui.reduced_motion=true
 await ui._restart(20260926);await settle()
 var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 for i in range(8):
  await ui._end_turn()
  await ui._restart(20260926)
  await settle()
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"repeated turns/restarts stable nodes")
 check(table.cards.is_empty() and table.mirror_cards.is_empty() and table.animations.is_empty(),"restart clears both views and flights")
 print("MIRROR_UI_PASS checks=",checks," nodes=",nodes,"/",nodes)
 quit()
