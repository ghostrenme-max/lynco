extends SceneTree
func _initialize() -> void:
 var loader = load("res://lynco_cards/lynco_card_loader.gd")
 var cards: Dictionary = loader.load_cards()
 assert(cards.size() == 12)
 var card = cards["strike"]
 assert(card.description == "한글 \"인용\"\n줄바꿈 <script>")
 assert(card.target_cells(Vector2i(2,2)).size() == 8)
 assert(card.target_cells(Vector2i.ZERO).size() == 3)
 assert(cards["strike_reverse"].action_cost == -1)
 assert(card.as_dictionary()["directions"].size() == 8)
 for c in cards.values():
  assert(c.icon != null)
 print("CARD_EDITOR_GODOT_PASS: 12 resources, Korean text, icons, 8 directions, edge clipping, unknown cost")
 quit()
