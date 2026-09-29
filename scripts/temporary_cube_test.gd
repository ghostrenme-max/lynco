extends RefCounted
## TEMPORARY: set ENABLED=false to disable all cube fixtures and hooks.
const ENABLED := true
const ITEM_ID := "temporary_cube_plus_four"
const Session = preload("res://scripts/collection_session.gd")

static func prepare_items() -> void:
 if not ENABLED:return
 Session.items=Session.items.filter(func(e: Dictionary):return str(e.get("id",""))!=ITEM_ID)
 Session.items.push_front({"id":ITEM_ID,"name":"큐브 +4 (임시)","description":"사용하면 현재 전투의 보유 큐브가 4개 증가합니다.\n1회 소모 · 0번으로 다시 준비할 수 있습니다.","temporary":true,"source":"shop"})

static func prepare_hand(model, drawn: Array) -> void:
 if not ENABLED:return
 # Transform only newly drawn entries, preserving UIDs and card conservation.
 for pair in [[false,"observe",1],[true,"strike",2]]:
  var found:=false
  for e in model.hand:
   if int(e.get("temporary_cube_cost",0))==int(pair[2]):found=true
  if found:continue
  for e in drawn:
   if int(e.get("temporary_cube_cost",0))>0:continue
   e.id=pair[1];e.temporary_cube_cost=pair[2]
   break

static func cost(entry: Dictionary) -> int:
 return int(entry.get("temporary_cube_cost",0)) if ENABLED else 0

static func decorate(entry: Dictionary, definition: Dictionary) -> Dictionary:
 if cost(entry)==0:return definition
 var result:=definition.duplicate(true)
 result.name=str(result.name)+" [임시]"
 result.text="배치 시 큐브 -%d\n%s" % [cost(entry),str(result.text)]
 result.detail="임시 테스트: 배치 시 큐브 %d개 소모. 부족하면 사용 불가.\n" % cost(entry)+str(result.detail)
 return result

static func use_item(model) -> bool:
 if not ENABLED or model.finished or model.ai_running:return false
 for i in range(Session.items.size()):
  if str(Session.items[i].get("id",""))==ITEM_ID:
   Session.items.remove_at(i);model.change_cubes("player",4);model._scores();return true
 return false

static func attach_inventory(ui, inventory) -> void:
 if not ENABLED:return
 var button:=Button.new();button.text="선택한 큐브 +4 사용 (임시)"
 button.position=Vector2(580,805);button.size=Vector2(320,38)
 inventory.stage.add_child(button)
 button.pressed.connect(func():
  var i:int=inventory.selected_index
  if ui.busy or ui.model.finished or i<0 or i>=Session.items.size():return
  if str(Session.items[i].get("id",""))!=ITEM_ID:
   ui._toast("첫 번째 큐브 +4 아이템을 선택하세요");return
  if use_item(ui.model):
   inventory.refresh()
   await ui._animate_cube_changes()
   ui._sync_ui();ui._toast("임시 아이템 사용 · 큐브 +4")
 )
