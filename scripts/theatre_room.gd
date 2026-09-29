extends RefCounted
# Decoration only: preserve original table meshes, transforms and collisions.
const ASSETS := "res://assets/theatre_3d/"

static func build(world: Node3D) -> void:
 var room:=Node3D.new();room.name="TheatreRoom";world.add_child(room)
 world.get_node("DummyProps").hide()
 for side in [-1,1]:
  var near_chair:=_prop(room,"chair",Vector3(side*13.5,-3.1,-1.8),-side*PI*0.5)
  near_chair.scale=Vector3.ONE*1.25
  _prop(room,"chair",Vector3(side*13.5,-3.1,-20.3),-side*PI*0.5)
  # Restrained warm bounce makes upholstery folds readable in the dark room.
  for seat_z in [-1.8,-20.3]:
   var fill_name: String="ChairBounce_"+str(side)+"_"+str(int(seat_z*10))
   _spot(room,fill_name,Vector3(side*10.5,3.0,seat_z+2.0),Vector3(side*13.5,-1.2,seat_z),1.25,35.0)
   room.get_node(fill_name).spot_range=10.0
  var candle_prop:=_prop(room,"candelabra",Vector3(side*13.1,-3.1,-6.0))
  _prop(room,"pedestal_vase",Vector3(side*14.4,-3.1,-14.4))
  _prop(room,"curtain",Vector3(side*17.5,-3.1,-13.5),side*0.28)
  _prop(room,"curtain",Vector3(side*12.8,-3.1,-29.0))
  _prop(room,"star_pendant",Vector3(side*8.4,6.5,-28.2))
  var candle:=OmniLight3D.new();candle.name="CandlePool"+str(side)
  candle.position=Vector3(side*13.1,1.65,-6.0)
  candle.light_color=Color("ffb45f");candle.light_energy=1.6;candle.omni_range=6.3
  candle.omni_attenuation=1.5;candle.shadow_enabled=false;room.add_child(candle)
  candle_prop.set_script(preload("res://scripts/candle_animation.gd"))
  candle_prop.setup(candle,0.0 if side==-1 else 4.17)
 var env: Environment=world.get_node("Environment").environment
 env.background_color=Color("080709")
 env.ambient_light_color=Color("b5a99a");env.ambient_light_energy=0.09
 var key: DirectionalLight3D=world.get_node("KeyLight")
 key.light_color=Color("d6c4b0");key.light_energy=0.08;key.shadow_enabled=false
 _spot(world,"TableSpot",Vector3(-3,17,3),Vector3(0,0,-1),6.0,38.0)
 _spot(world,"FarTableSpot",Vector3(2,17,-18),Vector3(0,0,-18),0.0,36.0)
 var top: StandardMaterial3D=preload("res://scripts/silk_tablecloth.gd").build(world)
 var wood:=StandardMaterial3D.new()
 wood.albedo_texture=load(ASSETS+"walnut.png");wood.roughness=0.83
 wood.uv1_scale=Vector3(4,1,1)
 for table_name in ["Table","OpponentTable"]:
  for part in world.get_node(table_name).get_children():
   if part is MeshInstance3D:
    part.material_override=top if part.name=="Tabletop" else wood
    part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var floor_mat:=ShaderMaterial.new()
 floor_mat.shader=load("res://asset/theatre_floor.gdshader")
 world.get_node("Floor").material_override=floor_mat

static func _prop(parent: Node3D, asset: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
 var packed: PackedScene=load(ASSETS+asset+".glb")
 var node: Node3D=packed.instantiate()
 node.name=asset;node.position=pos;node.rotation.y=yaw
 parent.add_child(node)
 return node

static func _spot(parent: Node3D, title: String, pos: Vector3, target: Vector3, energy: float, angle: float) -> void:
 var light:=SpotLight3D.new();light.name=title;parent.add_child(light)
 light.position=pos;light.look_at(target,Vector3.FORWARD)
 light.light_color=Color("ffe2b5");light.light_energy=energy
 light.spot_range=38;light.spot_angle=angle;light.spot_angle_attenuation=0.65
 light.spot_attenuation=0.6;light.shadow_enabled=false
 light.shadow_bias=0.1;light.shadow_normal_bias=1.0
