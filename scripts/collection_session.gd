extends RefCounted

# Session only: no disk saves until persistence design is decided.
const DECKS := {
 "starter": {"name":"린코의 기본 덱","owner":"린코","price":0,"cards":["strike","observe","guard","echo","cycle","link","strike","guard","observe","strike","guard","link","strike","observe","guard","echo","cycle","strike"]},
 "remnant": {"name":"웃는 잔상의 덱","owner":"웃는 잔상","price":60,"cards":["link","observe","guard","cycle","strike","link","observe","guard","echo","link","strike","guard","observe","cycle","strike","echo","strike","guard"]},
}
static var items: Array[Dictionary] = []
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

# UI preview fixtures only; these items have no gameplay effects or prices.
static func add_preview_items() -> void:
 var names: Array[String]=["관측 렌즈","봉쇄 인장","순환 고리","기억 조각","공허 결정","연쇄 매듭"]
 var icons: Array[String]=["eye","guard","cycle","memory","void","link"]
 for i in range(6):
  var id: String="preview_item_"+str(i)
  if items.any(func(entry: Dictionary) -> bool:return str(entry.get("id",""))==id):continue
  items.append({
   "id":id,
   "name":names[i],
   "description":"보유 아이템 화면 확인용 임시 아이템입니다.\n실제 효과와 사용 규칙은 아직 없습니다.",
   "source":"shop" if i<3 else "black_market",
   "icon":"res://assets/icons/"+icons[i]+".png",
   "temporary":true,
  })
