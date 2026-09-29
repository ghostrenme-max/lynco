extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1280,720)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 change_scene_to_file("res://scenes/battle.tscn");await scene_changed
 var ui=current_scene.get_node("Interface")
 while ui.busy:await process_frame
 ui.stage.hide()
 var pile=ui.table.get_node("GarnetCubes")
 ui.table.camera.global_transform=Transform3D(Basis.IDENTITY,Vector3(8.3,6,12)).looking_at(Vector3(8.3,1,6))
 var results:Array=[]
 for count in [30,100,300]:
  pile.visual_rng.seed=94721
  pile.reset_count(count)
  await create_timer(5).timeout
  var times:Array[float]=[]
  var last:int=Time.get_ticks_usec()
  for frame in range(90):
   await process_frame
   var now:int=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
  times.sort()
  var record={"count":count,"median_frame_ms":times[45],"p95_frame_ms":times[85],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0}
  results.append(record);print(record)
 var label:String="optimized" if "--optimized" in OS.get_cmdline_user_args() else "baseline"
 var file:=FileAccess.open("res://test-results/cube-benchmark-"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify(results," "))
 quit()
