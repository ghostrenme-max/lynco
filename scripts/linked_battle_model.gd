extends "res://scripts/table_battle_model.gd"
## Each directed edge is evaluated once per event; effects never recursively emit events.
const CubeTest = preload("res://scripts/temporary_cube_test.gd")
const Rules = preload("res://scripts/linked_rules.gd")
# Declare this dependency locally so editor reloads do not rely on inherited aliases.
const BoardGeometry = preload("res://scripts/board_geometry.gd")
var rules: Dictionary={}
var definitions: Dictionary={}
var cube_changes: Array[int]=[]
var cubes := {"player":0,"opponent":0}
var performance := {"player":0,"opponent":0}
var cell_map: Dictionary={}
var events: Array[Dictionary]=[]
var event_drawn: Array[Dictionary]=[]
var enemy_energy := 0
var pending_energy := {"player":0,"opponent":0}
var ai_running := false
var ending_reason := ""
var edge_checks := 0

func reset(new_seed: int) -> void:
 super.reset(new_seed)
 cube_changes.clear()
 Rules.ensure();rules=Rules.settings.duplicate(true);definitions=Rules.cards.duplicate(true)
 cubes={"player":int(rules.starting_cubes),"opponent":int(rules.starting_cubes)}
 performance={"player":0,"opponent":0};cell_map.clear();events.clear();event_drawn.clear();ending_reason="";edge_checks=0;ai_running=false
 pending_energy={"player":0,"opponent":0}
 energy=int(rules.energy)
 deck.clear();opponent_deck.clear()
 var uid:=0
 for id in Rules.deck_ids(Session.selected):deck.append({"uid":uid,"id":id});uid+=1
 total_cards=deck.size();_shuffle(deck)
 uid=1000
 for id in Rules.deck_ids("remnant"):opponent_deck.append({"uid":uid,"id":id});uid+=1
 _shuffle(opponent_deck)
 _scores()

func fill_hand() -> Dictionary:
 var drawn:=draw_cards(maxi(0,5-hand.size()))
 CubeTest.prepare_hand(self,drawn)
 return {"drawn":drawn,"reason":""}

func free_cell(cell: Vector2i) -> bool:
 return BoardGeometry.contains(cell) and not cell_map.has(cell)

func next_cell() -> Vector2i:
 return BoardGeometry.first_empty(cell_map)

func unavailable_reason(uid: int) -> String:
 if finished:return "전투가 종료되었습니다"
 if ai_running:return "상대 턴입니다"
 if placed.size()>=CAPACITY:return "테이블이 가득 찼습니다"
 var index:=find_card(uid)
 if index<0:return "손에 없는 카드입니다"
 if cubes.player<CubeTest.cost(hand[index]):return "큐브가 부족합니다 (임시 카드 비용 %d)" % CubeTest.cost(hand[index])
 if is_concealed(uid):return ""
 if int(definitions[hand[index].id].cost)>energy:return "행동력이 부족합니다"
 return ""

func play(uid: int) -> Dictionary:
 return play_at(uid,next_cell())

func play_at(uid: int, cell: Vector2i) -> Dictionary:
 var reason:=unavailable_reason(uid)
 if not reason.is_empty():return {"ok":false,"reason":reason}
 if not free_cell(cell):return {"ok":false,"reason":"빈 테이블 칸에 놓아주세요"}
 events.clear();event_drawn.clear()
 var index:=find_card(uid)
 var entry: Dictionary=hand[index];hand.remove_at(index)
 change_cubes("player",-CubeTest.cost(entry))
 var reverse:=bool(entry.get("concealed",false));entry.erase("concealed")
 var record:=_place(entry,"player",cell,reverse)
 _finish_if_needed(false);_scores()
 return {"ok":true,"entry":entry,"damage":0,"extra":0,"drawn":event_drawn.duplicate(),"effect":"pending_back" if reverse else "table","reverse":reverse,"score":record.score,"events":events.duplicate(true)}

func _place(entry: Dictionary, side: String, cell: Vector2i, reverse: bool=false) -> Dictionary:
 var c: Dictionary=definitions[entry.id]
 var record: Dictionary={"entry":entry,"owner":side,"reverse":reverse,"score":0,"cell":cell,"invested":0,"invested_turn":-1,"last_invest_turn":-1}
 placed.append(record);cell_map[cell]=record
 if reverse:return record
 if side=="player":energy-=int(c.cost)
 else:enemy_energy-=int(c.cost)
 _effect(side,str(c.base_effect),int(c.base_value),cell,cell,"base")
 record.score=int(c.base_value) if c.base_effect=="score" else 0
 # Only sources adjacent to the target can affect its placement.
 for offset in Rules.OFFSETS.values():
  var source_cell: Vector2i=cell-Vector2i(offset)
  if cell_map.has(source_cell):_edge(cell_map[source_cell],record,"on_place")
 return record

func _effect(side: String, kind: String, amount: int, source: Vector2i, target: Vector2i, cause: String) -> void:
 if amount<=0 or kind=="none":return
 match kind:
  "score":performance[side]+=amount
  "cubes":change_cubes(side,amount)
  "energy":
   if side=="player":
    if ai_running:pending_energy.player+=amount
    else:energy+=amount
   else:
    if ai_running:enemy_energy+=amount
    else:pending_energy.opponent+=amount
  "draw":
   if side=="player":event_drawn.append_array(draw_cards(amount))
   else:_draw_enemy(amount)
 events.append({"side":side,"kind":kind,"amount":amount,"source":source,"target":target,"cause":cause})

func edge_allowed(source: Dictionary, target: Dictionary, trigger: String) -> bool:
 if source.reverse or target.reverse:return false
 var c: Dictionary=definitions[source.entry.id]
 if c.link_trigger!=trigger and c.link_trigger!="any":return false
 if c.requires_investment and int(source.invested)==0:return false
 if c.link_condition=="ally" and source.owner!=target.owner:return false
 if c.link_condition=="enemy" and source.owner==target.owner:return false
 for d in c.directions:
  if source.cell+Rules.OFFSETS[d]==target.cell:return true
 return false

func _edge(source: Dictionary, target: Dictionary, trigger: String) -> void:
 edge_checks+=1
 if not edge_allowed(source,target,trigger):return
 var c: Dictionary=definitions[source.entry.id]
 _effect(target.owner,c.link_effect,int(c.link_value)+(int(c.invest_bonus) if int(source.invested)>0 else 0),source.cell,target.cell,"link")

func _outgoing(source: Dictionary, trigger: String, target_side: String="") -> void:
 var c: Dictionary=definitions[source.entry.id]
 for d in c.directions:
  var cell: Vector2i=source.cell+Rules.OFFSETS[d]
  if cell_map.has(cell) and (target_side.is_empty() or cell_map[cell].owner==target_side):_edge(source,cell_map[cell],trigger)

func investment_reason(cell: Vector2i, is_recovery: bool=false, side: String="player") -> String:
 if finished:return "전투가 종료되었습니다"
 if side=="player" and ai_running:return "상대 턴입니다"
 if not cell_map.has(cell):return "배치된 내 카드를 선택하세요"
 var r: Dictionary=cell_map[cell]
 if r.owner!=side:return "상대 카드는 연결만 이용할 수 있습니다"
 if r.reverse:return "뒷면 효과는 아직 미정입니다"
 var c: Dictionary=definitions[r.entry.id]
 if is_recovery:
  if int(r.invested)==0:return "투자한 큐브가 없습니다"
  if turn-int(r.invested_turn)<int(rules.recover_delay):return "%d턴부터 회수 가능" % (int(r.invested_turn)+int(rules.recover_delay))
 else:
  if int(r.invested)>0:return "이미 투자한 카드입니다"
  if int(r.last_invest_turn)==turn:return "같은 턴에 재투자할 수 없습니다"
  if int(c.investment_cost)<=0:return "투자 기능이 없는 카드입니다"
  if cubes[side]<int(c.investment_cost):return "보유 큐브가 부족합니다"
 return ""

func invest(cell: Vector2i, side: String="player") -> Dictionary:
 var reason:=investment_reason(cell,false,side)
 if not reason.is_empty():return {"ok":false,"reason":reason,"drawn":[]}
 events.clear();event_drawn.clear()
 var r: Dictionary=cell_map[cell]
 var amount:=int(definitions[r.entry.id].investment_cost)
 change_cubes(side,-amount);r.invested=amount;r.invested_turn=turn;r.last_invest_turn=turn
 _outgoing(r,"on_invest")
 _scores()
 return {"ok":true,"reason":"큐브 %d개 투자 · 연결 추가 효과 활성" % amount,"drawn":event_drawn.duplicate(),"events":events.duplicate(true)}

func recover(cell: Vector2i, side: String="player") -> Dictionary:
 var reason:=investment_reason(cell,true,side)
 if not reason.is_empty():return {"ok":false,"reason":reason,"drawn":[]}
 var r: Dictionary=cell_map[cell]
 var fee:=mini(int(r.invested),int(rules.recover_fee))
 var returned:=int(r.invested)-fee
 change_cubes(side,returned);r.invested=0;_scores()
 return {"ok":true,"reason":"큐브 %d개 회수 · 회수 비용 %d" % [returned,fee],"drawn":[],"events":[]}

func invested_total(side: String) -> int:
 var amount:=0
 for r in placed:
  if r.owner==side:amount+=int(r.invested)
 return amount

func _scores() -> void:
 player_score=total_score("player");opponent_score=total_score("opponent")

func total_score(side: String) -> int:
 var settled:=int(cubes[side])+floori(float(invested_total(side)*int(rules.get("final_invested_percent",0)))/100.0)
 return settled*int(rules.get("cube_weight",3))+int(performance[side])*int(rules.get("score_weight",1))

func _finish_if_needed(round_complete: bool) -> void:
 var full:=placed.size()>=CAPACITY
 var time_up:=round_complete and turn>=int(rules.max_turns)
 # Full board is always a safety end: no hidden extra placements or empty loop.
 if full or time_up:
  finished=true;ending_reason="30칸 배치 완료" if full else "마지막 턴 완료"
  _scores();winner="player" if player_score>opponent_score else ("opponent" if opponent_score>player_score else "draw")

func _draw_enemy(amount: int) -> void:
 for i in range(amount):
  if opponent_hand.size()>=7:return
  if opponent_deck.is_empty():
   if opponent_discard.is_empty():return
   opponent_deck.assign(opponent_discard);opponent_discard.clear();_shuffle(opponent_deck)
  opponent_hand.append(opponent_deck.pop_back())

func _start_links(side: String) -> void:
 for r in placed:_outgoing(r,"turn_start",side)

func _best_enemy_cell(id: String) -> Vector2i:
 var best:=next_cell();var best_value: int=-2147483648
 for y in range(Grid.ROWS):
  for x in range(Grid.COLS):
   var cell:=Vector2i(x,y)
   if not free_cell(cell):continue
   var value:=0
   var target: Dictionary={"cell":cell,"entry":{"id":id},"owner":"opponent","reverse":false}
   for offset in Rules.OFFSETS.values():
    var source_cell: Vector2i=cell-Vector2i(offset)
    if cell_map.has(source_cell) and edge_allowed(cell_map[source_cell],target,"on_place"):value+=int(definitions[cell_map[source_cell].entry.id].link_value)
   if value>best_value:best_value=value;best=cell
 return best

func end_turn() -> Dictionary:
 if finished or ai_running:return {"ok":false,"drawn":[],"placements":[],"hand_count":0}
 ai_running=true;events.clear();event_drawn.clear()
 for entry in hand:entry.erase("concealed")
 discard.append_array(hand);hand.clear()
 _draw_enemy(maxi(0,5-opponent_hand.size()));enemy_energy=int(rules.energy)+int(pending_energy.opponent);pending_energy.opponent=0
 if turn>1:change_cubes("opponent",int(rules.turn_cubes))
 _start_links("opponent")
 var moves: Array=[]
 var count:=opponent_hand.size()
 while not finished and moves.size()<CAPACITY:
  var best:=-1
  for i in range(opponent_hand.size()):
   var c: Dictionary=definitions[opponent_hand[i].id]
   if int(c.cost)>enemy_energy:continue
   if best<0 or int(c.base_value)>int(definitions[opponent_hand[best].id].base_value):best=i
  if best<0:break
  var before_count:=opponent_hand.size()
  var entry: Dictionary=opponent_hand[best];opponent_hand.remove_at(best)
  var record:=_place(entry,"opponent",_best_enemy_cell(entry.id))
  record.hand_before=before_count;record.hand_after=opponent_hand.size();moves.append(record)
  _finish_if_needed(false)
 # Seed-independent policy: harvest old investments late; invest where an ally benefits.
 for r in placed:
  if finished:break
  if r.owner!="opponent":continue
  if turn>=int(rules.max_turns)-1 and investment_reason(r.cell,true,"opponent").is_empty():recover(r.cell,"opponent")
  elif turn<int(rules.max_turns)-1 and investment_reason(r.cell,false,"opponent").is_empty():
   for d in definitions[r.entry.id].directions:
    var cell: Vector2i=r.cell+Rules.OFFSETS[d]
    if cell_map.has(cell) and cell_map[cell].owner=="opponent":invest(r.cell,"opponent");break
 opponent_discard.append_array(opponent_hand);opponent_hand.clear()
 _finish_if_needed(true)
 if not finished:
  ai_running=false
  turn+=1;energy=int(rules.energy)+int(pending_energy.player);pending_energy.player=0;change_cubes("player",int(rules.turn_cubes));observed=false;block=0
  event_drawn.clear();event_drawn.append_array(hand);event_drawn.append_array(fill_hand().drawn);_start_links("player")
 _scores();ai_running=false
 return {"ok":true,"damage":0,"absorbed":0,"placements":moves,"hand_count":count,"drawn":[] if finished else event_drawn.duplicate()}

func preview_at(uid: int, cell: Vector2i) -> String:
 var index:=find_card(uid)
 if index<0:return ""
 if is_concealed(uid):return "뒷면 공개 · 실제 효과 미정"
 if not free_cell(cell):return "빈 칸을 선택하세요"
 var lines: Array[String]=[]
 var c: Dictionary=definitions[hand[index].id]
 lines.append("기본 "+Rules.effect_text(c.base_effect,int(c.base_value)))
 var target: Dictionary={"cell":cell,"entry":hand[index],"owner":"player","reverse":false}
 for offset in Rules.OFFSETS.values():
  var origin: Vector2i=cell-Vector2i(offset)
  if cell_map.has(origin) and edge_allowed(cell_map[origin],target,"on_place"):
   var source: Dictionary=cell_map[origin];var source_card: Dictionary=definitions[source.entry.id]
   lines.append(("상대" if source.owner=="opponent" else "내")+" 연결 "+Rules.effect_text(source_card.link_effect,int(source_card.link_value)+(int(source_card.invest_bonus) if int(source.invested)>0 else 0)))
 return " · ".join(lines)

func conserved() -> bool:
 if not super.conserved() or cell_map.size()!=placed.size():return false
 for side in cubes:
  if cubes[side]<0:return false
 for r in placed:
  if r.invested<0 or not cell_map.has(r.cell):return false
 return true

func link_allowed_at(source_cell: Vector2i, target_cell: Vector2i) -> bool:
 if not cell_map.has(source_cell) or not cell_map.has(target_cell):return false
 var source: Dictionary=cell_map[source_cell]
 var trigger: String=definitions[source.entry.id].link_trigger
 return edge_allowed(source,cell_map[target_cell],"on_place" if trigger=="any" else trigger)

func change_cubes(side: String, amount: int) -> void:
 if amount==0:return
 cubes[side]+=amount
 if side=="player":cube_changes.append(amount)
