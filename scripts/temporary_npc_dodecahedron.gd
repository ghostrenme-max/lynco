extends Node3D
## Temporary NPC visual only. Remove this node to replace it with the final NPC.
@export var radius: float=1.15
@export var hover_height: float=2.3
@export var hover_amplitude: float=0.16
@export var rotation_speed: float=0.18
var elapsed: float=0.0
var body: MeshInstance3D

func _ready() -> void:
 body=MeshInstance3D.new();body.name="Dodecahedron"
 body.mesh=build_mesh(radius)
 var material:=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.roughness=0.48;material.metallic=0.55
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 material.emission_enabled=true;material.emission=Color("58482c");material.emission_energy_multiplier=0.35
 body.material_override=material
 add_child(body);position.y=hover_height
 body.rotation=Vector3(0.18,0.0,0.12)

func _process(delta: float) -> void:
 elapsed+=delta
 position.y=hover_height+sin(elapsed*TAU/5.0)*hover_amplitude
 body.rotation.y=fmod(elapsed*rotation_speed,TAU)

static func build_mesh(size_radius: float) -> ArrayMesh:
 var phi:float=(1.0+sqrt(5.0))*0.5
 var vertices: Array[Vector3]=[]
 var normals: Array[Vector3]=[]
 for x in [-1.0,1.0]:
  for y in [-1.0,1.0]:
   for z in [-1.0,1.0]:vertices.append(Vector3(x,y,z))
   vertices.append(Vector3(0,x/phi,y*phi))
   vertices.append(Vector3(x/phi,y*phi,0))
   vertices.append(Vector3(x*phi,0,y/phi))
   normals.append(Vector3(0,x*phi,y).normalized())
   normals.append(Vector3(x*phi,y,0).normalized())
   normals.append(Vector3(x,0,y*phi).normalized())
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var face_index:=0
 for normal in normals:
  var support:float=-INF
  for vertex in vertices:support=maxf(support,normal.dot(vertex))
  var face: Array[Vector3]=[]
  var center:=Vector3.ZERO
  for vertex in vertices:
   if absf(normal.dot(vertex)-support)<0.001:face.append(vertex);center+=vertex
  assert(face.size()==5,"Regular dodecahedron requires five vertices per face")
  center/=5.0
  var tangent:Vector3=(face[0]-center).normalized()
  var bitangent:Vector3=normal.cross(tangent)
  face.sort_custom(func(a:Vector3,b:Vector3):return atan2((a-center).dot(bitangent),(a-center).dot(tangent))<atan2((b-center).dot(bitangent),(b-center).dot(tangent)))
  for i in range(5):
   for vertex in [center,face[(i+1)%5],face[i]]:
    surface.set_normal(normal)
    surface.set_color(Color("c6a468") if face_index%3==0 else (Color("766443") if face_index%3==1 else Color("a28b60")))
    surface.add_vertex(vertex*size_radius/sqrt(3.0))
  face_index+=1
 return surface.commit()
