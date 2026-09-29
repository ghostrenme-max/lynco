extends SceneTree
const BASE = "res://effects/curtain_transition/"
const OUTPUT = "C:/Users/user/Documents/ChatGPT/린코/curtain-webp/"
var failures: int = 0
var covers: int = 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(20.0).timeout.connect(func(): push_error("CURTAIN TEST TIMEOUT"); quit(1))
	change_scene_to_file(BASE + "demo.tscn")
	await scene_changed
	await process_frame
	await process_frame
	var curtain := root.get_node("CurtainTransition")
	assert(not curtain.busy and not curtain.visible and not curtain.is_processing())
	curtain.transition_failed.connect(func(_message): failures += 1)
	curtain.covered.connect(func(): covers += 1)
	assert(curtain.transition_to("res://missing_curtain_scene.tscn") == ERR_FILE_NOT_FOUND)
	assert(not curtain.busy and failures == 1)
	assert(curtain.play() == OK)
	assert(curtain.play() == ERR_BUSY)
	await create_timer(0.40).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "runtime_moving.png")
	await curtain.covered
	assert(current_scene.scene_file_path == BASE + "demo.tscn")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "runtime_closed.png")
	await curtain.transition_finished
	assert(covers == 1 and not curtain.visible and not curtain.is_processing())
	assert(not curtain.is_processing_input())
	# Resize, then actually change scenes behind the persistent overlay.
	root.size = Vector2i(1280, 720)
	await process_frame
	var expected := root.get_visible_rect().size / Vector2(1920, 1080)
	assert(curtain.get_node("Curtains").scale.is_equal_approx(expected))
	assert(curtain.transition_to(BASE + "demo_next.tscn") == OK)
	assert(curtain.transition_to(BASE + "demo.tscn") == ERR_BUSY)
	await curtain.covered
	assert(current_scene.scene_file_path == BASE + "demo.tscn")
	await curtain.transition_finished
	assert(current_scene.scene_file_path == BASE + "demo_next.tscn")
	assert(root.get_node("CurtainTransition") == curtain)
	assert(covers == 2 and failures == 1 and not curtain.busy)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "runtime_revealed.png")
	# The overlay remains usable while the game is paused.
	paused = true
	assert(curtain.play() == OK)
	await curtain.transition_finished
	assert(covers == 3 and not curtain.is_processing())
	paused = false
	print("CURTAIN_RUNTIME_PASS: idle off, duplicate rejection, missing scene recovery, coverage, threaded scene switch, persistence, resize, paused playback")
	quit()
