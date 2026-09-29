extends SceneTree
const Grid=preload("res://scripts/board_geometry.gd")
const Rules=preload("res://scripts/linked_rules.gd")
const Catalog=preload("res://scripts/catalog.gd")
const Model=preload("res://scripts/linked_battle_model.gd")

func _initialize() -> void:
 var occupied: Dictionary={}
 for y in range(Grid.ROWS):
  for x in range(Grid.COLS):
   var cell:=Vector2i(x,y)
   assert(Grid.first_empty(occupied)==cell)
   occupied[cell]=true
 assert(Grid.first_empty(occupied)==Grid.INVALID)
 var model:=Model.new();model.reset(42)
 for cell in [Vector2i(-1,0),Vector2i(6,0),Vector2i(0,5),Vector2i(0,-1)]:
  assert(not Grid.contains(cell) and not model.free_cell(cell))
 var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Rules.PATH))
 for field in ["kind","dark","description","icon","directions"]:
  var malformed: Dictionary=raw.duplicate(true)
  malformed.cards[0][field]=null
  assert(not Rules.validate(malformed).is_empty(),"Incomplete editor data must fail at the boundary")
 for version in [null,"2",{},[],2.5]:
  var malformed: Dictionary=raw.duplicate(true);malformed.schema_version=version
  assert(not Rules.validate(malformed).is_empty())
 var duplicate: Dictionary=raw.duplicate(true);duplicate.cards[0].directions=["right","right"]
 assert(not Rules.validate(duplicate).is_empty())
 for id in Catalog.runtime_ids():
  var first: Dictionary=Rules.definition(id)
  var expected: Dictionary=first.duplicate(true)
  first.name="changed by a view";first.directions.clear()
  assert(Rules.definition(id)==expected,"View changes must not poison the definition cache")
 var count: int=Rules._display_definitions.size()
 for repeat in range(500):
  for id in Catalog.runtime_ids():Rules.definition(id)
 assert(Rules._display_definitions.size()==count,"Cache must stay bounded by card definitions")
 print("STRUCTURE_REFACTOR_PASS bounds row_order schema_validation cache_isolation bounded_cache")
 quit()
