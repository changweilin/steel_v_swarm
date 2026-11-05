class_name SceneDamageGeometry
extends RefCounted

var stage := -1
var parts: Array[Dictionary] = []
var bindings: Array[Dictionary] = []
var colours: Dictionary = {}
var material_copies: Dictionary = {}
var cracks: MeshInstance3D
var root: Node3D
var cached_nodes: Array[GeometryInstance3D] = []
var collected := false
var captured := false

static func health_stage(hp: float, maximum: float, collapsed: bool = false) -> int:
	if collapsed:
		return 3
	if not is_finite(hp) or not is_finite(maximum) or maximum <= 0:
		return 0
	if hp <= 0:
		return 3
	var thresholds: Dictionary = Content.balance.destruction.damageThresholds
	return 2 if hp <= maximum * float(thresholds.HEAVY_F) else 1 if hp <= maximum * float(thresholds.LIGHT_F) else 0

func apply(target: Node3D, kind: String, id: int, dimensions: Dictionary, destination: int, neutral: bool = false) -> bool:
	var profile: Dictionary = Content.balance.destruction.sceneProfiles.get(kind, {})
	if profile.is_empty() or profile.get("mobile", false) or destination == stage:
		return false
	if root != null and root != target:
		push_error("Scene damage geometry cannot be rebound to another model")
		return false
	stage = destination
	root = target
	if not collected:
		_collect(target)
		collected = true
	if destination == 0 and not captured:
		return true
	if not captured:
		var seen := {}
		_capture(target, seen)
		if neutral:
			_capture_aliases(target, seen)
		captured = true
	var strength := 0.0 if destination == 0 else .45 if destination == 1 else 1.0
	var tint := Color.hex((int(profile.color) << 8) | 0xff).srgb_to_linear()
	for material: Material in colours:
		var original: Color = colours[material]
		var colour := original.lerp(tint, strength * .55) * (1 - strength * .22)
		colour.a = original.a
		if material is ShaderMaterial:
			# Vertex-colour cel surfaces keep their state in uSourceAlbedo, not albedo_color.
			(material as ShaderMaterial).set_shader_parameter("uSourceAlbedo", colour.linear_to_srgb())
		else:
			(material as BaseMaterial3D).albedo_color = colour.linear_to_srgb()
	var radius := maxf(1, float(dimensions.radius))
	var height := maxf(1, float(dimensions.height))
	for part: Dictionary in parts:
		var positions := PackedVector3Array()
		for original: Vector3 in part.original:
			var point := _transform(part.frame, [original.x, original.y, original.z])
			var upper := clampf(float(point[1]) / height, 0, 1)
			var fold := maxf(0, sin(float(point[0]) / radius * 5 + float(point[2]) / radius * 4 + id))
			var dent := strength * float(profile.dent) * fold * upper
			point = _transform(part.inverse, [point[0] * (1 - dent), point[1] * (1 - dent), point[2] * (1 - dent * .7)])
			positions.append(Vector3(point[0], point[1], point[2]))
		part.positions = positions
		part.normals = part.original_normals if part.outline else _normals(positions, part.indices, part.indexed)
	for binding: Dictionary in bindings:
		_rebuild(binding)
	_update_cracks(destination)
	return true

func _collect(node: Node3D) -> void:
	if ViewOcclusion._geometry(node) != null and not node.get_meta("teamRing", false) and not node.get_meta("weatherScorch", false):
		cached_nodes.append(node as GeometryInstance3D)
	for child: Node in node.get_children():
		if child is Node3D:
			_collect(child)

func _capture(_target: Node3D, seen: Dictionary) -> void:
	for candidate: Variant in cached_nodes:
		if is_instance_valid(candidate):
			_capture_node(candidate as GeometryInstance3D, seen)

func _capture_node(node: GeometryInstance3D, seen: Dictionary) -> void:
	var geometry := ViewOcclusion._geometry(node)
	if geometry != null:
		var key: Variant = geometry.get_meta("source_geometry_id", geometry.get_instance_id())
		if not seen.has(key):
			var arrays := geometry.surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var topology := source_indices(geometry)
			var frame := root.global_transform.affine_inverse() * node.global_transform
			seen[key] = parts.size()
			parts.append({"original": positions, "original_normals": arrays[Mesh.ARRAY_NORMAL], "indices": topology.indices,
				"indexed": topology.indexed, "frame": frame, "inverse": frame.affine_inverse(), "outline": node.get_meta("isOutline", false)})
		var surfaces: Array = []
		var materials: Array[Material] = []
		for surface in range(geometry.get_surface_count()):
			surfaces.append(geometry.surface_get_arrays(surface))
			var original := ViewOcclusion._material(node as GeometryInstance3D, surface)
			if original is BaseMaterial3D:
				if not material_copies.has(original):
					var copy := original.duplicate() as BaseMaterial3D
					material_copies[original] = copy
					colours[copy] = original.albedo_color.srgb_to_linear()
				materials.append(material_copies[original])
			elif original is ShaderMaterial and original.get_shader_parameter("uSourceAlbedo") is Color:
				if not material_copies.has(original):
					var copy := original.duplicate() as ShaderMaterial
					material_copies[original] = copy
					colours[copy] = (original.get_shader_parameter("uSourceAlbedo") as Color).srgb_to_linear()
				materials.append(material_copies[original])
			else:
				materials.append(original)
		bindings.append({"node": node, "part": seen[key], "surfaces": surfaces, "materials": materials, "original": geometry})

func _capture_aliases(node: Node3D, seen: Dictionary) -> void:
	# Source neutral models own their resources; retain aliases inside this instance.
	var geometry := ViewOcclusion._geometry(node)
	if geometry != null and not cached_nodes.has(node):
		var key: Variant = geometry.get_meta("source_geometry_id", geometry.get_instance_id())
		var surfaces: Array = []
		var materials: Array[Material] = []
		for surface in range(geometry.get_surface_count()):
			surfaces.append(geometry.surface_get_arrays(surface))
			var original := ViewOcclusion._material(node as GeometryInstance3D, surface)
			materials.append(material_copies.get(original, original))
		bindings.append({"node": node, "part": seen.get(key, -1), "surfaces": surfaces, "materials": materials, "original": geometry})
	for child: Node in node.get_children():
		if child is Node3D:
			_capture_aliases(child, seen)

func _rebuild(binding: Dictionary) -> void:
	if not is_instance_valid(binding.node):
		return
	var node: GeometryInstance3D = binding.node
	var mesh := ArrayMesh.new()
	mesh.set_meta("source_custom_attributes", (binding.original as Mesh).get_meta("source_custom_attributes", {}))
	if (binding.original as Mesh).has_meta("source_cel_geometry"):
		mesh.set_meta("source_cel_geometry", (binding.original as Mesh).get_meta("source_cel_geometry"))
	for surface in range(binding.surfaces.size()):
		var arrays: Array = binding.surfaces[surface].duplicate()
		if int(binding.part) >= 0:
			var part: Dictionary = parts[int(binding.part)]
			arrays[Mesh.ARRAY_VERTEX] = part.positions
			arrays[Mesh.ARRAY_NORMAL] = part.normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, binding.materials[surface])
	if node is MeshInstance3D:
		node.mesh = mesh
		for surface in range(mesh.get_surface_count()):
			node.set_surface_override_material(surface, binding.materials[surface])
	else:
		var batch := node as MultiMeshInstance3D
		var instances := batch.multimesh.duplicate() as MultiMesh
		instances.mesh = mesh
		batch.multimesh = instances
	if node.material_override != null and binding.materials.size() > 0:
		node.material_override = binding.materials[0]

func _update_cracks(destination: int) -> void:
	if cracks == null:
		cracks = MeshInstance3D.new()
		cracks.name = "SceneDamageCracks"
		cracks.set_meta("noOutline", true)
		cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.hex(0x211b18ff)
		material.albedo_color.a = .9
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		cracks.material_override = material
		root.add_child(cracks)
	cracks.visible = destination > 0
	if destination == 0:
		return
	var faces: Array[Dictionary] = []
	for part: Dictionary in parts:
		if part.outline:
			continue
		var positions: PackedVector3Array = part.positions
		var indices: PackedInt32Array = part.indices
		for offset in range(0, indices.size() - 2, 3):
			var points: Array = []
			for corner in range(3):
				var point := positions[indices[offset + corner]]
				points.append(_transform(part.frame, [point.x, point.y, point.z]))
			var normal := _cross(_subtract(points[1], points[0]), _subtract(points[2], points[0]))
			var area := sqrt(normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2])
			if area < .08 or normal[1] / area < -.4:
				continue
			faces.append({"points": points, "normal": [normal[0] / area, normal[1] / area, normal[2] / area], "area": area, "order": faces.size()})
	faces.sort_custom(func(a, b): return a.order < b.order if a.area == b.area else a.area > b.area)
	var lines := PackedVector3Array()
	for face: Dictionary in faces.slice(0, 14 if destination == 1 else 32):
		var points: Array = face.points
		var previous := Vector3.ZERO
		for weights: Array in [[.7, .2], [.42, .34], [.36, .19], [.12, .33]]:
			var point := Vector3.ZERO
			for axis in range(3):
				point[axis] = points[0][axis] * weights[0] + points[1][axis] * weights[1] + points[2][axis] * (1 - weights[0] - weights[1]) + face.normal[axis] * .015
			if weights != [.7, .2]:
				lines.append_array(PackedVector3Array([previous, point]))
			previous = point
	var mesh := ArrayMesh.new()
	if not lines.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lines
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	cracks.mesh = mesh

static func source_indices(geometry: Mesh) -> Dictionary:
	var indices := PackedInt32Array()
	var indexed := bool(geometry.get_meta("source_indexed", true))
	if geometry.has_meta("source_indices"):
		indices = PackedInt32Array(geometry.get_meta("source_indices"))
	else:
		# Imported glTF surfaces retain Godot's reversed triangle winding.
		for surface in range(geometry.get_surface_count()):
			var native: PackedInt32Array = geometry.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			for offset in range(0, native.size(), 3):
				indices.append_array(PackedInt32Array([native[offset], native[offset + 2], native[offset + 1]]))
		indexed = not indices.is_empty()
	if indices.is_empty():
		indices = PackedInt32Array(range(geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()))
	return {"indices": indices, "indexed": indexed}

static func _normals(positions: PackedVector3Array, indices: PackedInt32Array, indexed: bool) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(positions.size())
	for offset in range(0, indices.size() - 2, 3):
		var a := positions[indices[offset]]
		var b := positions[indices[offset + 1]]
		var c := positions[indices[offset + 2]]
		var cross := _cross([c.x - b.x, c.y - b.y, c.z - b.z], [a.x - b.x, a.y - b.y, a.z - b.z])
		for corner in range(3):
			var vertex := indices[offset + corner]
			var previous := normals[vertex] if indexed else Vector3.ZERO
			normals[vertex] = Vector3(float(previous.x) + cross[0], float(previous.y) + cross[1], float(previous.z) + cross[2])
	for index in range(normals.size()):
		normals[index] = SourceQuaternion.vector_normalized(normals[index])
	return normals

static func _transform(frame: Transform3D, point: Array) -> Array:
	return [float(frame.basis.x.x) * point[0] + float(frame.basis.y.x) * point[1] + float(frame.basis.z.x) * point[2] + frame.origin.x,
		float(frame.basis.x.y) * point[0] + float(frame.basis.y.y) * point[1] + float(frame.basis.z.y) * point[2] + frame.origin.y,
		float(frame.basis.x.z) * point[0] + float(frame.basis.y.z) * point[1] + float(frame.basis.z.z) * point[2] + frame.origin.z]

static func _subtract(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]

static func _cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
