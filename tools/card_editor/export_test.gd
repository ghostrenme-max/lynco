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
 assert(card.base_effect == "score" and card.base_value == 3)
 assert(card.link_effect == "score" and card.link_trigger == "any")
 assert(card.investment_cost == 2 and card.invest_bonus == 1)
 assert(card.deck_starter == 5 and card.deck_remnant == 4)
 for c in cards.values():
  assert(c.icon != null)
 print("CARD_EDITOR_GODOT_PASS: 12 resources, Korean text, icons, 8 directions, edge clipping, unknown cost, runtime fields")
 quit()
