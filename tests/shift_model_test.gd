extends SceneTree
const Model = preload("res://scripts/battle_model.gd")
const Catalog = preload("res://scripts/catalog.gd")

func _initialize() -> void:
 for deck in preload("res://scripts/collection_session.gd").DECKS.values():
  var white_count:=0
  for id in deck.cards:
   if not bool(Catalog.card(id).dark):white_count+=1
   assert(Catalog.back_card(id).dark==Catalog.card(id).dark)
  var ratio: float=float(white_count)/deck.cards.size()
  assert(ratio>=0.7 and ratio<=0.8)
 for seed_value in range(250):
  var a = Model.new()
  var b = Model.new()
  a.reset(seed_value);b.reset(seed_value)
  a.fill_hand();b.fill_hand()
  assert(a.hand == b.hand and a.hand.size() == 5 and a.conserved())
  var counts: Dictionary = a.identity_counts()
  assert(int(counts.king) + int(counts.joker) >= 1)
  var snapshot: String = JSON.stringify([a.hand,a.deck,a.discard,a.energy])
  assert(a.fill_hand().drawn.is_empty())
  assert(snapshot == JSON.stringify([a.hand,a.deck,a.discard,a.energy]))
  for repeat in range(6):
   var ids: Array = []
   for entry in a.hand: ids.append(entry.uid)
   ids.sort()
   assert(a.conceal_and_shuffle() and b.conceal_and_shuffle())
   assert(a.hand == b.hand)
   var after: Array = []
   for entry in a.hand:
    after.append(entry.uid)
    assert(a.is_concealed(entry.uid))
    assert(Catalog.back_card(entry.id).identity == Catalog.back_identity(entry.id))
   after.sort()
   assert(ids == after)
   for _i in range(2):
    var uid: int = int(a.hand[0].uid)
    var resources: Array = [a.health,a.enemy_health,a.energy,a.block,a.observed]
    var played: Dictionary = a.play(uid)
    b.play(uid)
    assert(played.ok and played.effect == "pending_back" and played.reverse)
    assert(resources == [a.health,a.enemy_health,a.energy,a.block,a.observed])
    assert(not a.play(uid).ok and a.conserved())
   a.fill_hand();b.fill_hand()
   assert(a.hand == b.hand and a.hand.size() == 5 and a.conserved())
   counts = a.identity_counts()
   assert(int(counts.king) + int(counts.joker) >= 1)
  a.finished = true
  snapshot = JSON.stringify([a.hand,a.deck,a.discard])
  assert(a.fill_hand().drawn.is_empty() and not a.conceal_and_shuffle())
  assert(snapshot == JSON.stringify([a.hand,a.deck,a.discard]))
 # With no remaining special card, report shortage instead of manufacturing one.
 var c = Model.new()
 c.reset(7)
 for entry in c.deck.duplicate():
  if Catalog.back_identity(entry.id) != "normal":
   c.deck.erase(entry);c.exhausted.append(entry)
 var result: Dictionary = c.fill_hand()
 assert(c.hand.size() == 4 and not result.reason.is_empty() and c.conserved())
 print("LYNCO_SHIFT_MODEL_PASS seeds=250 fixed_identity seeded_shuffle refill_guarantee conservation no_pending_effect duplicate_guard shortage finished_guard")
 quit()
