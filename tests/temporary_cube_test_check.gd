extends SceneTree
const Model=preload("res://scripts/linked_battle_model.gd")
const Fixture=preload("res://scripts/temporary_cube_test.gd")
const Session=preload("res://scripts/collection_session.gd")
func _initialize() -> void:
 var m:=Model.new();m.reset(42);m.fill_hand()
 var white:Dictionary={};var black:Dictionary={}
 for e in m.hand:
  if Fixture.cost(e)==1:white=e
  if Fixture.cost(e)==2:black=e
 assert(not white.is_empty() and not black.is_empty())
 assert(not m.definitions[white.id].dark and m.definitions[black.id].dark)
 m.cubes.player=0
 assert(not m.play(white.uid).ok and not m.play(black.uid).ok)
 Session.items.clear();Fixture.prepare_items();Fixture.prepare_items()
 assert(Session.items.size()==1 and Session.items[0].id==Fixture.ITEM_ID)
 assert(Fixture.use_item(m) and m.cubes.player==4)
 assert(not Fixture.use_item(m) and m.cubes.player==4)
 assert(m.play_at(white.uid,Vector2i(0,0)).ok and m.cubes.player==3)
 assert(m.play_at(black.uid,Vector2i(5,4)).ok and m.cubes.player==1)
 assert(m.conserved())
 print("TEMP_CUBE_TEST_PASS")
 quit()
