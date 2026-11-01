extends Node3D

const WorldMeshes = preload("res://tools/source_world_meshes.gd")

var checks := 0
var failures: Array[String] = []
var worlds := 0
var maximum_error := 0.0
var support_probe: BattleUnit

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _height(x: float, z: float, start_y: float, end_y: float, mask: int, excluded: Array[RID] = []) -> Variant:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, start_y, z), Vector3(x, end_y, z), mask)
	query.hit_back_faces = true
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position.y if not hit.is_empty() else null

func _deck_references_valid(source: Dictionary) -> bool:
	var deck_references: Variant = source.get("deckReferences")
	var provenance: Variant = source.get("source")
	return deck_references is Dictionary and deck_references.get("inputs") is Dictionary and provenance is Dictionary and provenance.get("inputs") is Dictionary and deck_references.get("sourceFingerprint") is String and deck_references.sourceFingerprint == provenance.get("fingerprint") and deck_references.inputs.get("public/js/biomes.js") is String and deck_references.inputs["public/js/biomes.js"] == provenance.inputs.get("public/js/biomes.js")

func _run() -> void:
	support_probe = BattleUnit.new()
	add_child(support_probe)
	support_probe.configure({"id": 90001, "peer": 1, "side": "STEEL", "kind": "robot", "character": "t01", "position": Vector3.ZERO})
	support_probe.collision_layer = 0
	support_probe.collision_mask = 32
	var directory := DirAccess.open("res://assets/worlds")
	if directory == null:
		push_error("Native world resources are missing")
		get_tree().quit(1)
		return
	var selection := WorldVariant.select_required(Array(OS.get_cmdline_user_args()))
	if not selection.error.is_empty():
		push_error(selection.error)
		get_tree().quit(1)
		return
	var required: Dictionary = selection.worlds
	var verified := {}
	_check(not required.is_empty(), "Original seasonal world manifest is nonempty")
	for file in directory.get_files():
		var path := "res://assets/worlds/" + file
		if not file.ends_with(".res") or not required.has(path):
			continue
		var data: Resource = load(path)
		var source: Dictionary = Content.read_json("res://data/worlds/" + file.get_basename() + ".json")
		_check(WorldVariant.matches_identity(data.source.get("identity", {}), required[path]), file + ": original map/team/season identity matches the selected resource")
		_check(data.source == source.source, file + ": native provenance matches the verified source bundle")
		var altered_fp := {"source": source.get("source", {}), "deckReferences": {"sourceFingerprint": "0".repeat(64), "inputs": source.get("deckReferences", {}).get("inputs", {})}}
		var altered_biomes := {"source": source.get("source", {}), "deckReferences": {"sourceFingerprint": source.get("deckReferences", {}).get("sourceFingerprint", ""), "inputs": {"public/js/biomes.js": "0".repeat(64)}}}
		_check(_deck_references_valid(source) and not _deck_references_valid(altered_fp) and not _deck_references_valid(altered_biomes),
			file + ": layered-deck reference provenance matches the captured world bundle")
		_check(data.minimap_base != null and source.get("minimapBase") is Dictionary, file + ": original minimap terrain raster is present")
		if data.minimap_base != null and source.get("minimapBase") is Dictionary:
			var minimap_images := SourceTextureImages.new()
			if minimap_images.configure([source.textureImages[int(source.minimapBase.image)]]):
				var minimap_image: Image = data.minimap_base.get_image()
				if minimap_image != null:
					minimap_image.convert(Image.FORMAT_RGBA8)
				_check(minimap_image != null and minimap_image.get_size() == minimap_images.images[0].get_size()
					and minimap_image.get_data() == minimap_images.images[0].get_data(), file + ": native minimap retains every original hillshade/water/veil pixel")
			else:
				_check(false, file + ": original minimap raster can be decoded")
		_check(data.slabs_captured and data.authority_slabs == source.acceptedSlabs, file + ": original accepted structure layers belong to this seasonal resource")
		_check(data.climbs_captured and data.climb_routes == source.climbs, file + ": original seasonal climb routes preserved")
		_check(data.supports_captured and data.roof_platforms == source.roofPlatforms and data.source_buildings == source.sourceBuildings,
			file + ": original seasonal roof/building support preserved")
		_check(data.trains_captured and data.source_trains == source.trains, file + ": original seasonal train paths preserved")
		_check(data.motions_captured and data.source_motions == source.motions, file + ": original seasonal scenery pivot declarations preserved")
		_check(data.wildlife_captured and data.source_wildlife == source.wildlife, file + ": original seasonal wildlife rosters preserved")
		_check(data.source_wildlife.get("catalogCaptured", false), file + ": original density-independent per-route wildlife capacity is captured")
		_check(data.petals_captured and data.source_petals == source.petals, file + ": original seasonal petal rosters preserved")
		_check(data.aquatics_captured and data.source_aquatics == source.aquatics, file + ": original seasonal aquatic fauna/bubble rosters preserved")
		_check(data.marine_captured and data.source_marine == source.marine, file + ": original marine constants, depth sampler, rectangle and vessel wave packets preserved")
		_check(data.marine_depth_field != null, file + ": original marine depth field has a native texture")
		_check(data.marine_programs.size() == source.marinePrograms.size(), file + ": original shared marine shader program count preserved")
		for index in range(mini(data.marine_programs.size(), source.marinePrograms.size())):
			_check(data.marine_programs[index].code == source.marinePrograms[index], file + ": original source-derived native shader functions preserved")
		if data.marine_depth_field != null:
			var pixels := Marshalls.base64_to_raw(source.textureImages[int(source.marine.field.image)].rgba)
			_check(data.marine_depth_field.get_image().get_data() == pixels, file + ": original bathymetry/foam/slope RGBA bytes preserved without colour conversion")
		for petals: Dictionary in data.source_petals.variants:
			_check(petals.season == required[path].season, file + ": source vegetation and petal season agree")
		_check(data.terrain_grid == int(source.grid) and data.terrain_heights == PackedFloat32Array(source.heightField), file + ": original triangular terrain field preserved")
		_check(data.water_profile == source.waterProfile, file + ": original marine/dry-band/wet-grid water profile preserved")
		_check(data.corridors == source.corridors, file + ": original authority corridor pruning profile preserved")
		for probe: Dictionary in source.probes:
			var height := EnvironmentRules.height_at(data.terrain_heights, data.terrain_grid, data.bounds, probe.x, probe.z)
			_check(absf(height - float(probe.ground)) < 0.0001, file + ": original terrain water height probe")
			var dry := EnvironmentRules.in_dry_band(probe.x, probe.z, data.water_profile.dryBands)
			var border := EnvironmentRules.in_border_band(probe.x, probe.z, data.water_profile.get("borderMask", {}))
			_check(EnvironmentRules.ground_code(height, data.water_profile.baseY, [], dry, border) == int(probe.waterCode), file + ": original water classification probe")
		var scene: Node3D = data.scene.instantiate()
		_check(source.has("celPrograms") and source.has("celSamplers"), file + ": regenerate original world cel program/sampler tables")
		var cel_data := scene.get_meta("source_cel_data") as SourceCelData
		_check(cel_data != null, file + ": world shader data uses a shared native Resource")
		if cel_data != null:
			_check(cel_data.programs == source.get("celPrograms", []), file + ": original world cel shader text and include dependencies preserved")
			_check(cel_data.samplers == source.get("celSamplers", []), file + ": original world cel sampler fields preserved")
		add_child(scene)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var map_id: String = required[path].map
		var team_size := str(int(required[path].teamSize))
		var base_id := map_id.trim_suffix("_swap")
		var map_entry: Dictionary = (Content.maps + Content.campaign.get("maps", [])).filter(func(entry): return entry.id == base_id)[0]
		var variants: Dictionary = map_entry.swapped_variants if map_id.ends_with("_swap") else map_entry.variants
		var variant: Dictionary = variants[team_size]
		for structure in variant.structures:
			_check(_height(structure.position[0], structure.position[2], data.ceiling + 100, data.min_height - 100, 8) != null, file + ": structure has a verified standing surface")
		for side in variant.hero_spawns:
			for spawn_point in variant.hero_spawns[side]:
				_check(_height(spawn_point.position[0], spawn_point.position[1], data.ceiling + 100, data.min_height - 100, 8) != null, file + ": source hero spawn has a verified standing surface")
		var native_meshes := {}
		for node: GeometryInstance3D in scene.find_children("SourceMesh_*", "GeometryInstance3D", true, false):
			native_meshes[str(node.name)] = node
		var source_meshes := WorldMeshes.new(source)
		for source_mesh: Dictionary in source_meshes:
			_verify_mesh(file, native_meshes.get("SourceMesh_%d" % source_meshes.index), source_mesh, source.marinePrograms)
		_check(source_meshes.valid, file + ": complete original mesh chunks and numeric buffers")
		for system: Dictionary in data.source_aquatics.systems:
			if system.kind != "detritus":
				continue
			var node: MeshInstance3D = scene.get_node("AquaticPoints_%d" % int(system.batches[0].id))
			var mesh := node.mesh as ArrayMesh
			_check(mesh != null and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_POINTS, file + ": original suspended detritus point primitive")
			var point_arrays := mesh.surface_get_arrays(0)
			var points: PackedVector3Array = point_arrays[Mesh.ARRAY_VERTEX]
			_check(points.size() * 3 == system.positions.size(), file + ": original suspended detritus point count")
			for index in range(points.size()):
				_check(points[index] == Vector3(system.positions[index * 3], system.positions[index * 3 + 1], system.positions[index * 3 + 2]),
					file + ": original suspended detritus initial Float32 coordinates")
		var terrain: MeshInstance3D = scene.get_node("SourceMesh_0")
		var arrays: Array = terrain.mesh.surface_get_arrays(0)
		var expected := PackedVector3Array()
		for i in range(0, source.sourceGridPositions.size(), 3):
			expected.append(Vector3(source.sourceGridPositions[i], source.sourceGridPositions[i + 1], source.sourceGridPositions[i + 2]))
		_check(arrays[Mesh.ARRAY_VERTEX] == expected, file + ": source vertex positions preserved exactly")
		var actual: PackedInt32Array = arrays[Mesh.ARRAY_INDEX].duplicate()
		for i in range(0, actual.size(), 3):
			var previous := actual[i + 1]
			actual[i + 1] = actual[i + 2]
			actual[i + 2] = previous
		var expected_indices := PackedInt32Array()
		for index in source.sourceGridIndex:
			expected_indices.append(int(index))
		_check(actual == expected_indices, file + ": source triangle topology and portal holes preserved")
		for probe in data.probes:
			var native_height = _height(probe.x, probe.z, data.ceiling + 100, data.min_height - 100, 8)
			if probe.collisionGround == null:
				_check(native_height == null, file + ": portal removes ground collision")
			else:
				var error: float = absf(native_height - probe.collisionGround) if native_height != null else INF
				maximum_error = maxf(maximum_error, error)
				_check(error < 0.01, file + ": native terrain ray matches source, error=" + str(error))
		for deck in data.deck_probes:
			var x: float = deck.x
			var z: float = deck.z
			var y: float = deck.y
			var upper = _height(x, z, y + 0.03, y - 0.03, 16)
			_check(upper != null and absf(upper - deck.upper) < 0.01, file + ": source selects the highest overlapping deck")
			var lower: float = y - source.collision.deckThickness
			var underside = _height(x, z, lower - 0.03, lower + 0.03, 16)
			_check(underside != null and absf(underside - deck.lower) < 0.01, file + ": source selects the nearest overlapping underside")
		var floor_bodies := scene.get_node("TunnelFloors").get_children()
		for tunnel_index in range(data.tunnels.size()):
			var tunnel: Dictionary = data.tunnels[tunnel_index]
			if Vector2(tunnel.x1, tunnel.z1) == Vector2(tunnel.x2, tunnel.z2):
				continue
			var point := _interior_point(tunnel)
			var x: float = point.x
			var z: float = point.y
			var floor_height: float = lerpf(tunnel.fy1, tunnel.fy2, 0.371)
			var excluded: Array[RID] = []
			for floor_body: StaticBody3D in floor_bodies:
				if floor_body.name != "Floor_%d" % tunnel_index:
					excluded.append(floor_body.get_rid())
			var floor_hit = _height(x, z, floor_height + 0.03, floor_height - 0.03, 32, excluded)
			_check(floor_hit != null and absf(floor_hit - floor_height) < 0.01, file + ": tunnel floor x=" + str(x) + " z=" + str(z) + " expected=" + str(floor_height) + " actual=" + str(floor_hit))
			var ceiling_height: float = lerpf(tunnel.cy1, tunnel.cy2, 0.371)
			var roof_hit = _height(x, z, ceiling_height - 0.03, ceiling_height + 0.03, 64)
			if tunnel.get("open", false):
				# Another crossing tunnel may own this location; an open segment itself adds no roof.
				var overlapping: bool = data.tunnels.any(func(other):
					if other.get("open", false):
						return false
					var a := Vector2(other.x1, other.z1)
					var b := Vector2(other.x2, other.z2)
					return Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)) <= other.hw)
				if not overlapping:
					_check(roof_hit == null, file + ": open approach has no phantom ceiling collision")
			else:
				_check(roof_hit != null and absf(roof_hit - ceiling_height) < 0.01, file + ": tunnel ceiling blocks upward shots")
			# A point ray exactly on a float32 triangle edge has ambiguous ownership; verify support there with the real player collider.
			var parameters := PhysicsTestMotionParameters3D.new()
			var start_clearance := support_probe.radius + support_probe.height
			parameters.from = Transform3D(Basis.IDENTITY, Vector3((tunnel.x1 + tunnel.x2) / 2, (tunnel.fy1 + tunnel.fy2) / 2 + start_clearance, (tunnel.z1 + tunnel.z2) / 2))
			parameters.margin = 0.001
			parameters.recovery_as_collision = true
			var supported := false
			var fall_speed := 0.0
			var tick := 1.0 / Engine.physics_ticks_per_second
			for step in range(Engine.physics_ticks_per_second * 2):
				fall_speed += Content.constants.AIR.GRAV * tick
				parameters.motion = Vector3.DOWN * fall_speed * tick
				if PhysicsServer3D.body_test_motion(support_probe.get_rid(), parameters):
					supported = true
					break
				parameters.from.origin += parameters.motion
			_check(supported, file + ": player floor support segment=%d width=%f rise=%f length=%f" % [tunnel_index, tunnel.hw, tunnel.fy2 - tunnel.fy1, Vector2(tunnel.x2 - tunnel.x1, tunnel.z2 - tunnel.z1).length()])
		worlds += 1
		verified[path] = true
		scene.queue_free()
		await get_tree().process_frame
		print("WORLD_CHECKED ", file.get_basename())
	_check(worlds > 0, "At least one native world was verified")
	for path: String in required:
		_check(verified.has(path), "Required original seasonal world was verified: " + path)
	if failures.is_empty():
		print("WORLD_TEST_PASS worlds=", worlds, " checks=", checks, " max_ground_error_m=", maximum_error)
	else:
		print("WORLD_TEST_FAIL count=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _interior_point(segment: Dictionary) -> Vector2:
	var a := Vector2(segment.x1, segment.z1)
	var b := Vector2(segment.x2, segment.z2)
	var direction := (b - a).normalized()
	return a.lerp(b, 0.371) + Vector2(direction.y, -direction.x) * segment.hw * 0.173

func _verify_mesh(file: String, node: GeometryInstance3D, source: Dictionary, marine_sources: Array) -> void:
	_check(node != null, file + ": captured mesh exists in its static or moving hierarchy")
	if node == null:
		return
	_check(node.get_meta("source_water", false) == source.get("water", false), file + ": original water/swamp mesh identity")
	_check(node.get_meta("source_tide_water", false) == source.get("tideWater", false), file + ": only original main and ring water meshes follow tide")
	if source.get("water", false):
		_check(node.get_meta("source_marine_frame", []) == source.marineFrame, file + ": original water/reflection geometry frame preserved")
		_check(node.get_meta("source_marine_receive_shadow", false) == source.receiveShadow, file + ": original water shadow-receiver flag preserved")
	_check(node.visible == bool(source.visible), file + ": original captured mesh visibility")
	if source.has("outlineUniforms"):
		var frame := preload("res://tests/quaternion_suite.gd").frame(source.outlineFrame)
		_check(node.transform.is_equal_approx(frame), file + ": outline retains its original local-to-world or motion-parent frame")
		_check(node.get_meta("isOutline", false) and node.get_meta("source_outline_uniforms", {}) == source.outlineUniforms,
			file + ": original world shell uniforms survive packing without world-space rebaking")
		_check(node.get_meta("source_outline_frustum_culled", true) == source.frustumCulled,
			file + ": original world shell culling policy survives packing")
	_check((node is MultiMeshInstance3D) == source.has("instances"), file + ": original ordinary/instanced mesh kind")
	var mesh: Mesh
	if node is MultiMeshInstance3D:
		var batch: MultiMesh = node.multimesh
		mesh = batch.mesh
		_check(batch.instance_count == source.instances.size(), file + ": original instance count")
		for index in range(batch.instance_count):
			var expected := preload("res://tests/quaternion_suite.gd").frame(source.instances[index])
			_check(batch.get_instance_transform(index).is_equal_approx(expected), file + ": original instance frame in its captured parent")
			if source.has("instanceColors"):
				var color := batch.get_instance_color(index)
				var rgb: Array = source.instanceColors[index]
				_check(maxf(absf(color.r - float(rgb[0])), maxf(absf(color.g - float(rgb[1])), absf(color.b - float(rgb[2])))) < 0.004,
					file + ": original instance color")
	elif node is MeshInstance3D:
		mesh = node.mesh
	else:
		_check(false, file + ": unsupported captured geometry node")
		return
	var vertices := PackedVector3Array()
	_check(mesh.get_meta("source_custom_attributes", {}) == source.get("attributes", {}), file + ": original surface/card/land/wind attributes preserved")
	if source.has("celGeometry"):
		_check(mesh.get_meta("source_cel_geometry", {}) == source.celGeometry, file + ": original cel local vertices/normals and model frame survive world baking")
	for offset in range(0, source.positions.size(), 3):
		vertices.append(Vector3(source.positions[offset], source.positions[offset + 1], source.positions[offset + 2]))
	var surfaces: Array = source.get("surfaces", [source])
	_check(mesh.get_surface_count() == surfaces.size(), file + ": original material groups/draw ranges")
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if not surfaces[surface].get("vertexColors", false):
			_check((arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty()) and (arrays[SourceCelVertexColors.ARRAY_SLOT] == null or arrays[SourceCelVertexColors.ARRAY_SLOT].is_empty()), file + ": source-disabled vertex colours cannot multiply native instance colours")
		var material: Material = node.material_override if node.material_override != null else (node.get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface))
		if surfaces[surface].has("cel"):
			_check(material != null and SourceCelData.material_source(material) == surfaces[surface].cel,
				file + ": original material cel definitions and typed uniforms preserved")
		if surfaces[surface].has("marine"):
			_check(material != null and material.get_meta("source_marine", {}) == surfaces[surface].marine,
				file + ": original resolved per-material marine/reflection uniforms preserved")
			var program: ShaderInclude = material.get_meta("source_marine_program") if material != null else null
			_check(program != null and program.code == marine_sources[int(surfaces[surface].marine.program)],
				file + ": original marine material retains its shared native shader include")
			_check(material is ShaderMaterial and material.render_priority == int(source.get("renderOrder", 0)),
				file + ": original water/reflection material uses native shader and source render order")
		_check(arrays[Mesh.ARRAY_VERTEX] == vertices, file + ": original surface vertices preserved")
		if source.has("seaFade"):
			var expected := PackedFloat32Array()
			var origins: Array = source.get("reflectionOrigins", [])
			for vertex in range(vertices.size()):
				for axis in range(3):
					expected.append(origins[vertex * 3 + axis] if not origins.is_empty() else 0.0)
				expected.append(source.seaFade[vertex])
			_check(arrays[Mesh.ARRAY_CUSTOM0] == expected, file + ": original full-precision reflection origins and per-vertex wave fade preserved")
			_check(arrays[Mesh.ARRAY_CUSTOM1] == PackedFloat32Array(source.marinePositions),
				file + ": original local water vertices retained before world baking for shader placement and normals")
		var indices := PackedInt32Array()
		var triangles: Array = surfaces[surface].index
		for offset in range(0, triangles.size(), 3):
			indices.append_array(PackedInt32Array([int(triangles[offset]), int(triangles[offset + 2]), int(triangles[offset + 1])]))
		_check(arrays[Mesh.ARRAY_INDEX] == indices, file + ": original reflected/source winding converted")
		if not source.colors.is_empty() and surfaces[surface].get("vertexColors", false):
			var components := int(source.get("colorSize", 3))
			if surfaces[surface].has("marine"):
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var error := 0.0
				for offset in range(0, source.colors.size(), components):
					var color := colors[offset / components]
					for channel in range(components):
						error = maxf(error, absf(color[channel] - float(source.colors[offset + channel])))
				_check(error <= 1.0 / 255.0 + 0.000001, file + ": original RGB/RGBA surface colors within native precision")
			else:
				var expected_colors := PackedFloat32Array()
				expected_colors.resize(vertices.size() * 4)
				for vertex in range(vertices.size()):
					expected_colors[vertex * 4 + 3] = 1.0
					for channel in range(components):
						expected_colors[vertex * 4 + channel] = float(source.colors[vertex * components + channel])
				var actual_colors: Variant = arrays[SourceCelVertexColors.ARRAY_SLOT]
				_check((arrays[Mesh.ARRAY_COLOR] == null or arrays[Mesh.ARRAY_COLOR].is_empty())
					and actual_colors is PackedFloat32Array
					and (actual_colors as PackedFloat32Array).to_byte_array() == expected_colors.to_byte_array(),
					file + ": original RGB/RGBA surface colors preserved in Float32 attribute")

