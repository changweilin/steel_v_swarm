class_name MissileViewRay
extends RefCounted

var parts: Array[Dictionary] = []

func configure(source: Array) -> void:
	for part: Dictionary in source:
		var vertices := PackedVector3Array()
		for index in range(0, part.positions.size(), 3):
			vertices.append(Vector3(part.positions[index], part.positions[index + 1], part.positions[index + 2]))
		parts.append({"node": int(part.node), "vertices": vertices, "indices": PackedInt32Array(part.indices), "side": int(part.side)})

static func candidate(origin: Vector3, direction: Vector3, far: float, point: Vector3) -> bool:
	var radius := float(Content.balance.missile.presentation.rayRadius)
	var offset := point - origin
	var along := offset.dot(direction)
	if along < -radius or along > far + radius:
		return false
	along = clampf(along, 0, far)
	return (offset - direction * along).length_squared() <= radius * radius

func intersect(view: MissilePresentation, start: Vector3, end: Vector3) -> Dictionary:
	var length := start.distance_to(end)
	if length <= 0 or not candidate(start, (end - start) / length, length, view.global_position):
		return {}
	var hit := {}
	for part: Dictionary in parts:
		var node: Node3D = view.model.nodes.get(int(part.node))
		if node == null:
			push_error("Missile ray geometry lost its captured animation node")
			return {}
		hit = nearer(start, hit, _part(node.global_transform, part.vertices, part.indices, int(part.side), start, end))
	if view.damage_fx.node != null:
		hit = nearer(start, hit, _damage(view.damage_fx.node, start, end))
	if not hit.is_empty():
		hit.missile = view.missile_id
		hit.visual = true
	return hit

static func nearer(start: Vector3, first: Dictionary, second: Dictionary) -> Dictionary:
	if second.is_empty():
		return first
	if first.is_empty() or start.distance_squared_to(second.position) < start.distance_squared_to(first.position):
		return second
	return first

static func _damage(root: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	var hit := {}
	if root is MeshInstance3D and root.get_meta("source_ray_mesh", true):
		var mesh := root as MeshInstance3D
		if mesh.mesh == null:
			return hit
		for surface in range(mesh.mesh.get_surface_count()):
			# Only ArrayMesh exposes a primitive type; PrimitiveMesh surfaces are always triangles.
			if mesh.mesh is ArrayMesh:
				if (mesh.mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
					continue
			elif not mesh.mesh is PrimitiveMesh:
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			# Imported/native meshes reverse the source's front-face winding.
			var source_indices := PackedInt32Array()
			for index in range(0, indices.size(), 3):
				source_indices.append_array([indices[index], indices[index + 2], indices[index + 1]])
			hit = nearer(start, hit, _part(mesh.global_transform, vertices, source_indices, int(mesh.get_meta("source_ray_side", 0)), start, end))
	for child: Node in root.get_children():
		if child is Node3D:
			hit = nearer(start, hit, _damage(child, start, end))
	return hit

static func _part(frame: Transform3D, vertices: PackedVector3Array, indices: PackedInt32Array, side: int, start: Vector3, end: Vector3) -> Dictionary:
	if frame.basis.determinant() == 0:
		return {}
	var inverse := frame.affine_inverse()
	var origin := inverse * start
	var direction := inverse * end - origin
	var nearest := INF
	for index in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + (2 if side == 1 else 1)]]
		var c := vertices[indices[index + (1 if side == 1 else 2)]]
		var time := triangle(origin, direction, a, b, c, side != 2)
		if time >= 0 and time <= 1 and time < nearest:
			nearest = time
	return {"position": start + (end - start) * nearest} if is_finite(nearest) else {}

static func triangle(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, c: Vector3, cull: bool) -> float:
	# Preserve source material-side and exact-zero gates for hidden/transparent mesh parts.
	var edge1 := b - a
	var edge2 := c - a
	var normal := edge1.cross(edge2)
	var denominator := direction.dot(normal)
	var sign_value := 1.0
	if denominator > 0:
		if cull:
			return -1
	elif denominator < 0:
		sign_value = -1.0
		denominator = -denominator
	else:
		return -1
	var difference := origin - a
	var first := sign_value * direction.dot(difference.cross(edge2))
	if first < 0:
		return -1
	var second := sign_value * direction.dot(edge1.cross(difference))
	if second < 0 or first + second > denominator:
		return -1
	var distance := -sign_value * difference.dot(normal)
	return distance / denominator if distance >= 0 else -1.0
