extends Node3D
## Physical inventory presentation; never changes battle rules or currency.
const ORIGIN := Vector3(8.3,0.0,6.0)
const EDGE := 0.42
var bodies: Array[RigidBody3D]=[]
var walls: Array[CollisionShape3D]=[]
var budget:Node
var phase: String="idle"
var visual_rng:=RandomNumberGenerator.new()

func _ready() -> void:
 visual_rng.randomize()
 _boundary(Vector3(0,-0.12,0),Vector3(3.0,0.24,3.0))
 for offset in [Vector3(-1.5,0,0),Vector3(1.5,0,0),Vector3(0,0,-1.5),Vector3(0,0,1.5)]:
  walls.append(_boundary(offset+Vector3.UP*10,Vector3(0.2,20,3.2) if offset.x!=0 else Vector3(3.2,20,0.2)))

 budget=preload("res://scripts/cube_budget.gd").new();budget.name="CubeBudget";add_child(budget)

func _boundary(offset: Vector3, box_size: Vector3) -> CollisionShape3D:
 var wall:=StaticBody3D.new();wall.collision_layer=8;wall.collision_mask=8
 wall.position=ORIGIN+offset;add_child(wall)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=box_size;shape.shape=box;wall.add_child(shape)
 return shape

func _resize_walls(count: int) -> void:
 var height:float=maxf(20.0,float(count)*EDGE+5.0)
 for shape in walls:
  var box: BoxShape3D=shape.shape
  box.size.y=height;shape.get_parent().position.y=height*0.5

func _visual(parent: Node3D) -> void:
 parent.add_child(preload("res://scripts/garnet_cube_visual.gd").create_visual(EDGE))

func _spawn_cube(at: Vector3) -> RigidBody3D:
 var cube:=RigidBody3D.new();cube.collision_layer=8;cube.collision_mask=8
 cube.mass=0.2;cube.continuous_cd=true;cube.linear_damp=0.6;cube.angular_damp=0.8
 var physics:=PhysicsMaterial.new();physics.friction=0.8;physics.bounce=0.18;cube.physics_material_override=physics
 add_child(cube);cube.position=at
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3.ONE*EDGE;collision.shape=shape;cube.add_child(collision)
 _visual(cube);bodies.append(cube);return cube

func reset_count(count: int) -> void:
 for cube in bodies:remove_child(cube);cube.queue_free()
 bodies.clear();_resize_walls(count)
 budget.refresh()
 # Independent presentation randomness: never consumes the battle RNG.
 var layer_points:Array[Vector2]=[]
 var layer:=0
 for i in range(count):
  var spot:=Vector2.ZERO
  var found:=false
  for attempt in range(80):
   spot=Vector2(visual_rng.randf_range(-1.02,1.02),visual_rng.randf_range(-1.02,1.02))
   var clear:=true
   for existing in layer_points:
    if spot.distance_to(existing)<0.68:clear=false;break
   if clear:found=true;break
  if not found:
   layer+=1;layer_points.clear()
   spot=Vector2(visual_rng.randf_range(-1.02,1.02),visual_rng.randf_range(-1.02,1.02))
  layer_points.append(spot)
  var cube:=_spawn_cube(ORIGIN+Vector3(spot.x,0.8+layer*0.8+visual_rng.randf_range(0.0,0.08),spot.y))
  _tumble(cube)

func _tumble(cube: RigidBody3D) -> void:
 cube.rotation=Vector3(visual_rng.randf_range(-0.65,0.65),visual_rng.randf_range(-PI,PI),visual_rng.randf_range(-0.65,0.65))
 cube.linear_velocity=Vector3(visual_rng.randf_range(-0.4,0.4),-0.2,visual_rng.randf_range(-0.4,0.4))
 cube.angular_velocity=Vector3(visual_rng.randf_range(-2.0,2.0),visual_rng.randf_range(-2.0,2.0),visual_rng.randf_range(-2.0,2.0))

func _camera_move(camera: Camera3D, target: Transform3D, seconds: float) -> void:
 var tween:=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 tween.tween_property(camera,"global_transform",target,seconds)
 await tween.finished

func _view(from: Vector3, target: Vector3) -> Transform3D:
 return Transform3D(Basis.IDENTITY,from).looking_at(target,Vector3.UP)

func animate_changes(ui, changes: Array) -> void:
 if changes.is_empty():return
 var table=ui.table
 var camera:Camera3D=table.camera
 table.cancel_look_return()
 if table.placement_camera:table.placement_camera.restore()
 var saved_transform:=camera.global_transform
 var saved_projection:=camera.projection
 var saved_size:=camera.size
 var saved_fov:=camera.fov
 var npc_anchor:Node3D=table.get_node("NPCAnchor")
 var npc_visible:bool=npc_anchor.visible
 npc_anchor.show()
 var stage_visible:bool=ui.stage.visible
 var inventory=ui.inventory_layer
 if is_instance_valid(inventory):inventory.hide()
 ui.stage.hide()
 var overlay:=CanvasLayer.new();overlay.layer=100;ui.add_child(overlay)
 var block:=Control.new();block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);block.mouse_filter=Control.MOUSE_FILTER_STOP;overlay.add_child(block)
 camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=65
 var highest:=0.5
 for cube in bodies:highest=maxf(highest,cube.position.y)
 var pile_target:=ORIGIN+Vector3.UP*highest*0.5
 for delta in changes:
  if int(delta)>0:
   phase="focus"
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=65
   await _camera_move(camera,_view(pile_target+Vector3(0,3.5+highest*0.3,5),pile_target),0.28)
   phase="gain"
   _resize_walls(bodies.size()+int(delta))
   var top:=0.5
   for cube in bodies:top=maxf(top,cube.position.y+EDGE)
   for i in range(int(delta)):
    # Drop into irregular positions; collisions disturb the pile organically.
    var cube:=_spawn_cube(ORIGIN+Vector3(visual_rng.randf_range(-0.95,0.95),top+1.6+float(i)*0.3+visual_rng.randf_range(0.0,0.12),visual_rng.randf_range(-0.95,0.95)))
    _tumble(cube)
    await get_tree().create_timer(minf(0.09,0.9/float(delta))*visual_rng.randf_range(0.65,1.25)).timeout
   await get_tree().create_timer(1.25).timeout
  else:
   # Gather at the original gameplay view, never the pile close-up.
   phase="main_view"
   await _camera_move(camera,saved_transform,0.25)
   camera.projection=saved_projection;camera.size=saved_size;camera.fov=saved_fov
   await _offer(ui,overlay,-int(delta))
 phase="restore"
 await _camera_move(camera,saved_transform,0.3)
 camera.projection=saved_projection;camera.size=saved_size;camera.fov=saved_fov
 npc_anchor.visible=npc_visible
 ui.stage.visible=stage_visible
 if is_instance_valid(inventory):inventory.show()
 overlay.queue_free();phase="idle"

func _offer(ui, overlay: CanvasLayer, amount: int) -> void:
 phase="gather"
 assert(amount<=bodies.size())
 var camera:Camera3D=ui.table.camera
 var blur:=ColorRect.new();blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var shader:=ShaderMaterial.new();shader.shader=preload("res://asset/cube_background_blur.gdshader");blur.material=shader
 overlay.add_child(blur)
 var container:=SubViewportContainer.new();container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(container)
 var viewport:=SubViewport.new();viewport.size=Vector2i(get_viewport().get_visible_rect().size);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
 var foreground_camera:=Camera3D.new();foreground_camera.transform=camera.global_transform;foreground_camera.fov=camera.fov;foreground_camera.projection=camera.projection;foreground_camera.size=camera.size;viewport.add_child(foreground_camera)
 var lighting:=DirectionalLight3D.new();lighting.rotation_degrees=Vector3(-40,-25,0);lighting.light_energy=1.8;viewport.add_child(lighting)
 var copies:Array[Node3D]=[]
 var gather:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 bodies.sort_custom(func(a:RigidBody3D,b:RigidBody3D):return a.position.y<b.position.y)
 var side:int=ceili(pow(float(amount),1.0/3.0))
 var spacing:float=minf(0.48,2.0/maxf(1.0,side))
 var offsets:Array[Vector3]=[]
 var centroid:=Vector3.ZERO
 for i in range(amount):
  var offset:=Vector3((i%side-(side-1)*0.5)*spacing,(floori(float(i)/float(side))%side-(side-1)*0.5)*spacing,-floorf(float(i)/(side*side))*spacing)
  offsets.append(offset);centroid+=offset
 centroid/=float(amount)
 for i in range(amount):
  var original:RigidBody3D=bodies.pop_back()
  var copy:=Node3D.new();viewport.add_child(copy);copy.transform=original.global_transform;_visual(copy);copies.append(copy)
  remove_child(original);original.queue_free()
  var target:Vector3=camera.global_transform*(Vector3(0,0,-4.5)+offsets[i]-centroid)
  # Fast stagger, capped so large offerings do not cause a long wait.
  var delay:float=i*minf(0.045,0.4/maxf(1.0,float(amount-1)))
  gather.tween_property(copy,"position",target,0.28).set_delay(delay)
  gather.tween_property(copy,"scale",Vector3.ONE*minf(1.0,spacing/0.48),0.28).set_delay(delay)
 budget.invalidate()
 await gather.finished
 phase="center"
 await get_tree().create_timer(0.25).timeout
 phase="offer"
 var npc:Node3D=ui.table.get_node("NPCAnchor/TemporaryNPC")
 var destination:Vector3=npc.global_position
 var target_camera:=_view(destination+Vector3(0,3,6),destination)
 var send:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 send.tween_property(camera,"global_transform",target_camera,0.7)
 send.tween_property(foreground_camera,"global_transform",target_camera,0.7)
 send.tween_property(blur,"modulate:a",0.0,0.3)
 for copy in copies:
  send.tween_property(copy,"position",destination,0.7)
  send.tween_property(copy,"scale",Vector3.ONE*0.05,0.7)
 await send.finished
 container.queue_free();blur.queue_free()
