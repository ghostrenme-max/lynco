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
