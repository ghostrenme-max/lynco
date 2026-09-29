extends SceneTree
const BASE = "res://effects/curtain_transition/"
func _initialize() -> void:
 var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"cloth_mesh.json"))
 var count := int(data.vertices)
 var frames := int(data.frames)
 var position_bytes := FileAccess.get_file_as_bytes(BASE+"cloth_positions.bin")
 var normal_bytes := FileAccess.get_file_as_bytes(BASE+"cloth_normals.bin")
 assert(position_bytes.size() == count*frames*12)
 for item in [["baked_positions.res",position_bytes],["baked_normals.res",normal_bytes]]:
  var img := Image.create_from_data(count,frames,false,Image.FORMAT_RGBF,item[1])
  var tex := ImageTexture.create_from_image(img)
  assert(ResourceSaver.save(tex,BASE+item[0],ResourceSaver.FLAG_COMPRESS)==OK)
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var uv2 := PackedVector2Array()
 var normals := PackedVector3Array()
 for i in range(count):
  vertices.append(Vector3(position_bytes.decode_float(i*12),position_bytes.decode_float(i*12+4),position_bytes.decode_float(i*12+8)))
  normals.append(Vector3.FORWARD)
  uv.append(Vector2(data.uv[i][0],data.uv[i][1]))
  uv2.append(Vector2((float(i)+0.5)/count,0.0))
 var arrays: Array=[]
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_TEX_UV2]=uv2
 arrays[Mesh.ARRAY_INDEX]=PackedInt32Array(data.indices)
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.custom_aabb=AABB(Vector3(-18,-9,-5),Vector3(36,18,10))
 assert(ResourceSaver.save(mesh,BASE+"baked_cloth_mesh.res",ResourceSaver.FLAG_COMPRESS)==OK)
 var right_indices := PackedInt32Array(data.indices)
 for i in range(0,right_indices.size(),3):
  var swap := right_indices[i]
  right_indices[i]=right_indices[i+2]
  right_indices[i+2]=swap
 arrays[Mesh.ARRAY_INDEX]=right_indices
 var right_mesh := ArrayMesh.new()
 right_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 right_mesh.custom_aabb=mesh.custom_aabb
 assert(ResourceSaver.save(right_mesh,BASE+"baked_cloth_right.res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("BAKED_RESOURCES_PASS vertices=",count," frames=",frames)
 quit()

