extends SceneTree
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
 var popup=ui.notification
 var state:=JSON.stringify([ui.model.hand,ui.model.deck,ui.model.rng.state,ui.model.energy])
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=resolution;await process_frame
  ui._toast("행동력이 부족합니다 · 다른 카드를 선택하세요")
  while popup.phase=="opening":
   check(popup.outline().size()==36,"four rounded corners throughout opening")
   check(popup.extent.x>0 and popup.extent.y>0,"positive geometry")
   await process_frame
  check(root.get_visible_rect().encloses(popup.get_global_rect()),"popup fits viewport")
  check(popup.content.modulate.a>0.99,"fully readable at rest")
  check(popup.mouse_filter==Control.MOUSE_FILTER_IGNORE and popup.caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,"nonblocking input")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-results/notification_"+str(resolution.x)+".png")
  while popup.phase!="hidden":
   if popup.phase=="closing":check(popup.outline().size()==36,"four rounded corners throughout closing")
   await process_frame
 for i in range(30):ui._toast("연속 알림 %d" % i)
 check(popup.caption.text=="연속 알림 29","latest message replaces stale notices")
 check(popup.get_child_count()==1 and popup.content.get_child_count()==1,"no accumulating nodes")
 check(state==JSON.stringify([ui.model.hand,ui.model.deck,ui.model.rng.state,ui.model.energy]),"notifications preserve battle and RNG")
 ui._set_reduced_motion(true);ui._toast("간결한 알림")
 await create_timer(0.15).timeout
 check(popup.extent.is_equal_approx(popup.expanded),"reduced motion has no shape bounce")
 popup.clear();check(not popup.visible,"clear cancels notification")
 check(ui.result_panel is Panel,"result window keeps original panel")
 check(popup.expanded.y==52,"one line has compact height")
 ui._toast("첫 번째 줄 안내\n두 번째 줄 안내")
 await create_timer(0.15).timeout
 check(popup.caption.get_line_count()==2 and popup.expanded.y==78,"two lines have compact readable height")
 check(popup.caption.max_lines_visible==2,"short notification is limited to two visible lines")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/notification_two_lines.png")
 await ui._restart(20260926)
 check(popup.caption.text=="카드를 선택해 전투를 시작하세요","restart replaces old notification")
 change_scene_to_file("res://scenes/shop.tscn");await scene_changed
 var shop=current_scene
 shop._activate("starter")
 check(shop.notice is Label and shop.notice.text.contains("다음 대전"),"shop retains original text notice")
 print("NOTIFICATION_PASS checks=",checks)
 quit()
