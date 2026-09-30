extends RefCounted
## Shared original garnet appearance for physical cubes and offering copies.
static var shared_mesh: ArrayMesh
static var shared_material: ShaderMaterial

static func create_visual(size: float, teal_core: bool=false) -> MeshInstance3D:
 if shared_mesh==null:_build_resources()
 var mesh:=shared_mesh
 var cube:=MeshInstance3D.new()
 cube.name="GarnetVisual";cube.mesh=shared_mesh;cube.material_override=shared_material
 if teal_core:
  cube.material_override=shared_material.duplicate()
  cube.material_override.set_shader_parameter("core_glow_color",Color(0.035,0.65,0.51))
 cube.scale=Vector3.ONE*size
 var core:=MeshInstance3D.new()
 core.name="VioletCore"
 core.mesh=mesh
 core.scale=Vector3.ONE*0.34
 var core_material:=StandardMaterial3D.new()
 core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 core_material.albedo_color=Color("78ffe0") if teal_core else Color("b476ff")
 core_material.emission_enabled=true
 core_material.emission=Color("21e3c2") if teal_core else Color("a259ff")
 core_material.emission_energy_multiplier=1.6
 core.material_override=core_material
 core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 cube.add_child(core)
 var particles:=CPUParticles3D.new()
 particles.name="CoreParticles"
 particles.amount=18
 particles.lifetime=1.8
 particles.preprocess=1.8
 particles.explosiveness=0.0
 particles.randomness=0.35
 particles.local_coords=true
 particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_SPHERE
 particles.emission_sphere_radius=0.05
 particles.direction=Vector3.UP
 particles.spread=180.0
 particles.gravity=Vector3.ZERO
 particles.initial_velocity_min=0.11
 particles.initial_velocity_max=0.16
 particles.scale_amount_min=0.045
 particles.scale_amount_max=0.065
 var particle_mesh:=SphereMesh.new()
 particle_mesh.radius=0.5;particle_mesh.height=1.0
 particle_mesh.radial_segments=6;particle_mesh.rings=3
 var particle_material:=StandardMaterial3D.new()
 particle_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 particle_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 particle_material.vertex_color_use_as_albedo=true
 particle_material.albedo_color=Color("62eed5") if teal_core else Color("aa54ed")
 particle_material.emission_enabled=true
 particle_material.emission=Color("16bba6") if teal_core else Color("7430c7")
 particle_mesh.material=particle_material
 particles.mesh=particle_mesh
 var fade:=Gradient.new()
 fade.offsets=PackedFloat32Array([0.0,0.25,0.55,1.0])
 fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.78),Color(1,1,1,0.70),Color(1,1,1,0)])
 particles.color_ramp=fade
 particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 cube.add_child(particles)
 return cube

static func create_body(size: float, teal_core: bool=false, layer: int=8) -> RigidBody3D:
 var cube:=RigidBody3D.new()
 cube.collision_layer=layer;cube.collision_mask=layer
 cube.mass=0.2;cube.continuous_cd=true;cube.linear_damp=0.6;cube.angular_damp=0.8
 var physics:=PhysicsMaterial.new()
 physics.friction=0.8;physics.bounce=0.18;cube.physics_material_override=physics
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new();shape.size=Vector3.ONE*size;collision.shape=shape
 cube.add_child(collision)
 cube.add_child(create_visual(size,teal_core))
 return cube

static func _build_resources() -> void:
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Round the box edges so the glass catches a broad, readable highlight.
 var axes: Array[Vector3]=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]
 for normal in axes:
  var tangent: Vector3=Vector3.RIGHT if absf(normal.y)>0.5 else Vector3.UP
  var bitangent: Vector3=normal.cross(tangent)
  for y in range(8):
   for x in range(8):
    for corner in [Vector2i(0,0),Vector2i(1,1),Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]:
     var uv:=Vector2(float(x+corner.x)/8.0,float(y+corner.y)/8.0)
     var point: Vector3=normal*0.5+tangent*(uv.x-0.5)+bitangent*(uv.y-0.5)
     var inner: Vector3=point.clamp(Vector3.ONE*-0.43,Vector3.ONE*0.43)
     var rounded_normal: Vector3=(point-inner).normalized()
     surface.set_normal(rounded_normal)
     surface.add_vertex(inner+rounded_normal*0.07)
 var mesh: ArrayMesh=surface.commit()
 var material:=ShaderMaterial.new()
 material.shader=preload("res://asset/garnet_glass.gdshader")
 shared_mesh=mesh;shared_material=material
