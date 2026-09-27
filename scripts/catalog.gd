class_name LyncoCatalog
extends RefCounted

# All numerical effects are temporary prototype rules, not final game design.
const CARDS: Dictionary = {
 "strike": {"name":"공허의 일격", "cost":1, "icon":"void", "kind":"공격", "dark":true, "text":"피해 6\n관측 시 피해 +4", "detail":"적에게 피해 6을 줍니다.\n이번 턴 ‘관측’을 사용했다면\n추가 피해 4를 줍니다.", "effect":"damage", "value":6},
 "observe": {"name":"관측", "cost":1, "icon":"eye", "kind":"스킬", "dark":false, "text":"카드 1장 드로우\n이번 턴 관측 활성화", "detail":"카드를 1장 뽑습니다.\n이번 턴 공허의 일격에\n추가 피해 4가 적용됩니다.", "effect":"observe", "value":1},
 "guard": {"name":"봉쇄", "cost":1, "icon":"guard", "kind":"방어", "dark":false, "text":"방어 +7\n다음 턴에 소멸", "detail":"방어 7을 얻습니다.\n적의 공격 피해를 먼저 막고,\n다음 턴 시작 시 사라집니다.", "effect":"guard", "value":7},
 "echo": {"name":"기억 추출", "cost":0, "icon":"memory", "kind":"스킬", "dark":false, "text":"카드 1장 드로우\n사용 후 소멸", "detail":"카드를 1장 뽑습니다.\n이번 전투에서 다시 뽑히지\n않도록 소멸 더미로 갑니다.", "effect":"draw", "value":1, "exhaust":true},
 "cycle": {"name":"순환", "cost":0, "icon":"cycle", "kind":"스킬", "dark":false, "text":"행동력 +1\n사용 후 소멸", "detail":"행동력을 1 회복합니다.\n이번 전투에서 다시 뽑히지\n않도록 소멸 더미로 갑니다.", "effect":"energy", "value":1, "exhaust":true},
 "link": {"name":"연쇄", "cost":2, "icon":"link", "kind":"공격", "dark":false, "text":"피해 10\n방어 +3", "detail":"적에게 피해 10을 줍니다.\n동시에 방어 3을 얻습니다.", "effect":"link", "value":10},
}
const STARTING_DECK: Array[String] = ["strike","observe","guard","echo","cycle","link","strike","guard","observe","strike","guard","link","strike","observe","guard","echo","cycle","strike"]
const ENEMY: Dictionary = {"name":"웃는 잔상", "health":64, "intents":[6,9,12,7]}
const CHARACTER: Dictionary = {"name":"린코", "health":40, "energy":3, "draw":5, "hand_limit":7}
const PERKS: Array[Dictionary] = [] # Deliberately not implementing an undecided perk system.

static func card(id: String) -> Dictionary:
 return CARDS[id]


# Temporary identity mapping for interaction verification; effects remain undecided.
# This mapping is fixed by card definition, never rerolled by Shift.
const BACK_IDENTITIES := {"guard":"king", "echo":"joker"}
static var _back_definitions: Dictionary = {}

static func back_identity(id: String) -> String:
 return str(BACK_IDENTITIES.get(id, "normal"))

static func back_card(id: String) -> Dictionary:
 if not _back_definitions.has(id):
  var front: Dictionary = card(id)
  var identity: String = back_identity(id)
  var special: bool = identity != "normal"
  _back_definitions[id] = {
   "name": ("킹" if identity == "king" else "조커") if special else str(front.name) + "′",
   "cost":0, "cost_label":"—", "icon":identity if special else front.icon,
   "kind":str(front.name) + "의 뒷면", "dark":bool(front.dark),
   "text":"정체 공개\n효과 미정",
   "detail":str(front.name) + "의 고정된 뒷면입니다.\n현재는 정체 공개만 확인합니다.\n효과와 비용은 적용하지 않습니다.",
   "effect":"pending_back", "value":0, "identity":identity,
  }
 return _back_definitions[id]

# Separate from action cost; temporary balance numbers for table adjudication.
const TABLE_VALUES := {"strike":4,"observe":2,"guard":3,"echo":1,"cycle":1,"link":6}
static func table_effect_text(id: String) -> String:
 match id:
  "observe", "echo": return "카드 1장 드로우"
  "cycle": return "행동력 +1"
  _: return "추가 효과 설계 대기"

static func table_card(id: String) -> Dictionary:
 var data: Dictionary = card(id).duplicate()
 data["table_cost"] = TABLE_VALUES[id]
 data["text"] = table_effect_text(id)
 data["detail"] = "행동 비용 %d · 테이블 코스트 %d\n%s\n배치한 카드는 판정까지 유지됩니다." % [data.cost,TABLE_VALUES[id],table_effect_text(id)]
 return data
