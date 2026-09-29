extends SceneTree
const Model = preload("res://scripts/linked_battle_model.gd")

func _initialize() -> void:
 var traces: Array = []
 for seed_value in [0,1,2,17,42,12345,20260926,20260929]:
  for deck_id in ["starter","remnant"]:
   Model.Session.selected=deck_id
   var model=Model.new()
   model.reset(seed_value)
   model.fill_hand()
   for step in range(200):
    assert(model.conserved())
    traces.append([seed_value,deck_id,step,model.rng.state,model.hand.duplicate(true),model.deck.duplicate(true),model.discard.duplicate(true),model.placed.duplicate(true),model.cubes.duplicate(),model.performance.duplicate(),model.energy,model.player_score,model.opponent_score,model.finished,model.winner])
    if model.finished:break
    if step%7==3:model.conceal_and_shuffle()
    for record in model.placed:
     if record.owner!="player":continue
     if model.investment_reason(record.cell,true).is_empty():model.recover(record.cell)
     elif model.investment_reason(record.cell).is_empty():model.invest(record.cell)
    var uid: int=-1
    for entry in model.hand:
     if model.unavailable_reason(entry.uid).is_empty():uid=entry.uid;break
    if uid>=0:model.play(uid)
    else:model.end_turn()
   assert(model.finished)
 var digest: String=JSON.stringify(traces).sha256_text()
 assert(digest=="bffbbc93ad6687f9f3a46f3b2a73efe628299599f46aa925487106c6226f16ae","Seeded model behavior changed")
 print("LYNCO_MODEL_FINGERPRINT_PASS ",digest," states=",traces.size())
 quit()
