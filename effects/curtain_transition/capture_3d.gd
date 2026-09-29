extends SceneTree
const OUT = "C:/Users/user/Documents/ChatGPT/린코/curtain-webp/contact_frames/"
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var background := ColorRect.new()
 background.color = Color("171013")
 background.size = Vector2(1920,1080)
 root.add_child(background)
 var curtain = load("res://effects/curtain_transition/curtain_transition.tscn").instantiate()
 root.add_child(curtain)
 curtain.play()
 curtain.set_process(false)
 DirAccess.make_dir_recursive_absolute(OUT)
 for i in range(96):
  if curtain.busy:
   curtain._process(1.0/30.0)
  if FileAccess.file_exists(OUT + "%03d.png" % i):
   continue
  await process_frame
  RenderingServer.force_draw(false)
  var image := root.get_texture().get_image()
  image.resize(960,540)
  image.save_png(OUT + "%03d.png" % i)
 print("PHYSICS_CAPTURE_PASS")
 quit()



