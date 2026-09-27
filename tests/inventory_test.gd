extends SceneTree
const Session=preload("res://scripts/collection_session.gd")
func _initialize() -> void:call_deferred("run")
func key(code: Key) -> void:
 for down in [true,false]:
  var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
  root.push_input(e,true)
func run() -> void:
 create_timer(40).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy:await process_frame
 root.size=Vector2i(1280,720);await process_frame
 key(KEY_F);await process_frame
 assert(is_instance_valid(ui.inventory_layer))
 var panel=ui.inventory_layer.get_child(0)
 assert(panel.selected_index==-1 and panel.title_label.text=="보유한 아이템이 없습니다")
 var snapshot:=JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state,Session.gold])
 key(KEY_SPACE);key(KEY_E);key(KEY_SHIFT)
 assert(snapshot==JSON.stringify([ui.model.hand,ui.model.energy,ui.model.rng.state,Session.gold]))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/inventory_empty.png")
 key(KEY_F);await process_frame
 assert(not is_instance_valid(ui.inventory_layer))
 for i in range(8):
  Session.items.append({"id":"test_"+str(i),"name":"검증용 아이템 "+str(i+1),"description":"아이템을 선택하면 이 영역에 설명이 표시됩니다.","source":"shop" if i%2==0 else "black_market","icon":"res://assets/icons/eye.png"})
 key(KEY_F);await process_frame
 panel=ui.inventory_layer.get_child(0)
 assert(panel.item_buttons.size()==8 and panel.selected_index==0)
 panel.item_buttons[1].pressed.emit()
 assert(panel.selected_index==1 and panel.source_label.text=="암시장" and panel.preview.texture!=null)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/inventory_sample.png")
 key(KEY_ESCAPE);await process_frame
 assert(not is_instance_valid(ui.inventory_layer))
 Session.items.clear()
 ui.table.set_top_view(true);ui.stage.hide()
 key(KEY_F);await process_frame
 assert(is_instance_valid(ui.inventory_layer) and ui.table.top_view)
 key(KEY_ESCAPE);await process_frame
 assert(ui.table.top_view and not ui.stage.visible)
 print("INVENTORY_PASS empty populated selection source modal_guards F_Esc top_view")
 quit()
