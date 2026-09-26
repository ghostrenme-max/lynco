extends SceneTree

const Catalog = preload("res://scripts/catalog.gd")
const UI = preload("res://scripts/screen_style.gd")
var checks: Array[String] = []
var started: int = Time.get_ticks_msec()

func _initialize() -> void:
 call_deferred("_run")

func _check(ok: bool, message: String) -> void:
 if not ok:
  push_error("NAVIGATION FAILED: " + message)
  quit(1)
  assert(ok, message)
 checks.append(message)

func _settle() -> void:
 for _i in range(4): await process_frame

func _click(button: Control) -> void:
 var point: Vector2 = button.get_global_rect().get_center()
 var motion := InputEventMouseMotion.new()
 motion.position = point
 root.push_input(motion, true)
 for pressed in [true, false]:
  var event := InputEventMouseButton.new()
  event.position = point
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed
  root.push_input(event, true)
 await _settle()

func _capture(name: String) -> void:
 await create_timer(0.12).timeout
 await RenderingServer.frame_post_draw
 var error: Error = root.get_texture().get_image().save_png("res://test-results/" + name + ".png")
 _check(error == OK, "capture " + name)

func _wait_battle() -> void:
 await _settle()
 var ui = current_scene.get_node("Interface")
 while ui.views.is_empty() or ui.busy:
  await process_frame

func _proposal(ui: Control) -> void:
 # Review-only HUD, created by this test; never part of battle.tscn.
 var player := UI.panel(ui.stage, Rect2(34, 92, 420, 161), UI.PAPER)
 UI.label(player, "제스터 린코", Rect2(24, 16, 350, 35), 24)
 UI.label(player, "체력 %d / %d   ·   방어 %d" % [ui.model.health, Catalog.CHARACTER.health, ui.model.block], Rect2(24, 62, 360, 32), 22)
 var energy := UI.panel(player, Rect2(24, 107, 215, 38), UI.YELLOW)
 UI.label(energy, "행동력  %d / %d" % [ui.model.energy, Catalog.CHARACTER.energy], Rect2(14, 2, 198, 34), 22)
 var enemy := UI.panel(ui.stage, Rect2(1120, 92, 446, 161), UI.PAPER)
 UI.label(enemy, str(Catalog.ENEMY.name), Rect2(24, 16, 380, 35), 24)
 UI.label(enemy, "체력 %d / %d" % [ui.model.enemy_health, Catalog.ENEMY.health], Rect2(24, 62, 380, 32), 22)
 UI.label(enemy, "다음 행동  ·  공격 %d" % Catalog.ENEMY.intents[(ui.model.turn - 1) % Catalog.ENEMY.intents.size()], Rect2(24, 107, 395, 35), 23)
 var badge := UI.panel(ui.stage, Rect2(637, 73, 327, 82), UI.PAPER)
 UI.label(badge, "전투 UI 시안 · 미적용", Rect2(19, 9, 310, 32), 21)
 UI.label(badge, "턴 %d   /   기존 임시 규칙" % ui.model.turn, Rect2(19, 46, 300, 28), 17, UI.MUTED)

func _run() -> void:
 var watchdog := Timer.new()
 watchdog.wait_time = 90
 watchdog.one_shot = true
 watchdog.timeout.connect(func(): push_error("Navigation test timeout"); quit(1))
 root.add_child(watchdog)
 watchdog.start()
 _check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn", "main scene configured")
 change_scene_to_file("res://scenes/main_menu.tscn")
 await _settle()
 _check(current_scene.name == "MainMenu", "main loaded")
 await _capture("main_menu_1440")
 root.size = Vector2i(1280, 720)
 await _settle()
 await _capture("main_menu_1280")
 await _click(current_scene.action_buttons.book)
 _check(current_scene.name == "CardBook", "mouse main to book")
 _check(current_scene.card_buttons.size() == Catalog.CARDS.size(), "all catalog cards available without unlocks")
 for id in Catalog.CARDS:
  await _click(current_scene.card_buttons[id])
  _check(current_scene.selected_id == id, "select " + id)
  _check(current_scene.detail_body.text == Catalog.card(id).detail, "shared effect " + id)
  _check(current_scene.detail_meta.text.contains(str(Catalog.card(id).cost)), "shared cost " + id)
 await _capture("card_book_1280")
 root.size = Vector2i(1440, 810)
 await _settle()
 await _click(current_scene.card_buttons.strike)
 await _capture("card_book_black")
 await _click(current_scene.card_buttons.observe)
 await _capture("card_book_white")
 var escape := InputEventKey.new()
 escape.keycode = KEY_ESCAPE
 escape.pressed = true
 root.push_input(escape, true)
 await _settle()
 _check(current_scene.name == "MainMenu", "book escape returns main")
 await _click(current_scene.action_buttons.book)
 await _click(current_scene.action_buttons.back)
 _check(current_scene.name == "MainMenu", "book back button")
 var main_nodes: int = root.get_child_count()
 var scene_nodes: int = 0
 for iteration in range(3):
  await _click(current_scene.action_buttons.start)
  _check(current_scene is Node3D, "existing Node3D battle " + str(iteration))
  var ui = current_scene.get_node("Interface")
  ui._return_to_main()
  _check(not ui.leaving_battle, "return blocked during startup")
  await _wait_battle()
  _check(ui.model.hand.size() == 5 and ui.model.conserved(), "battle initialized " + str(iteration))
  if iteration == 0:
   ui._test_inspect_card(int(ui.model.hand[0].uid))
   ui._return_to_main()
   _check(not ui.leaving_battle and ui.inspector_open, "inspector blocks return")
   ui._close_inspector()
   ui._test_pointer(Vector2(350, 300))
   await create_timer(2.2).timeout
   await _capture("battle_connected")
   _proposal(ui)
   await _capture("battle_ui_proposal_1440")
   root.size = Vector2i(1280, 720)
   await _settle()
   await _capture("battle_ui_proposal_1280")
   root.size = Vector2i(1440, 810)
   await _settle()
  if iteration == 2:
   ui.model.finished = true
   ui._sync_ui()
   _check(not ui.menu_button.disabled, "return available after battle end")
  await _click(ui.menu_button)
  _check(current_scene.name == "MainMenu", "battle to main " + str(iteration))
  _check(root.get_child_count() == main_nodes, "no retained root scenes " + str(iteration))
  var count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
  if iteration == 0: scene_nodes = count
  else: _check(count == scene_nodes, "stable menu node count " + str(iteration))
 var report := {"engine": Engine.get_version_info().string, "checks": checks, "menu_nodes": scene_nodes, "duration_ms": Time.get_ticks_msec() - started}
 var file := FileAccess.open("res://test-results/navigation_test.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(report, "  "))
 file.close()
 print("LYNCO_NAVIGATION_TEST_PASS %d checks, %d stable nodes" % [checks.size(), scene_nodes])
 quit()
