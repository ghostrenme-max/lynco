class_name LyncoTableView
extends Node3D

# Presentation only: cells never affect combat rules or card ownership.
const COLS := 6
const ROWS := 3
const INVALID := Vector2i(-1, -1)
const STEP := Vector2(1.65, 2.35)
const CARD_METRES := Vector2(1.48, 2.14)
const CARD_OBJECT = preload("res://scenes/card_3d.tscn")
var ui_stage: Control
var world: Node3D
var camera: Camera3D
@export_range(1.0, 20.0) var look_yaw_limit_degrees: float = 12.0
@export_range(1.0, 12.0) var look_pitch_limit_degrees: float = 7.0
@export var look_sensitivity: float = 0.002
var base_camera_rotation: Vector3
var look_offset := Vector2.ZERO
var cards: Dictionary = {}
var materials: Dictionary = {}
var back_materials: Dictionary = {}
var black_body_material: StandardMaterial3D
const Catalog = preload("res://scripts/catalog.gd")
var hint: MeshInstance3D
var hint_material: ShaderMaterial
var preview_cell := INVALID
var preview_allowed: bool = false
var card_mesh: PlaneMesh
var animations: Array[Tween] = []

func _ready() -> void:
 world=$PlacedCards
 camera=$Camera3D
 base_camera_rotation=camera.rotation
 black_body_material=StandardMaterial3D.new()
 black_body_material.albedo_color=Color(0.025,0.028,0.025,1.0)
 black_body_material.roughness=0.9
 card_mesh=PlaneMesh.new();card_mesh.size=CARD_METRES
 hint_material=ShaderMaterial.new()
 hint_material.shader=preload("res://asset/card_placement.gdshader")
 hint=MeshInstance3D.new();hint.mesh=card_mesh;hint.material_override=hint_material
 world.add_child(hint);hint.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;hint.hide()
 set_process(false)

func set_card_texture(id: String, texture: Texture2D) -> void:
 var material:=StandardMaterial3D.new()
 material.albedo_texture=texture
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold=0.4
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 materials[id]=material

func cell_position(cell: Vector2i) -> Vector3:
 return Vector3((cell.x-2.5)*STEP.x,0.065,(cell.y-1)*STEP.y-1.3)

func cell_at(local_point: Vector2) -> Vector2i:
 if not ui_stage:return INVALID
 if not Rect2(310,30,940,565).has_point(local_point):return INVALID
 var point:Vector2=ui_stage.get_global_transform_with_canvas()*local_point
 if not get_viewport().get_visible_rect().has_point(point):return INVALID
 var hit:Variant=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
 if hit==null:return INVALID
 var cell:=Vector2i(roundi(hit.x/STEP.x+2.5),roundi((hit.z+1.3)/STEP.y+1))
 if cell.x<0 or cell.x>=COLS or cell.y<0 or cell.y>=ROWS:return INVALID
 return cell

func free_cell(cell: Vector2i) -> bool:
 return cell!=INVALID and not cards.has(cell)

func next_cell() -> Vector2i:
 for row in range(ROWS):
  for col in range(COLS):
   var cell:=Vector2i(col,row)
   if free_cell(cell):return cell
 return INVALID

func screen_position(cell: Vector2i) -> Vector2:
 return ui_stage.get_global_transform_with_canvas().affine_inverse()*camera.unproject_position(cell_position(cell))

func preview(local_point: Vector2, usable: bool) -> Vector2i:
 var cell:=cell_at(local_point)
 if cell==INVALID:
  hide_preview()
  return cell
 var allowed:bool=usable and free_cell(cell)
 if preview_cell!=cell or not hint.visible:
  hint.position=cell_position(cell)+Vector3(0,0.018,0)
 if preview_allowed!=allowed or not hint.visible:
  hint_material.set_shader_parameter("tint",Color(1.0,0.84,0.26,1.0) if allowed else Color(0.55,0.57,0.59,0.35))
 preview_cell=cell;preview_allowed=allowed
 if not hint.visible:hint.show()
 return cell

func hide_preview() -> void:
 if hint.visible:hint.hide()
 preview_cell=INVALID

func place(id: String, cell: Vector2i, quick: bool = false) -> void:
 assert(free_cell(cell))
 var holder:Node3D=CARD_OBJECT.instantiate();world.add_child(holder)
 holder.position=cell_position(cell)+Vector3(0,0.65,0)
 holder.rotation.x=0.32
 holder.set_meta("card_id",id)
 var dark:bool=bool(Catalog.card(id).dark)
 if dark:holder.get_node("Body").material_override=black_body_material
 holder.get_node("Front").material_override=materials[id]
 holder.get_node("Back").material_override=back_materials["back_black" if dark else "back_white"]
 cards[cell]=holder
 var tween:=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 var duration:=0.1 if quick else 0.22
 tween.tween_property(holder,"position:y",cell_position(cell).y,duration)
 tween.tween_property(holder,"rotation:x",0.0,duration)
 animations.append(tween)
 tween.finished.connect(func(): animations.erase(tween))

func clear_cards() -> void:
 for tween in animations:
  if tween.is_valid():tween.kill()
 animations.clear();set_process(false)
 for holder in cards.values():holder.queue_free()
 cards.clear();hide_preview()

func set_back_texture(id: String, texture: Texture2D) -> void:
 var material:=StandardMaterial3D.new()
 material.albedo_texture=texture
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold=0.4
 back_materials[id]=material

func look_by(relative: Vector2) -> void:
 look_offset.x=clampf(look_offset.x-relative.x*look_sensitivity,-deg_to_rad(look_yaw_limit_degrees),deg_to_rad(look_yaw_limit_degrees))
 look_offset.y=clampf(look_offset.y-relative.y*look_sensitivity,-deg_to_rad(look_pitch_limit_degrees),deg_to_rad(look_pitch_limit_degrees))
 camera.rotation=base_camera_rotation+Vector3(look_offset.y,look_offset.x,0)

func reset_look() -> void:
 look_offset=Vector2.ZERO
 camera.rotation=base_camera_rotation