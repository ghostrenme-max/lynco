extends SceneTree
const Model=preload("res://scripts/linked_battle_model.gd")
const Rules=preload("res://scripts/linked_rules.gd")
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func fixture() -> RefCounted:
 var m:=Model.new();m.reset(123)
 m.rules.max_turns=30;m.energy=100
 m.hand.clear();m.deck.clear();m.discard.clear();m.total_cards=3
 m.hand.assign([{"id":"strike","uid":0},{"id":"guard","uid":1},{"id":"observe","uid":2}])
 for c in m.definitions.values():
  c.base_effect="none";c.base_value=0;c.link_effect="none";c.link_value=0
 return m
func run() -> void:
 Rules.ensure()
 var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(Rules.PATH))
 check(Rules.validate(raw).is_empty(),"live editor configuration valid")
 var bad: Dictionary=raw.duplicate(true);bad.rules.recover_delay=0
 check(not Rules.validate(bad).is_empty(),"reject zero-delay infinite reinvest")
 bad=raw.duplicate(true);bad.cards[0].link_effect="eval"
 check(not Rules.validate(bad).is_empty(),"reject unknown executable effects")
 for condition in ["any","ally","enemy"]:
  for other in [false,true]:
   var m=fixture()
   var source: Dictionary=m.definitions.strike
   source.link_effect="cubes";source.link_value=2;source.link_condition=condition;source.link_trigger="on_place";source.directions=["right"]
   check(m.play_at(0,Vector2i(1,2)).ok,"source placement")
   if other:m.placed[0].owner="opponent"
   var before:=int(m.cubes.player)
   var snapshot:=JSON.stringify([m.cubes,m.hand,m.rng.state])
   var preview: String=m.preview_at(1,Vector2i(2,2))
   check(snapshot==JSON.stringify([m.cubes,m.hand,m.rng.state]),"preview does not mutate model/RNG")
   check(m.play_at(1,Vector2i(2,2)).ok,"target placement")
   var expected: int=2 if condition=="any" or (condition=="enemy" and other) or (condition=="ally" and not other) else 0
   check(int(m.cubes.player)==before+expected,"owner condition applies to recipient")
   check(preview.contains("연결")==(expected>0),"preview matches actual condition")
   check(m.placed[0].owner==("opponent" if other else "player"),"link never steals ownership")
 var m=fixture();m.definitions.strike.link_effect="score";m.definitions.strike.link_value=2;m.definitions.strike.link_trigger="any";m.definitions.strike.directions=["right"];m.definitions.strike.investment_cost=2;m.definitions.strike.invest_bonus=3
 m.play_at(0,Vector2i(1,2));m.play_at(1,Vector2i(2,2))
 check(m.performance.player==2,"unfunded link baseline")
 check(m.invest(Vector2i(1,2)).ok,"investment succeeds")
 check(m.cubes.player==4 and m.invested_total("player")==2 and m.performance.player==7,"investment transfers principal and applies extra effect once")
 var stable:=JSON.stringify([m.cubes,m.performance,m.rng.state])
 check(not m.invest(Vector2i(1,2)).ok and not m.recover(Vector2i(1,2)).ok,"duplicate and same-turn recovery rejected")
 check(stable==JSON.stringify([m.cubes,m.performance,m.rng.state]),"rejected actions preserve state")
 m.turn+=1;check(m.recover(Vector2i(1,2)).ok,"next-turn recovery succeeds")
 check(m.cubes.player==5 and m.invested_total("player")==0,"recovery deducts fee once")
 check(not m.recover(Vector2i(1,2)).ok,"double recovery rejected")
 check(m.invest(Vector2i(1,2)).ok,"later-turn reinvest")
 m.rules.recover_delay=1;m.turn+=1;m.recover(Vector2i(1,2));m.invest(Vector2i(1,2))
 m.rules.recover_delay=1
 check(not m.recover(Vector2i(1,2)).ok,"fresh investment starts fresh lock")
 m=fixture();m.definitions.strike.requires_investment=true;m.definitions.strike.link_effect="score";m.definitions.strike.link_value=4;m.definitions.strike.link_trigger="on_place";m.definitions.strike.directions=["right"]
 m.play_at(0,Vector2i(0,0));m.play_at(1,Vector2i(1,0));check(m.performance.player==0,"funding prerequisite")
 check(not m.play_at(2,Vector2i(1,0)).ok and not m.play_at(2,Vector2i(6,0)).ok,"occupied and out-of-bounds rejected")
 for effect in ["score","cubes","energy","draw","none"]:
  m=fixture();m.definitions.strike.base_effect=effect;m.definitions.strike.base_value=2
  var result: Dictionary=m.play_at(0,Vector2i(0,0))
  check(result.ok,"supported base effect "+effect)
  if effect=="score":check(m.performance.player==2,"score effect")
  if effect=="cubes":check(m.cubes.player==8,"cube effect")
  if effect=="energy":check(m.energy==101,"energy effect and cost")
 m=fixture();m.cubes.player=4;m.performance.player=2;m.cubes.opponent=5;m.performance.opponent=0
 m.rules.max_turns=1;m._finish_if_needed(true)
 check(m.finished and m.player_score==14 and m.opponent_score==15 and m.winner=="opponent","weighted final judgment")
 check(not m.play_at(0,Vector2i(0,0)).ok and not m.invest(Vector2i(0,0)).ok,"finished input guard")
 # Opponent investments can draw for us before our next hand is animated.
 m=Model.new();m.reset(321);m.rules.max_turns=8;m.energy=100
 for c in m.definitions.values():
  c.base_effect="none";c.base_value=0;c.link_effect="none";c.link_value=0;c.cost=10
 m.opponent_hand.clear();m.opponent_deck.clear();m.opponent_discard.clear()
 m.definitions.strike.link_effect="draw";m.definitions.strike.link_value=2;m.definitions.strike.link_trigger="on_invest";m.definitions.strike.directions=["left","right"];m.definitions.strike.investment_cost=1;m.definitions.strike.invest_bonus=0
 m._place({"id":"strike","uid":1000},"opponent",Vector2i(2,2))
 m._place({"id":"guard","uid":1001},"opponent",Vector2i(1,2))
 m._place({"id":"guard","uid":0},"player",Vector2i(3,2))
 var transition: Dictionary=m.end_turn()
 check(m.cell_map[Vector2i(2,2)].invested==1,"AI investment actually triggers cross-turn draw")
 check(transition.drawn.size()==m.hand.size() and m.hand.size()==5,"all cross-turn draws reach UI, then fill to five")
 for entry in m.hand:check(transition.drawn.has(entry),"no invisible cards after opponent effects")
 m=fixture();m.opponent_deck.clear();m.opponent_hand.clear();m.opponent_discard.clear()
 m.ai_running=true;m._effect("player","energy",2,Vector2i.ZERO,Vector2i.ZERO,"link");m.ai_running=false
 check(m.pending_energy.player==2,"inactive energy deferred")
 m.end_turn();check(m.energy==int(m.rules.energy)+2 and m.pending_energy.player==0,"deferred energy delivered next turn")
 m.end_turn();check(m.energy==int(m.rules.energy),"deferred energy consumed exactly once")
 m=fixture()
 for id in ["strike","guard"]:
  m.definitions[id].link_effect="score";m.definitions[id].link_value=1;m.definitions[id].link_trigger="any";m.definitions[id].directions=["left","right"]
 m.play_at(0,Vector2i(1,1));m.play_at(1,Vector2i(2,1));m.performance.player=0;m.edge_checks=0
 m._start_links("player")
 check(m.performance.player==2 and m.edge_checks==2,"cyclic links do not recurse or duplicate effects")
 for seed_value in range(64):
  var a:=Model.new();var b:=Model.new();a.reset(seed_value);b.reset(seed_value);a.fill_hand();b.fill_hand()
  for round_index in range(35):
   for game in [a,b]:
    if game.finished:continue
    var limit:=0
    while limit<30:
     limit+=1
     var uid:=-1
     for entry in game.hand:
      if game.unavailable_reason(entry.uid).is_empty():uid=entry.uid;break
     if uid<0:break
     game.play(uid)
    if not game.finished:game.end_turn()
    check(game.conserved(),"cards conserved in full seeded match")
   if a.finished and b.finished:break
  check(a.finished and b.finished,"match terminates")
  check(JSON.stringify([a.placed,a.cubes,a.performance,a.rng.state,a.winner])==JSON.stringify([b.placed,b.cubes,b.performance,b.rng.state,b.winner]),"seed replay parity")
 print("LINKED_RULES_PASS checks=",checks)
 quit()
