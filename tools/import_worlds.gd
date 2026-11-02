extends Node

const WorldData = preload("res://scripts/native_world_data.gd")
const WorldMeshes = preload("res://tools/source_world_meshes.gd")
const ResourcePublisher = preload("res://tools/source_resource_publisher.gd")
const TERRAIN_LAYER := 8
const STRUCTURE_LAYER := 16
# Everything else in a capture record must match for parts to share one draw.
const BATCH_GEOMETRY_FIELDS := ["name", "positions", "normals", "colors", "uv", "uv1", "uv2", "uv3", "index", "celGeometry", "attributes"]
# Each of these is read per source mesh, so it keeps its own node.
const BATCH_EXCLUDED_FIELDS := ["instances", "instanceColors", "surfaces", "outlineUniforms", "seaFade", "sourceWorldText", "sourceCampLandmark",
	"sourceCampBuildingBatch", "sourceMotionId", "sourceTrainId", "sourceClimb", "climbArrow", "sourceWildlifeMesh", "sourcePetalMesh", "sourceAquaticMesh"]
var source_textures := SourceTextureImages.new()
var cel_data: SourceCelData
var marine_programs: Array[ShaderInclude] = []
var marine_source: Dictionary = {}
var marine_depth_field: Texture2D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native world packing requires a real rendering driver to preserve source graphics buffers")
		get_tree().quit(1)
		return
	var output := "res://assets/worlds"
	DirAccess.make_dir_recursive_absolute(output)
	DirAccess.make_dir_recursive_absolute(output + "/shaders")
	var directory := DirAccess.open("res://data/worlds")
	if directory == null:
		push_error("World source bundles are missing")
		get_tree().quit(1)
		return
	var selection := WorldVariant.select_required(Array(OS.get_cmdline_user_args()))
	if not selection.error.is_empty():
		push_error(selection.error)
		get_tree().quit(1)
		return
	var required: Dictionary = selection.worlds
	var imported := {}
	if required.is_empty():
		push_error("No matching original seasonal world requirements")
		get_tree().quit(1)
		return
	for file in directory.get_files():
		if not file.ends_with(".json") or not required.has(output + "/" + file.get_basename() + ".res"):
			continue
		var data: Dictionary = Content.read_json("res://data/worlds/" + file)
		var identity: Dictionary = data.source.get("identity", {})
		if identity.is_empty():
			print("WORLD_LEGACY_SKIPPED ", file.get_basename())
			continue
		var base := "res://assets/worlds/%s_%d.res" % [identity.get("map", ""), int(identity.get("teamSize", 0))]
		if not WorldVariant.matches_identity(identity, WorldVariant.identity(base, {"season": identity.get("season")})) or WorldVariant.path(base, {"season": identity.get("season")}).get_file().get_basename() != file.get_basename():
			push_error("Seasonal world identity does not match its source bundle name: %s captured=%s expected=%s" % [file, str(identity), str(WorldVariant.identity(base, {"season": identity.get("season")}))])
			get_tree().quit(1)
			return
		if not data.get("slabsCaptured", false) or not data.get("acceptedSlabs") is Array:
			push_error("Missing original accepted structure layers in seasonal world: " + file)
			get_tree().quit(1)
			return
		if not data.get("collision") is Dictionary or not data.get("deckProbes") is Array:
			push_error("Missing original deck references; run tools/world_references.mjs before native packing: " + file)
			get_tree().quit(1)
			return
		var references: Variant = data.get("deckReferences")
		var biomes_input := "public/js/biomes.js"
		if not references is Dictionary or not references.get("inputs") is Dictionary or not data.source.get("inputs") is Dictionary \
				or not references.get("sourceFingerprint") is String or references.sourceFingerprint != data.source.get("fingerprint") \
				or not references.inputs.get(biomes_input) is String or references.inputs[biomes_input] != data.source.inputs.get(biomes_input):
			push_error("Original deck references do not belong to this capture; rerun tools/world_references.mjs: " + file)
			get_tree().quit(1)
			return
		for key: String in ["deckThickness", "deckEndTolerance", "roofThickness"]:
			var value: Variant = data.collision.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
				push_error("Missing/invalid original collision field; run tools/world_references.mjs: " + file + ": " + key)
				get_tree().quit(1)
				return
		if not source_textures.configure(data.get("textureImages", [])):
			get_tree().quit(1)
			return
		cel_data = SourceCelData.new()
		if not cel_data.configure(data, source_textures):
			get_tree().quit(1)
			return
		var minimap: Dictionary = data.get("minimapBase", {})
		var minimap_index := int(minimap.get("image", -1))
		if minimap_index < 0 or minimap_index >= source_textures.images.size():
			push_error("Missing original minimap terrain raster: " + file)
			get_tree().quit(1)
			return
		var minimap_image: Image = source_textures.images[minimap_index]
		if minimap_image.get_width() != int(minimap.get("width", 0)) or minimap_image.get_height() != int(minimap.get("height", 0)):
			push_error("Original minimap raster dimensions do not match its capture: " + file)
			get_tree().quit(1)
			return
		marine_programs.clear()
		marine_source = {}
		marine_depth_field = null
		if data.get("marineCaptured", false):
			if not data.get("marine") is Dictionary or not data.marine.get("field") is Dictionary or not data.marine.get("wind") is Dictionary:
				push_error("Missing original marine depth/uniform capture: " + file)
				get_tree().quit(1)
				return
			var field_id := int(data.marine.field.get("image", -1))
			if field_id < 0 or field_id >= source_textures.images.size() or data.marine.field.get("srgb", true):
				push_error("Original marine bathymetry requires its linear RGBA field: " + file)
				get_tree().quit(1)
				return
			marine_source = data.marine
			marine_depth_field = ImageTexture.create_from_image(source_textures.images[field_id])
			if not data.get("marinePrograms") is Array:
				push_error("Missing original marine shader program capture: " + file)
				get_tree().quit(1)
				return
			for code: String in data.marinePrograms:
				if not code.contains("float celSeaH(") or not code.contains("void celMarineFinish("):
					push_error("Incomplete original marine shader program: " + file)
					get_tree().quit(1)
					return
				var publication := await _publish_marine_program(code, output + "/shaders", get_tree())
				if not publication.error.is_empty():
					push_error(publication.error + ": " + file)
					get_tree().quit(1)
					return
				marine_programs.append(publication.program)
		var scene_root := Node3D.new()
		scene_root.name = "SourceWorld"
		scene_root.set_meta("source_cel_data", cel_data)
		for system: Dictionary in data.get("aquatics", {}).get("systems", []):
			if system.kind != "detritus":
				continue
			var points := AquaticDetritus.create_node(system)
			scene_root.add_child(points)
			points.owner = scene_root
		var train_visuals := {}
		var trains: Array = []
		if data.get("trainsCaptured", false):
			if not data.get("trains") is Array:
				push_error("Missing original train motion capture: " + file)
				get_tree().quit(1)
				return
			trains = data.trains
		for train: Dictionary in trains:
			var id := int(train.id)
			if id <= 0 or train_visuals.has(id):
				push_error("Invalid/duplicate original train identity: " + file)
				get_tree().quit(1)
				return
			var path := SceneryTrainMotion.create_path(train)
			if path.curve.get_point_count() < 2 or path.curve.get_baked_length() <= 0:
				push_error("Original train has no native path: " + file)
				get_tree().quit(1)
				return
			scene_root.add_child(path)
			path.owner = scene_root
			for child in path.find_children("*", "Node", true, false):
				child.owner = scene_root
			train_visuals[id] = path.get_node("TrainFollower/TrainVisual")
		var motion_pivots := {}
		var motions: Array = []
		if data.get("motionsCaptured", false):
			if not data.get("motions") is Array:
				push_error("Missing original scenery motion capture: " + file)
				get_tree().quit(1)
				return
			motions = data.motions
		for motion: Dictionary in motions:
			var id := int(motion.id)
			var parent: Node3D = scene_root
			if int(motion.parentMotion) > 0:
				parent = motion_pivots.get(int(motion.parentMotion))
			elif int(motion.parentTrain) > 0:
				parent = train_visuals.get(int(motion.parentTrain))
			if id <= 0 or motion_pivots.has(id) or parent == null:
				push_error("Invalid original scenery motion hierarchy: " + file)
				get_tree().quit(1)
				return
			var anchor := SceneryMotion.create_anchor(motion)
			parent.add_child(anchor)
			anchor.owner = scene_root
			var pivot: Node3D = anchor.get_node("Pivot")
			pivot.owner = scene_root
			pivot.set_meta("source_motion_id", id)
			motion_pivots[id] = pivot
		var building_batches := {}
		var source_meshes := WorldMeshes.new(data)
		for source_entry: Dictionary in source_meshes:
			var i: int = source_meshes.index
			if i < 8 or i % 8192 == 0:
				print("WORLD_MESH_IMPORT ", file, " index=", i)
			# Only sampler descriptors change; vertex arrays stay immutable and shared.
			var entry: Dictionary = source_entry.duplicate()
			if entry.has("surfaces"):
				entry.surfaces = entry.surfaces.map(func(surface): return surface.duplicate())
			for surface: Dictionary in entry.get("surfaces", [entry]):
				if not surface.has("texture"):
					continue
				var channel := int(surface.texture.get("channel", 0))
				surface.texture = SourceTextureImages.prepare(surface.texture, entry.get("uv" if channel == 0 else "uv" + str(channel), []))
				if surface.texture.is_empty():
					get_tree().quit(1)
					return
			var batch_key := _batch_key(entry)
			if building_batches.has(batch_key):
				if not _batch_append(building_batches[batch_key], entry, i):
					scene_root.free()
					get_tree().quit(1)
					return
				continue
			var mesh := ArrayMesh.new() if not batch_key.is_empty() else _mesh(entry)
			if mesh == null:
				scene_root.free()
				get_tree().quit(1)
				return
			var instance: GeometryInstance3D
			if entry.has("instances"):
				var batch := MultiMeshInstance3D.new()
				batch.multimesh = MultiMesh.new()
				batch.multimesh.resource_local_to_scene = true
				batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
				batch.multimesh.use_colors = entry.has("instanceColors")
				batch.multimesh.mesh = mesh
				batch.multimesh.instance_count = entry.instances.size()
				for index in range(entry.instances.size()):
					var matrix: Array = entry.instances[index]
					batch.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3(matrix[0], matrix[1], matrix[2]),
						Vector3(matrix[4], matrix[5], matrix[6]), Vector3(matrix[8], matrix[9], matrix[10])), Vector3(matrix[12], matrix[13], matrix[14])))
					if entry.has("instanceColors"):
						var color: Array = entry.instanceColors[index]
						batch.multimesh.set_instance_color(index, Color(color[0], color[1], color[2]))
				if batch.multimesh.buffer.size() != batch.multimesh.instance_count * (16 if batch.multimesh.use_colors else 12):
					push_error("Native renderer did not preserve the source world MultiMesh buffer: %s:%d" % [file, i])
					batch.free()
					scene_root.free()
					get_tree().quit(1)
					return
				instance = batch
			else:
				var single := MeshInstance3D.new()
				single.mesh = mesh
				instance = single
			instance.name = ("SourceMesh_%d" if batch_key.is_empty() else "SourceBatch_%d") % i
			if not batch_key.is_empty():
				# The source fades one part at a time; a whole-building fade would substitute it.
				instance.set_meta("noViewOcclusion", true)
				building_batches[batch_key] = _batch_begin(mesh)
				if not _batch_append(building_batches[batch_key], entry, i):
					instance.free()
					scene_root.free()
					get_tree().quit(1)
					return
			if entry.has("outlineUniforms"):
				var matrix: Array = entry.outlineFrame
				instance.transform = Transform3D(Basis(Vector3(matrix[0], matrix[1], matrix[2]),
					Vector3(matrix[4], matrix[5], matrix[6]), Vector3(matrix[8], matrix[9], matrix[10])), Vector3(matrix[12], matrix[13], matrix[14]))
				instance.set_meta("isOutline", true)
				instance.set_meta("source_outline_uniforms", entry.outlineUniforms)
				instance.set_meta("source_outline_frustum_culled", entry.frustumCulled)
			instance.visible = bool(entry.get("visible", true))
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry.get("castShadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if not str(entry.get("sourceBuildingKey", "")).is_empty():
				instance.set_meta("source_building_key", entry.sourceBuildingKey)
			if entry.get("sourceCampBuildingBatch", false):
				instance.set_meta("source_camp_building_batch", true)
			if entry.has("sourceCampLandmark"):
				instance.set_meta("source_camp_landmark", entry.sourceCampLandmark)
			if entry.has("sourceWildlifeMesh"):
				if not instance is MultiMeshInstance3D:
					push_error("Original wildlife requires an instanced mesh: " + file)
					get_tree().quit(1)
					return
				instance.set_meta("source_wildlife_mesh", int(entry.sourceWildlifeMesh))
			if entry.has("sourcePetalMesh"):
				if not instance is MultiMeshInstance3D:
					push_error("Original petals require an instanced mesh: " + file)
					get_tree().quit(1)
					return
				instance.set_meta("source_petal_mesh", int(entry.sourcePetalMesh))
			if entry.has("sourceAquaticMesh"):
				if not instance is MultiMeshInstance3D:
					push_error("Original aquatic fauna/bubbles require an instanced mesh: " + file)
					get_tree().quit(1)
					return
				instance.set_meta("source_aquatic_mesh", int(entry.sourceAquaticMesh))
			var colored: bool = not entry.colors.is_empty() or entry.has("instanceColors")
			if entry.has("surfaces"):
				for surface in range(mesh.get_surface_count()):
					var material := _material(entry.surfaces[surface], colored, entry.has("instanceColors"), entry.get("marineFrame", []), entry.get("receiveShadow", false), not entry.colors.is_empty())
					if material == null:
						get_tree().quit(1)
						return
					if entry.get("water", false):
						material.render_priority = int(entry.get("renderOrder", 0))
					mesh.surface_set_material(surface, material)
			else:
				var material := _material(entry, colored, entry.has("instanceColors"), entry.get("marineFrame", []), entry.get("receiveShadow", false), not entry.colors.is_empty())
				if material == null:
					get_tree().quit(1)
					return
				if entry.get("water", false):
					material.render_priority = int(entry.get("renderOrder", 0))
				instance.material_override = material
			if not str(entry.get("climbArrow", "")).is_empty():
				instance.set_meta("source_climb_arrow", entry.climbArrow)
			if entry.get("water", false):
				instance.set_meta("source_water", true)
				instance.set_meta("source_marine_frame", entry.marineFrame)
				instance.set_meta("source_marine_receive_shadow", entry.get("receiveShadow", false))
				instance.set_meta("source_marine_frustum_culled", entry.get("frustumCulled", true))
			if entry.get("tideWater", false):
				instance.set_meta("source_tide_water", true)
			var parent: Node3D = scene_root
			if entry.has("sourceMotionId"):
				parent = motion_pivots.get(int(entry.sourceMotionId))
			elif entry.has("sourceTrainId"):
				parent = train_visuals.get(int(entry.sourceTrainId))
			if parent == null:
				push_error("Source mesh has no captured motion root: " + file)
				get_tree().quit(1)
				return
			parent.add_child(instance)
			instance.owner = scene_root
			if entry.terrain:
				if entry.has("instances"):
					push_error("Terrain collision requires the original non-instanced mesh: " + file)
					get_tree().quit(1)
					return
				var body := StaticBody3D.new()
				body.name = "TerrainCollision"
				body.collision_layer = 1 | TERRAIN_LAYER
				instance.add_child(body)
				body.owner = scene_root
				var collision := CollisionShape3D.new()
				collision.shape = mesh.create_trimesh_shape()
				collision.shape.backface_collision = true
				body.add_child(collision)
				collision.owner = scene_root
		if not source_meshes.valid:
			scene_root.free()
			get_tree().quit(1)
			return
		for batch: Dictionary in building_batches.values():
			_batch_finish(batch)
		building_batches.clear()
		var structure_body := StaticBody3D.new()
		structure_body.name = "StructureCollision"
		structure_body.collision_layer = 1 | STRUCTURE_LAYER
		scene_root.add_child(structure_body)
		structure_body.owner = scene_root
		for deck in data.decks:
			_ribbon(structure_body, scene_root, deck, deck.y1 - data.collision.deckThickness, deck.y2 - data.collision.deckThickness, deck.y1, deck.y2)
			# The source deck query has rectangular endpoint tolerance beyond its rendered mesh.
			for cap in _end_caps(deck, data.collision.deckEndTolerance):
				var height: float = deck.y1 if cap.start else deck.y2
				_ribbon(structure_body, scene_root, cap, height - data.collision.deckThickness, height - data.collision.deckThickness, height, height)
		var floors := Node3D.new()
		floors.name = "TunnelFloors"
		scene_root.add_child(floors)
		floors.owner = scene_root
		var roof_body := _body(scene_root, "TunnelRoofs", 64)
		var wall_body := _body(scene_root, "TunnelWalls", 128)
		var column_body := _body(scene_root, "StructureColumns", 256)
		for tunnel_index in range(data.tunnels.size()):
			var tunnel: Dictionary = data.tunnels[tunnel_index]
			var floor_body := StaticBody3D.new()
			floor_body.name = "Floor_%d" % tunnel_index
			floor_body.collision_layer = 1 | 32
			floors.add_child(floor_body)
			floor_body.owner = scene_root
			_floor(floor_body, scene_root, tunnel, tunnel.fy1, tunnel.fy2)
			if not tunnel.get("open", false):
				_ribbon(roof_body, scene_root, tunnel, tunnel.cy1, tunnel.cy2, tunnel.cy1 + data.collision.roofThickness, tunnel.cy2 + data.collision.roofThickness)
			for side in [-1, 1]:
				var bit := 1 if side == 1 else 2
				if (int(tunnel.get("gal", 0)) & bit) != 0:
					continue
				var wall: Dictionary = tunnel.duplicate()
				var direction := Vector2(tunnel.x2 - tunnel.x1, tunnel.z2 - tunnel.z1).normalized()
				var normal := Vector2(direction.y, -direction.x)
				wall.x1 += normal.x * side * tunnel.hw
				wall.z1 += normal.y * side * tunnel.hw
				wall.x2 += normal.x * side * tunnel.hw
				wall.z2 += normal.y * side * tunnel.hw
				_wall(wall_body, scene_root, wall, tunnel.fy1, tunnel.fy2, tunnel.get("by1", tunnel.cy1), tunnel.get("by2", tunnel.cy2))
		for index in range(data.columns.size()):
			var column: Dictionary = data.columns[index]
			var collision := CollisionShape3D.new()
			collision.set_meta("source_column_index", index)
			collision.position = Vector3(column.x, column.y + column.h / 2, column.z)
			if column.has("hw2") and column.has("hd2"):
				var box := BoxShape3D.new()
				box.size = Vector3(column.hw2 * 2, column.h, column.hd2 * 2)
				collision.shape = box
				collision.rotation.y = column.get("ry", 0)
			else:
				var cylinder := CylinderShape3D.new()
				cylinder.radius = column.r
				cylinder.height = column.h
				collision.shape = cylinder
			column_body.add_child(collision)
			collision.owner = scene_root
		var supports_captured := bool(data.get("supportsCaptured", false))
		if supports_captured:
			if not data.get("roofPlatforms") is Array or not data.get("sourceBuildings") is Array:
				push_error("Missing original scenery support capture: " + file)
				get_tree().quit(1)
				return
			var roof_platform_body := _body(scene_root, "BuildingRoofPlatforms", 1024)
			for index in range(data.roofPlatforms.size()):
				var platform: Dictionary = data.roofPlatforms[index]
				if not platform.get("faces") is Array or platform.faces.is_empty() or platform.faces.size() % 9 != 0:
					push_error("Missing original triangulated roof support: " + file)
					get_tree().quit(1)
					return
				var faces := PackedVector3Array()
				for offset in range(0, platform.faces.size(), 3):
					var point := Vector3(platform.faces[offset], platform.faces[offset + 1], platform.faces[offset + 2])
					if not point.is_finite():
						push_error("Invalid original roof support vertex: " + file)
						get_tree().quit(1)
						return
					faces.append(point)
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				shape.backface_collision = true
				var collision := CollisionShape3D.new()
				collision.shape = shape
				collision.disabled = platform.get("active", true) == false
				collision.set_meta("source_roof_platform_index", index)
				roof_platform_body.add_child(collision)
				collision.owner = scene_root
		var resource := WorldData.new()
		resource.scene = PackedScene.new()
		print("WORLD_SCENE_PACK_BEGIN ", file)
		if resource.scene.pack(scene_root) != OK:
			push_error("Cannot pack world: " + file)
			get_tree().quit(1)
			return
		print("WORLD_SCENE_PACK_PASS ", file)
		resource.bounds = data.bounds
		resource.minimap_base = ImageTexture.create_from_image(minimap_image)
		resource.source = data.source
		resource.slabs_captured = true
		resource.authority_slabs = data.acceptedSlabs
		resource.decks = data.decks
		resource.tunnels = data.tunnels
		resource.columns = data.columns
		resource.trains_captured = bool(data.get("trainsCaptured", false))
		resource.source_trains = trains
		resource.motions_captured = bool(data.get("motionsCaptured", false))
		resource.source_motions = motions
		resource.wildlife_captured = bool(data.get("wildlifeCaptured", false))
		if resource.wildlife_captured:
			if not data.get("wildlife") is Dictionary or not data.wildlife.get("variants") is Array or not data.wildlife.get("footprints") is Dictionary \
					or not data.wildlife.get("catalogCaptured", false) or not data.wildlife.get("catalogs") is Array:
				push_error("Missing original wildlife route-capacity catalog/habitat index: " + file)
				get_tree().quit(1)
				return
			resource.source_wildlife = data.wildlife
		resource.petals_captured = bool(data.get("petalsCaptured", false))
		if resource.petals_captured:
			if not data.get("petals") is Dictionary or not data.petals.get("variants") is Array:
				push_error("Missing original petal season/power-mode rosters: " + file)
				get_tree().quit(1)
				return
			resource.source_petals = data.petals
		resource.aquatics_captured = bool(data.get("aquaticsCaptured", false))
		if resource.aquatics_captured:
			if not data.get("aquatics") is Dictionary or not data.aquatics.get("systems") is Array:
				push_error("Missing original aquatic fauna/bubble rosters: " + file)
				get_tree().quit(1)
				return
			resource.source_aquatics = data.aquatics
		resource.marine_captured = bool(data.get("marineCaptured", false))
		if resource.marine_captured:
			resource.source_marine = data.marine
			resource.marine_programs.assign(marine_programs)
			resource.marine_depth_field = marine_depth_field
		resource.supports_captured = supports_captured
		if supports_captured:
			if not data.get("structurePads") is Dictionary or not data.structurePads.get("tower") is Array or not data.structurePads.get("base") is Array:
				push_error("Missing original tower/base platform anchors: " + file)
				get_tree().quit(1)
				return
			resource.structure_pads = data.structurePads
			resource.roof_platforms = data.roofPlatforms
			resource.source_buildings = data.sourceBuildings
		if not data.has("corridors"):
			push_error("Missing original corridor clearance capture: " + file)
			get_tree().quit(1)
			return
		resource.corridors = data.corridors
		resource.probes = data.probes
		resource.lane_heights = data.laneHeights
		resource.deck_probes = data.deckProbes
		resource.min_height = data.minH
		resource.max_height = data.maxH
		resource.average_height = data.avgH
		resource.ceiling = data.ceiling
		if not data.has("heightField") or not data.has("waterProfile"):
			push_error("Missing original terrain/water capture: " + file)
			get_tree().quit(1)
			return
		resource.terrain_grid = int(data.grid)
		resource.terrain_heights = PackedFloat32Array(data.heightField)
		resource.water_profile = data.waterProfile
		if resource.water_profile.get("borderBands", false) and not EnvironmentRules.valid_border_mask(resource.water_profile.get("borderMask")):
			push_error("Missing/invalid original border dry mask: " + file)
			get_tree().quit(1)
			return
		resource.climbs_captured = bool(data.get("climbsCaptured", false))
		if resource.climbs_captured:
			if not supports_captured:
				push_error("Climbing requires complete original scenery supports: " + file)
				get_tree().quit(1)
				return
			if not data.get("climbs") is Array or not data.get("climbFacilitiesCaptured", false):
				push_error("Original climb routes require their matching source facilities: " + file)
				get_tree().quit(1)
				return
			resource.climb_routes = data.climbs
			if not resource.climb_routes.is_empty() and not source_meshes.has_climb_mesh:
				push_error("Captured climb routes have no original facility meshes: " + file)
				get_tree().quit(1)
				return
			for route: Dictionary in resource.climb_routes:
				for key: String in ["x", "z", "y0", "y1", "nx", "nz", "bx", "bz", "tx", "tz"]:
					var value: Variant = route.get(key)
					if not (value is float or value is int):
						push_error("Missing/invalid original climb route field: " + file + ": " + key)
						get_tree().quit(1)
						return
					if not is_finite(float(value)):
						push_error("Missing/invalid original climb route field: " + file + ": " + key)
						get_tree().quit(1)
						return
				if float(route.y1) <= float(route.y0) or not Content.balance.movement.climb.notices.has(route.get("kind", "")):
					push_error("Unsupported original climb route: " + file)
					get_tree().quit(1)
					return
		var target := output + "/" + file.get_basename() + ".res"
		print("WORLD_RESOURCE_SAVE_BEGIN ", file, " shared_materials=", cel_data.material_sources.size())
		var error: Error = await ResourcePublisher.publish(resource, target, get_tree())
		scene_root.free()
		if error != OK:
			push_error(error_string(error))
			get_tree().quit(1)
			return
		print("WORLD_IMPORTED ", file.get_basename())
		imported[target] = true
	for target: String in required:
		if not imported.has(target):
			push_error("Missing original seasonal world bundle: " + target)
			get_tree().quit(1)
			return
	get_tree().quit()

static func _publish_marine_program(code: String, directory: String, tree: SceneTree) -> Dictionary:
	var path := directory.path_join(code.sha256_text() + ".gdshaderinc")
	if FileAccess.file_exists(path):
		if FileAccess.get_sha256(path) != code.sha256_text():
			return {"program": null, "error": "Corrupt original native marine shader include: " + path}
	else:
		var program := ShaderInclude.new()
		program.code = code
		var error := await ResourcePublisher.publish(program, path, tree)
		if error != OK:
			return {"program": null, "error": "Cannot publish original native marine shader include: " + error_string(error)}
	var reloaded := ResourceLoader.load(path, "ShaderInclude", ResourceLoader.CACHE_MODE_IGNORE) as ShaderInclude
	if reloaded == null or reloaded.code != code:
		return {"program": null, "error": "Cannot reload original native marine shader include: " + path}
	return {"program": reloaded, "error": ""}

func _body(scene_root: Node3D, label: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1 | layer
	scene_root.add_child(body)
	body.owner = scene_root
	return body

func _end_caps(segment: Dictionary, tolerance: float) -> Array:
	var a := Vector2(segment.x1, segment.z1)
	var b := Vector2(segment.x2, segment.z2)
	if a == b or tolerance <= 0:
		return []
	var direction := (b - a).normalized()
	var start := a - direction * tolerance
	var finish := b + direction * tolerance
	return [
		{"x1": start.x, "z1": start.y, "x2": a.x, "z2": a.y, "hw": segment.hw, "start": true},
		{"x1": b.x, "z1": b.y, "x2": finish.x, "z2": finish.y, "hw": segment.hw, "start": false}]

func _mesh(entry: Dictionary) -> ArrayMesh:
	var surfaces: Variant = _surface_arrays(entry)
	if surfaces == null:
		return null
	var mesh := ArrayMesh.new()
	if entry.has("sourceWorldText"):
		mesh.set_meta("source_world_text", entry.sourceWorldText.duplicate(true))
	mesh.set_meta("source_custom_attributes", entry.get("attributes", {}))
	if entry.has("celGeometry"):
		mesh.set_meta("source_cel_geometry", entry.celGeometry)
	for surface: Dictionary in surfaces:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.arrays, [], {}, surface.flags)
	return mesh

# Godot caps one RID owner at 262,144 entries, and Berlin has 400,000+ building parts.
# Returns an empty key for a mesh that must keep its own node.
func _batch_key(entry: Dictionary) -> String:
	if str(entry.get("sourceBuildingKey", "")).is_empty() or entry.get("transparent", false) or entry.get("terrain", false) or entry.get("water", false):
		return ""
	for field: String in BATCH_EXCLUDED_FIELDS:
		if entry.has(field):
			return ""
	var cel: Variant = entry.get("celGeometry")
	if not entry.get("attributes", {}).is_empty() or not cel is Dictionary or not cel.get("frame") is PackedFloat64Array or cel.frame.size() != 16 \
			or not cel.get("positions") is PackedFloat64Array or cel.positions.size() != entry.positions.size() \
			or not cel.get("normals") is PackedFloat64Array or cel.normals.size() != entry.normals.size():
		return ""
	var shape := entry.duplicate()
	for field: String in BATCH_GEOMETRY_FIELDS:
		shape.erase(field)
	shape["batchFormat"] = [entry.normals.size() == entry.positions.size(), entry.get("uv", []).size() * 3 == entry.positions.size() * 2, entry.colors.is_empty()]
	return JSON.stringify(shape, "", false, true)

func _batch_begin(mesh: ArrayMesh) -> Dictionary:
	return {"mesh": mesh, "flags": 0, "vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uv": PackedVector2Array(),
		"colors": PackedFloat32Array(), "indices": PackedInt32Array(), "sources": PackedInt32Array(), "vertex_starts": PackedInt32Array([0]),
		"index_starts": PackedInt32Array([0]), "cel_frames": PackedFloat64Array(), "cel_positions": PackedFloat32Array(), "cel_normals": PackedFloat32Array()}

func _batch_append(batch: Dictionary, entry: Dictionary, source_index: int) -> bool:
	var surfaces: Variant = _surface_arrays(entry)
	if surfaces == null:
		return false
	var cel_positions: Variant = _float32_words(entry.celGeometry.positions)
	var cel_normals: Variant = _float32_words(entry.celGeometry.normals)
	if cel_positions == null or cel_normals == null:
		push_error("Original cel local geometry is not Float32: mesh %d" % source_index)
		return false
	var arrays: Array = surfaces[0].arrays
	var base: int = batch.vertices.size()
	batch.flags = surfaces[0].flags
	batch.vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
	if arrays[Mesh.ARRAY_NORMAL] != null:
		batch.normals.append_array(arrays[Mesh.ARRAY_NORMAL])
	if arrays[Mesh.ARRAY_TEX_UV] != null:
		batch.uv.append_array(arrays[Mesh.ARRAY_TEX_UV])
	if arrays[SourceCelVertexColors.ARRAY_SLOT] != null:
		batch.colors.append_array(arrays[SourceCelVertexColors.ARRAY_SLOT])
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for offset in range(indices.size()):
		indices[offset] += base
	batch.indices.append_array(indices)
	batch.sources.append(source_index)
	batch.vertex_starts.append(batch.vertices.size())
	batch.index_starts.append(batch.indices.size())
	batch.cel_frames.append_array(entry.celGeometry.frame)
	batch.cel_positions.append_array(cel_positions)
	batch.cel_normals.append_array(cel_normals)
	return true

func _batch_finish(batch: Dictionary) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = batch.vertices
	arrays[Mesh.ARRAY_INDEX] = batch.indices
	if not batch.normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
	if not batch.uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = batch.uv
	if not batch.colors.is_empty():
		arrays[SourceCelVertexColors.ARRAY_SLOT] = batch.colors
	var mesh: ArrayMesh = batch.mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, batch.flags)
	mesh.set_meta("source_batch", {"sources": batch.sources, "vertex_starts": batch.vertex_starts, "index_starts": batch.index_starts,
		"cel_frames": batch.cel_frames, "cel_positions": batch.cel_positions, "cel_normals": batch.cel_normals})

# Godot truncates long plain decimals (4.3e-12 relative seen at 1.8e-6). JavaScript prints
# plain decimals down to 1e-6, so 1e-10 stays 600 times below Float32 half-spacing.
func _float32_words(values: PackedFloat64Array) -> Variant:
	var words := PackedFloat32Array(Array(values))
	for index in range(values.size()):
		if absf(values[index] - words[index]) > absf(float(words[index])) * 1e-10:
			return null
	return words

func _surface_arrays(entry: Dictionary) -> Variant:
	if entry.has("sourceWorldText"):
		var text: Variant = entry.sourceWorldText
		if not text is Dictionary or not text.get("glow") is Array or text.glow.size() * 3 != entry.positions.size():
			push_error("Invalid original world-text glow layout")
			return null
		for value: Variant in text.glow:
			if not (value is int or value is float) or not is_finite(float(value)):
				push_error("Invalid original world-text glow value")
				return null
			if float(value) > 0:
				push_error("Original world-text glow requires the accepted shared cel sign shader contract")
				return null
	var color_size := int(entry.get("colorSize", 3))
	if color_size not in [3, 4] or entry.positions.size() % 3 != 0 or entry.normals.size() % 3 != 0 or entry.colors.size() % color_size != 0 or entry.get("uv", []).size() % 2 != 0:
		push_error("Invalid original world vertex attribute layout")
		return null
	var positions := PackedVector3Array()
	for i in range(0, entry.positions.size(), 3):
		positions.append(Vector3(entry.positions[i], entry.positions[i + 1], entry.positions[i + 2]))
	var normals := PackedVector3Array()
	for i in range(0, entry.normals.size(), 3):
		normals.append(Vector3(entry.normals[i], entry.normals[i + 1], entry.normals[i + 2]))
	# Water keeps its marine program and RGBA8 colours; every other active colour is Float32.
	var colors := PackedColorArray()
	var marine_colors := false
	for surface: Dictionary in entry.get("surfaces", [entry]):
		if surface.get("vertexColors", false) and surface.has("marine"):
			marine_colors = true
			break
	if marine_colors:
		for i in range(0, entry.colors.size(), color_size):
			var color := Color(entry.colors[i], entry.colors[i + 1], entry.colors[i + 2], entry.colors[i + 3] if color_size == 4 else 1.0)
			if color != color.clamp():
				push_error("Original water vertex colors outside [0, 1] require accepted float-color shader storage")
				return null
			colors.append(color)
	var float_colors := PackedFloat32Array()
	var uv := PackedVector2Array()
	var coordinates: Array = entry.get("uv", [])
	for i in range(0, coordinates.size(), 2):
		uv.append(Vector2(coordinates[i], coordinates[i + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	if normals.size() == positions.size():
		arrays[Mesh.ARRAY_NORMAL] = normals
	if uv.size() == positions.size():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	var flags := 0
	if entry.has("seaFade"):
		var fade: Array = entry.seaFade
		var origins: Array = entry.get("reflectionOrigins", [])
		if fade.size() != positions.size() or (not origins.is_empty() and origins.size() != positions.size() * 3):
			push_error("Invalid original marine fade/reflection vertex layout")
			return null
		var custom := PackedFloat32Array()
		for index in range(positions.size()):
			for axis in range(3):
				custom.append(origins[index * 3 + axis] if not origins.is_empty() else 0.0)
			custom.append(fade[index])
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		flags = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var local_positions: Array = entry.get("marinePositions", [])
		if local_positions.size() != positions.size() * 3 or entry.get("marineFrame", []).size() != 16:
			push_error("Missing original marine local vertices/model matrix")
			return null
		arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array(local_positions)
		flags |= Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	var result := []
	for surface: Dictionary in entry.get("surfaces", [entry]):
		# Instance tint remains active without enabling an ignored vertex-colour attribute.
		var surface_flags := flags
		arrays[Mesh.ARRAY_COLOR] = null
		arrays[SourceCelVertexColors.ARRAY_SLOT] = null
		if surface.get("vertexColors", false) and entry.colors.size() == positions.size() * color_size:
			if surface.has("marine"):
				arrays[Mesh.ARRAY_COLOR] = colors
			else:
				if float_colors.is_empty():
					var encoded := SourceCelVertexColors.encode(_float32_colors(entry.colors), color_size, positions.size())
					if not encoded.ok:
						push_error(encoded.error)
						return null
					float_colors = encoded.value
				arrays[SourceCelVertexColors.ARRAY_SLOT] = float_colors
				surface_flags |= SourceCelVertexColors.FORMAT
		arrays[Mesh.ARRAY_TEX_UV] = uv if uv.size() == positions.size() else null
		if surface.has("texture"):
			var texture: Dictionary = surface.texture
			var channel := int(texture.get("channel", 0))
			var raw_uv: Array = entry.get("uv" if channel == 0 else "uv" + str(channel), [])
			if raw_uv.size() != positions.size() * 2 or texture.matrix.size() != 9:
				push_error("Missing original material UV channel/transform")
				return null
			var transformed := PackedVector2Array()
			for offset in range(0, raw_uv.size(), 2):
				var point := SourceTextureImages.coordinates(Vector2(raw_uv[offset], raw_uv[offset + 1]), texture)
				if not point.is_finite():
					push_error("Non-finite original world texture coordinates")
					return null
				transformed.append(point)
			arrays[Mesh.ARRAY_TEX_UV] = transformed
		var indices := PackedInt32Array()
		# Godot's front-face winding is opposite Three.js; vertices and normals stay unchanged.
		for i in range(0, surface.index.size(), 3):
			indices.append_array(PackedInt32Array([int(surface.index[i]), int(surface.index[i + 2]), int(surface.index[i + 1])]))
		arrays[Mesh.ARRAY_INDEX] = indices
		result.append({"arrays": arrays.duplicate(), "flags": surface_flags})
	return result

# The source stores Float32 colours, but Godot's decimal parser accumulates digits
# and can move an inline double by several ulps (1.3e-15 relative observed). Snap
# only values within 1e-12 of their Float32 neighbour, four orders below the 6e-8
# half-spacing of Float32; anything else stays unchanged so
# SourceCelVertexColors.encode rejects it.
func _float32_colors(values: Array) -> PackedFloat64Array:
	var narrowed := PackedFloat32Array(values)
	var result := PackedFloat64Array(values)
	for index in range(result.size()):
		var exact := narrowed[index]
		if absf(result[index] - exact) <= absf(exact) * 1e-12:
			result[index] = exact
	return result

func _material(spec: Dictionary, colored: bool, instance_colors: bool, source_frame: Array, receive_shadow: bool, vertex_data := false) -> Material:
	var material := StandardMaterial3D.new()
	if spec.has("cel"):
		if not cel_data.attach(material, spec.cel):
			return null
	if spec.has("marine"):
		material.set_meta("source_marine", spec.marine)
		var program_index := int(spec.marine.get("program", -1))
		if program_index < 0 or program_index >= marine_programs.size():
			push_error("Original water material has no captured native shader program")
			return null
		material.set_meta("source_marine_program", marine_programs[program_index])
	material.vertex_color_use_as_albedo = (colored and spec.get("vertexColors", true)) or instance_colors
	material.albedo_color = Color.hex((int(spec.albedoHex) << 8) | 0xff) if spec.has("albedoHex") else Color(spec.albedo[0], spec.albedo[1], spec.albedo[2])
	material.albedo_color.a = float(spec.opacity)
	material.roughness = float(spec.get("roughness", 0.95))
	material.metallic = float(spec.get("metalness", 0))
	var side := int(spec.get("side", 2))
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if side == 2 else BaseMaterial3D.CULL_FRONT if side == 1 else BaseMaterial3D.CULL_BACK
	material.no_depth_test = not spec.get("depthTest", true)
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS if spec.get("depthWrite", true) else BaseMaterial3D.DEPTH_DRAW_DISABLED
	if spec.has("texture"):
		material.albedo_texture = source_textures.resolve(spec.texture)
		if material.albedo_texture == null or not SourceTextureImages.apply_sampling(material, spec.texture):
			return null
	if spec.get("unshaded", false):
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if int(spec.get("blending", 1)) == 2:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if float(spec.get("alphaTest", 0)) > 0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = float(spec.alphaTest)
	elif spec.transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if int(spec.get("emissionHex", 0)) != 0:
		material.emission_enabled = true
		material.emission = Color.hex((int(spec.emissionHex) << 8) | 0xff)
		material.emission_energy_multiplier = float(spec.get("emissionIntensity", 1))
	if spec.has("marine"):
		var field_id := int(spec.marine.get("weatherField", {}).get("image", -1))
		if field_id < 0 or field_id >= source_textures.images.size():
			push_error("Missing original marine weathering texture")
			return null
		var field := ImageTexture.create_from_image(source_textures.images[field_id])
		var surface := MarineSurfaceMaterial.create(material, spec, material.get_meta("source_marine_program"), field)
		var binding := MarineShaderBinding.new()
		if not binding.configure(surface, spec.marine, marine_source, marine_depth_field) or not binding.configure_geometry(source_frame, receive_shadow):
			return null
		return binding.material
	if material.vertex_color_use_as_albedo:
		# Consumers read this surface's state from uSourceAlbedo, never albedo_color.
		return SourceCelVertexColors.material(material, vertex_data and spec.get("vertexColors", false))
	return material

func _ribbon(body: StaticBody3D, scene_root: Node3D, segment: Dictionary, bottom_a: float, bottom_b: float, top_a: float, top_b: float) -> void:
	var a := Vector3(segment.x1, 0, segment.z1)
	var b := Vector3(segment.x2, 0, segment.z2)
	if a == b or (top_a <= bottom_a and top_b <= bottom_b):
		return
	var right: Vector3 = (b - a).normalized().cross(Vector3.UP) * segment.hw
	var vertices := PackedVector3Array()
	for record in [[a, bottom_a, top_a], [b, bottom_b, top_b]]:
		for side in [-1, 1]:
			for y in [record[1], record[2]]:
				var point: Vector3 = record[0] + right * side
				point.y = y
				vertices.append(point)
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	shape.margin = 0.0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_root

func _wall(body: StaticBody3D, scene_root: Node3D, segment: Dictionary, bottom_a: float, bottom_b: float, top_a: float, top_b: float) -> void:
	if top_a <= bottom_a and top_b <= bottom_b:
		return
	var a := Vector3(segment.x1, bottom_a, segment.z1)
	var b := Vector3(segment.x2, bottom_b, segment.z2)
	var c := Vector3(segment.x1, top_a, segment.z1)
	var d := Vector3(segment.x2, top_b, segment.z2)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([a, b, c, c, b, d]))
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_root

func _floor(body: StaticBody3D, scene_root: Node3D, segment: Dictionary, height_a: float, height_b: float) -> void:
	var a := Vector3(segment.x1, height_a, segment.z1)
	var b := Vector3(segment.x2, height_b, segment.z2)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	if flat == Vector3.ZERO:
		return
	var right: Vector3 = flat.normalized().cross(Vector3.UP) * segment.hw
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([a - right, a + right, b - right, a + right, b + right, b - right]))
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	collision.owner = scene_root

