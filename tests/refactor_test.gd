extends SceneTree

const Rolling = preload("res://scripts/rolling_number_label.gd")
var checks := 0

func _initialize() -> void:call_deferred("run")

func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1

func run() -> void:
 create_timer(40).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var state:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 ui._inspect_placed("link",false,"opponent")
 var title: String=ui.preview_title.text
 var kind: String=ui.preview_kind.text
 ui._sync_ui()
 check(ui.preview_title.text==title and ui.preview_kind.text==kind,"HUD refresh preserves placed inspector source and owner")
 ui._toggle_inspector_face();ui._sync_ui()
 check(ui.inspector_source_id=="link" and ui.inspector_reverse,"placed reverse stays selected")
 ui._toggle_inspector_face()
 check(ui.preview_kind.text==kind,"return to front preserves owner")
 ui._close_inspector()
 ui._test_inspect_card(ui.model.hand[0].uid)
 check(not ui.inspector_placed,"hand opening clears placed context")
 ui._close_inspector()
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"inspection leaves rules and RNG untouched")

 var table=ui.table
 var cell:=Vector2i(2,1)
 var point: Vector2=table.screen_position(cell)
 table.preview(point,true)
 var refreshes: int=table.grid_refreshes
 for i in range(240):table.preview(point,i%2==0)
 check(table.grid_refreshes==refreshes,"stationary preview does not rescan the board")
 table.hide_preview()
 refreshes=table.grid_refreshes
 for i in range(240):table.hide_preview()
 check(table.grid_refreshes==refreshes,"hidden preview is a no-op")
 table.place("observe",cell,true);table.mark_owner(cell,"opponent")
 check(int(table.battle_grid_material.get_shader_parameter("opponent_mask"))==(1 << (cell.y*table.COLS+cell.x)),"owner change still updates grid")
 table.place("observe",Vector2i(3,1),true)
 for holder in table.mirror_cards.values():
  for child in holder.get_children():
   if str(child.name).begins_with("Direction_"):
    check(child.material_override==table.far_direction_material,"mirror direction materials shared")
 table.clear_cards()
 check(not table.battle_grid.visible,"reset hides grid after no-op preview")

 var uid: int=ui.model.hand[0].uid
 var hand_view=ui.views[uid]
 var camera_before: Transform3D=table.camera.transform
 ui._test_drag(hand_view.rest_position+ui.Card.CARD_SIZE*0.5,point,false)
 await create_timer(0.2).timeout
 check(ui.drag_uid==uid,"HUD release test starts a real drag")
 var release:=InputEventMouseButton.new()
 release.button_index=MOUSE_BUTTON_LEFT
 release.position=ui.stage.get_global_transform_with_canvas()*ui.turn_board.get_rect().get_center()
 root.push_input(release,true)
 check(ui.drag_uid==-1 and ui.press_uid==-1,"releasing over HUD always clears drag")
 check(table.camera.transform.is_equal_approx(camera_before),"HUD cancellation restores camera")
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"HUD cancellation does not place or spend")

 var sample:=Rolling.new()
 sample.position=Vector2(400,340);sample.size=Vector2(800,100)
 sample.add_theme_font_size_override("font_size",48)
 sample.text="1 / 99"
 ui.stage.add_child(sample)
 await process_frame
 sample.text="80 / 99"
 await create_timer(0.05).timeout
 var layouts: int=sample.layout_updates
 var frames:=0
 while sample.changing:
  await process_frame
  frames+=1
 var updates: int=sample.layout_updates-layouts
 check(frames>2 and updates<=2,"steady rolling changes pixels without reshaping text each frame")
 sample.text="100 / 99"
 await create_timer(0.03).timeout
 layouts=sample.layout_updates
 sample.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 sample.size.x=700
 sample.add_theme_font_size_override("font_size",54)
 await create_timer(0.05).timeout
 check(sample.layout_updates>layouts,"resize, alignment and theme invalidate rolling layout")
 check(sample.reels[0].font_size==54,"rolling font stays synchronized")
 sample.finish_rolls()
 check(int(sample.number_material.get_shader_parameter("mask_count"))==0,"finish removes masks")
 sample.queue_free()
 print("REFACTOR_PASS checks=",checks," rolling_frames=",frames," layout_updates=",updates," repeated_preview_refreshes=0/240")
 quit()
