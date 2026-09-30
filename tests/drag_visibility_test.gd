extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 create_timer(45).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn")
 await scene_changed
 var ui:=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var uid: int=ui.model.hand[2].uid
 var card: Control=ui.views[uid]
 var start: Vector2=card.position+card.size*0.5
 var cell:=Vector2i(2,2)
 var end: Vector2=ui.table.screen_position(cell)
 ui._test_drag(start,end,false)
 await create_timer(0.2).timeout
 assert(ui.drag_uid>=0,"drag starts")
 card=ui.views[ui.drag_uid]
 assert(is_equal_approx(card.modulate.a,0.55),"drag opacity")
 assert(ui.drag_placement_overlay.visible,"overlay shown")
 assert(ui.drag_placement_overlay.caption.text=="놓아서 배치","valid placement guidance")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/drag_preview.png")
 ui._cancel_drag()
 assert(card.modulate.a==1.0 and not ui.drag_placement_overlay.visible,"cancel restores opacity and hides preview")
 await create_timer(0.4).timeout
 ui._test_drag(card.rest_position+card.CARD_SIZE*0.5,end,true)
 await process_frame
 while ui.busy:await process_frame
 assert(ui.model.cell_map.has(cell),"drop places card")
 assert(ui.drag_uid==-1,"drop cleans drag state")
 var next_card: Control=ui.views.values()[0]
 await create_timer(0.4).timeout
 ui._test_drag(next_card.rest_position+next_card.CARD_SIZE*0.5,end,false)
 await create_timer(0.15).timeout
 assert(ui.drag_placement_overlay.caption.text=="이미 카드가 있는 칸입니다","occupied guidance")
 ui._cancel_drag()
 print("DRAG_VISIBILITY_PASS")
 quit()
