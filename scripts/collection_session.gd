extends RefCounted

# Session only: no disk saves until persistence design is decided.
const DECKS := {
 "starter": {"name":"린코의 기본 덱","owner":"린코","price":0,"cards":["strike","observe","guard","echo","cycle","link","strike","guard","observe","strike","guard","link","strike","observe","guard","echo","cycle","strike"]},
 "remnant": {"name":"웃는 잔상의 덱","owner":"웃는 잔상","price":60,"cards":["link","observe","guard","cycle","strike","link","observe","guard","echo","link","strike","guard","observe","cycle","link","echo","strike","guard"]},
}
static var gold: int = 0
static var unlocked: Array[String] = ["starter"]
static var selected: String = "starter"

static func purchase(id: String) -> Dictionary:
 if not DECKS.has(id): return {"ok":false,"reason":"존재하지 않는 덱입니다"}
 if id in unlocked: return {"ok":false,"reason":"이미 해금한 덱입니다"}
 var price: int = int(DECKS[id].price)
 if gold < price: return {"ok":false,"reason":"골드가 부족합니다"}
 gold -= price; unlocked.append(id)
 return {"ok":true,"reason":"덱 전체를 해금했습니다"}

static func equip(id: String) -> bool:
 if id not in unlocked: return false
 selected = id
 return true

static func selected_cards() -> Array:
 return DECKS[selected].cards.duplicate()
