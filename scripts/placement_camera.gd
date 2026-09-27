extends Node

var ui: Control
var pointer := Vector2.ZERO
var active := false
var returning := false
var saved: Transform3D

func _input(event: InputEvent) -> void:
 if event is InputEventMouseMotion or event is InputEventMouseButton:
  pointer=event.position

func restore() -> void:
 if not active and not returning:return
 ui.table.camera.transform=saved
 active=false
 returning=false

func _process(delta: float) -> void:
 if not is_instance_valid(ui) or not is_instance_valid(ui.table):return
 var t=ui.table
 var enabled: bool=ui.drag_uid>=0 and not (ui.busy or ui.inspector_open or ui.looking or ui.model.finished or ui.help_panel.visible or ui.leaving_battle or is_instance_valid(ui.inventory_layer) or t.top_view or t.opponent_view or t.card_focus_active or t.card_focus_returning)
 if not enabled and not active and not returning:return
 var local: Vector2=ui.stage.get_global_transform_with_canvas().affine_inverse()*pointer
 enabled=enabled and Rect2(20,180,1560,450).has_point(local) and not ui.turn_board.get_rect().has_point(local) and ui._hand_card_at(local)<0
 # Raycast in the saved view so camera motion cannot feed back into hover detection.
 var reference: Transform3D=saved if active or returning else t.camera.transform
 var ray: Vector3=reference.basis*(t.camera.global_basis.inverse()*t.camera.project_ray_normal(pointer))
 var hit: Variant=Plane(Vector3.UP,0).intersects_ray(reference.origin,ray)
 enabled=enabled and hit!=null
 if enabled:
  enabled=absf(hit.x)<=t.STEP.x*t.COLS*0.5 and absf(hit.z+1.3)<=t.STEP.y*t.ROWS*0.5
 if enabled:
  if not active and not returning:saved=t.camera.transform
  active=true
  returning=false
  var offset:=Vector2(clampf((local.x-800.0)/780.0,-1,1),clampf((local.y-405.0)/225.0,-1,1))
  var target:=saved
  target.origin-=saved.basis.z*4.5
  target.origin+=saved.basis.x*offset.x*3.8
  target.origin+=Vector3(0,0,offset.y*1.2)
  target.basis=saved.basis*Basis(Vector3.UP,-offset.x*0.08)*Basis(Vector3.RIGHT,-offset.y*0.045)
  t.camera.transform=t.camera.transform.interpolate_with(target,1.0-exp(-delta*(24.0 if ui.reduced_motion else 10.0)))
  var uid: int=ui.drag_uid if ui.drag_uid>=0 else ui.selected_uid
  t.preview(local,ui.model.unavailable_reason(uid).is_empty())
 elif active or returning:
  active=false
  returning=true
  t.hide_preview()
  t.camera.transform=t.camera.transform.interpolate_with(saved,1.0-exp(-delta*16.0))
  if t.camera.position.distance_to(saved.origin)<0.003:restore()
