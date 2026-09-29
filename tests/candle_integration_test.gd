extends SceneTree
const OUTPUT = "C:/Users/user/Documents/ChatGPT/린코/flame-effect/integration/"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(45.0).timeout.connect(func(): quit(1))
	change_scene_to_file("res://scenes/battle.tscn")
	await scene_changed
	for i in range(15):
		await process_frame
	var world := current_scene.get_node("TableWorld") as Node3D
	var room := world.get_node("TheatreRoom") as Node3D
	var groups: Array = []
	for child in room.get_children():
		if child.get_script() == load("res://scripts/candle_animation.gd"):
			groups.append(child)
	assert(groups.size() == 2)
	assert(room.find_children("MeltedWax*", "Node3D", true, false).size() == 6)
	assert(room.find_children("CharredWick", "MeshInstance3D", true, false).size() == 6)
	for wax in room.find_children("SculptedWax", "MeshInstance3D", true, false):
		assert(wax.mesh.get_surface_count() == 1)
		assert(wax.mesh.surface_get_array_len(0) < 5000)
	for old in room.find_children("Ivory candle*", "MeshInstance3D", true, false):
		assert(not old.visible)
	for old in room.find_children("Wax drip*", "MeshInstance3D", true, false):
		assert(not old.visible)
	for group in groups:
		var minimum: float = INF
		var maximum: float = -INF
		var previous_energy: float = -1.0
		for sample in range(240):
			group._process(1.0 / 30.0)
			var energy: float = group.pool.light_energy
			minimum = minf(minimum, energy)
			maximum = maxf(maximum, energy)
			assert(energy > 0.98 and energy < 1.22, "Light flicker out of bounds")
			if previous_energy > 0.0:
				assert(absf(energy - previous_energy) < 0.025, "Light changed abruptly")
			previous_energy = energy
		assert(maximum - minimum > 0.035, "Light does not visibly vary")
		print("LIGHT_WIGGLE_RANGE ", minimum, "..", maximum)
	for group in groups:
		var waxes: Array[Node] = group.find_children("Ivory candle*", "MeshInstance3D", true, false)
		waxes.sort_custom(func(a: Node,b: Node) -> bool: return String(a.name)<String(b.name))
		var heights: Array[float] = []
		for wax in waxes:
			var original: Transform3D = wax.get_meta("original_transform")
			var previous: AABB = original * wax.get_aabb()
			var resized: AABB = wax.transform * wax.get_aabb()
			assert(is_equal_approx(previous.position.y,resized.position.y), "Wax foot moved")
			assert(is_equal_approx(previous.size.x,resized.size.x), "Wax diameter changed")
			heights.append(resized.size.y)
		if is_zero_approx(group.phase):
			assert(heights[0]>heights[1] and heights[1]>heights[2])
		else:
			assert(heights.max()/heights.min()<1.05)
		print("WAX_HEIGHTS offset=",group.phase," lengths=",heights)
	var flames := room.find_children("LivingFlame*", "Node3D", true, false)
	assert(flames.size() == 6, "Expected six candle flames")
	assert(room.find_children("Flame*", "MeshInstance3D", true, false).is_empty(), "Old static flames remain")
	var materials: Array = []
	var speeds: Array = []
	var phases: Array = []
	for flame in flames:
		var surface := flame.get_node("Surface") as MeshInstance3D
		var mat := surface.material_override as ShaderMaterial
		assert(not materials.has(mat), "Shared flame material")
		materials.append(mat)
		assert(not speeds.has(flame.speed), "Shared speed")
		assert(not phases.has(flame.phase), "Shared phase")
		speeds.append(flame.speed)
		phases.append(flame.phase)
		assert(surface.position == Vector3.ZERO)
		assert(is_equal_approx(mat.get_shader_parameter("vertical_anchor"), 0.765))
		var candles := flame.get_parent().find_children("Ivory candle*", "MeshInstance3D", true, false)
		var matching := false
		for candle in candles:
			var relative: Transform3D = flame.get_parent().global_transform.affine_inverse() * candle.global_transform
			var bounds: AABB = relative * candle.get_aabb()
			var tip: Vector3 = candle.get_meta("wick_anchor")
			if flame.position.distance_to(tip) < 0.0001:
				assert(is_equal_approx(flame.scale.y * 1.5, bounds.size.y * 0.9))
				assert(is_equal_approx(flame.scale.x * 0.9, maxf(bounds.size.x,bounds.size.z)*1.25))
				matching = true
		assert(matching, "Flame is not on a candle tip")
		print("CANDLE ", flame.get_path(), " scale=", flame.scale, " speed=", flame.speed, " phase=", flame.phase)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "ingame.png")
	# Confirm visibility transitions stop visual time without changing game state.
	var controller := flames[0].get_parent()
	room.hide()
	var before: float = controller.elapsed
	await process_frame
	await process_frame
	assert(is_equal_approx(controller.elapsed, before))
	room.show()
	await process_frame
	await process_frame
	assert(controller.elapsed > before)
	# Reinitializing the decoration must replace, not stack, effects.
	var sizes: Array = []
	for candle in controller.find_children("Ivory candle*", "MeshInstance3D", true, false):
		sizes.append(candle.transform)
	controller.setup(controller.pool, controller.phase)
	assert(room.find_children("MeltedWax*", "Node3D", true, false).size() == 6)
	var wax_after := controller.find_children("Ivory candle*", "MeshInstance3D", true, false)
	for i in range(wax_after.size()):
		assert(wax_after[i].transform == sizes[i], "Repeated setup compounded height")
	assert(room.find_children("LivingFlame*", "Node3D", true, false).size() == 6)
	current_scene.get_node("Interface").hide()
	current_scene.get_node("Interface").stage.hide()
	var camera: Camera3D = world.camera
	camera.position = Vector3(-11.0, 3.5, -0.5)
	camera.look_at(Vector3(-13.1, 1.6, -6.0))
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "candle_closeup.png")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(OUTPUT + "soft_light")
		for group in groups:
			group.set_process(false)
		for frame in range(84):
			for group in groups:
				group._process(1.0 / 28.0)
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			picture.save_png(OUTPUT + "soft_light/frame_%03d.png" % frame)
	camera.position = Vector3(-12.0, 6.5, -4.0)
	camera.look_at(Vector3(-13.1, 1.6, -6.0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "candle_high_angle.png")
	camera.position = Vector3(11.0, 3.5, -0.5)
	camera.look_at(Vector3(13.1, 1.6, -6.0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "candle_right.png")
	camera.position = Vector3(-13.1, 2.9, -3.4)
	camera.look_at(Vector3(-13.1, 1.85, -6.0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + "wax_detail.png")
	print("CANDLE_INTEGRATION_PASS: six effects, no old flames, proportional size, independent phases/speeds/materials, wick anchors, visibility and repeat setup")
	quit()

