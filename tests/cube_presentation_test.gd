extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(90).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var pile=ui.table.get_node("GarnetCubes")
 assert(pile.bodies.size()==6)
 var camera:Camera3D=ui.table.camera
 var saved:=camera.global_transform
 ui.model.change_cubes("player",4)
 ui._animate_cube_changes()
 assert(ui.cube_animating and ui.busy)
 while pile.phase!="gain":await process_frame
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/cube-gain.png")
 while ui.cube_animating:await process_frame
 assert(pile.bodies.size()==10 and camera.global_transform.is_equal_approx(saved))
 ui.model.change_cubes("player",-2)
 ui._animate_cube_changes()
 while pile.phase!="center":await process_frame
 assert(camera.global_transform.is_equal_approx(saved),"Offering gathers in original gameplay view")
 assert(ui.cube_animating)
 var input:=InputEventKey.new();input.keycode=KEY_F;input.pressed=true;ui._input(input)
 assert(not is_instance_valid(ui.inventory_layer))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/cube-center.png")
 while pile.phase!="offer":await process_frame
 await create_timer(0.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/cube-offer.png")
 while ui.cube_animating:await process_frame
 assert(pile.bodies.size()==8 and ui.model.cubes.player==8)
 assert(not ui.busy and ui.stage.visible and camera.global_transform.is_equal_approx(saved))
 # Opposite changes must not cancel before presentation.
 ui.model.change_cubes("player",-1);ui.model.change_cubes("player",1)
 assert(ui.model.cube_changes==[-1,1])
 await ui._animate_cube_changes()
 assert(pile.bodies.size()==8 and ui.model.cube_changes.is_empty())
 # Real item and card entry points.
 ui.CubeTest.prepare_items();ui._toggle_inventory()
 var inventory=ui.inventory_layer.get_child(0)
 inventory.select_item(0,true)
 inventory.stage.get_child(inventory.stage.get_child_count()-1).pressed.emit()
 while ui.cube_animating:await process_frame
 assert(pile.bodies.size()==ui.model.cubes.player)
 assert(ui.inventory_layer.visible)
 ui._toggle_inventory()
 var uid:int=ui.model.hand[0].uid
 ui._activate_card(uid,Vector2i(0,0))
 while ui.busy:await process_frame
 assert(pile.bodies.size()==ui.model.cubes.player)
 assert(ui.model.invest(Vector2i(0,0)).ok)
 await ui._animate_cube_changes()
 assert(pile.bodies.size()==ui.model.cubes.player)
 ui.model.turn+=1
 assert(ui.model.recover(Vector2i(0,0)).ok)
 await ui._animate_cube_changes()
 assert(pile.bodies.size()==ui.model.cubes.player)
 # Stress the bounded physical stack, not the logical resource limit.
 pile.reset_count(100)
 await create_timer(2).timeout
 for cube in pile.bodies:
  assert(absf(cube.position.x-pile.ORIGIN.x)<1.5 and absf(cube.position.z-pile.ORIGIN.z)<1.5 and cube.position.y>0)
 print("CUBE_PRESENTATION_PASS")
 quit()
