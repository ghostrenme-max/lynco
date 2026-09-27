extends "res://scripts/battle_model.gd"

# Board rules are independent of camera, animation and shop currency.
const Session = preload("res://scripts/collection_session.gd")
const CAPACITY := 18
var placed: Array[Dictionary] = []
var opponent_hand: Array[Dictionary] = []
var opponent_deck: Array[Dictionary] = []
var opponent_discard: Array[Dictionary] = []
var player_score: int = 0
var opponent_score: int = 0
var winner: String = ""
var reward_claimed: bool = false

func reset(new_seed: int) -> void:
 super.reset(new_seed)
 placed.clear(); opponent_hand.clear(); opponent_deck.clear(); opponent_discard.clear()
 player_score = 0; opponent_score = 0; winner = ""; reward_claimed = false
 deck.clear()
 var ids: Array = Session.selected_cards()
 for i in range(ids.size()): deck.append({"uid":i,"id":ids[i]})
 total_cards = deck.size()
 _shuffle(deck)
 var enemy_ids: Array = Session.DECKS["remnant"].cards
 for i in range(enemy_ids.size()): opponent_deck.append({"uid":1000+i,"id":enemy_ids[i]})
 _shuffle(opponent_deck)

func unavailable_reason(uid: int) -> String:
 if placed.size() >= CAPACITY: return "테이블이 가득 찼습니다"
 return super.unavailable_reason(uid)

func preview(uid: int) -> String:
 var index := find_card(uid)
 if index < 0: return ""
 if is_concealed(uid): return "뒷면 정체 공개 · 효과·비용·점수 미정"
 var id: String = hand[index].id
 return "테이블 +%d · %s" % [Catalog.TABLE_VALUES[id], Catalog.table_effect_text(id)]

func play(uid: int) -> Dictionary:
 var reason := unavailable_reason(uid)
 if not reason.is_empty(): return {"ok":false,"reason":reason}
 var index := find_card(uid)
 var entry: Dictionary = hand[index]
 var reverse: bool = bool(entry.get("concealed", false))
 hand.remove_at(index)
 entry.erase("concealed")
 var id: String = entry.id
 var draw_count := 0
 if not reverse:
  energy -= int(Catalog.card(id).cost)
  if id == "cycle": energy += 1
  if id in ["observe", "echo"]: draw_count = 1
 # Unspecified reverse effects/costs/points are deliberately not applied.
 var record := {"entry":entry,"owner":"player","reverse":reverse,"score":0 if reverse else int(Catalog.TABLE_VALUES[id])}
 placed.append(record)
 player_score += int(record.score)
 _judge()
 return {"ok":true,"entry":entry,"damage":0,"extra":0,"drawn":draw_cards(draw_count),"effect":"pending_back" if reverse else "table","reverse":reverse,"score":record.score}

func _judge() -> void:
 if placed.size() < CAPACITY: return
 finished = true
 winner = "player" if player_score > opponent_score else ("opponent" if opponent_score > player_score else "draw")

func _enemy_draw() -> void:
 while opponent_hand.size() < 5:
  if opponent_deck.is_empty():
   if opponent_discard.is_empty(): break
   opponent_deck.assign(opponent_discard); opponent_discard.clear(); _shuffle(opponent_deck)
  opponent_hand.append(opponent_deck.pop_back())

func end_turn() -> Dictionary:
 if finished: return {"ok":false,"drawn":[],"placements":[]}
 for entry in hand: entry.erase("concealed")
 discard.append_array(hand); hand.clear()
 _enemy_draw()
 var budget: int = int(Catalog.CHARACTER.energy)
 var moves: Array[Dictionary] = []
 var hand_count: int = opponent_hand.size()
 # Seeded hand; deterministic greedy choice. No hidden score or free placements.
 while not finished:
  var best := -1
  for i in range(opponent_hand.size()):
   var id: String = opponent_hand[i].id
   if int(Catalog.card(id).cost) > budget: continue
   if best < 0 or int(Catalog.TABLE_VALUES[id]) > int(Catalog.TABLE_VALUES[opponent_hand[best].id]): best = i
  if best < 0: break
  var entry: Dictionary = opponent_hand[best]
  opponent_hand.remove_at(best)
  var id: String = entry.id
  budget -= int(Catalog.card(id).cost)
  if id == "cycle": budget += 1
  var record := {"entry":entry,"owner":"opponent","reverse":false,"score":int(Catalog.TABLE_VALUES[id])}
  record["hand_before"] = opponent_hand.size()+1
  placed.append(record); moves.append(record)
  opponent_score += int(record.score)
  _judge()
  if not finished and id in ["observe", "echo"]:
   if opponent_deck.is_empty() and not opponent_discard.is_empty():
    opponent_deck.assign(opponent_discard); opponent_discard.clear(); _shuffle(opponent_deck)
   if not opponent_deck.is_empty(): opponent_hand.append(opponent_deck.pop_back())
  record["hand_after"] = opponent_hand.size()
 opponent_discard.append_array(opponent_hand); opponent_hand.clear()
 if not finished:
  turn += 1; energy = int(Catalog.CHARACTER.energy); observed = false; block = 0
 return {"ok":true,"damage":0,"absorbed":0,"placements":moves,"hand_count":hand_count,"drawn":[] if finished else fill_hand().drawn}

func conserved() -> bool:
 var ids: Dictionary = {}
 for pile in [hand, deck, discard, exhausted]:
  for entry in pile:
   if ids.has(entry.uid): return false
   ids[entry.uid] = true
 for record in placed:
  if record.owner != "player": continue
  if ids.has(record.entry.uid): return false
  ids[record.entry.uid] = true
 return ids.size() == total_cards and energy >= 0 and hand.size() <= 7 and placed.size() <= CAPACITY

func claim_reward() -> int:
 if not finished or reward_claimed: return 0
 reward_claimed = true
 var amount: int = 30 if winner == "player" else (15 if winner == "draw" else 10)
 Session.gold += amount
 return amount
