extends SceneTree
var ui: Control
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func click_card() -> void:
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  event.position=ui.inspector_card.get_global_rect().get_center()
  root.push_input(event,true)
func run() -> void:
 create_timer(30).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 ui=current_scene.get_node("Interface")
 check(root.size==Vector2i(1920,1080),"game starts at 1920 by 1080")
 while ui.busy or ui.views.is_empty():await process_frame
 var state:=JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state])
 for entry in ui.model.hand:
  ui._test_inspect_card(int(entry.uid))
  var front: String=ui.preview_text.text
  check(ui.inspector_comparison.visible,"front shows comparison")
  check(ui.comparison_effects[0].text==ui.Catalog.table_card(entry.id).rule_detail,"front executable conditions comparison")
  check(ui.comparison_effects[1].self_modulate.a<=0.11 and ui.comparison_titles[1].self_modulate.a<=0.11,"inactive text nearly transparent")
  for band in ui.comparison_bands:
   var style: StyleBoxFlat=band.get_theme_stylebox("panel")
   check(style.corner_radius_top_left==16 and style.corner_radius_top_right==16 and style.corner_radius_bottom_left==16 and style.corner_radius_bottom_right==16,"all comparison corners rounded")
  click_card()
  check(ui.inspector_open and ui.inspector_reverse,"left click switches without closing")
  check(ui.preview_text.text==ui.Catalog.back_card(entry.id).detail,"correct back explanation")
  check(ui.inspector_score.cube_count()==0,"unknown back value not invented")
  var special: bool=ui.Catalog.back_identity(entry.id) in ["king","joker"]
  check(ui.inspector_comparison.visible!=special,"king and joker hide comparison")
  if not special:
   check(ui.comparison_effects[1].self_modulate.a==1.0 and ui.comparison_effects[0].self_modulate.a<=0.11,"opacity swaps with face")
   check(ui.comparison_effects[1].get_theme_color("font_color").r>ui.comparison_effects[0].get_theme_color("font_color").r,"back highlight swaps")
  ui._sync_ui()
  check(ui.inspector_reverse and ui.preview_text.text==ui.Catalog.back_card(entry.id).detail,"refresh preserves back")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/inspector_flip.png")
  click_card()
  check(not ui.inspector_reverse and ui.preview_text.text==front,"second click restores front")
  ui._close_inspector()
 ui._inspect_placed("guard",true,"opponent")
 click_card()
 check(not ui.inspector_reverse and ui.preview_title.text=="봉쇄","placed reverse can show front")
 click_card()
 check(ui.inspector_reverse and ui.preview_title.text=="킹","placed front returns to king")
 ui._close_inspector()
 ui._inspect_placed("link",false)
 for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size=resolution;await process_frame
  var left: Rect2=ui.inspector_comparison.get_global_rect()
  check(root.get_visible_rect().encloses(left),"comparison remains inside viewport")
  check(not left.intersects(ui.inspector_card.get_global_rect()),"comparison does not overlap card")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/comparison_"+str(resolution.x)+".png")
 ui._close_inspector()
 check(state==JSON.stringify([ui.model.hand,ui.model.placed,ui.model.energy,ui.model.rng.state]),"inspection does not flip actual cards")
 print("INSPECTOR_FLIP_PASS checks=",checks)
 quit()
