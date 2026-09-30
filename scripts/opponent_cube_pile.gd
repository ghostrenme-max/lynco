extends Node3D
## Background physical inventory. Never owns input, camera, or battle timing.
const EDGE := 0.42
const Visual = preload("res://scripts/garnet_cube_visual.gd")
var cubes: Array[RigidBody3D] = []
var offerings: Array[Node3D] = []
var count_label: Label3D
var count := -1
var visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
 position = Vector3(0, 0, -7.4)
 visual_rng.randomize()
 _boundary(Vector3(0,-0.12,0), Vector3(3,0.24,3))
 for offset in [Vector3(-1.5,0,0),Vector3(1.5,0,0),Vector3(0,0,-1.5),Vector3(0,0,1.5)]:
  _boundary(offset+Vector3.UP*10, Vector3(0.2,20,3.2) if offset.x!=0 else Vector3(3.2,20,0.2))
 count_label = Label3D.new()
 count_label.name = "OpponentCubeCount"
 count_label.position = Vector3(0,0.1,1.65)
 count_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 count_label.font_size = 32
 count_label.pixel_size = 0.010
 count_label.modulate = Color("93f4df")
 count_label.outline_size = 7
 count_label.no_depth_test = true
 add_child(count_label)

func _boundary(at: Vector3, size: Vector3) -> void:
 var wall := StaticBody3D.new()
 wall.collision_layer = 16
 wall.collision_mask = 16
 wall.position = at
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = size
 shape.shape = box
 wall.add_child(shape)
 add_child(wall)

func set_count(value: int) -> void:
 value = maxi(0,value)
 if count == value: return
 var initial := count < 0
 count = value
 while cubes.size() > value:
  _offer(cubes.pop_back())
 # Wake supported cubes when their neighbours are removed.
 for cube in cubes: cube.sleeping = false
 var top := 0.3
 for cube in cubes: top = maxf(top,cube.position.y+EDGE)
 var added := 0
 while cubes.size() < value:
  var cube := Visual.create_body(EDGE,true,16)
  cube.position = Vector3(visual_rng.randf_range(-0.95,0.95),top+(0.6 if initial else 1.6)+added*0.65,visual_rng.randf_range(-0.95,0.95))
  cube.rotation = Vector3(visual_rng.randf_range(-0.65,0.65),visual_rng.randf_range(-PI,PI),visual_rng.randf_range(-0.65,0.65))
  cube.linear_velocity = Vector3(visual_rng.randf_range(-0.4,0.4),-0.2,visual_rng.randf_range(-0.4,0.4))
  cube.angular_velocity = Vector3(visual_rng.randf_range(-2,2),visual_rng.randf_range(-2,2),visual_rng.randf_range(-2,2))
  add_child(cube)
  cubes.append(cube)
  added += 1
 # Keep containment taller than even unusually large inventory drops.
 for child in get_children():
  if child is StaticBody3D and child.position.y > 0:
   var height := maxf(20,top+added*0.65+5)
   child.position.y = height*0.5
   child.get_child(0).shape.size.y = height
 count_label.text = "상대 큐브 %d" % count

func _offer(body: RigidBody3D) -> void:
 # Detach only the visual: it can fly out without fighting the cage or physics.
 var visual: Node3D = body.get_node("GarnetVisual")
 visual.reparent(self,true)
 offerings.append(visual)
 remove_child(body)
 body.queue_free()
 var npc := get_parent().get_node_or_null("NPCAnchor/TemporaryNPC") as Node3D
 var destination := to_local(npc.global_position) if npc else Vector3(0,1,-5)
 var start := visual.position
 var motion := create_tween()
 motion.tween_method(func(t: float):
  visual.position = start.lerp(destination,t)+Vector3.UP*sin(PI*t)*1.1
  visual.scale = Vector3.ONE*EDGE*lerpf(1.0,0.08,t*t)
 ,0.0,1.0,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 motion.tween_callback(func():
  offerings.erase(visual)
  visual.queue_free()
 )
