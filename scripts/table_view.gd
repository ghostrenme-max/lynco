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
@export var pan_speed: float = 3.0
@export var pan_limits := Vector2(3.5,2.5)
var base_camera_position: Vector3
var base_camera_rotation: Vector3
var look_offset := Vector2.ZERO
var cards: Dictionary = {}
var materials: Dictionary = {}
var back_materials: Dictionary = {}
var black_body_material: StandardMaterial3D
const Directions = preload("res://scripts/direction_preview.gd")
var direction_mesh: PlaneMesh
var direction_material: ShaderMaterial
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
 base_camera_position=camera.position
 black_body_material=StandardMaterial3D.new()
 black_body_material.albedo_color=Color(0.025,0.028,0.025,1.0)
 black_body_material.roughness=0.9
 card_mesh=PlaneMesh.new();card_mesh.size=CARD_METRES
 hint_material=ShaderMaterial.new()
 hint_material.shader=preload("res://asset/card_placement.gdshader")
 hint=MeshInstance3D.new();hint.mesh=card_mesh;hint.material_override=hint_material
 world.add_child(hint);hint.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;hint.hide()
 direction_mesh=PlaneMesh.new();direction_mesh.size=Vector2(0.28,0.34)
 direction_material=ShaderMaterial.new()
 direction_material.shader=preload("res://asset/card_direction.gdshader")
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
 if not ui_stage or opponent_view:return INVALID
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

func place(id: String, cell: Vector2i, quick: bool = false, reverse: bool = false) -> void:
 assert(free_cell(cell))
 var near := _make_card(id,reverse,quick)
 var far := _make_card(id,reverse,quick)
 cards[cell]=near; mirror_cards[cell]=far
 _fly(near,cell_position(cell)+Vector3(0,0.65,0),cell_position(cell),Vector3(0.32,0,0),Vector3.ZERO,0.1 if quick else 0.22,0.0)
 _fly(far,cell_position(cell)+Vector3(0,0.1,0),mirror_position(cell),Vector3.ZERO,Vector3(0,PI,0),0.14 if quick else 0.48,0.3 if quick else 2.0)

func clear_cards() -> void:
 for tween in animations:
  if tween.is_valid():tween.kill()
 animations.clear();set_process(false)
 for holder in cards.values():holder.queue_free()
 cards.clear();hide_preview()
 for holder in mirror_cards.values():holder.queue_free()
 mirror_cards.clear()
 for holder in opponent_fan:holder.hide()

func set_back_texture(id: String, texture: Texture2D) -> void:
 var material:=StandardMaterial3D.new()
 material.albedo_texture=texture
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold=0.4
 back_materials[id]=material

func look_by(relative: Vector2) -> void:
 if opponent_view:return
 look_offset.x=clampf(look_offset.x-relative.x*look_sensitivity,-deg_to_rad(look_yaw_limit_degrees),deg_to_rad(look_yaw_limit_degrees))
 look_offset.y=clampf(look_offset.y-relative.y*look_sensitivity,-deg_to_rad(look_pitch_limit_degrees),deg_to_rad(look_pitch_limit_degrees))
 camera.rotation=base_camera_rotation+Vector3(look_offset.y,look_offset.x,0)

func reset_look() -> void:
 if camera_transition and camera_transition.is_valid():camera_transition.kill()
 opponent_view=false
 look_offset=Vector2.ZERO
 camera.rotation=base_camera_rotation
 camera.position=base_camera_position

func _add_direction_arrows(holder: Node3D, data: Dictionary, quick: bool) -> void:
 direction_material.set_shader_parameter("reduced_motion",quick)
 for key in Directions.for_definition(data):
  var offset:Vector2=Directions.OFFSETS[key]
  var arrow:=MeshInstance3D.new()
  arrow.name="Direction_"+str(key)
  arrow.mesh=direction_mesh
  arrow.material_override=direction_material
  arrow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  arrow.position=Vector3(offset.x*0.60,0.038,offset.y*0.95)
  arrow.rotation.y=-offset.angle()-PI*0.5
  holder.add_child(arrow)

func pan_by(direction: Vector2, delta: float) -> void:
 if opponent_view:return
 var step := direction.limit_length() * pan_speed * delta
 camera.position.x = clampf(camera.position.x + step.x,base_camera_position.x-pan_limits.x,base_camera_position.x+pan_limits.x)
 camera.position.z = clampf(camera.position.z + step.y,base_camera_position.z-pan_limits.y,base_camera_position.z+pan_limits.y)

func mark_owner(cell: Vector2i, owner: String) -> void:
 if not cards.has(cell): return
 for holder in [cards[cell],mirror_cards[cell]]:
  _label_owner(holder,owner)

func _label_owner(holder: Node3D, owner: String) -> void:
 holder.set_meta("owner",owner)
 if owner=="opponent":
  _ensure_fan()
  holder.get_node("Back").material_override=opponent_back_material
 var label := Label3D.new()
 label.text = "상대" if owner == "opponent" else "나"
 label.font_size = 44; label.pixel_size = 0.006
 label.position = Vector3(0,0.055,1.0)
 label.rotation_degrees.x = -90
 label.modulate = Color("f0f0ea") if owner == "opponent" else Color("f5d335")
 label.no_depth_test = false
 holder.add_child(label)

# These are render-only counterparts. Only `cards` represents board occupancy.
const OPPONENT_TABLE_Z: float = -13.8
var mirror_cards: Dictionary = {}
var opponent_fan: Array[Node3D] = []
var opponent_back_material: StandardMaterial3D
var camera_transition: Tween
var opponent_view: bool = false
var saved_player_position: Vector3
var saved_player_rotation: Vector3
var saved_look_offset: Vector2
@export var opponent_camera_position := Vector3(0,6.4,1.0)
@export var opponent_camera_rotation := Vector3(-0.38,0,0)

func mirror_position(cell: Vector2i) -> Vector3:
 var near := cell_position(cell)
 return Vector3(-near.x,near.y,OPPONENT_TABLE_Z-near.z)

func _make_card(id: String, reverse: bool, quick: bool) -> Node3D:
 var holder: Node3D = CARD_OBJECT.instantiate()
 world.add_child(holder)
 holder.set_meta("card_id",id); holder.set_meta("reverse",reverse)
 var data: Dictionary = Catalog.back_card(id) if reverse else Catalog.card(id)
 if bool(data.dark): holder.get_node("Body").material_override=black_body_material
 holder.get_node("Front").material_override=materials["reverse:"+id if reverse else id]
 holder.get_node("Back").material_override=back_materials["back_black" if bool(data.dark) else "back_white"]
 _add_direction_arrows(holder,data,quick)
 return holder

func _track(tween: Tween) -> void:
 animations.append(tween)
 tween.finished.connect(func(): animations.erase(tween))

func _flight_pose(t: float, holder: Node3D, start: Vector3, finish: Vector3, start_rotation: Vector3, end_rotation: Vector3, height: float) -> void:
 holder.position=start.lerp(finish,t)+Vector3.UP*sin(PI*t)*height
 holder.rotation=start_rotation.lerp(end_rotation,t)

func _fly(holder: Node3D, start: Vector3, finish: Vector3, start_rotation: Vector3, end_rotation: Vector3, duration: float, height: float) -> Tween:
 holder.position=start; holder.rotation=start_rotation
 holder.get_node("ContactShadow").hide()
 var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 tween.tween_method(_flight_pose.bind(holder,start,finish,start_rotation,end_rotation,height),0.0,1.0,duration)
 tween.finished.connect(func():
  if is_instance_valid(holder):holder.get_node("ContactShadow").show())
 _track(tween)
 return tween

func _ensure_fan() -> void:
 if not opponent_fan.is_empty():return
 opponent_back_material=StandardMaterial3D.new()
 opponent_back_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 opponent_back_material.albedo_color=Color.BLACK
 for i in range(7):
  var holder: Node3D = CARD_OBJECT.instantiate()
  $OpponentHand.add_child(holder)
  holder.get_node("Body").material_override=black_body_material
  holder.get_node("Front").material_override=opponent_back_material
  holder.get_node("Back").material_override=opponent_back_material
  holder.get_node("ContactShadow").hide()
  holder.hide(); opponent_fan.append(holder)

func show_opponent_hand(count: int) -> void:
 _ensure_fan()
 for i in range(opponent_fan.size()):
  var holder: Node3D = opponent_fan[i]
  holder.visible=i<count
  if i>=count:continue
  var t: float = (float(i)-float(count-1)*0.5)/maxf(float(count-1)*0.5,1.0)
  holder.position=Vector3((float(i)-float(count-1)*0.5)*1.08,2.55+0.52*(1.0-t*t),-18.0)
  holder.rotation=Vector3(1.20,0,-t*0.16)

func play_opponent(id: String, cell: Vector2i, hand_before: int, hand_after: int, quick: bool) -> void:
 assert(free_cell(cell))
 show_opponent_hand(hand_before)
 var slot: int = maxi(0,(hand_before-1)/2)
 var source: Node3D = opponent_fan[slot]
 var start: Vector3 = source.global_position
 var start_rotation: Vector3 = source.rotation
 source.hide()
 var near := _make_card(id,false,quick)
 var far := _make_card(id,false,quick)
 cards[cell]=near; mirror_cards[cell]=far
 far.position=mirror_position(cell); far.rotation.y=PI
 mark_owner(cell,"opponent")
 var flight := _fly(near,start,cell_position(cell),start_rotation,Vector3.ZERO,0.16 if quick else 0.62,0.5 if quick else 2.4)
 await flight.finished
 show_opponent_hand(hand_after)

func set_opponent_view(enabled: bool, quick: bool = false) -> void:
 if enabled==opponent_view:return
 if camera_transition and camera_transition.is_valid():camera_transition.kill()
 if enabled:
  saved_player_position=camera.position; saved_player_rotation=camera.rotation; saved_look_offset=look_offset
 opponent_view=enabled
 hide_preview()
 camera_transition=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
 camera_transition.tween_property(camera,"position",opponent_camera_position if enabled else saved_player_position,0.14 if quick else 0.46)
 camera_transition.tween_property(camera,"rotation",opponent_camera_rotation if enabled else saved_player_rotation,0.14 if quick else 0.46)
 await camera_transition.finished
 if not enabled:look_offset=saved_look_offset
