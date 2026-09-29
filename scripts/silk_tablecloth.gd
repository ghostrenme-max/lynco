extends RefCounted
# One continuous static cloth covers the shared banquet table.
const ASSETS := "res://assets/theatre_3d/"
static func build(world: Node3D) -> StandardMaterial3D:
 var silk:=StandardMaterial3D.new()
 silk.resource_name="Crimson woven silk"
 silk.albedo_texture=load(ASSETS+"silk_crimson.png")
 silk.roughness=1.0
 silk.roughness_texture=load(ASSETS+"silk_roughness.png")
 silk.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 silk.normal_enabled=true
 silk.normal_texture=load(ASSETS+"silk_normal.png")
 silk.normal_scale=0.65
 silk.metallic_specular=0.4
 silk.uv1_scale=Vector3(4.5,6.64,1.0)
 silk.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 silk.cull_mode=BaseMaterial3D.CULL_DISABLED
 var hem:=StandardMaterial3D.new()
 hem.albedo_color=Color("79603a")
 hem.metallic=0.35;hem.roughness=0.48
 hem.cull_mode=BaseMaterial3D.CULL_DISABLED
 var holder:=Node3D.new();holder.name="Tablecloths";world.add_child(holder)
 var packed: PackedScene=load(ASSETS+"silk_tablecloth.glb")
 var cloth: Node3D=packed.instantiate()
 cloth.name="ContinuousCloth"
 holder.add_child(cloth)
 cloth.position=Vector3(0,0,-8.9)
 for mesh in cloth.find_children("*","MeshInstance3D",true,false):
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  mesh.set_surface_override_material(0,silk)
  mesh.set_surface_override_material(1,hem)
 return silk
