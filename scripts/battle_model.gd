class_name LyncoBattleModel
extends RefCounted

const Catalog = preload("res://scripts/catalog.gd")
var rng := RandomNumberGenerator.new()
var seed_value: int = 20260926
var hand: Array[Dictionary] = []
var deck: Array[Dictionary] = []
var discard: Array[Dictionary] = []
var exhausted: Array[Dictionary] = []
var turn: int = 1
var health: int = 40
var enemy_health: int = 64
var energy: int = 3
var block: int = 0
var observed: bool = false
var finished: bool = false
var total_cards: int = 0

func reset(new_seed: int) -> void:
 seed_value = new_seed
 rng.seed = new_seed
 hand.clear(); deck.clear(); discard.clear(); exhausted.clear()
 turn = 1; health = int(Catalog.CHARACTER.health); enemy_health = int(Catalog.ENEMY.health)
 energy = int(Catalog.CHARACTER.energy); block = 0; observed = false; finished = false
 var uid: int = 0
 for id in Catalog.STARTING_DECK:
  deck.append({"uid":uid, "id":id})
  uid += 1
 total_cards = uid
 _shuffle(deck)

func _shuffle(cards: Array[Dictionary]) -> void:
 for i in range(cards.size() - 1, 0, -1):
  var j := rng.randi_range(0, i)
  var a: Dictionary = cards[i]
  cards[i] = cards[j]
  cards[j] = a

func draw_cards(amount: int) -> Array[Dictionary]:
 var drawn: Array[Dictionary] = []
 if finished:
  return drawn
 for _i in range(amount):
  if hand.size() >= int(Catalog.CHARACTER.hand_limit):
   break
  if deck.is_empty():
   if discard.is_empty():
    break
   deck.assign(discard)
   discard.clear()
   _shuffle(deck)
  var entry: Dictionary = deck.pop_back()
  hand.append(entry)
  drawn.append(entry)
 return drawn

func find_card(uid: int) -> int:
 for i in range(hand.size()):
  if int(hand[i].uid) == uid:
   return i
 return -1

func unavailable_reason(uid: int) -> String:
 if finished:
  return "전투가 종료되었습니다"
 var index := find_card(uid)
 if index < 0:
  return "손에 없는 카드입니다"
 if bool(hand[index].get("concealed", false)): return "" # Unspecified back costs must not leak identity.
 if int(Catalog.card(hand[index].id).cost) > energy:
  return "행동력이 부족합니다"
 return ""

func preview(uid: int) -> String:
 var index := find_card(uid)
 if index < 0:
  return ""
 if bool(hand[index].get("concealed", false)): return "가려진 카드 · 선택하면 뒷면 정체 공개 / 효과 미정"
 var data: Dictionary = Catalog.card(hand[index].id)
 match str(data.effect):
  "damage": return "예상 피해 %d%s" % [int(data.value) + (4 if observed else 0), " · 연계 +4" if observed else ""]
  "link": return "예상 피해 10 · 방어 +3"
  "guard": return "방어 +7"
  "energy": return "행동력 +1 · 사용 후 소멸"
  _: return "카드 1장 드로우" + (" · 손패가 가득 참" if hand.size() > 7 else "")

func play(uid: int) -> Dictionary:
 var reason := unavailable_reason(uid)
 if not reason.is_empty():
  return {"ok":false, "reason":reason}
 var index := find_card(uid)
 var entry: Dictionary = hand[index]
 if bool(entry.get("concealed", false)):
  hand.remove_at(index)
  entry.erase("concealed")
  discard.append(entry)
  return {"ok":true, "entry":entry, "damage":0, "extra":0, "drawn":[], "effect":"pending_back", "reverse":true}
 var data: Dictionary = Catalog.card(entry.id)
 # Atomic state transition: remove the card before resolving any effect.
 hand.remove_at(index)
 energy -= int(data.cost)
 if bool(data.get("exhaust", false)):
  exhausted.append(entry)
 else:
  discard.append(entry)
 var damage: int = 0
 var extra: int = 0
 var draw_count: int = 0
 match str(data.effect):
  "damage":
   damage = int(data.value)
   if observed: extra = 4
  "observe":
   observed = true
   draw_count = 1
  "draw": draw_count = 1
  "guard": block += int(data.value)
  "energy": energy += int(data.value)
  "link":
   damage = int(data.value)
   block += 3
 enemy_health = maxi(0, enemy_health - damage - extra)
 if enemy_health == 0:
  finished = true
 var drawn: Array[Dictionary] = draw_cards(draw_count)
 return {"ok":true, "entry":entry, "damage":damage, "extra":extra, "drawn":drawn, "effect":data.effect}

func intent() -> int:
 var values: Array = Catalog.ENEMY.intents
 return int(values[(turn - 1) % values.size()])

func end_turn() -> Dictionary:
 if finished:
  return {"ok":false}
 var incoming := intent()
 var absorbed := mini(incoming, block)
 health = maxi(0, health - maxi(0, incoming - block))
 for entry in hand: entry.erase("concealed")
 discard.append_array(hand)
 hand.clear()
 if health == 0:
  finished = true
  return {"ok":true, "damage":incoming - absorbed, "absorbed":absorbed, "drawn":[]}
 turn += 1
 block = 0; observed = false; energy = int(Catalog.CHARACTER.energy)
 var drawn: Array = fill_hand().drawn
 return {"ok":true, "damage":incoming - absorbed, "absorbed":absorbed, "drawn":drawn}

func conserved() -> bool:
 var ids: Dictionary = {}
 for pile in [hand, deck, discard, exhausted]:
  for entry in pile:
   if ids.has(entry.uid): return false
   ids[entry.uid] = true
 return ids.size() == total_cards and energy >= 0 and hand.size() <= int(Catalog.CHARACTER.hand_limit)


func is_concealed(uid: int) -> bool:
 var index: int = find_card(uid)
 return index >= 0 and bool(hand[index].get("concealed", false))

func identity_counts() -> Dictionary:
 var counts := {"king":0, "joker":0}
 for entry in hand:
  var identity: String = Catalog.back_identity(str(entry.id))
  if counts.has(identity): counts[identity] += 1
 return counts

func conceal_and_shuffle() -> bool:
 if finished or hand.is_empty(): return false
 for entry in hand: entry["concealed"] = true
 _shuffle(hand)
 return true

func fill_hand() -> Dictionary:
 var drawn: Array[Dictionary] = []
 if finished: return {"drawn":drawn, "reason":"전투가 종료되었습니다"}
 if hand.size() >= 5: return {"drawn":drawn, "reason":"손패가 이미 5장 이상입니다"}
 while hand.size() < 5:
  # Only the final slot needs an identity scan; preserve candidate/RNG order.
  var needs_special: bool = false
  if hand.size() == 4:
   var counts: Dictionary = identity_counts()
   needs_special = int(counts.king) + int(counts.joker) == 0
  if needs_special:
   var candidates: Array[Dictionary] = []
   for pile in [deck, discard]:
    for entry in pile:
     if Catalog.back_identity(str(entry.id)) != "normal": candidates.append(entry)
   if candidates.is_empty():
    return {"drawn":drawn, "reason":"남은 더미에 킹·조커 카드가 없어 마지막 칸을 보충할 수 없습니다"}
   var entry: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
   deck.erase(entry)
   discard.erase(entry)
   entry.erase("concealed")
   hand.append(entry)
   drawn.append(entry)
  else:
   var next: Array[Dictionary] = draw_cards(1)
   if next.is_empty(): return {"drawn":drawn, "reason":"뽑을 카드가 없습니다"}
   next[0].erase("concealed")
   drawn.append_array(next)
 return {"drawn":drawn, "reason":""}
