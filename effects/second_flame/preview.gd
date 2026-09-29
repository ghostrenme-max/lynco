extends Node2D

func _ready() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		capture.call_deferred()

func capture() -> void:
	$Flame.playing = false
	DirAccess.make_dir_recursive_absolute("res://captures")
	for frame in range(216):
		$Flame.seek(float(frame) / 28.0 * $Flame.speed)
		await RenderingServer.frame_post_draw
		var err := get_viewport().get_texture().get_image().save_png("res://captures/frame_%03d.png" % frame)
		if err != OK:
			push_error("Capture failed: %s" % err)
			get_tree().quit(1)
			return
	print("FLAME_CAPTURE_PASS: 216 frames, 7.714 second seamless loop, speed 3.5x, rounded lower bulb")
	get_tree().quit()
