extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func button(index: MouseButton, point: Vector2) -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=index;event.pressed=pressed;event.position=point
  root.push_input(event,true)
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
 create_timer(50).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 root.size=Vector2i(1280,720)
 var t=ui.table
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 for cell in [Vector2i(2,1),Vector2i(2,0),Vector2i(3,1),Vector2i(1,1),Vector2i(2,2)]:
  t.place("observe" if cell==Vector2i(2,1) else "guard",cell,true)
  t.mark_owner(cell,"player")
 await create_timer(0.2).timeout
 var old_transform: Transform3D=t.camera.transform
 ui._test_pointer(t.screen_position(Vector2i(2,1)),true)
 check(t.cards[Vector2i(2,1)].get_node("Direction_right").position.x>0.74,"right tab projects outside card")
 check(t.cards[Vector2i(2,1)].get_node("Direction_up").position.z < -1.07,"up tab projects outside card")
 check(t.influence_links.size()==8,"bounded reusable link pool")
 check(t.influence_links.filter(func(link):return link.visible).size()==4,"two targets on two tables")
 check(not ui.inspector_open and t.selected_cell==Vector2i(2,1),"left click selects instead of inspector")
 check(t.influenced_cells.size()==2 and Vector2i(2,0) in t.influenced_cells and Vector2i(3,1) in t.influenced_cells,"up and right only")
 check(not t.cards[Vector2i(2,1)].get_node("InfluenceOverlay").visible,"source stays clear")
 check(t.cards[Vector2i(1,1)].get_node("InfluenceOverlay").material_override==t.influence_dim,"unaffected dims")
 check(t.mirror_cards[Vector2i(3,1)].get_node("InfluenceOverlay").material_override==t.influence_glow,"mirror shares target")
 check(int(t.battle_grid_material.get_shader_parameter("influence_mask"))==((1<<2)|(1<<9)),"actual grid receives up/right range")
 check(t.mirror_grid.material_override==t.battle_grid_material,"mirror shares grid range")
 await capture("influence_perspective")
 button(MOUSE_BUTTON_MIDDLE,Vector2(600,300))
 check(t.influence_links.filter(func(link):return link.visible).size()==2,"top view hides mirrored links")
 check(t.top_view and not ui.stage.visible,"MMB hides HUD in top view")
 check(t.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and is_equal_approx(t.camera.rotation.x,-PI/2),"vertical orthographic camera")
 check(not t.get_node("DummyProps").visible and not t.get_node("OpponentTable").visible and not t.get_node("Floor").visible,"table and cards only")
 for y in range(5):
  for x in range(6):
   var cell:=Vector2i(x,y)
   check(t.cell_at(t.screen_position(cell))==cell,"top view hit mapping")
 await RenderingServer.frame_post_draw
 var top_image: Image=root.get_texture().get_image()
 for corner in [Vector2i(1,1),Vector2i(1278,1),Vector2i(1,718),Vector2i(1278,718)]:
  var color: Color=top_image.get_pixelv(corner)
  check(maxf(color.r,maxf(color.g,color.b))<0.3,"top corners are black board, never beige")
 await capture("influence_top_1280")
 var fit_size: float=t.camera.size
 button(MOUSE_BUTTON_WHEEL_UP,Vector2(600,300))
 check(t.camera.size<fit_size,"wheel up zooms in")
 button(MOUSE_BUTTON_WHEEL_DOWN,Vector2(600,300))
 check(is_equal_approx(t.camera.size,fit_size),"wheel down zooms out")
 for i in range(50):button(MOUSE_BUTTON_WHEEL_UP,Vector2(600,300))
 check(is_equal_approx(t.top_zoom,0.35),"zoom in bounded")
 check(t.cell_at(t.screen_position(Vector2i(2,1)))==Vector2i(2,1),"zoomed card hit mapping")
 await capture("influence_top_zoom")
 for i in range(70):button(MOUSE_BUTTON_WHEEL_DOWN,Vector2(600,300))
 check(is_equal_approx(t.top_zoom,1.0),"zoom out bounded")
 t.top_zoom=1.0;t._fit_top_view()
 button(MOUSE_BUTTON_LEFT,t.camera.unproject_position(t.cell_position(Vector2i(2,1))))
 check(t.selected_cell==t.INVALID,"second click deselects")
 check(int(t.battle_grid_material.get_shader_parameter("influence_mask"))==0,"deselect clears grid range")
 check(t.influence_links.all(func(link):return not link.visible),"deselect clears every link")
 button(MOUSE_BUTTON_LEFT,t.camera.unproject_position(t.cell_position(Vector2i(2,1))))
 t.mark_owner(Vector2i(2,1),"opponent")
 t.select_influence(t.INVALID);t.select_influence(Vector2i(2,1))
 check(Vector2i(2,0) in t.influenced_cells and Vector2i(3,1) in t.influenced_cells,"upright opponent directions match visible tabs")
 root.size=Vector2i(800,720);await process_frame
 check(t.camera.size>16,"narrow aspect fits whole table")
 button(MOUSE_BUTTON_MIDDLE,Vector2(400,300))
 check(not t.top_view and ui.stage.visible and t.camera.transform.is_equal_approx(old_transform),"MMB restores exact camera and HUD")
 root.size=Vector2i(1280,720);await process_frame
 var p: Vector2=ui.stage.get_global_transform_with_canvas()*t.screen_position(Vector2i(2,1))
 button(MOUSE_BUTTON_RIGHT,p)
 check(ui.inspector_open,"right click retains placed detail")
 ui._close_inspector()
 t.place("observe",Vector2i(4,3),true);t.mark_owner(Vector2i(4,3),"player")
 t.select_influence(t.INVALID);t.select_influence(Vector2i(4,3))
 check(t.influenced_cells.is_empty() and t.influence_range.size()==2,"empty cells still show range")
 check(int(t.battle_grid_material.get_shader_parameter("influence_mask"))==((1<<16)|(1<<23)),"empty grid cells highlighted")
 t.set_top_view(true);ui.stage.hide()
 await create_timer(0.2).timeout
 await capture("grid_influence_empty")
 t.place("observe",Vector2i(5,0),true);t.mark_owner(Vector2i(5,0),"player")
 t.select_influence(Vector2i(5,0))
 check(t.influence_range.is_empty(),"edge range never wraps outside board")
 t.set_top_view(false);ui.stage.show()
 var nodes: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 for i in range(40):
  t.select_influence(Vector2i(2,1));t.select_influence(t.INVALID)
  button(MOUSE_BUTTON_MIDDLE,Vector2(600,300));button(MOUSE_BUTTON_MIDDLE,Vector2(600,300))
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"repeated selection/top toggles reuse nodes")
 check(snapshot==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"preview leaves rules and RNG unchanged")
 await ui._restart(20260926)
 check(t.selected_cell==t.INVALID and t.influenced_cells.is_empty(),"restart clears influence")
 print("INFLUENCE_TOP_PASS checks=",checks)
 quit()
