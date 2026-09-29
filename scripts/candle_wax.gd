extends RefCounted
## Static meshes built once per candle. No animation, lights or per-frame work.
const SEGMENTS: int = 32
const WICK_TIP: float = 0.035
static var wax_material: StandardMaterial3D
static var wick_material: StandardMaterial3D
static var cached_meshes: Dictionary = {}

static func build(parent: Node3D, bounds: AABB, shape_seed: float, index: int) -> Vector3:
	if wax_material == null:
		wax_material = StandardMaterial3D.new()
		wax_material.albedo_color = Color(0.83, 0.71, 0.49)
		wax_material.vertex_color_use_as_albedo = true
		wax_material.roughness = 0.48
		wick_material = StandardMaterial3D.new()
		wick_material.albedo_color = Color(0.075, 0.029, 0.013)
		wick_material.roughness = 0.95
	var root := Node3D.new()
	root.name = "MeltedWax" + str(index)
	root.position = Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	parent.add_child(root)
	var height: float = bounds.size.y
	var radius: float = maxf(bounds.size.x, bounds.size.z) * 0.5
	var key := Vector3(height, radius, shape_seed)
	if not cached_meshes.has(key):
		cached_meshes[key] = _make_mesh(height, radius, shape_seed)
	var wax := MeshInstance3D.new()
	wax.name = "SculptedWax"
	wax.mesh = cached_meshes[key]
	wax.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wax)
	var wick := MeshInstance3D.new()
	wick.name = "CharredWick"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.047
	cylinder.bottom_radius = radius * 0.075
	cylinder.height = 0.095
	cylinder.radial_segments = 8
	cylinder.rings = 1
	wick.mesh = cylinder
	wick.material_override = wick_material
	wick.position = Vector3(0.0, height + WICK_TIP - 0.0475, 0.0)
	wick.rotation.z = 0.10 * sin(shape_seed)
	wick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wick)
	return root.position + wick.transform * Vector3(0.0, 0.0475, 0.0)

static func _rim(angle: float, height: float, shape_seed: float) -> float:
	return height - 0.008 + 0.025 * sin(angle + shape_seed) + 0.012 * sin(3.0 * angle + shape_seed * 1.7) + 0.005 * sin(5.0 * angle - shape_seed)

static func _make_mesh(height: float, radius: float, shape_seed: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(wax_material)
	var rings: Array[PackedVector3Array] = []
	# Rounded body -> thick wavy lip -> inward slope -> recessed wax pool.
	for ring in range(9):
		var points := PackedVector3Array()
		for segment in range(SEGMENTS):
			var angle: float = TAU * float(segment) / float(SEGMENTS)
			var rim: float = _rim(angle, height, shape_seed)
			var y: float = 0.0
			var r: float = radius
			match ring:
				0: y = 0.0; r *= 0.92
				1: y = 0.035; r *= 0.99
				2: y = height * 0.45; r *= 0.99
				3: y = height - 0.09; r *= 1.0
				4: y = rim - 0.017; r *= 1.055
				5: y = rim; r *= 0.98
				6: y = rim - 0.014; r *= 0.78
				7: y = height - 0.058 + 0.005 * sin(angle + shape_seed); r *= 0.45
				8: y = height - 0.063; r = 0.0
			if ring > 2:
				r *= 1.0 + 0.035 * sin(angle * 3.0 + shape_seed)
			points.append(Vector3(cos(angle) * r, y, sin(angle) * r))
		rings.append(points)
	for ring in range(8):
		var color := Color(1.0, 0.98, 0.91) if ring >= 4 else Color(0.94, 0.95, 0.94)
		for segment in range(SEGMENTS):
			var next: int = (segment + 1) % SEGMENTS
			_quad(st, rings[ring][segment], rings[ring][next], rings[ring+1][next], rings[ring+1][segment], color)
	# Five asymmetrical wax runs, attached to the rim and ending in rounded droplets.
	for drip in range(5):
		var angle: float = TAU * float(drip) / 5.0 + shape_seed * 0.67 + 0.17 * sin(float(drip) * 4.3 + shape_seed)
		var length: float = height * (0.16 + 0.39 * (0.5 + 0.5 * sin(shape_seed * 2.3 + float(drip) * 3.7)))
		var width: float = radius * (0.13 + 0.06 * (0.5 + 0.5 * sin(float(drip) + shape_seed)))
		var rows: Array[PackedVector3Array] = []
		for row in range(8):
			var u: float = [0.0, 0.18, 0.38, 0.60, 0.80, 0.93, 0.98, 1.0][row]
			var bend: float = angle + 0.05 * sin(u * PI + shape_seed)
			var radial := Vector3(cos(bend), 0.0, sin(bend))
			var tangent := Vector3(-sin(bend), 0.0, cos(bend))
			var center := radial * radius * (1.015 + 0.020 * sin(u * PI))
			center.y = _rim(angle, height, shape_seed) - 0.021 - u * length
			var thickness: float = width * (0.82 + 0.22 * sin(u * 5.0))
			if row == 0: thickness *= 1.3
			if row == 5: thickness *= 1.05
			if row == 6: thickness *= 0.64
			if row == 7: thickness = 0.001
			var points := PackedVector3Array()
			for segment in range(8):
				var phi: float = TAU * float(segment) / 8.0
				points.append(center + tangent * cos(phi) * thickness + radial * sin(phi) * thickness * 0.70)
			rows.append(points)
		for row in range(7):
			for segment in range(8):
				var next: int = (segment + 1) % 8
				_quad(st, rows[row][segment], rows[row][next], rows[row+1][next], rows[row+1][segment], Color(1.0, 0.98, 0.94))
	st.generate_normals()
	st.index()
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	st.set_color(color)
	for point in [a,b,c,a,c,d]:
		st.add_vertex(point)
