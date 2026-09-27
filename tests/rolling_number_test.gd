extends SceneTree
const Rolling=preload("res://scripts/rolling_number_label.gd")
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func run() -> void:
 create_timer(50).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy or ui.views.is_empty():await process_frame
 var sample:=Rolling.new()
 sample.position=Vector2(420,320);sample.size=Vector2(800,95)
 sample.add_theme_font_size_override("font_size",54)
 sample.add_theme_color_override("font_color",Color.WHITE)
 sample.text="골드 19 / 100 · 01 턴"
 ui.stage.add_child(sample)
 await process_frame
 check(not sample.changing,"initial values do not animate")
 sample.text="골드 25 / 100 · 02 턴"
 await create_timer(0.025).timeout
 check(sample.changing and sample.reels[0].active and not sample.reels[1].active,"only changed numeric runs roll")
 check(sample.reels[0].target_value>sample.reels[0].start_value,"increase rolls upward")
 check(int(sample.number_material.get_shader_parameter("mask_count"))==2,"native text masked only in changed slots")
 await create_timer(0.07).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/number_scroll_mid.png")
 check(sample.reels[0].shown_value()>19 and sample.reels[0].shown_value()<25,"intermediate numeric values")
 sample.text="골드 3 / 100 · 03 턴"
 await create_timer(0.025).timeout
 check(sample.reels[0].target_value<sample.reels[0].start_value,"interrupted decrease rolls downward")
 await create_timer(0.5).timeout
 check(not sample.changing and int(sample.number_material.get_shader_parameter("mask_count"))==0,"completion restores native exact text")
 sample.text="99.10 ms"
 await create_timer(0.025).timeout
 sample.text="12.05 ms"
 await create_timer(0.5).timeout
 check(sample.text=="12.05 ms" and not sample.changing,"decimal values settle")
 sample.text="9999999"
 await create_timer(0.025).timeout
 sample.text="1"
 await create_timer(0.025).timeout
 check(sample.reels[0].steps<=12,"large changes use bounded rolling rows")
 sample.finish_rolls()
 var count: int=sample.get_child_count()
 for i in range(80):
  sample.text=str(i)
  await process_frame
 check(sample.get_child_count()==count,"reels reused during rapid updates")
 Rolling.reduced_motion=true
 sample.text="500"
 await create_timer(0.14).timeout
 check(not sample.changing,"reduced motion settles quickly")
 Rolling.reduced_motion=false
 sample.queue_free()
 for label in [ui.garnet_label,ui.hand_label,ui.king_count,ui.joker_count,ui.turn_caption,ui.preview_cost,ui.result_body,ui.hud_values.energy]:
  check(label.get_script()==Rolling,"battle numeric displays share the roller")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/number_scroll_battle.png")
 change_scene_to_file("res://scenes/shop.tscn");await scene_changed
 await process_frame
 var shop=current_scene
 check(shop.balance.get_script()==Rolling,"shop gold uses same roller")
 shop.Session.gold=100;shop._refresh();await create_timer(0.025).timeout
 shop.Session.gold=40;shop._refresh();await create_timer(0.025).timeout
 check(shop.balance.changing,"shop spending rolls downward")
 await create_timer(0.5).timeout
 check(not shop.balance.changing,"shop gold settles")
 print("ROLLING_NUMBERS_PASS checks=",checks)
 quit()
