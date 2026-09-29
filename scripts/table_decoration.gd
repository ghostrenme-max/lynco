extends RefCounted

# Visual construction only; no combat state or per-frame processing.
static func build_garnet_cubes(parent: Node3D) -> void:
 var group:=Node3D.new();group.name="GarnetCubes";parent.add_child(group)
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
 var positions: Array[Vector3]=[Vector3(8.0,0.245,6.2),Vector3(8.6,0.245,6.2),Vector3(8.3,0.245,5.6)]
 for i in range(3):
  var cube:=MeshInstance3D.new()
  cube.name="Garnet"+str(i+1);cube.mesh=mesh;cube.material_override=material
  cube.position=positions[i];cube.scale=Vector3.ONE*0.48;cube.rotation.y=0.12+float(i)*0.23
  group.add_child(cube)
  var core:=MeshInstance3D.new()
  core.name="VioletCore"
  core.mesh=mesh
  core.scale=Vector3.ONE*0.34
  var core_material:=StandardMaterial3D.new()
  core_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  core_material.albedo_color=Color("b476ff")
  core_material.emission_enabled=true
  core_material.emission=Color("a259ff")
  core_material.emission_energy_multiplier=1.6
  core.material_override=core_material
  core.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  cube.add_child(core)
  var glow:=OmniLight3D.new()
  glow.name="CoreLight"
  glow.light_color=Color("a26aff");glow.light_energy=0.65
  glow.omni_range=1.8;glow.shadow_enabled=false
  cube.add_child(glow)
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
  particle_material.albedo_color=Color("aa54ed")
  particle_material.emission_enabled=true
  particle_material.emission=Color("7430c7")
  particle_mesh.material=particle_material
  particles.mesh=particle_mesh
  var fade:=Gradient.new()
  fade.offsets=PackedFloat32Array([0.0,0.25,0.55,1.0])
  fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.78),Color(1,1,1,0.70),Color(1,1,1,0)])
  particles.color_ramp=fade
  particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  cube.add_child(particles)

static func build_distributors(parent: Node3D, opponent_table_z: float) -> StandardMaterial3D:
 var black_market_glow: StandardMaterial3D
 var group:=Node3D.new();group.name="Distributors";parent.add_child(group)
 for side in [-1,1]:
  var machine:=Node3D.new()
  machine.name="Shop" if side<0 else "BlackMarket"
  machine.position=Vector3(float(side)*9.2,0.1,opponent_table_z*0.5)
  group.add_child(machine)
  var shell:=StandardMaterial3D.new()
  shell.albedo_color=Color("dddcd1") if side<0 else Color("292c2d")
  shell.roughness=0.3; shell.metallic=0.2
  if side>0:
   machine.position.z=-3.0
   # Open rectangular deck case; the original node remains the interaction target.
   for part in [Vector4(0,0.08,0,0),Vector4(-0.88,0.68,0,1),Vector4(0.88,0.68,0,1),Vector4(0,0.68,-1.2,2),Vector4(0,0.68,1.2,2)]:
    var wall:=MeshInstance3D.new()
    var box:=BoxMesh.new()
    box.size=Vector3(1.86,0.16,2.5) if part.w==0 else (Vector3(0.1,1.2,2.5) if part.w==1 else Vector3(1.86,1.2,0.1))
    wall.mesh=box;wall.material_override=shell;wall.position=Vector3(part.x,part.y,part.z)
    machine.add_child(wall)
   var mouth:=Marker3D.new();mouth.name="CardEntry";mouth.position=Vector3(0,1.5,0);machine.add_child(mouth)
   var case_glow_material:=StandardMaterial3D.new();case_glow_material.albedo_color=Color("181a19")
   black_market_glow=case_glow_material
   var case_light:=OmniLight3D.new();case_light.name="ActiveLight";case_light.position=Vector3(0,1.5,0)
   case_light.light_color=Color("f12c40");case_light.light_energy=1.2;case_light.omni_range=2.8;case_light.hide();machine.add_child(case_light)
   continue
  var body:=MeshInstance3D.new()
  var cylinder:=CylinderMesh.new()
  cylinder.top_radius=0.66;cylinder.bottom_radius=0.72;cylinder.height=1.55
  body.mesh=cylinder;body.material_override=shell;body.position.y=0.6
  machine.add_child(body)
  var cap:=MeshInstance3D.new()
  var lid:=CylinderMesh.new();lid.top_radius=0.62;lid.bottom_radius=0.66;lid.height=0.12
  cap.mesh=lid;cap.material_override=shell;cap.position.y=1.4;machine.add_child(cap)
  var slot:=MeshInstance3D.new();slot.name="Slot"
  var slot_mesh:=BoxMesh.new();slot_mesh.size=Vector3(0.87,0.14,0.08)
  slot.mesh=slot_mesh;slot.position=Vector3(0,0.68,0.67)
  var slot_material:=StandardMaterial3D.new()
  slot_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  slot_material.albedo_color=Color("181a19")
  slot.material_override=slot_material;machine.add_child(slot)
  var lip:=MeshInstance3D.new();var tray:=BoxMesh.new();tray.size=Vector3(0.95,0.05,0.42)
  lip.mesh=tray;lip.material_override=shell;lip.position=Vector3(0,0.49,0.8);machine.add_child(lip)
  var light:=OmniLight3D.new();light.name="ActiveLight";light.position=Vector3(0,0.9,0.8)
  light.light_color=Color("f12c40");light.light_energy=1.2;light.omni_range=2.8
  light.hide();machine.add_child(light)
  if side>0:black_market_glow=slot_material
 return black_market_glow
