extends Node3D
const BAKED_MESH = preload("res://effects/curtain_transition/baked_cloth_mesh.res")
const BAKED_SHADER = preload("res://effects/curtain_transition/cloth_baked.gdshader")
const BAKED_POSITIONS = preload("res://effects/curtain_transition/baked_positions.res")
const BAKED_NORMALS = preload("res://effects/curtain_transition/baked_normals.res")
const CLOTH_TEXTURE = preload("res://effects/curtain_transition/curtain_cloth.png")
var materials: Array[ShaderMaterial] = []
func _ready() -> void:
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color(0,0,0,0)
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color(0.65,0.68,0.75)
 env.ambient_light_energy=0.48
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
 environment.environment=env
 add_child(environment)
 var camera := Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=10.8
 camera.position=Vector3(0,0,24)
 add_child(camera)
 camera.current=true
 var key := DirectionalLight3D.new()
 key.rotation_degrees=Vector3(-20,-38,0)
 key.light_color=Color(1.0,0.88,0.76)
 key.light_energy=0.7
 key.shadow_enabled=false
 key.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
 key.directional_shadow_max_distance=45.0
 key.shadow_bias=0.015
 add_child(key)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees=Vector3(-20,38,0)
 fill.light_color=Color(1.0,0.88,0.76)
 fill.light_energy=0.7
 add_child(fill)
 for side in range(1):
  var panel := MeshInstance3D.new()
  panel.name="BakedCurtainPair"
  panel.mesh=BAKED_MESH
  panel.extra_cull_margin=20.0
  var material := ShaderMaterial.new()
  material.shader=BAKED_SHADER
  material.set_shader_parameter("mirror_side",1.0 if side==0 else -1.0)
  material.set_shader_parameter("positions",BAKED_POSITIONS)
  material.set_shader_parameter("normals",BAKED_NORMALS)
  material.set_shader_parameter("cloth",CLOTH_TEXTURE)
  panel.material_override=material
  materials.append(material)
  add_child(panel)
func set_frame(frame: float) -> void:
 for material in materials:
  material.set_shader_parameter("frame",frame)


