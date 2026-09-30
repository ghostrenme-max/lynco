extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(40).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui:=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var panel: Panel=ui.linked_panel
 panel.refresh()
 assert(not panel.visible and not panel.stats_panel.visible,"no permanent white status panel")
 panel.stats_button.pressed.emit()
 assert(panel.stats_panel.visible and panel.balance.text.contains("누적 성과"),"on-demand battle totals")
 panel.stats_button.pressed.emit()
 var chosen: Dictionary={}
 for entry in ui.model.hand:
  if int(ui.model.definitions[entry.id].investment_cost)>0 and ui.model.unavailable_reason(entry.uid).is_empty():chosen=entry;break
 assert(not chosen.is_empty())
 var cell:=Vector2i(2,2)
 ui._activate_card(chosen.uid,cell)
 while ui.busy:await process_frame
 assert(ui.model.cell_map.has(cell))
 ui.table.selected_cell=cell
 ui._sync_ui();panel.refresh()
 assert(panel.visible and panel.socket_button.visible and not panel.invest_button.disabled,"selected own card has contextual controls")
 assert(panel.taught,"first selection taught once")
 var initial: int=ui.model.cubes.player
 var cost: int=ui.model.definitions[chosen.id].investment_cost
 panel.socket_button.pressed.emit()
 while ui.busy:await process_frame
 panel.refresh()
 assert(ui.model.cubes.player==initial-cost,"socket invests cubes")
 assert(ui.model.cell_map[cell].invested==cost,"investment stored on card")
 assert(panel.socket_button.text.contains(str(cost)),"socket shows live amount")
 assert(ui.table.cards[cell].get_node("InvestmentLabel").text=="◆ %d" % cost,"persistent card count")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/investment_context.png")
 ui.model.turn+=int(ui.model.rules.recover_delay)
 panel.refresh()
 assert(not panel.recover_button.disabled,"recovery unlocks at correct turn")
 panel.recover_button.pressed.emit()
 while ui.busy:await process_frame
 panel.refresh()
 assert(ui.model.cell_map[cell].invested==0,"context menu recovers")
 ui.table.selected_cell=ui.Table.INVALID;panel.refresh()
 assert(not panel.visible and not panel.socket_button.visible,"deselection removes controls")
 print("INVESTMENT_CONTEXT_PASS")
 quit()
