extends Node
## Keeps the natural physics transforms; budgets only simulation and rendering detail.
const Visual=preload("res://scripts/garnet_cube_visual.gd")
const CLOSE_PARTICLES:=24
const FAR_PARTICLES:=6
var pile:Node3D
var glass:MultiMeshInstance3D
var cores:MultiMeshInstance3D
var clock:=0.0
var previous_count:=-1
var thaw_until:=0
var lights:Array[OmniLight3D]=[]

func _ready() -> void:
 pile=get_parent()
 var sample:=Visual.create_visual(pile.EDGE)
 glass=_batch(sample.mesh,sample.material_override)
 cores=_batch(sample.get_node("VioletCore").mesh,sample.get_node("VioletCore").material_override)
 sample.free()
 for i in range(2):
  var light:=OmniLight3D.new();light.light_color=Color("a26aff");light.light_energy=0.7;light.omni_range=2.5;light.shadow_enabled=false
  pile.add_child(light);lights.append(light)

func _batch(mesh:Mesh, material:Material) -> MultiMeshInstance3D:
 var node:=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
 node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=mesh;node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 pile.add_child(node);return node

func invalidate() -> void:
 # Removing supporting cubes must let the pile settle again immediately.
 for cube in pile.bodies:
  if cube.freeze:cube.freeze=false;cube.sleeping=false
 thaw_until=Time.get_ticks_msec()+1200
 refresh()

func _process(delta:float) -> void:
 clock+=delta
 if clock<0.2:return
 clock=0.0
 if previous_count!=pile.bodies.size():
  previous_count=pile.bodies.size();invalidate()
 else:refresh()

func refresh() -> void:
 var camera:Camera3D=get_viewport().get_camera_3d()
 if not camera:return
 var top:=0.3
 for cube in pile.bodies:top=maxf(top,cube.position.y)
 var sorted:Array=pile.bodies.duplicate()
 # Favor the visible surface nearest the camera, rather than buried cubes.
 sorted.sort_custom(func(a:RigidBody3D,b:RigidBody3D):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
 var close:bool=camera.global_position.distance_to(pile.ORIGIN+Vector3.UP*top*0.5)<10.0
 var budget:int=CLOSE_PARTICLES if close else FAR_PARTICLES
 var batched:Array[Transform3D]=[]
 var detailed:=0
 for cube in sorted:
  var buried:bool=cube.position.y<top-0.85 and absf(cube.position.x-pile.ORIGIN.x)<0.95 and absf(cube.position.z-pile.ORIGIN.z)<0.95
  if cube.freeze and not buried:cube.freeze=false;cube.sleeping=false
  if buried and cube.sleeping and Time.get_ticks_msec()>thaw_until:cube.freeze=true
  cube.can_sleep=true
  # Continuous collision detection is useful in flight, not at rest.
  cube.continuous_cd=not cube.freeze and not cube.sleeping and cube.linear_velocity.length_squared()>2.0
  var visual:MeshInstance3D=cube.get_node("GarnetVisual")
  var particle:CPUParticles3D=visual.get_node("CoreParticles")
  var full:bool=not buried and detailed<budget and pile.is_visible_in_tree()
  if full:detailed+=1
  particle.emitting=full;particle.visible=full
  var combine:bool=(cube.sleeping or cube.freeze) and not full
  visual.visible=not combine
  if combine:batched.append(cube.transform.scaled_local(Vector3.ONE*pile.EDGE))
 for target in [glass,cores]:
  target.multimesh.instance_count=batched.size()
 for i in range(batched.size()):
  glass.multimesh.set_instance_transform(i,batched[i])
  cores.multimesh.set_instance_transform(i,batched[i].scaled_local(Vector3.ONE*0.34))
 for i in range(lights.size()):
  lights[i].position=pile.ORIGIN+Vector3(-0.65 if i==0 else 0.65,0.45+top*0.5,0)
  lights[i].visible=not pile.bodies.is_empty()
