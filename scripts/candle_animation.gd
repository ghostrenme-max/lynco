extends Node3D
## Visual-only animation: independent of the gameplay RNG.
const FLAME_SCENE: PackedScene = preload("res://effects/second_flame/flame_3d.tscn")
const WAX_DETAILS = preload("res://scripts/candle_wax.gd")
const LIGHT_BASE: float = 1.10
const GLOW_BASE: float = 0.58
var elapsed: float = 0.0
var phase: float = 0.0
var pool: OmniLight3D
var flames: Array[Node3D] = []
var flame_materials: Array[ShaderMaterial] = []
var flame_speeds: PackedFloat32Array = PackedFloat32Array()
var flame_phases: PackedFloat32Array = PackedFloat32Array()
var lighting_elapsed: float = 0.0
const LIGHT_UPDATE_INTERVAL: float = 1.0 / 30.0

func setup(light: OmniLight3D, offset: float) -> void:
	pool = light
	phase = offset
	# Remove the imported static flames and any prior procedural instances.
	for child in find_children("Flame*", "MeshInstance3D", true, false):
		child.free()
	for child in find_children("LivingFlame*", "Node3D", true, false):
		child.free()
	for child in find_children("MeltedWax*", "Node3D", true, false):
		child.free()
	flames.clear()
	flame_materials.clear()
	flame_speeds.clear()
	flame_phases.clear()
	lighting_elapsed = 0.0
	var candles := find_children("Ivory candle*", "MeshInstance3D", true, false)
	candles.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	# Change wax height only, keeping each candle foot and diameter fixed.
	var height_factors: Array = [1.35, 1.0, 0.68] if is_zero_approx(offset) else [0.98, 1.02, 1.0]
	for index in range(candles.size()):
		var candle := candles[index] as MeshInstance3D
		if not candle.has_meta("original_transform"):
			candle.set_meta("original_transform", candle.transform)
		candle.transform = candle.get_meta("original_transform")
		var bounds: AABB = candle.transform * candle.get_aabb()
		var factor: float = height_factors[index % height_factors.size()]
		_scale_wax_height(candle, bounds.position.y, factor)
		for drip in find_children("Wax drip*", "MeshInstance3D", true, false):
			if not drip.has_meta("original_transform"):
				drip.set_meta("original_transform", drip.transform)
			var original: Transform3D = drip.get_meta("original_transform")
			var drip_bounds: AABB = original * drip.get_aabb()
			if absf(drip_bounds.get_center().x - bounds.get_center().x) < bounds.size.x:
				drip.transform = original
				_scale_wax_height(drip, bounds.position.y, factor)
	for index in range(candles.size()):
		var candle := candles[index] as MeshInstance3D
		var relative := global_transform.affine_inverse() * candle.global_transform
		var bounds: AABB = relative * candle.get_aabb()
		candle.hide()
		var wick_anchor: Vector3 = WAX_DETAILS.build(self, bounds, offset * 1.31 + float(index) * 2.37 + 0.4, index)
		candle.set_meta("wick_anchor", wick_anchor)
		var diameter: float = maxf(bounds.size.x, bounds.size.z)
		# Visible body is ~0.9 units wide and 1.5 units tall on the stock 2x2 quad.
		var flame_width: float = diameter * 1.25
		var flame_height: float = bounds.size.y * 0.9
		var flame := FLAME_SCENE.instantiate() as Node3D
		flame.name = "LivingFlame" + str(index)
		flame.position = wick_anchor
		flame.scale = Vector3(flame_width / 0.9, flame_height / 1.5, 1.0)
		flame.set("phase", offset * 2.73 + float(index) * 7.31)
		flame.set("speed", 3.5 + 0.32 * sin(float(index) * 2.13 + offset * 1.71 + 0.4))
		flame.set("playing", false)
		add_child(flame)
		var surface := flame.get_node("Surface") as MeshInstance3D
		# Offset vertices in billboard space, not world space: the base stays on the wick.
		surface.position = Vector3.ZERO
		var material := surface.material_override as ShaderMaterial
		material.set_shader_parameter("vertical_anchor", 0.765)
		material.set_shader_parameter("intensity", 0.86)
		material.set_shader_parameter("glow_strength", GLOW_BASE)
		surface.custom_aabb = AABB(Vector3(-1.1, -0.3, -1.1), Vector3(2.2, 2.2, 2.2))
		flame.call("seek", elapsed * float(flame.get("speed")))
		flames.append(flame)
		flame_materials.append(material)
		flame_speeds.append(float(flame.get("speed")))
		flame_phases.append(float(flame.get("phase")))
		# This controller owns animation; avoid six idle script callbacks each frame.
		flame.set_process(false)
	for drip in find_children("Wax drip*", "MeshInstance3D", true, false):
		drip.hide()
	if is_instance_valid(pool):
		pool.light_energy = LIGHT_BASE
	if not visibility_changed.is_connected(_refresh_processing):
		visibility_changed.connect(_refresh_processing)
	_refresh_processing()

func _refresh_processing() -> void:
	set_process(is_visible_in_tree())

func _scale_wax_height(wax: Node3D, base_y: float, factor: float) -> void:
	var stretch := Transform3D(Basis.from_scale(Vector3(1.0, factor, 1.0)), Vector3(0.0, base_y * (1.0 - factor), 0.0))
	wax.transform = stretch * wax.transform

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	elapsed += delta
	# Keep flame motion at render rate; cache resources instead of resolving nodes/properties.
	for index in range(flame_materials.size()):
		flame_materials[index].set_shader_parameter("flame_time", elapsed * flame_speeds[index] + flame_phases[index])
	# The slow lighting wiggle does not need render-rate updates.
	lighting_elapsed += delta
	if lighting_elapsed < LIGHT_UPDATE_INTERVAL:
		return
	lighting_elapsed = fmod(lighting_elapsed, LIGHT_UPDATE_INTERVAL)
	var wiggle: float = _light_wiggle(elapsed, phase)
	for index in range(flame_materials.size()):
		var local_wiggle: float = _light_wiggle(elapsed, flame_phases[index] + 9.0)
		flame_materials[index].set_shader_parameter("intensity", 0.86 * (1.0 + wiggle * 0.25 + local_wiggle * 0.15))
		flame_materials[index].set_shader_parameter("glow_strength", GLOW_BASE * (1.0 + wiggle + local_wiggle * 0.25))
	if is_instance_valid(pool):
		pool.light_energy = LIGHT_BASE * (1.0 + wiggle)

func _light_wiggle(time: float, noise_seed: float) -> float:
	# Slow breathing with small, quicker fluctuations; bounded to +/-10.7%.
	return 0.07 * _smooth_noise(time * 0.85, noise_seed) + 0.025 * _smooth_noise(time * 2.3, noise_seed + 31.0) + 0.012 * _smooth_noise(time * 5.7, noise_seed + 79.0)

func _smooth_noise(time: float, noise_seed: float) -> float:
	var cell: float = floorf(time)
	var weight: float = smoothstep(0.0, 1.0, time - cell)
	var first: float = fposmod(sin(cell * 127.1 + noise_seed * 311.7 + 5.0) * 43758.5453, 1.0) * 2.0 - 1.0
	var second: float = fposmod(sin((cell + 1.0) * 127.1 + noise_seed * 311.7 + 5.0) * 43758.5453, 1.0) * 2.0 - 1.0
	return lerpf(first, second, weight)
