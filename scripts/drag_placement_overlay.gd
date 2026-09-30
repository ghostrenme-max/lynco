extends Control
var ui: Control
var caption: Label
var pointer := Vector2.ZERO
const VALID := Color("e9faff")
const LINK := Color("70dfff")
const BLOCKED := Color("f1a998")

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=151
 caption=Label.new();caption.add_theme_font_size_override("font_size",18)
 caption.add_theme_color_override("font_color",VALID)
 var bg:=StyleBoxFlat.new();bg.bg_color=Color("16151bee")
 bg.set_corner_radius_all(5);bg.content_margin_left=12;bg.content_margin_right=12
 bg.content_margin_top=7;bg.content_margin_bottom=7
 caption.add_theme_stylebox_override("normal",bg)
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(caption)

func _process(_delta: float) -> void:
 visible=ui.drag_uid>=0
 if visible:queue_redraw()

func project(point: Vector3) -> Vector2:
 return ui.stage.get_global_transform_with_canvas().affine_inverse()*ui.table.camera.unproject_position(point)

func outline(cell: Vector2i, color: Color) -> void:
 var center: Vector3=ui.table.cell_position(cell)+Vector3(0,0.12,0)
 var half: Vector2=ui.table.CARD_METRES*0.54
 var points:=PackedVector2Array()
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1),Vector2(-1,-1)]:
  points.append(project(center+Vector3(corner.x*half.x,0,corner.y*half.y)))
 draw_polyline(points,Color(color,0.14),6,true)
 draw_polyline(points,color,1.7,true)

func arrow(from: Vector2, to: Vector2, color: Color) -> void:
 if from.distance_to(to)<3:return
 var direction:=from.direction_to(to)
 draw_line(from,to,color,2,true)
 draw_polyline(PackedVector2Array([to-direction.rotated(0.55)*9,to,to-direction.rotated(-0.55)*9]),color,2,true)

func _draw() -> void:
 if ui.drag_uid<0:return
 var point: Vector2=pointer
 var cell: Vector2i=ui.table.cell_at(point)
 var reason: String=ui.model.unavailable_reason(ui.drag_uid)
 if reason.is_empty():
  if cell==ui.Table.INVALID:reason="테이블의 빈칸에 놓아주세요"
  elif not ui.table.free_cell(cell):reason="이미 카드가 있는 칸입니다"
 caption.text=reason if not reason.is_empty() else "놓아서 배치"
 caption.add_theme_color_override("font_color",BLOCKED if not reason.is_empty() else VALID)
 caption.reset_size()
 caption.position=Vector2(clampf(point.x+22,12,1600-caption.size.x-12),clampf(point.y+24,12,900-caption.size.y-12))
 if cell==ui.Table.INVALID:return
 outline(cell,VALID if reason.is_empty() else BLOCKED)
 if not reason.is_empty():return
 var index: int=ui.model.find_card(ui.drag_uid)
 if index<0 or ui.model.is_concealed(ui.drag_uid):return
 var entry: Dictionary=ui.model.hand[index]
 var source: Dictionary={"cell":cell,"entry":entry,"owner":"player","reverse":false,"invested":0}
 var start: Vector2=ui.table.screen_position(cell)
 for direction in ui.model.definitions[entry.id].directions:
  var target_cell: Vector2i=cell+ui.model.Rules.OFFSETS[direction]
  var target: Vector2=ui.table.screen_position(target_cell)
  arrow(start.lerp(target,0.18),start.lerp(target,0.44),Color(VALID,0.8))
 for target in ui.model.placed:
  if ui.model.edge_allowed(target,source,"on_place"):
   outline(target.cell,LINK)
   arrow(ui.table.screen_position(target.cell).lerp(start,0.25),ui.table.screen_position(target.cell).lerp(start,0.75),LINK)
