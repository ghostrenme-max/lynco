extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui = current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty(): await process_frame
 var pile = ui.table.get_node("OpponentCubes")
 var camera_before: Transform3D = ui.table.camera.global_transform
 var original: int = ui.model.cubes.opponent
 var sample = preload("res://scripts/garnet_cube_visual.gd").create_body(0.42)
 assert(sample.get_node("GarnetVisual").mesh == pile.cubes[0].get_node("GarnetVisual").mesh)
 assert(sample.physics_material_override.friction == pile.cubes[0].physics_material_override.friction)
 assert(sample.get_node("GarnetVisual/VioletCore").material_override.emission == Color("a259ff"))
 assert(pile.cubes[0].get_node("GarnetVisual/VioletCore").material_override.emission == Color("21e3c2"))
 sample.free()
 await create_timer(3).timeout
 for cube in pile.cubes:
  assert(absf(cube.position.x)<1.5 and absf(cube.position.z)<1.5 and cube.position.y>0.1,"settled inside cage")
 ui.model.cubes.opponent = original+3; ui._sync_ui()
 var falling: RigidBody3D = pile.cubes.back()
 var initial_y := falling.position.y
 await create_timer(0.25).timeout
 assert(falling.position.y<initial_y,"new cube falls with gravity")
 ui.model.cubes.opponent = 2; ui._sync_ui()
 assert(pile.cubes.size()==2 and pile.offerings.size()==original+1)
 var offered: Node3D = pile.offerings[0]
 var from: Vector3 = offered.position
 await create_timer(0.25).timeout
 assert(offered.position.distance_to(from)>0.1,"offering moves toward NPC")
 for amount in [8,0,6]:
  ui.model.cubes.opponent=amount;ui._sync_ui()
  assert(pile.cubes.size()==amount)
  assert(ui.table.camera.global_transform==camera_before and not ui.busy,"no camera or battle lock")
 await create_timer(3).timeout
 assert(pile.offerings.is_empty(),"all offerings removed")
 for cube in pile.cubes:
  assert(absf(cube.position.x)<1.5 and absf(cube.position.z)<1.5 and cube.position.y>0.1,"no escaped cubes")
 var destination: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "res://test-results/opponent-physics.png"
 DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(destination)
 ui.model.cubes.opponent=original;ui._sync_ui()
 print("OPPONENT_CUBES_PASS")
 quit()