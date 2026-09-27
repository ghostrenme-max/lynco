extends SceneTree
const Model = preload("res://scripts/table_battle_model.gd")
const Session = preload("res://scripts/collection_session.gd")
const Catalog = preload("res://scripts/catalog.gd")
var checks := 0
func check(value: bool, message: String) -> void:
 if not value:
  push_error(message); quit(1); assert(value,message)
 checks += 1
func _initialize() -> void:
 for seed_id in range(256):
  var a := Model.new(); var b := Model.new()
  a.reset(seed_id); b.reset(seed_id); a.fill_hand(); b.fill_hand()
  for step in range(100):
   check(a.conserved(),"conservation")
   check(JSON.stringify(a.hand)==JSON.stringify(b.hand) and a.rng.state==b.rng.state,"seed parity")
   if a.finished: break
   var uid := -1
   for entry in a.hand:
    if a.unavailable_reason(entry.uid).is_empty(): uid = entry.uid; break
   if uid >= 0:
    var before: int = a.energy
    var id: String = a.hand[a.find_card(uid)].id
    var result: Dictionary = a.play(uid)
    b.play(uid)
    check(result.ok and not a.play(uid).ok,"one use only")
    check(a.energy == before-int(Catalog.card(id).cost)+(1 if id=="cycle" else 0),"action costs")
   else:
    var before: int = a.placed.size()
    a.end_turn(); b.end_turn()
    check(a.placed.size()>=before,"table persists")
  check(a.finished and a.placed.size()==Model.CAPACITY,"table full terminates")
  var player := 0; var enemy := 0
  for record in a.placed:
   if record.owner=="player": player += record.score
   else: enemy += record.score
  check(player==a.player_score and enemy==a.opponent_score,"score by owner")
  check(a.winner==("player" if player>enemy else ("opponent" if enemy>player else "draw")),"adjudication")
  var snapshot := JSON.stringify(a.placed)
  check(not a.end_turn().ok and a.draw_cards(5).is_empty(),"finished inputs blocked")
  check(snapshot==JSON.stringify(a.placed),"finished board intact")
  var reward := a.claim_reward()
  check(reward>0 and a.claim_reward()==0,"single reward")
 Session.gold=0; Session.unlocked.assign(["starter"]); Session.selected="starter"
 check(not Session.purchase("remnant").ok and not Session.equip("remnant"),"locked purchase/equip")
 Session.gold=60
 check(Session.purchase("remnant").ok and Session.gold==0,"exact price")
 check(not Session.purchase("remnant").ok and not Session.purchase("missing").ok,"duplicate and invalid purchase")
 check(Session.equip("remnant"),"equip unlocked")
 var model := Model.new(); model.reset(42)
 var counts: Dictionary = {}
 for entry in model.deck: counts[entry.id]=int(counts.get(entry.id,0))+1
 check(counts.link==4 and model.total_cards==18,"full deck used")
 model.fill_hand(); model.conceal_and_shuffle()
 var gold_before: int = Session.gold
 var uid: int = model.hand[0].uid
 var energy_before: int = model.energy
 var reveal: Dictionary = model.play(uid)
 check(reveal.reverse and reveal.score==0 and model.energy==energy_before,"pending reverse effects")
 check(Session.gold==gold_before,"gold independent of placement")
 print("TABLE RULES PASS: ",checks," checks / 256 seeds")
 quit()
