extends SceneTree
const OUTPUT = "C:/Users/user/Documents/ChatGPT/린코/flame-effect/integration/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://scenes/battle.tscn")
	await scene_changed
	var ui := current_scene.get_node("Interface")
	while ui.busy or ui.views.is_empty():
		await process_frame
	await create_timer(1.0).timeout
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world := current_scene.get_node("TableWorld")
	var room := world.get_node("TheatreRoom")
	var flames := room.find_children("LivingFlame*", "Node3D", true, false)
	var groups: Array[Node] = []
	for child in room.get_children():
		if child.get_script() == load("res://scripts/candle_animation.gd"):
			groups.append(child)
	var results: Array = []
	for view in ["game", "close"]:
		if view == "close":
			ui.stage.hide()
			world.camera.position = Vector3(-11.0,3.5,-0.5)
			world.camera.look_at(Vector3(-13.1,1.6,-6.0))
		for repeat in range(3):
			for enabled in ([true,false] if repeat%2==0 else [false,true]):
				for flame in flames:
					flame.visible = enabled
				for group in groups:
					group.set_process(enabled)
					group.pool.visible = enabled
				for i in range(30):
					await process_frame
				var times: Array[float] = []
				var last := Time.get_ticks_usec()
				for i in range(150):
					await process_frame
					var now := Time.get_ticks_usec()
					times.append(float(now-last)/1000.0)
					last = now
				var average: float = 0.0
				for time in times:
					average += time/float(times.size())
				times.sort()
				var result := {"view":view,"enabled":enabled,"repeat":repeat,"mean_ms":average,"median_ms":times[75],"p95_ms":times[142]}
				results.append(result)
				print("BENCH ",JSON.stringify(result))
	var tag := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var file := FileAccess.open(OUTPUT+"benchmark_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	print("BENCHMARK_PASS ", tag, " resolution=",root.size)
	quit()

