extends SceneTree

const UI = preload("res://scripts/screen_style.gd")
const Symbols = preload("res://scripts/card_symbols.gd")
const Catalog = preload("res://scripts/catalog.gd")

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var watchdog := create_timer(30)
 watchdog.timeout.connect(func(): push_error("Resource test timeout"); quit(1))
 var dark := UI.ink_material()
 var light := UI.ink_material(true)
 assert(dark.shader == light.shader and dark != light)
 assert(dark.get_shader_parameter("ink") == UI.INK)
 assert(light.get_shader_parameter("ink") == Color.WHITE)
 for id in Catalog.CARDS:
  var data: Dictionary = Catalog.table_card(id)
  assert(Symbols.texture_for(data) == Symbols.texture_for(data))
 var fallback: Texture2D = Symbols.SPECIAL.king[0]
 assert(Symbols.texture_for(Catalog.table_card("strike"), fallback) == fallback)
 for identity in ["king", "joker"]:
  for is_dark in [false, true]:
   var data := {"icon":identity, "dark":is_dark}
   assert(Symbols.texture_for(data, fallback) == Symbols.SPECIAL[identity][1 if is_dark else 0])
   assert(Symbols.material_for(data, dark) == null)
 change_scene_to_file("res://scenes/card_book.tscn")
 await scene_changed
 await process_frame
 var book = current_scene
 var styles: Array = [book.idle_card_style, book.hover_card_style, book.selected_card_style, book.light_detail_style, book.dark_detail_style]
 for cycle in range(40):
  for id in Catalog.CARDS:
   book._select_card(id)
   book._select_card(id) # Repeated selection must retain details and styles.
   assert(book.detail_body.text == Catalog.table_card(id).detail)
   assert(book.detail_panel.get_theme_stylebox("panel") == styles[4 if Catalog.table_card(id).dark else 3])
   for key in book.card_buttons:
    assert(book.card_buttons[key].get_theme_stylebox("normal") == styles[2 if key == id else 0])
    assert(book.card_buttons[key].get_theme_stylebox("hover") == styles[2 if key == id else 1])
  # Rebuild the current page, exercising selected-id invalidation.
  book._page_by(0)
  assert(book.selected_id == Catalog.CARDS.keys()[0])
  assert(book.card_buttons[book.selected_id].get_theme_stylebox("normal") == styles[2])
  await process_frame
 print("LYNCO_RESOURCE_TEST_PASS 240_selections 40_page_rebuilds shared_styles shared_shader independent_ink native_symbols fallback_preserved")
 quit()
