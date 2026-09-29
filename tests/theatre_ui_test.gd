extends SceneTree
const Session=preload("res://scripts/collection_session.gd")
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);quit(1);assert(ok,message)
 checks+=1
func settle() -> void:
 for i in range(5):await process_frame
func click(control: Control) -> void:
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new()
 motion.position=point
 root.push_input(motion,true)
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
  root.push_input(event,true)
  await process_frame
 await settle()
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-results/theatre_"+name+".png")
func run() -> void:
 create_timer(60).timeout.connect(func():quit(1))
 change_scene_to_file("res://scenes/shop.tscn");await scene_changed;await settle()
 var ui=current_scene
 check(ui.deck_panels.size()==4,"four deck panels")
 check(Session.DECKS.size()==2,"dummy decks do not enter battle data")
 for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,1000)]:
  root.size=resolution;ui.scroll.scroll_vertical=0;await settle()
  check(ui.scroll.get_v_scroll_bar().visible,"vertical scroll exists")
  check(not ui.scroll.get_h_scroll_bar().visible,"no horizontal overflow")
  check(ui.buttons.remnant.disabled,"insufficient funds blocked")
  var heading: Vector2=ui.balance.global_position
  await capture("shop_top_"+str(resolution.x))
  var point: Vector2=ui.scroll.get_global_rect().get_center()
  for n in range(12):
   var event:=InputEventMouseButton.new()
   event.position=point;event.button_index=MOUSE_BUTTON_WHEEL_DOWN;event.pressed=true
   root.push_input(event,true)
   event.pressed=false
   root.push_input(event,true)
  await process_frame
  await settle()
  check(ui.scroll.scroll_vertical>0,"mouse wheel scrolls deck content")
  check(ui.balance.global_position==heading,"header stays fixed")
  check(ui.scroll.get_global_rect().intersects(ui.deck_panels.preview_seat.get_global_rect()),"dummy deck can be reached")
  await capture("shop_bottom_"+str(resolution.x))
 ui.scroll.scroll_vertical=0;Session.gold=60;ui._refresh();await settle()
 await click(ui.buttons.remnant)
 check(Session.gold==0 and "remnant" in Session.unlocked,"purchase works once")
 await click(ui.buttons.remnant)
 check(Session.selected=="remnant","unlocked deck can be equipped")
 await click(ui.buttons.starter)
 check(Session.selected=="starter","original deck can be restored")
 await click(ui.back_button)
 check(current_scene.name=="MainMenu","back returns to main")
 root.size=Vector2i(1920,1080);await settle();await capture("main_1920")
 await click(current_scene.action_buttons.book)
 check(current_scene.name=="CardBook","main to card book")
 await click(current_scene.card_buttons.observe)
 await capture("book_1920")
 current_scene._show_owners();await settle();await capture("owners_1920")
 check(current_scene.owner_panel.visible,"deck ownership remains available")
 print("THEATRE_UI_PASS checks=",checks)
 quit()