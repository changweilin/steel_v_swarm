extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const GEOMETRY := "civilianBodyGeometry"

static func run(h: Node, _fixtures: Dictionary = {}) -> void:
	var section: Dictionary = Content.fixture_registry.get("sections", {}).get(GEOMETRY, {})
	if section.is_empty():
		h._check(false, "Regenerate original per-ID civilian geometry and articulated-frame references")
		return
	# The oracle is too large to hold at once; each part is compared and released before the next.
	for part in section.parts.size():
		var items: Array = Content.read_fixture_part(GEOMETRY, part)
		for item: Dictionary in items:
			_case(h, item)
		items.clear()

static func _case(h: Node, item: Dictionary) -> void:
	var unit := BattleUnit.new()
	h.add_child(unit)
	unit.configure({"id": int(item.seed), "kind": "civilian", "side": "", "position": Vector3.ZERO,
		"special": {"role": "civilian", "civil_side": item.side, "profession": int(item.profession)}})
	if unit.body_presentation == null:
		h._check(false, "Pack original civilian components")
		unit.free()
		return
	unit.body.rotation.y = 0
	for node: Node3D in unit.body.nodes.values():
		var geometry := ViewOcclusion._geometry(node)
		if geometry == null:
			continue
		for surface in range(geometry.get_surface_count()):
			var material := ViewOcclusion._material(node as GeometryInstance3D, surface)
			if material != null and material.has_meta("source_original_material"):
				material = material.get_meta("source_original_material")
			if material == null or not material.has_meta("source_cel"):
				continue
			var source := SourceCelData.material_source(material)
			var data := material.get_meta("source_cel_data", null) as SourceCelData
			h._check(data != null and int(source.program) >= 0 and int(source.program) < data.programs.size(),
				"Assembled civilian surfaces retain component-local shader programs after discarded part roots are freed")
			if data != null:
				h._check(data.samplers.size() == data.sampler_images.size(), "Civilian material bundles retain raw image sampler resources after assembly")
	unit.body_presentation.pending_snap = false
	Helper.compare(h, unit.body.profile.appearance, item.appearance, "Original civilian seed/profession appearance is independent of combat RNG")
	Helper.compare(h, unit.geometry_override, item.dimensions, "Original per-ID civilian silhouette and asymmetric model centre")
	var previous := Vector3.ZERO
	var previous_yaw := 0.0
	for step: Dictionary in item.steps:
		var point := BodyPose.vector(step.position)
		unit.body.poses.set_position(unit.body.source_root, point)
		unit.body.poses.set_axis(unit.body.source_root, "y", step.yaw)
		unit.body.step_combat(unit.body_presentation.entity, step.now, step.delta)
		unit.body.step_locomotion(unit.body_presentation.entity, step.delta, step.now, previous, previous_yaw)
		_compare_meshes(h, unit.body, step.meshes)
		previous = point
		previous_yaw = step.yaw
	unit.free()

static func _compare_meshes(h: Node, body: BodyRig, expected: Array) -> void:
	var meshes: Array = body.source_root.find_children("*", "MeshInstance3D", true, false).filter(func(mesh): return not mesh.get_meta("isOutline", false))
	h._check(meshes.size() == expected.size(), "Original civilian clothing/hair/equipment/ring mesh count")
	for reference: Dictionary in expected:
		var found := -1
		for index in range(meshes.size()):
			var mesh := meshes[index] as MeshInstance3D
			if mesh.get_meta("source_name") != reference.name:
				continue
			var material := mesh.get_active_material(0) as BaseMaterial3D
			if int(material.albedo_color.to_rgba32() >> 8) != int(reference.color):
				continue
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if vertices.size() != reference.points.size():
				continue
			if not vertices.is_empty() and (mesh.global_transform * vertices[0]).distance_to(BodyPose.vector(reference.points[0])) > .0005:
				continue
			found = index
			var outlines: Array = mesh.get_children().filter(func(child): return child.get_meta("isOutline", false))
			h._check(reference.has("outlines"), "Regenerate original assembled civilian outline references")
			if reference.has("outlines"):
				h._check(outlines.size() == reference.outlines.size(), "Original civilian shells follow their assembled source surface")
				for shell_index in range(mini(outlines.size(), reference.outlines.size())):
					var outline := outlines[shell_index] as MeshInstance3D
					var outline_material := outline.material_override as ShaderMaterial
					h._check(outline_material != null, "Assembled civilian outline uses the native shell shader")
					if outline_material != null:
						Helper.compare(h, {"width": outline_material.get_shader_parameter("local_width"),
							"minimum": outline_material.get_shader_parameter("minimum_width"), "maximum": outline_material.get_shader_parameter("maximum_width")},
							reference.outlines[shell_index], "Original civilian appearance-adjusted bind-pose shell widths remain fixed during animation")
			for vertex in range(vertices.size()):
				h._check((mesh.global_transform * vertices[vertex]).distance_to(BodyPose.vector(reference.points[vertex])) < .0005,
					"Original per-ID civilian world-space geometry across source body frames")
			var normals: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
			var normal_basis := mesh.global_basis.inverse().transposed()
			for vertex in range(mini(normals.size(), reference.normals.size())):
				h._check((normal_basis * normals[vertex]).normalized().distance_to(BodyPose.vector(reference.normals[vertex])) < .001,
					"Original civilian normals retain nonuniform body/shoulder/head scaling")
			break
		h._check(found >= 0, "Original civilian surface and palette binding: " + reference.name)
		if found >= 0:
			meshes.remove_at(found)
