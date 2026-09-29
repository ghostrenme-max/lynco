extends RefCounted
## Immutable per-launch editor snapshot; no disk I/O in card/animation loops.
const PATH := "res://data/battle_cards.json"
const FALLBACK := "res://data/default_battle_cards.json"
const EFFECTS := ["none","score","cubes","energy","draw"]
const CONDITIONS := ["any","ally","enemy"]
const TRIGGERS := ["on_place","on_invest","turn_start","any"]
const Grid = preload("res://scripts/board_geometry.gd")
const OFFSETS := Grid.OFFSETS
static var loaded := false
static var cards: Dictionary = {}
static var settings: Dictionary = {}
static var load_error := ""
static var _display_definitions: Dictionary = {}

static func validate(raw: Variant) -> String:
 if not raw is Dictionary:return "규칙 파일 버전 오류"
 var version: Variant=raw.get("schema_version")
 if (not version is int and not version is float) or version!=2:return "규칙 파일 버전 오류"
 if not raw.get("rules") is Dictionary or not raw.get("cards") is Array:return "규칙/카드 데이터 누락"
 var ranges := {"starting_cubes":[0,100],"turn_cubes":[0,20],"energy":[1,10],"max_turns":[1,30],"cube_weight":[1,20],"score_weight":[0,20],"recover_delay":[1,10],"recover_fee":[0,5],"final_invested_percent":[0,100]}
 for key in ranges:
  var n: Variant=raw.rules.get(key)
  if not n is float and not n is int:return "숫자 설정 누락: "+key
  if float(n)!=floor(float(n)) or n<ranges[key][0] or n>ranges[key][1]:return "설정 범위 오류: "+key
 if raw.rules.get("end_mode") not in ["either"]:return "종료 조건 오류"
 var ids: Dictionary={}
 var counts := {"starter":0,"remnant":0}
 for c in raw.cards:
  if not c is Dictionary:return "카드 형식 오류"
  var id: String=str(c.get("id",""))
  if id.is_empty() or ids.has(id):return "카드 ID 중복/누락"
  ids[id]=true
  for field in ["name","kind","description","icon"]:
   if not c.get(field) is String:return id+": 표시 필드 오류 "+field
  if not c.get("dark") is bool:return id+": 카드 색상 오류"
  if str(c.name).strip_edges().is_empty():return id+": 이름 누락"
  if str(c.get("icon","")).contains("/") or str(c.get("icon","")).contains("\\") or not FileAccess.file_exists("res://assets/icons/"+str(c.get("icon",""))):return id+": 심볼 파일 오류"
  if c.get("face") not in ["front","reverse"]:return id+": 카드 면 오류"
  if not c.get("directions") is Array:return id+": 방향 누락"
  var seen: Dictionary={}
  for d in c.directions:
   if not d is String or not OFFSETS.has(d):return id+": 방향 오류"
   if seen.has(d):return id+": 중복 방향"
   seen[d]=true
  if c.get("face")=="reverse":continue
  for key in ["base_effect","link_effect"]:
   if c.get(key) not in EFFECTS:return id+": 실행 효과 오류"
  if c.get("link_condition") not in CONDITIONS or c.get("link_trigger") not in TRIGGERS:return id+": 연결 조건 오류"
  for key in ["cost","base_value","link_value","investment_cost","invest_bonus","deck_starter","deck_remnant"]:
   var n: Variant=c.get(key)
   if not n is float and not n is int:return id+": 수치 누락 "+key
   var maximum: int=5 if key=="investment_cost" else (10 if key=="cost" else (30 if key.begins_with("deck_") else 20))
   if float(n)!=floor(float(n)) or n<0 or n>maximum:return id+": 수치 범위 오류 "+key
  if not c.get("requires_investment") is bool:return id+": 투자 조건 오류"
  counts.starter+=int(c.deck_starter);counts.remnant+=int(c.deck_remnant)
 for key in counts:
  if counts[key]<5 or counts[key]>60:return "각 덱은 5~60장이어야 합니다"
 return ""

static func ensure() -> void:
 if loaded:return
 loaded=true
 var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
 load_error=validate(raw)
 if not load_error.is_empty():
  push_warning("편집 규칙 로드 실패, 기본 규칙 사용: "+load_error)
  raw=JSON.parse_string(FileAccess.get_file_as_string(FALLBACK))
  assert(validate(raw).is_empty(),"Bundled battle rules must be valid")
 settings=raw.rules.duplicate(true)
 for c in raw.cards:cards[str(c.id)]=c.duplicate(true)

static func deck_ids(deck_name: String) -> Array:
 ensure()
 var result: Array=[]
 for c in cards.values():
  if c.face!="front":continue
  for i in range(int(c.get("deck_"+deck_name,0))):result.append(str(c.id))
 return result

static func effect_text(kind: String, amount: int) -> String:
 return "%s +%d" % [{"score":"성과","cubes":"큐브","energy":"행동력","draw":"드로우","none":"효과 없음"}.get(kind,kind),amount]

static func definition(id: String) -> Dictionary:
 ensure()
 if not cards.has(id) or cards[id].face!="front":return {}
 if not _display_definitions.has(id):
  _display_definitions[id]=_build_definition(id)
 # Callers may customize a card view; never expose the cached arrays/dictionary.
 return _display_definitions[id].duplicate(true)

static func _build_definition(id: String) -> Dictionary:
 if not cards.has(id):return {}
 var c: Dictionary=cards[id]
 if c.face!="front":return {}
 var base: String=effect_text(c.base_effect,int(c.base_value))
 var linked: String=effect_text(c.link_effect,int(c.link_value))
 var trigger: String={"on_place":"대상 배치","on_invest":"출발 카드 투자","turn_start":"대상 소유자 턴 시작","any":"배치·투자·턴 시작"}[c.link_trigger]
 var condition: String={"any":"양측","ally":"같은 소유자","enemy":"다른 소유자"}[c.link_condition]
 var detail: String="기본 %s\n연결 %s\n투자 %d · 연결 수치 +%d\n출발 방향 → 대상 주인에게 적용" % [base,linked,c.investment_cost,c.invest_bonus]
 var conditions: String="대상: %s\n발동: %s\n투자 %s\n회수 %d턴 후 / 비용 %d\n방향은 출발 카드 기준" % [condition,trigger,"필수" if c.requires_investment else "선택",settings.recover_delay,settings.recover_fee]

 return {"name":c.name,"kind":c.kind,"cost":int(c.cost),"dark":bool(c.dark),"icon":str(c.icon).trim_suffix(".png"),"effect":c.base_effect,"value":int(c.base_value),"text":base+"\n연결 "+linked,"detail":detail,"rule_detail":conditions,"memo":c.description,"table_cost":int(c.investment_cost),"directions":c.directions.duplicate()}
