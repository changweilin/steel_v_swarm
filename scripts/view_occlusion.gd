class_name ViewOcclusion
extends RefCounted

var registry: Dictionary = {}
var skipped: Dictionary = {}
var fades: Dictionary = {}
var triangles: Dictionary = {}
var next_scan := 0.0
var previous := NAN

func skip_mesh(mesh: GeometryInstance3D) -> void:
	var id := mesh.get_instance_id()
	skipped[id] = weakref(mesh)
	registry.erase(id)
	_restore(id)

func register_root(root: Node) -> void:
	if root.get_meta("source_detached_view", false):
		return
	if root is MeshInstance3D or root is MultiMeshInstance3D:
		var id := root.get_instance_id()
		if not skipped.has(id) and not root.get_meta("isOutline", false) and not root.get_meta("noViewOcclusion", false) and _has_opaque(root):
			registry[id] = weakref(root)
	for child: Node in root.get_children():
		register_root(child)

func unregister_root(root: Node) -> void:
	var id := root.get_instance_id()
	registry.erase(id)
	_restore(id)
	for child: Node in root.get_children():
		unregister_root(child)

func dispose() -> void:
	clear()
	registry.clear()
	skipped.clear()
	triangles.clear()

func clear() -> void:
	for id: int in fades.keys():
		_restore(id)
	next_scan = 0
	previous = 0

func advance(now: float) -> void:
	if fades.is_empty():
		previous = now
		return
	var rules: Dictionary = Content.balance.playerView.occlusion
	var delta := clampf(now - (now if is_nan(previous) else previous), 0, float(rules.frameCap))
	previous = now
	if delta <= 0:
		return
	for id: int in fades.keys():
		var state: Dictionary = fades[id]
		if not is_instance_valid(state.mesh.get_ref()):
			fades.erase(id)
			continue
		var wanted := 1.0 if now - float(state.last_hit) <= float(rules.RELEASE_S) else 0.0
		var rate: float = rules.FADE_IN_K if wanted > float(state.k) else rules.FADE_OUT_K
		state.k = float(state.k) + clampf(wanted - float(state.k), -rate * delta, rate * delta)
		var factor := 1 - (1 - float(rules.OPACITY_F)) * float(state.k)
		for item: Dictionary in state.items:
			var material: Material = item.faded
			if material is ShaderMaterial and material.get_meta("source_outline", false):
				material.set_shader_parameter("source_opacity", float(item.alpha) * factor)
			else:
				var native := material as BaseMaterial3D
				var color := native.albedo_color
				color.a = float(item.alpha) * factor
				native.albedo_color = color
		if wanted == 0 and float(state.k) <= 0:
			_restore(id)

func hit(mesh: GeometryInstance3D, now: float) -> void:
	if skipped.has(mesh.get_instance_id()):
		return
	_fade_one(mesh, now)
	_refresh(mesh, now)
	_refresh_outlines(mesh, now)

func _refresh_outlines(root: Node, now: float) -> void:
	for child: Node in root.get_children():
		if (child is MeshInstance3D or child is MultiMeshInstance3D) and child.get_meta("isOutline", false):
			_fade_one(child, now)
			_refresh(child, now)
		_refresh_outlines(child, now)

func _refresh(mesh: GeometryInstance3D, now: float) -> void:
	var id := mesh.get_instance_id()
	if fades.has(id):
		fades[id].last_hit = now

func _fade_one(mesh: GeometryInstance3D, now: float) -> void:
	var id := mesh.get_instance_id()
	var geometry := _geometry(mesh)
	if fades.has(id) or geometry == null:
		return
	var items: Array = []
	var state := {"mesh": weakref(mesh), "items": items, "last_hit": now, "k": 0.0}
	if mesh.material_override != null:
		var item := _material_item(mesh.material_override, mesh.material_override, -1)
		if not item.is_empty():
			mesh.material_override = item.faded
			items.append(item)
	elif mesh is MeshInstance3D:
		for surface in range(geometry.get_surface_count()):
			var item := _material_item(_material(mesh, surface), mesh.get_surface_override_material(surface), surface)
			if not item.is_empty():
				mesh.set_surface_override_material(surface, item.faded)
				items.append(item)
	else:
		var batch := mesh as MultiMeshInstance3D
		if batch == null:
			return
		for surface in range(geometry.get_surface_count()):
			var item := _material_item(_material(mesh, surface), geometry.surface_get_material(surface), surface)
			if not item.is_empty():
				items.append(item)
		if not items.is_empty():
			# MultiMesh has no node-level surface overrides. Keep animated instance
			# buffers independent and replace only this node's material bindings.
			var instances := MultiMeshCopy.duplicate_of(batch.multimesh)
			var faded: Mesh = geometry.duplicate()
			for item: Dictionary in items:
				faded.surface_set_material(int(item.surface), item.faded)
			instances.mesh = faded
			batch.multimesh = instances
			state.instances = instances
			state.geometry = faded
			state.original_geometry = geometry
	if not items.is_empty():
		fades[id] = state

func _restore(id: int) -> void:
	if not fades.has(id):
		return
	var state: Dictionary = fades[id]
	var mesh: GeometryInstance3D = state.mesh.get_ref()
	if is_instance_valid(mesh):
		var batch := mesh as MultiMeshInstance3D
		var restore_instances: bool = batch != null and state.has("instances") and batch.multimesh == state.instances and batch.multimesh.mesh == state.geometry
		for item: Dictionary in state.items:
			if int(item.surface) < 0:
				if mesh.material_override == item.faded:
					mesh.material_override = item.base
			elif mesh is MeshInstance3D and mesh.mesh != null and int(item.surface) < mesh.mesh.get_surface_count() and mesh.get_surface_override_material(int(item.surface)) == item.faded:
				mesh.set_surface_override_material(int(item.surface), item.base)
			elif restore_instances and state.geometry.surface_get_material(int(item.surface)) == item.faded:
				state.geometry.surface_set_material(int(item.surface), item.base)
		if restore_instances:
			var unchanged := true
			for surface in range(state.geometry.get_surface_count()):
				unchanged = unchanged and state.geometry.surface_get_material(surface) == state.original_geometry.surface_get_material(surface)
			if unchanged:
				# Keep the current instance transforms, including animation during fade.
				batch.multimesh.mesh = state.original_geometry
	fades.erase(id)

static func _geometry(node: Node) -> Mesh:
	if node.get_meta("source_sprite", false):
		return null
	if node is MeshInstance3D:
		return node.mesh
	if node is MultiMeshInstance3D and node.multimesh != null:
		return node.multimesh.mesh
	return null

static func _material(mesh: GeometryInstance3D, surface: int) -> Material:
	if mesh.material_override != null:
		return mesh.material_override
	if mesh is MeshInstance3D:
		return mesh.get_active_material(surface)
	return _geometry(mesh).surface_get_material(surface)

static func _instance_count(mesh: MultiMeshInstance3D) -> int:
	var instances := mesh.multimesh
	return mini(instances.instance_count, instances.visible_instance_count) if instances.visible_instance_count >= 0 else instances.instance_count

static func _local_bounds(node: Node) -> Dictionary:
	var geometry := _geometry(node)
	if geometry == null:
		return {}
	if node is MeshInstance3D:
		return {"box": geometry.get_aabb()}
	var batch := node as MultiMeshInstance3D
	var result: Dictionary = {}
	for index in range(_instance_count(batch)):
		var box: AABB = batch.multimesh.get_instance_transform(index) * geometry.get_aabb()
		result.box = result.box.merge(box) if result.has("box") else box
	return result

static func _opaque(material: Material) -> bool:
	if material is ShaderMaterial and material.get_meta("source_outline", false):
		return not bool(material.get_meta("source_transparent", false))
	if not material is BaseMaterial3D:
		return false
	var native := material as BaseMaterial3D
	return not bool(native.get_meta("source_transparent", native.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED))

static func _has_opaque(mesh: GeometryInstance3D) -> bool:
	var geometry := _geometry(mesh)
	if geometry == null:
		return false
	for surface in range(geometry.get_surface_count()):
		if _opaque(_material(mesh, surface)):
			return true
	return false

static func _material_item(material: Material, base: Material, surface: int) -> Dictionary:
	if not _opaque(material):
		return {}
	if material is ShaderMaterial and material.get_meta("source_outline", false):
		return {"faded": SourceOutlineMaterial.faded(material), "base": base, "surface": surface, "alpha": float(material.get_meta("source_opacity", 1))}
	var faded: BaseMaterial3D = material.duplicate()
	faded.set_meta("source_transparent", true)
	faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faded.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return {"faded": faded, "base": base, "surface": surface, "alpha": (material as BaseMaterial3D).albedo_color.a}

static func body_bounds(root: Node) -> Dictionary:
	var result: Dictionary = {}
	_expand_body(root, false, result)
	return result

static func _expand_body(node: Node, included: bool, result: Dictionary) -> void:
	if _geometry(node) != null:
		included = included or not (node.get_meta("teamRing", false) or node.get_meta("isOutline", false) or node.get_meta("noOutline", false))
		if included:
			var local := _local_bounds(node)
			if local.has("box"):
				var box: AABB = (node as Node3D).global_transform * local.box
				result.box = result.box.merge(box) if result.has("box") else box
	# Source expandByObject includes descendants of an eligible mesh, even hidden ones.
	for child: Node in node.get_children():
		_expand_body(child, included, result)

static func targets(box: AABB, camera_basis: Basis, height: float) -> Array[Vector3]:
	var rules: Dictionary = Content.balance.playerView.occlusion
	var right := camera_basis.x
	right.y = 0
	right = Vector3.RIGHT if right.length_squared() < float(rules.rightEpsilon) else right.normalized()
	var span := maxf(float(rules.minimumSpan), maxf(box.size.x, box.size.z) * float(rules.spanRatio))
	var size := maxf(box.size.y, maxf(height, float(rules.minimumHeight)))
	var center := box.get_center()
	var result: Array[Vector3] = []
	for fraction: float in rules.heights:
		result.append(Vector3(center.x, box.position.y + size * fraction, center.z))
	for fraction: float in rules.heights:
		var point := Vector3(center.x, box.position.y + size * fraction, center.z)
		result.append(point + right * span)
		result.append(point - right * span)
	return result

func update(now: float, camera: Transform3D, owner: Node3D, height: float, enabled: bool) -> void:
	if not enabled:
		clear()
		return
	advance(now)
	if now < next_scan:
		return
	var rules: Dictionary = Content.balance.playerView.occlusion
	next_scan = now + float(rules.UPDATE_S)
	if not is_instance_valid(owner) or not owner.visible or registry.is_empty():
		clear()
		return
	var bounds := body_bounds(owner)
	if bounds.is_empty():
		clear()
		return
	var box: AABB = bounds.box
	var center := box.get_center()
	var span := maxf(float(rules.minimumSpan), maxf(box.size.x, box.size.z) * float(rules.spanRatio))
	var maximum := camera.origin.distance_to(center) * 0.5 + span + float(rules.broadMargin)
	var midpoint := (camera.origin + center) * 0.5
	var samples := targets(box, camera.basis, height)
	for id: int in registry.keys():
		var mesh: GeometryInstance3D = registry[id].get_ref()
		if not is_instance_valid(mesh):
			registry.erase(id)
			continue
		if not mesh.visible or mesh == owner or owner.is_ancestor_of(mesh):
			continue
		var position := mesh.global_position
		if Vector2(position.x - midpoint.x, position.z - midpoint.z).length_squared() > maximum * maximum:
			continue
		var source := _geometry(mesh)
		if source == null or mesh.global_basis.determinant() == 0:
			continue
		if fades.has(id) and fades[id].get("geometry") == source:
			source = fades[id].original_geometry
		if not triangles.has(source):
			triangles[source] = source.generate_triangle_mesh()
		var geometry: TriangleMesh = triangles[source]
		if geometry == null:
			continue
		var frames: Array[Transform3D] = []
		if mesh is MultiMeshInstance3D:
			for index in range(_instance_count(mesh)):
				frames.append(mesh.global_transform * mesh.multimesh.get_instance_transform(index))
		else:
			frames.append(mesh.global_transform)
		var blocked := false
		for frame: Transform3D in frames:
			if frame.basis.determinant() == 0:
				continue
			var inverse := frame.affine_inverse()
			for target: Vector3 in samples:
				var offset := target - camera.origin
				var distance := offset.length()
				if distance <= float(rules.minimumRay):
					continue
				var direction := offset / distance
				var start := camera.origin + direction * float(rules.rayNear)
				var end := target - direction * float(rules.rayNear)
				# The two-sided BVH covers the union of the source forward/reverse casts.
				var result := geometry.intersect_segment(inverse * start, inverse * end)
				if not result.is_empty():
					var point: Vector3 = frame * result.position
					var from_eye := camera.origin.distance_to(point)
					if from_eye >= float(rules.rayNear) and from_eye < distance - float(rules.rayNear):
						blocked = true
						break
			if blocked:
				hit(mesh, now)
				break
