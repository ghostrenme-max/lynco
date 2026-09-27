extends SceneTree
const Catalog=preload("res://scripts/catalog.gd")
const Directions=preload("res://scripts/direction_preview.gd")
func _initialize() -> void:
 var records: Array=[]
 for id in Catalog.CARDS:
  var data: Dictionary=Catalog.table_card(id)
  var effect: String="draw" if id in ["observe","echo"] else ("energy" if id=="cycle" else "pending")
  records.append({"id":id,"name":data.name,"kind":data.kind,"description":Catalog.table_effect_text(id),"cost":data.cost,"table_cost":data.table_cost,"dark":data.dark,"icon":str(data.icon)+".png","directions":Directions.for_definition(data),"effect_id":effect,"value":1 if effect!="pending" else 0,"status":"implemented" if effect!="pending" else "pending","face":"front","source_id":id,"legacy_description":Catalog.card(id).detail})
  var back: Dictionary=Catalog.back_card(id)
  var icon: String=str(back.icon)+".png"
  if str(back.icon) in ["king","joker"]:icon=str(back.icon)+("_white.png" if back.dark else "_black.png")
  records.append({"id":str(id)+"_reverse","name":back.name,"kind":back.kind,"description":"정체 공개 · 효과·비용·점수 미정","cost":-1,"table_cost":-1,"dark":back.dark,"icon":icon,"directions":[],"effect_id":"pending_back","value":0,"status":"pending","face":"reverse","source_id":id,"legacy_description":""})
 var output:=FileAccess.open("res://tools/card_editor/default_cards.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"schema_version":1,"cards":records},"  "))
 output.close()
 print("EDITOR_CATALOG_EXPORTED ",records.size())
 quit()
