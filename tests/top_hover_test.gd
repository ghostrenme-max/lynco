extends SceneTree
var checks:=0
var ui: Node
var table: Node
const SOURCE:=Vector2i(2,2)
const TARGET:=Vector2i(3,2)
const OTHER:=Vector2i(1,1)
const NEXT:=Vector2i(4,2)
func _initialize() -> void:run.call_deferred()
func check(ok: bool, message: String) -> void:
 if not ok:
  push_error(message);quit(1);assert(ok,message)
 checks+=1
func motion(point: Vector2) -> void:
 var event:=InputEventMouseMotion.new();event.position=point
 root.push_input(event,true)
func hover(cell: Vector2i) -> void:
 motion(table.camera.unproject_position(table.cards[cell].global_position))
func middle() -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_MIDDLE;event.pressed=true
 root.push_input(event,true)
func factor(cell: Vector2i, amount: float) -> bool:
 return table.cards[cell].scale.is_equal_approx(Vector3(amount,1,amount))
func capture(label: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/top_hover_"+label+".png")
func run() -> void:
 create_timer(40).timeout.connect(func():push_error("TOP_HOVER_TIMEOUT");quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 table=ui.table
 var index:=100
 for cell in [SOURCE,TARGET,OTHER,NEXT]:
  ui.model._place({"id":"strike","uid":index},"player",cell)
  table.place("strike",cell,true)
  index+=1
 await create_timer(0.4).timeout
 var original_state:=JSON.stringify([ui.model.placed,ui.model.hand,ui.model.deck,ui.model.rng.state])
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=resolution;await process_frame
  ui._set_reduced_motion(resolution.x==1920)
  middle();await create_timer(0.65).timeout
  check(table.top_view and not ui.stage.visible,"middle click enters top view")
  hover(SOURCE);await create_timer(0.2).timeout
  check(table.hovered_cell==SOURCE and factor(SOURCE,1.5),"real pointer enlarges source")
  check(factor(TARGET,0.8) and factor(OTHER,0.8),"all other cards shrink initially")
  await capture("initial_"+str(resolution.x))
  hover(SOURCE)
  await create_timer(0.4).timeout
  check(factor(SOURCE,1.5) and factor(TARGET,1.2) and factor(OTHER,0.8),"continuous hover reveals linked target after delay")
  check(factor(NEXT,0.8),"indirect target stays small")
  await capture("linked_"+str(resolution.x))
  hover(TARGET);await create_timer(0.2).timeout
  check(factor(TARGET,1.5) and factor(SOURCE,0.8) and factor(NEXT,0.8),"moving source clears previous reveal")
  hover(SOURCE);await create_timer(0.3).timeout
  check(factor(TARGET,0.8) and not table.top_hover_revealed,"old hover delay cannot reveal new target early")
  motion(Vector2(3,3));await create_timer(0.85).timeout
  for cell in table.cards:check(factor(cell,1.0),"leaving cards cancels delay and restores scale")
  hover(SOURCE);await create_timer(0.15).timeout
  middle();await create_timer(0.85).timeout
  check(not table.top_view and ui.stage.visible,"middle click leaves top view")
  for cell in table.cards:check(factor(cell,1.0),"leaving top view cancels pending enlargement")
 # Eligibility must come from the model, not only a direction arrow.
 table.set_top_view(true);ui.stage.hide()
 ui.model.definitions.strike.link_condition="enemy"
 hover(SOURCE);await create_timer(0.95).timeout
 check(factor(TARGET,0.8),"ineligible allied target is not enlarged")
 ui.model.definitions.strike.link_condition="any"
 table.refresh_link_rules();await create_timer(0.2).timeout
 check(factor(TARGET,1.2),"rule refresh updates revealed targets")
 root.mouse_exited.emit();await create_timer(0.2).timeout
 for cell in table.cards:check(factor(cell,1.0),"window exit restores cards")
 hover(SOURCE);await create_timer(0.1).timeout
 table.click_influence(SOURCE);await create_timer(0.85).timeout
 for cell in table.cards:check(factor(cell,1.0),"click focus cancels pending hover")
 table.set_top_view(false);ui.stage.show()
 check(original_state==JSON.stringify([ui.model.placed,ui.model.hand,ui.model.deck,ui.model.rng.state]),"hover does not mutate battle state")
 table.set_top_view(true);ui.stage.hide();hover(SOURCE)
 await ui._restart(123)
 check(table.hovered_cell==table.INVALID and table.cards.is_empty(),"restart safely clears pending hover")
 print("TOP_HOVER_PASS checks=",checks)
 quit()
