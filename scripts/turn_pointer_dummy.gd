extends Node3D
# Temporary primitive-only turn prop. No imported models or gameplay state.
var arm: Node3D
var motion: Tween
var opponent := false
var initialized := false
const PLAYER_ANGLE := -0.30
const OPPONENT_ANGLE := PI+0.30

func material(color: String, metallic: float=0.0) -> StandardMaterial3D:
 var result:=StandardMaterial3D.new()
 result.albedo_color=Color(color);result.metallic=metallic;result.roughness=0.72
 return result

func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material, title: String) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.name=title;node.mesh=shape;node.position=pos;node.material_override=mat
 parent.add_child(node)
 return node

func box(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material, title: String) -> MeshInstance3D:
 var shape:=BoxMesh.new();shape.size=dimensions
 return mesh(parent,shape,pos,mat,title)

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, title: String, axis: String="y") -> MeshInstance3D:
 var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=20
 var node:=mesh(parent,shape,pos,mat,title)
 if axis=="z":node.rotation.x=PI*0.5
 if axis=="x":node.rotation.z=PI*0.5
 return node

func _ready() -> void:
 var gold:=material("b59558",0.6)
 var dark:=material("30232a")
 var burgundy:=material("682b37")
 var glove:=material("f3ecdc")
 box(self,Vector3(0,0.12,0),Vector3(2.2,0.24,0.9),dark,"FixedBase")
 box(self,Vector3(0,0.27,0),Vector3(1.95,0.08,0.72),gold,"BaseTrim")
 cylinder(self,Vector3(0,1.18,0),0.90,0.18,gold,"FixedDial","z")
 cylinder(self,Vector3(0,1.18,0.105),0.81,0.04,burgundy,"DialFace","z")
 for i in range(9):
  var angle:=PI*float(i)/8.0
  var marker:=box(self,Vector3(cos(angle)*0.68,1.18+sin(angle)*0.68,0.145),Vector3(0.055,0.15,0.025),gold,"Tick%d" % i)
  marker.rotation.z=angle-PI*0.5
 cylinder(self,Vector3(0,1.18,0.19),0.18,0.25,gold,"FixedAxle","z")
 arm=Node3D.new();arm.name="SpringArm";arm.position=Vector3(0,1.18,0.32);add_child(arm)
 cylinder(arm,Vector3(0.79,0,0),0.055,1.58,dark,"Wand","x")
 cylinder(arm,Vector3(1.53,0,0),0.16,0.20,gold,"CuffRing","x")
 cylinder(arm,Vector3(1.67,0,0),0.20,0.22,glove,"CottonCuff","x")
 box(arm,Vector3(1.98,0.02,0),Vector3(0.47,0.43,0.30),glove,"GlovePalm")
 # Long pointing index + three folded fingers + angled thumb, all cylinders.
 cylinder(arm,Vector3(2.42,0.17,0),0.085,0.67,glove,"IndexFinger","x")
 for i in range(3):
  cylinder(arm,Vector3(2.17,-0.03-float(i)*0.115,0.05),0.08,0.26,glove,"FoldedFinger%d" % i,"x")
 var thumb:=cylinder(arm,Vector3(1.91,0.20,0.17),0.09,0.29,glove,"Thumb","x")
 thumb.rotation.z=-0.65
 for side in [-1,1]:
  box(self,Vector3(float(side)*1.9,0.30,0.32),Vector3(0.45,0.25,0.55),burgundy,"PaddedStop"+str(side))
 var fill:=OmniLight3D.new();fill.position=Vector3(-0.5,2.6,2.0);fill.light_color=Color("ffdfb2")
 fill.light_energy=0.8;fill.omni_range=4.8;fill.shadow_enabled=false;add_child(fill)
 var hand_group:=Node3D.new();hand_group.name="GloveAssembly";hand_group.position=Vector3(1.53,0,0);arm.add_child(hand_group)
 for piece_name in ["CuffRing","CottonCuff","GlovePalm","IndexFinger","FoldedFinger0","FoldedFinger1","FoldedFinger2","Thumb"]:
  var piece: Node3D=arm.get_node(piece_name)
  var local_position:=piece.position
  piece.reparent(hand_group,false)
  piece.position=local_position-hand_group.position
 hand_group.scale=Vector3.ONE*1.3
 arm.rotation.z=PLAYER_ANGLE

func set_turn(is_opponent: bool, reduced: bool=false) -> void:
 var target:=OPPONENT_ANGLE if is_opponent else PLAYER_ANGLE
 if initialized and opponent==is_opponent:
  if reduced and motion and motion.is_valid():motion.kill();arm.rotation.z=target
  return
 var animate:=initialized and not reduced
 initialized=true;opponent=is_opponent
 if motion and motion.is_valid():motion.kill()
 if not animate:arm.rotation.z=target;return
 motion=create_tween()
 motion.tween_property(arm,"rotation:z",target,0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 var rebound_sign: float=-1.0 if is_opponent else 1.0
 motion.tween_method(func(t: float):arm.rotation.z=target+rebound_sign*0.40*absf(sin(t*PI*3.0))*exp(-t*4.8),0.0,1.0,0.58)
 motion.tween_callback(func():arm.rotation.z=target)
