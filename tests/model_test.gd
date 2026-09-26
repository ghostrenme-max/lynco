extends SceneTree
const Model=preload("res://scripts/battle_model.gd")
const Catalog=preload("res://scripts/catalog.gd")

func _initialize() -> void:
 var a=Model.new();var b=Model.new()
 a.reset(20260926);b.reset(20260926)
 assert(a.deck==b.deck,"Seed replay differs")
 print("INITIAL_HAND ",a.draw_cards(5))
 assert(a.hand.size()==5 and a.conserved())
 a.draw_cards(99);assert(a.hand.size()==7 and a.conserved())
 var before=JSON.stringify([a.hand,a.deck,a.energy])
 assert(not a.play(-1).ok)
 assert(JSON.stringify([a.hand,a.deck,a.energy])==before)
 # Isolated sequence verifies ordering and independent base value.
 a.reset(1);a.hand.assign(a.deck);a.deck.clear()
 var observe_uid:int=-1;var strike_uid:int=-1
 for entry in a.hand:
  if entry.id=="observe":observe_uid=entry.uid
  if entry.id=="strike":strike_uid=entry.uid
 a.energy=0
 before=JSON.stringify([a.hand,a.discard,a.energy,a.enemy_health])
 assert(not a.play(strike_uid).ok)
 assert(JSON.stringify([a.hand,a.discard,a.energy,a.enemy_health])==before)
 a.energy=3
 assert(a.play(observe_uid).ok)
 var result:Dictionary=a.play(strike_uid)
 assert(result.damage==6 and result.extra==4 and a.enemy_health==54)
 assert(not a.play(strike_uid).ok,"Double use accepted")
 a.finished=true
 before=JSON.stringify([a.hand,a.deck,a.discard,a.health,a.energy])
 assert(a.draw_cards(5).is_empty() and not a.end_turn().ok)
 assert(JSON.stringify([a.hand,a.deck,a.discard,a.health,a.energy])==before)
 # Many deterministic runs exercise reshuffling, exhaustion, win/loss and conservation.
 var turns:int=0;var uses:int=0
 for seed_value in range(150):
  a.reset(seed_value);a.draw_cards(5)
  for turn_index in range(25):
   if a.finished:break
   for attempt in range(14):
    var played:bool=false
    for entry in a.hand.duplicate():
     if a.unavailable_reason(entry.uid).is_empty():
      assert(a.play(entry.uid).ok);uses+=1;played=true
      assert(a.conserved());break
    if not played or a.finished:break
   if not a.finished:a.end_turn();turns+=1
   assert(a.conserved())
 print("LYNCO_MODEL_TEST_PASS seeds=150 turns=",turns," card_uses=",uses)
 quit()
