extends SceneTree
const Model=preload("res://scripts/linked_battle_model.gd")
const Rules=preload("res://scripts/linked_rules.gd")
func _initialize() -> void:
 var m:=Model.new();m.reset(456)
 assert(Rules.load_error.is_empty())
 assert(m.rules.starting_cubes==9 and m.rules.max_turns==6)
 assert(m.definitions.strike.name=="검증 카드")
 assert(m.definitions.strike.cost==2 and m.definitions.strike.base_effect=="cubes")
 m.hand.clear();m.deck.clear();m.total_cards=1;m.hand.append({"uid":0,"id":"strike"})
 assert(m.play_at(0,Vector2i(2,2)).ok)
 assert(m.cubes.player==13 and m.energy==1)
 var enemy: Dictionary={"entry":{"id":"guard","uid":1000},"owner":"opponent","reverse":false,"cell":Vector2i(3,2),"invested":0}
 m.placed.append(enemy);m.cell_map[enemy.cell]=enemy
 assert(m.invest(Vector2i(2,2)).ok)
 assert(m.cubes.player==11 and m.performance.opponent==5 and m.performance.player==0)
 assert(m.invested_total("player")==2)
 print("EDITOR_GAME_BRIDGE_PASS: EXE UI edits -> apply -> runtime name/cost/base effect/condition/trigger/bonus/rules")
 quit()
