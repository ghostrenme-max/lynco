extends SceneTree
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func table_snapshot(world: Node3D) -> Array:
 var state: Array=[]
 for key in ["Table","OpponentTable"]:
  var table:=world.get_node(key)
  state.append(table.transform)
  for node in table.get_children():
   state.append([node.name,node.transform])
   if node is MeshInstance3D:state.append(node.mesh.size)
   if node is StaticBody3D:state.append([node.get_node("Shape").transform,node.get_node("Shape").shape.size])
 return state
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/room_"+name+".png")
func run() -> void:
 create_timer(45).timeout.connect(func():quit(1))
 var original: Node3D=load("res://scenes/table_world.tscn").instantiate()
 var baseline:=table_snapshot(original)
 original.free()
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var world: Node3D=ui.table
 check(table_snapshot(world)==baseline,"table meshes, dimensions, transforms and collision unchanged")
 check(world.get_node("TheatreRoom").get_child_count()==20,"14 Blender props, 2 candle lights and 4 restrained chair bounce lights")
 check(world.get_node("TheatreRoom").find_children("*","CollisionObject3D",true,false).is_empty(),"decorations cannot intercept board collision")
 check(world.get_node("Distributors/Shop").position==Vector3(-9.2,0.1,-8.9),"shop distributor preserved")
 check(world.get_node("Distributors/BlackMarket").position==Vector3(9.2,0.1,-8.9),"black market distributor preserved")
 check(world.get_node("Environment").environment.ambient_light_energy<0.1,"dark room ambient")
 check(world.get_node("TableSpot").light_energy>world.get_node("KeyLight").light_energy,"table focus lighting")
 var top_material: Material=world.get_node("Table/Tabletop").material_override
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=resolution
  for i in range(5):await process_frame
  await capture("player_"+str(resolution.x))
 world.set_top_view(true)
 for i in range(5):await process_frame
 check(not world.get_node("TheatreRoom").visible,"props hidden in top view")
 var zoom_material: StandardMaterial3D=world.get_node("Table/Tabletop").material_override
 check(zoom_material.albedo_texture==top_material.albedo_texture,"top view uses the same felt texture")
 check(zoom_material.albedo_color==top_material.albedo_color,"top view retains table color")
 check(zoom_material.shading_mode==top_material.shading_mode,"top view retains table lighting")
 await capture("top")
 world.set_top_view(false)
 for i in range(5):await process_frame
 check(world.get_node("TheatreRoom").visible,"props restored on return")
 check(world.get_node("Table/Tabletop").material_override==top_material,"felt restored after top view")
 check(table_snapshot(world)==baseline,"table unchanged after camera transitions")
 ui.stage.hide()
 world.camera.position=Vector3(27,23,24)
 world.camera.look_at(Vector3(0,0,-8.9))
 await capture("overview")
 world.camera.position=Vector3(-7.8,2.8,3.6)
 world.camera.look_at(Vector3(-13.5,-0.5,-1.8))
 await capture("chair_detail")
 var candles: Array=[]
 for child in world.get_node("TheatreRoom").get_children():
  if child.get_script()==preload("res://scripts/candle_animation.gd"):candles.append(child)
 check(candles.size()==2,"two independently animated candelabras")
 for candle in candles:
  check(candle.is_processing(),"runtime flame processing enabled")
  check(candle.flames.size()==3,"three living flames per candelabra")
  for old in candle.find_children("Flame*","MeshInstance3D",true,false):check(not old.visible,"static flame replaced")
 world.camera.position=Vector3(-9.8,2.6,-2.4)
 world.camera.look_at(Vector3(-13.1,1.7,-6.0))
 await capture("flame_a")
 var before_pixels: PackedByteArray=root.get_texture().get_image().get_data()
 var start_time: float=candles[0].elapsed
 await create_timer(0.4).timeout
 check(candles[0].elapsed>start_time+0.2,"flames advance automatically without manual process calls")
 await capture("flame_b")
 check(before_pixels!=root.get_texture().get_image().get_data(),"actual rendered flame changes over time")
 for candle in candles:
  for i in range(100):
   await process_frame
   # Approved flame controller: base 1.10, smooth wiggle bounded by +/-10.7%.
   check(candle.pool.light_energy>=0.9823 and candle.pool.light_energy<=1.2177,"approved candle glow stays within its bounded wiggle")
 var paused_time: float=candles[0].elapsed
 world.set_top_view(true)
 await create_timer(0.2).timeout
 check(is_equal_approx(candles[0].elapsed,paused_time),"hidden top-view flames pause")
 world.set_top_view(false)
 print("THEATRE_ROOM_PASS checks=",checks)
 quit()
