extends SceneTree
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func snapshot(world: Node3D) -> Array:
 var result: Array=[]
 for key in ["Table","OpponentTable"]:
  var table:=world.get_node(key)
  result.append(table.transform)
  for node in table.get_children():
   result.append([node.name,node.transform])
   if node is MeshInstance3D:result.append(node.mesh.size)
   if node is StaticBody3D:result.append([node.get_node("Shape").transform,node.get_node("Shape").shape.size])
 return result
func render() -> Image:
 for i in range(4):await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run() -> void:
 create_timer(45).timeout.connect(func():quit(1))
 var original: Node3D=load("res://scenes/table_world.tscn").instantiate()
 var before:=snapshot(original);original.free()
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var world: Node3D=ui.table
 var cloth: Node3D=world.get_node("Tablecloths")
 var meshes:=cloth.find_children("*","MeshInstance3D",true,false)
 check(meshes.size()==1,"one continuous static cloth mesh")
 check(world.get_node("Table/Tabletop").mesh.size==Vector3(22.5,0.22,33.2),"continuous table covers both board ends")
 check(cloth.find_children("*","CollisionObject3D",true,false).is_empty(),"cloth cannot block card raycasts")
 check(snapshot(world)==before,"original tables and collisions preserved")
 var silk: StandardMaterial3D=meshes[0].get_surface_override_material(0)
 check(silk==world.get_node("Table/Tabletop").material_override,"same silk on tabletop and cloth")
 check(silk.normal_enabled and silk.normal_texture!=null and silk.roughness_texture!=null,"lit normal and roughness textures loaded")
 check(silk.shading_mode==BaseMaterial3D.SHADING_MODE_PER_PIXEL,"material responds to real lights")
 var verts:=0;var triangles:=0
 for surface in range(meshes[0].mesh.get_surface_count()):
  var data: Array=meshes[0].mesh.surface_get_arrays(surface)
  verts+=data[Mesh.ARRAY_VERTEX].size();triangles+=data[Mesh.ARRAY_INDEX].size()/3
  check(not data[Mesh.ARRAY_TANGENT].is_empty(),"normal map has imported tangent basis")
 check(verts<3000 and triangles<=4400,"bounded static geometry including UV seam splits")
 var bounds: AABB=meshes[0].global_transform*meshes[0].get_aabb()
 check(bounds.end.y<world.battle_grid.global_position.y and bounds.position.y> -3.1,"cloth below cards/grid and above floor")
 var anchor: Marker3D=world.get_node("NPCAnchor")
 check(anchor.position.is_equal_approx(Vector3(0,0.003,-8.9)),"central NPC anchor")
 check(not world.has_node("BetweenTablesShade"),"old gap shade removed")
 check(world.get_node("OpponentTable").get_child_count()==0,"opponent is an empty board anchor, no second table mesh")
 var space: Vector3=anchor.get_meta("reserved_size")
 for y in range(5):
  for x in range(6):
   for point in [world.cell_position(Vector2i(x,y)),world.mirror_position(Vector2i(x,y))]:
    check(absf(point.z-anchor.position.z)>space.z*0.5+1.07,"card footprint stays clear of NPC space")
 ui.stage.hide();root.size=Vector2i(1280,720)
 world.camera.position=Vector3(25,19,23)
 world.camera.look_at(Vector3(0,-0.4,-8.9))
 var lit: Image=await render()
 lit.save_png("res://test-results/continuous_table_detail.png")
 silk.normal_enabled=false
 var flat: Image=await render()
 silk.normal_enabled=true
 check(lit.get_region(Rect2i(520,310,240,80)).get_data()!=flat.get_region(Rect2i(520,310,240,80)).get_data(),"normal map changes actual rendered tabletop")
 cloth.hide();await render()
 var no_cloth_draws:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 cloth.show();await render()
 var cloth_draws:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 check(cloth_draws-no_cloth_draws<=2,"at most two extra material draws for the entire cloth")
 world.set_top_view(true)
 await render()
 check(not cloth.visible,"skirts hidden in top view")
 var zoom: StandardMaterial3D=world.get_node("Table/Tabletop").material_override
 check(zoom.normal_texture==silk.normal_texture and zoom.albedo_texture==silk.albedo_texture,"top view keeps matching silk")
 for y in range(5):
  for x in range(6):
   var cell:=Vector2i(x,y)
   check(world.cell_at(world.screen_position(cell))==cell,"all 30 board cells remain selectable")
 world.set_top_view(false)
 check(cloth.visible and snapshot(world)==before,"return restores cloth without table changes")
 world.reset_look();ui.stage.show()
 var game_image: Image=await render()
 game_image.save_png("res://test-results/continuous_table_game.png")
 print("SILK_TABLECLOTH_PASS checks=",checks," imported_vertices=",verts," triangles=",triangles," added_draw_calls=",cloth_draws-no_cloth_draws)
 quit()
