extends SceneTree

const Model = preload("res://scripts/battle_model.gd")
const FIXTURE = "res://tests/optimization_model_baseline.json"

func _initialize() -> void:
 var hashes: Array[String] = []
 for seed_value in range(256):
  var model = Model.new()
  model.reset(seed_value)
  var choices := RandomNumberGenerator.new()
  choices.seed = seed_value + 70000
  var trace: Array = []
  for step in range(80):
   var result: Variant
   match choices.randi_range(0, 5):
    0: result = model.fill_hand()
    1: result = model.conceal_and_shuffle()
    2, 3:
     var uid: int = -1 if model.hand.is_empty() else int(model.hand[choices.randi_range(0, model.hand.size()-1)].uid)
     result = model.play(uid)
    4: result = model.end_turn()
    5: result = model.draw_cards(choices.randi_range(0, 3))
   var queries: Array = []
   for uid in range(-1, model.total_cards + 1):
    queries.append([model.find_card(uid), model.is_concealed(uid), model.unavailable_reason(uid), model.preview(uid)])
   # Serialize now: hand/deck dictionaries are deliberately mutable.
   trace.append(JSON.stringify([result, queries, model.hand, model.deck, model.discard, model.exhausted, model.turn, model.health, model.enemy_health, model.energy, model.block, model.observed, model.finished, model.rng.state, model.identity_counts(), model.conserved()]))
  hashes.append(JSON.stringify(trace).sha256_text())
 if OS.get_cmdline_user_args().has("--record-baseline"):
  var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
  file.store_string(JSON.stringify(hashes, " "))
  print("LYNCO_MODEL_BASELINE_RECORDED seeds=256 transitions=20480")
 else:
  var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
  if expected != hashes:
   push_error("Optimization changed model results, queries, pile order or RNG state")
   quit(1)
   return
  print("LYNCO_MODEL_PARITY_PASS seeds=256 transitions=20480 exact_results_queries_piles_rng")
 quit()
