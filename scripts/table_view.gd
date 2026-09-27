class_name LyncoTableView
extends Node3D

# Presentation only: cells never affect combat rules or card ownership.
const COLS := 6
const ROWS := 5
const INVALID := Vector2i(-1, -1)
const STEP := Vector2(3.1, 2.35)
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
const FAR_OPACITY := 0.84
var far_materials: Dictionary = {}
var hovered_cell := INVALID
var owner_line_mesh: PlaneMesh
var owner_dash_mesh: PlaneMesh
var owner_line_material: StandardMaterial3D
var opponent_mark_material: StandardMaterial3D
var opponent_side_mesh: PlaneMesh
var battle_grid: MeshInstance3D
var mirror_grid: MeshInstance3D
var battle_grid_material: ShaderMaterial
var reduced_motion := false
var influence_tween: Tween
var preview_tween: Tween

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
 direction_mesh=PlaneMesh.new();direction_mesh.size=Vector2(0.22,0.22)
 direction_material=ShaderMaterial.new()
 direction_material.shader=preload("res://asset/card_direction_tab.gdshader")
 owner_line_mesh=PlaneMesh.new();owner_line_mesh.size=Vector2(0.74,0.035)
 owner_dash_mesh=PlaneMesh.new();owner_dash_mesh.size=Vector2(0.21,0.075)
 opponent_side_mesh=PlaneMesh.new();opponent_side_mesh.size=Vector2(0.065,1.65)
 opponent_mark_material=StandardMaterial3D.new()
 opponent_mark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 opponent_mark_material.albedo_color=Color("ff655c")
 owner_line_material=StandardMaterial3D.new()
 owner_line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 owner_line_material.albedo_color=Color("dddeda")
 _setup_battle_grid()
 get_viewport().size_changed.connect(_fit_top_view)
 _setup_atmosphere()
 _setup_garnet_cubes()
 _setup_distributors()
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
 return Vector3((cell.x-2.5)*STEP.x,0.065,(cell.y-2.0)*STEP.y-1.3)

func cell_at(local_point: Vector2) -> Vector2i:
 if not ui_stage or opponent_view:return INVALID
 if not top_view and not Rect2(20,180,1560,450).has_point(local_point):return INVALID
 var point:Vector2=ui_stage.get_global_transform_with_canvas()*local_point
 if not get_viewport().get_visible_rect().has_point(point):return INVALID
 var hit:Variant=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))
 if hit==null:return INVALID
 var cell:=Vector2i(roundi(hit.x/STEP.x+2.5),roundi((hit.z+1.3)/STEP.y+2.0))
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
  if preview_tween and preview_tween.is_valid():preview_tween.kill()
  hint.position=cell_position(cell)+Vector3(0,0.018,0)
  hint.scale=Vector3.ONE*0.97 if not reduced_motion else Vector3.ONE
  if not reduced_motion:
   preview_tween=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
   preview_tween.tween_property(hint,"scale",Vector3.ONE,0.1)
 if preview_allowed!=allowed or not hint.visible:
  hint_material.set_shader_parameter("tint",Color(1.0,0.84,0.26,1.0) if allowed else Color(0.55,0.57,0.59,0.35))
 preview_cell=cell;preview_allowed=allowed
 if not hint.visible:hint.show()
 _refresh_battle_grid()
 return cell

func hide_preview() -> void:
 if preview_tween and preview_tween.is_valid():preview_tween.kill()
 hint.scale=Vector3.ONE
 if hint.visible:hint.hide()
 preview_cell=INVALID
 _refresh_battle_grid()

func place(id: String, cell: Vector2i, quick: bool = false, reverse: bool = false) -> void:
 assert(free_cell(cell))
 var near := _make_card(id,reverse,quick)
 var far := _make_card(id,reverse,quick)
 _configure_mirror(far)
 cards[cell]=near; mirror_cards[cell]=far
 _fly(near,cell_position(cell)+Vector3(0,0.65,0),cell_position(cell),Vector3(0.32,0,0),Vector3.ZERO,0.1 if quick else 0.22,0.0)
 far.position=mirror_position(cell);far.rotation=Vector3(0,PI,0)
 _refresh_battle_grid()

func clear_cards() -> void:
 select_influence(INVALID)
 set_hover_card(INVALID)
 for tween in animations:
  if tween.is_valid():tween.kill()
 animations.clear();set_process(false)
 for holder in cards.values():holder.queue_free()
 cards.clear();hide_preview()
 for holder in mirror_cards.values():holder.queue_free()
 mirror_cards.clear()
 for holder in opponent_fan:holder.hide()
 _refresh_battle_grid()

func set_back_texture(id: String, texture: Texture2D) -> void:
 var material:=StandardMaterial3D.new()
 material.albedo_texture=texture
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
 material.alpha_scissor_threshold=0.4
 back_materials[id]=material

func look_by(relative: Vector2) -> void:
 if opponent_view or top_view or card_focus_active or card_focus_returning:return
 look_offset.x=clampf(look_offset.x-relative.x*look_sensitivity,-deg_to_rad(look_yaw_limit_degrees),deg_to_rad(look_yaw_limit_degrees))
 look_offset.y=clampf(look_offset.y-relative.y*look_sensitivity,-deg_to_rad(look_pitch_limit_degrees),deg_to_rad(look_pitch_limit_degrees))
 camera.rotation=base_camera_rotation+Vector3(look_offset.y,look_offset.x,0)

func reset_look() -> void:
 select_influence(INVALID)
 if top_view:set_top_view(false)
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
  arrow.position=Vector3(offset.x*0.79,0.038,offset.y*1.13)
  arrow.rotation.y=-offset.angle()-PI*0.5
  holder.add_child(arrow)

func pan_by(direction: Vector2, delta: float) -> void:
 if opponent_view or top_view or card_focus_active or card_focus_returning:return
 var step := direction.limit_length() * pan_speed * delta
 camera.position.x = clampf(camera.position.x + step.x,base_camera_position.x-pan_limits.x,base_camera_position.x+pan_limits.x)
 camera.position.z = clampf(camera.position.z + step.y,base_camera_position.z-pan_limits.y,base_camera_position.z+pan_limits.y)

func mark_owner(cell: Vector2i, owner: String) -> void:
 if not cards.has(cell): return
 for holder in [cards[cell],mirror_cards[cell]]:
  _label_owner(holder,owner)
 _refresh_battle_grid()

func _label_owner(holder: Node3D, owner: String) -> void:
 holder.set_meta("owner",owner)
 if owner=="opponent":
  _ensure_fan()
  holder.get_node("Back").material_override=_far_material(opponent_back_material) if bool(holder.get_meta("mirror",false)) else opponent_back_material
  holder.get_node("Front").material_override=_face_material(holder,"opponent:"+str(holder.get_meta("card_id")))
 var existing:=holder.get_node_or_null("OwnerMark")
 if existing:
  holder.remove_child(existing);existing.queue_free()
 var mark:=Node3D.new();mark.name="OwnerMark";holder.add_child(mark)
 var inverted: bool=bool(holder.get_meta("mirror",false))
 mark.position=Vector3(0,-0.025,-1.17 if inverted else 1.17)
 var segments: int=4 if owner=="opponent" else 1
 for i in range(segments):
  var line:=MeshInstance3D.new()
  line.mesh=owner_dash_mesh if owner=="opponent" else owner_line_mesh
  var material: StandardMaterial3D=opponent_mark_material if owner=="opponent" else owner_line_material
  line.material_override=_far_material(material) if bool(holder.get_meta("mirror",false)) else material
  line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  line.position.x=(float(i)-1.5)*0.29 if owner=="opponent" else 0.0
  mark.add_child(line)
 if owner=="opponent":
  var side:=MeshInstance3D.new()
  side.name="OwnerSide"
  side.mesh=opponent_side_mesh
  side.material_override=_far_material(opponent_mark_material) if inverted else opponent_mark_material
  side.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  side.position=Vector3(-0.84,0,-mark.position.z)
  mark.add_child(side)

func set_hover_card(cell: Vector2i) -> void:
 if hovered_cell==cell:return
 _set_card_brightness(hovered_cell,false)
 hovered_cell=cell
 _set_card_brightness(hovered_cell,true)

func _set_card_brightness(cell: Vector2i, highlighted: bool) -> void:
 if not cards.has(cell) or str(cards[cell].get_meta("owner","player"))!="opponent":return
 var id: String=str(cards[cell].get_meta("card_id"))
 var material: Material=materials[id if highlighted else "opponent:"+id]
 cards[cell].get_node("Front").material_override=material
 mirror_cards[cell].get_node("Front").material_override=_far_material(material)

# These are render-only counterparts. Only `cards` represents board occupancy.
const OPPONENT_TABLE_Z: float = -17.8
var mirror_cards: Dictionary = {}
var opponent_fan: Array[Node3D] = []
var opponent_back_material: StandardMaterial3D
var camera_transition: Tween
var opponent_view: bool = false
var saved_player_position: Vector3
var saved_player_rotation: Vector3
var saved_look_offset: Vector2
@export var opponent_camera_position := Vector3(0,9.2,0.0)
@export var opponent_camera_rotation := Vector3(-0.42,0,0)

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
 _add_influence_overlay(holder)
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
  if is_instance_valid(holder):
   holder.get_node("ContactShadow").show()
   _settle_card(holder))
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
  holder.get_node("Back").material_override=_far_material(opponent_back_material) if bool(holder.get_meta("mirror",false)) else opponent_back_material
  holder.get_node("ContactShadow").hide()
  holder.hide(); opponent_fan.append(holder)

func show_opponent_hand(count: int) -> void:
 _ensure_fan()
 for i in range(opponent_fan.size()):
  var holder: Node3D = opponent_fan[i]
  holder.visible=i<count
  if i>=count:continue
  var t: float = (float(i)-float(count-1)*0.5)/maxf(float(count-1)*0.5,1.0)
  holder.position=Vector3((float(i)-float(count-1)*0.5)*1.08,2.55+0.52*(1.0-t*t),OPPONENT_TABLE_Z-5.6)
  holder.rotation=Vector3(1.20,0,-t*0.16)

func play_opponent(id: String, cell: Vector2i, hand_before: int, hand_after: int, quick: bool) -> void:
 assert(free_cell(cell))
 show_opponent_hand(hand_before)
 var slot: int = maxi(0,floori(float(hand_before-1) / 2.0))
 var source: Node3D = opponent_fan[slot]
 var start: Vector3 = source.global_position
 source.hide()
 var near := _make_card(id,false,quick)
 var far := _make_card(id,false,quick)
 _configure_mirror(far)
 cards[cell]=near; mirror_cards[cell]=far
 far.position=mirror_position(cell); far.rotation.y=PI
 mark_owner(cell,"opponent")
 var flight := _slide_opponent(near,start,cell_position(cell),quick)
 await flight.finished
 show_opponent_hand(hand_after)

func set_opponent_view(enabled: bool, quick: bool = false) -> void:
 if top_view:set_top_view(false)
 select_influence(INVALID)
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

func _slide_opponent(holder: Node3D, start: Vector3, finish: Vector3, quick: bool) -> Tween:
 holder.position=start
 holder.rotation=Vector3.ZERO
 holder.get_node("ContactShadow").hide()
 holder.get_node("OwnerMark").hide()
 _set_card_directions_visible(holder,false)
 var tween:=create_tween()
 # A straight, accelerating insertion with a hard stop; no arc, spin or bounce.
 tween.tween_property(holder,"position",finish,0.10 if quick else 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
 tween.tween_callback(func():
  if is_instance_valid(holder):
   holder.get_node("ContactShadow").show()
   holder.get_node("OwnerMark").show()
   _set_card_directions_visible(holder,true))
 tween.tween_callback(_settle_card.bind(holder))
 tween.tween_interval(0.02 if quick else 0.04)
 _track(tween)
 return tween

func _settle_card(holder: Node3D) -> void:
 if reduced_motion:return
 holder.scale=Vector3(1.035,1,0.97)
 var settle:=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 settle.tween_property(holder,"scale",Vector3.ONE,0.14)
 _track(settle)

# Cache distant variants without modifying resources shared by the near table.
func _far_material(source: StandardMaterial3D) -> StandardMaterial3D:
 if not far_materials.has(source):
  var faded: StandardMaterial3D=source.duplicate()
  faded.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  faded.albedo_color.a=FAR_OPACITY
  far_materials[source]=faded
 return far_materials[source]

func _face_material(holder: Node3D, id: String) -> StandardMaterial3D:
 return _far_material(materials[id]) if bool(holder.get_meta("mirror",false)) else materials[id]

func _configure_mirror(holder: Node3D) -> void:
 holder.set_meta("mirror",true)
 # The opaque paper core would otherwise cancel the translucent face.
 holder.get_node("Body").hide()
 holder.get_node("ContactShadow").hide()
 for face in ["Front","Back"]:
  var mesh: MeshInstance3D=holder.get_node(face)
  mesh.material_override=_far_material(mesh.material_override)
 for child in holder.get_children():
  if str(child.name).begins_with("Direction_"):
   var faded: ShaderMaterial=direction_material.duplicate()
   faded.set_shader_parameter("opacity",FAR_OPACITY)
   child.material_override=faded

func _setup_atmosphere() -> void:
 for child in $OpponentTable.get_children():
  if child is MeshInstance3D:
   child.material_override=_far_material(child.mesh.surface_get_material(0))
 var gap:=MeshInstance3D.new()
 gap.name="BetweenTablesShade"
 var plane:=PlaneMesh.new()
 plane.size=Vector2(24.0,3.4)
 gap.mesh=plane
 var shade:=ShaderMaterial.new()
 shade.shader=preload("res://asset/table_gap.gdshader")
 gap.material_override=shade
 gap.position=Vector3(0,-0.16,OPPONENT_TABLE_Z*0.5)
 gap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(gap)

# Visual adjacency preview only; it never applies card effects.
var selected_cell := INVALID
var influenced_cells: Array[Vector2i] = []
var influence_range: Array[Vector2i] = []
var influence_dim: ShaderMaterial
var influence_glow: ShaderMaterial
var influence_mesh: PlaneMesh
var influence_links: Array[MeshInstance3D] = []
var top_view := false
var top_zoom := 1.0
var top_saved_transform: Transform3D
var top_saved_projection: Camera3D.ProjectionType
var top_saved_table_scale: Vector3
var top_saved_table_material: Material
var top_saved_size: float
var top_hidden: Dictionary = {}
var card_focus_active := false
var card_focus_transform: Transform3D
var card_focus_size: float
var card_focus_zoom: float
var card_focus_tween: Tween
var card_focus_returning := false

func restore_card_focus() -> void:
 if not card_focus_active and not card_focus_returning:return
 if card_focus_tween and card_focus_tween.is_valid():card_focus_tween.kill()
 camera.transform=card_focus_transform
 camera.size=card_focus_size
 top_zoom=card_focus_zoom
 card_focus_active=false
 card_focus_returning=false

func dismiss_card_focus() -> void:
 var from_transform: Transform3D=camera.transform
 var from_size: float=camera.size
 var animate: bool=card_focus_active and not reduced_motion
 select_influence(INVALID)
 if not animate:return
 camera.transform=from_transform;camera.size=from_size
 card_focus_returning=true
 card_focus_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 card_focus_tween.tween_property(camera,"transform",card_focus_transform,0.2)
 card_focus_tween.tween_property(camera,"size",card_focus_size,0.2)
 card_focus_tween.finished.connect(func():card_focus_returning=false)

func click_influence(cell: Vector2i) -> void:
 if card_focus_active:
  dismiss_card_focus()
  return
 select_influence(cell)
 if selected_cell==INVALID:return
 card_focus_transform=camera.transform
 card_focus_size=camera.size
 card_focus_zoom=top_zoom
 card_focus_active=true
 var target: Vector3=cell_position(selected_cell)
 var destination: Transform3D=camera.transform
 if top_view:
  destination.origin=Vector3(target.x,camera.position.y,target.z)
 else:
  destination.origin=target+camera.basis.z*11.5
 card_focus_tween=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 var duration: float=0.07 if reduced_motion else 0.18
 card_focus_tween.tween_property(camera,"transform",destination,duration)
 if top_view:card_focus_tween.tween_property(camera,"size",minf(camera.size,7.5),duration)

func _add_influence_overlay(holder: Node3D) -> void:
 if influence_mesh==null:
  influence_mesh=PlaneMesh.new()
  influence_mesh.size=Vector2(1.92,2.58)
  influence_dim=ShaderMaterial.new()
  influence_dim.shader=preload("res://asset/card_influence.gdshader")
  influence_glow=influence_dim.duplicate()
  influence_glow.set_shader_parameter("glowing",true)
 var overlay:=MeshInstance3D.new()
 overlay.name="InfluenceOverlay"
 overlay.mesh=influence_mesh
 overlay.position.y=0.055
 overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 overlay.hide()
 holder.add_child(overlay)

func select_influence(cell: Vector2i) -> void:
 restore_card_focus()
 if influence_tween and influence_tween.is_valid():influence_tween.kill()
 for link in influence_links:link.hide()
 selected_cell=cell if cards.has(cell) and selected_cell!=cell else INVALID
 influenced_cells.clear()
 influence_range.clear()
 if cards.has(selected_cell):
  var source: Node3D=cards[selected_cell]
  var id: String=str(source.get_meta("card_id"))
  var definition: Dictionary=Catalog.back_card(id) if bool(source.get_meta("reverse",false)) else Catalog.card(id)
  for direction in Directions.for_definition(definition):
   var target: Vector2i=selected_cell+Vector2i(Directions.OFFSETS[direction])
   if target.x>=0 and target.x<COLS and target.y>=0 and target.y<ROWS:
    influence_range.append(target)
   if cards.has(target):influenced_cells.append(target)
 for placed_cell in cards:
  for holder in [cards[placed_cell],mirror_cards[placed_cell]]:
   var overlay: MeshInstance3D=holder.get_node("InfluenceOverlay")
   overlay.visible=selected_cell!=INVALID and placed_cell!=selected_cell
   overlay.material_override=influence_glow if placed_cell in influenced_cells else influence_dim
 _show_influence_links()
 _refresh_battle_grid()
 battle_grid_material.set_shader_parameter("influence_origin",Vector2(selected_cell)+Vector2(0.5,0.5))
 battle_grid_material.set_shader_parameter("influence_reveal",1.0 if reduced_motion or selected_cell==INVALID else 0.0)
 if selected_cell!=INVALID and not reduced_motion:
  influence_tween=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  influence_tween.tween_property(battle_grid_material,"shader_parameter/influence_reveal",1.0,0.22)

func set_top_view(enabled: bool) -> void:
 if top_view==enabled:return
 restore_card_focus()
 if enabled:
  top_zoom=1.0
  top_saved_transform=camera.transform
  top_saved_projection=camera.projection
  top_saved_size=camera.size
  camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.position=Vector3(0,25,-1.3)
  top_saved_table_scale=$Table/Tabletop.scale
  top_saved_table_material=$Table/Tabletop.material_override
  $Table/Tabletop.scale=Vector3(10,1,10)
  var black_board:=StandardMaterial3D.new()
  black_board.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  black_board.albedo_color=Color("202324")
  $Table/Tabletop.material_override=black_board
  camera.rotation=Vector3(-PI*0.5,0,0)
  for node in [$OpponentTable,$OpponentHand,$DummyProps,$Floor,$BetweenTablesShade,$GarnetCubes,$Distributors]:
   top_hidden[node]=node.visible
   node.hide()
  for link in influence_links:
   if bool(link.get_meta("mirror",false)):
    top_hidden[link]=link.visible;link.hide()
  for holder in mirror_cards.values():
   top_hidden[holder]=holder.visible
   holder.hide()
 else:
  $Table/Tabletop.scale=top_saved_table_scale
  $Table/Tabletop.material_override=top_saved_table_material
  camera.transform=top_saved_transform
  camera.projection=top_saved_projection
  camera.size=top_saved_size
  for node in top_hidden:
   if is_instance_valid(node):node.visible=top_hidden[node]
  top_hidden.clear()
 top_view=enabled
 _refresh_battle_grid()
 hide_preview()
 if enabled:_fit_top_view()
 else:
  for link in influence_links:link.hide()
  _show_influence_links()

func _fit_top_view() -> void:
 if not top_view:return
 if card_focus_active:return
 var viewport_size: Vector2=get_viewport().get_visible_rect().size
 camera.size=maxf(STEP.y*ROWS+0.1,(STEP.x*COLS+0.1)*viewport_size.y/maxf(viewport_size.x,1.0))*top_zoom
 _clamp_top_camera()
func zoom_top_view(steps: float, pointer: Vector2 = Vector2(-1,-1)) -> void:
 if not top_view:return
 if card_focus_returning:restore_card_focus()
 if card_focus_active:select_influence(INVALID)
 var before: Variant=null
 if pointer.x>=0:
  before=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(pointer),camera.project_ray_normal(pointer))
 top_zoom=clampf(top_zoom*pow(0.88,steps),0.35,1.0)
 _fit_top_view()
 if before!=null:
  var after: Variant=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(pointer),camera.project_ray_normal(pointer))
  if after!=null:camera.position+=before-after
 _clamp_top_camera()

func _clamp_top_camera() -> void:
 if not top_view:return
 var viewport_size: Vector2=get_viewport().get_visible_rect().size
 var half_height: float=camera.size*0.5
 var half_width: float=half_height*viewport_size.x/maxf(viewport_size.y,1.0)
 var limit_x: float=maxf(0.0,STEP.x*COLS*0.5-half_width)
 var limit_z: float=maxf(0.0,STEP.y*ROWS*0.5-half_height)
 camera.position.x=clampf(camera.position.x,-limit_x,limit_x)
 camera.position.z=clampf(camera.position.z,-1.3-limit_z,-1.3+limit_z)
func _show_influence_links() -> void:
 if influenced_cells.is_empty():return
 if influence_links.is_empty():
  var material:=ShaderMaterial.new()
  material.shader=preload("res://asset/card_connection.gdshader")
  var mesh:=PlaneMesh.new()
  mesh.size=Vector2(0.20,0.52)
  for i in range(Directions.OFFSETS.size()*2):
   var link:=MeshInstance3D.new()
   link.name="InfluenceLink"+str(i)
   link.mesh=mesh;link.material_override=material
   link.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   link.set_meta("mirror",i%2==1)
   world.add_child(link);link.hide()
   influence_links.append(link)
 for i in range(influenced_cells.size()):
  var target: Vector2i=influenced_cells[i]
  for side in range(2):
   var mirrored: bool=side==1
   var start: Vector3=mirror_position(selected_cell) if mirrored else cell_position(selected_cell)
   var finish: Vector3=mirror_position(target) if mirrored else cell_position(target)
   var direction: Vector3=(finish-start).normalized()
   var link: MeshInstance3D=influence_links[i*2+side]
   link.position=(start+finish)*0.5+Vector3(0,0.085,0)
   link.rotation.y=atan2(-direction.x,-direction.z)
   var card_extent: float=CARD_METRES.x if absf(direction.x)>0.5 else CARD_METRES.y
   link.scale.z=(start.distance_to(finish)-card_extent+0.30)/0.52
   link.visible=not mirrored or not top_view

func _setup_garnet_cubes() -> void:
 var group:=Node3D.new();group.name="GarnetCubes";add_child(group)
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
 var positions: Array[Vector3]=[Vector3(7.3,0.245,5.2),Vector3(7.9,0.245,5.2),Vector3(7.6,0.245,4.6)]
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

func _set_card_directions_visible(holder: Node3D, enabled: bool) -> void:
 for child in holder.get_children():
  if str(child.name).begins_with("Direction_"):child.visible=enabled

func _setup_battle_grid() -> void:
 var mesh:=PlaneMesh.new();mesh.size=Vector2(STEP.x*COLS,STEP.y*ROWS)
 battle_grid_material=ShaderMaterial.new()
 battle_grid_material.shader=preload("res://asset/battle_grid.gdshader")
 battle_grid=MeshInstance3D.new()
 battle_grid.name="BattleGrid";battle_grid.mesh=mesh;battle_grid.material_override=battle_grid_material
 battle_grid.position=Vector3(0,0.008,-1.3)
 battle_grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(battle_grid);battle_grid.hide()
 mirror_grid=MeshInstance3D.new()
 mirror_grid.name="MirrorGrid";mirror_grid.mesh=mesh;mirror_grid.material_override=battle_grid_material
 mirror_grid.position=Vector3(0,0.008,OPPONENT_TABLE_Z+1.3);mirror_grid.rotation.y=PI
 mirror_grid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(mirror_grid);mirror_grid.hide()

func _refresh_battle_grid() -> void:
 if not is_instance_valid(battle_grid):return
 var opponent_mask: int=0
 for cell in cards:
  if str(cards[cell].get_meta("owner","player"))=="opponent":
   opponent_mask |= 1 << (cell.y*COLS+cell.x)
 battle_grid_material.set_shader_parameter("opponent_mask",opponent_mask)
 var influence_mask: int=0
 for cell in influence_range:influence_mask |= 1 << (cell.y*COLS+cell.x)
 battle_grid_material.set_shader_parameter("influence_mask",influence_mask)
 var active: bool=not cards.is_empty() or preview_cell!=INVALID
 battle_grid.visible=active
 mirror_grid.visible=active and not top_view

var black_market_open := false
var black_market_glow: StandardMaterial3D

func _setup_distributors() -> void:
 var group:=Node3D.new();group.name="Distributors";add_child(group)
 for side in [-1,1]:
  var machine:=Node3D.new()
  machine.name="Shop" if side<0 else "BlackMarket"
  machine.position=Vector3(float(side)*9.2,0.1,OPPONENT_TABLE_Z*0.5)
  group.add_child(machine)
  var shell:=StandardMaterial3D.new()
  shell.albedo_color=Color("dddcd1") if side<0 else Color("292c2d")
  shell.roughness=0.3; shell.metallic=0.2
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

func set_black_market_open(enabled: bool) -> void:
 black_market_open=enabled
 black_market_glow.albedo_color=Color("ff263b") if enabled else Color("181a19")
 $Distributors/BlackMarket/ActiveLight.visible=enabled
