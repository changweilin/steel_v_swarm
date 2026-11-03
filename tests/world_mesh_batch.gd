extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var importer := preload("res://tools/import_worlds.gd").new()
	_eligibility(importer)
	_members(importer)
	importer.free()
	print("WORLD_MESH_BATCH assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func _part(offset: float, key: String = "b1") -> Dictionary:
	var positions := [offset, 0, 0, offset + 1, 0, 0, offset, 1, 0]
	return {"positions": positions, "normals": [0, 0, 1, 0, 0, 1, 0, 0, 1], "colors": [.25, .5, .75, .25, .5, .75, .25, .5, .75], "colorSize": 3,
		"uv": [0, 0, 1, 0, 0, 1], "index": [0, 1, 2], "vertexColors": true, "albedo": [1, 1, 1], "transparent": false, "terrain": false, "water": false,
		"visible": true, "castShadow": true, "sourceBuildingKey": key, "attributes": {},
		"celGeometry": {"frame": PackedFloat64Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, offset, 0, 0, 1]),
			"positions": PackedFloat64Array([0, 0, 0, 1, 0, 0, 0, 1, 0]), "normals": PackedFloat64Array([0, 0, 1, 0, 0, 1, 0, 0, 1])}}

func _eligibility(importer: Node) -> void:
	var key: String = importer._batch_key(_part(0))
	_check(not key.is_empty(), "Ordinary static building part is batchable")
	_check(importer._batch_key(_part(5)) == key, "Geometry and source order never split a batch")
	_check(importer._batch_key(_part(0, "b2")) != key, "Parts of different buildings never share camp clearance")
	var unowned := _part(0)
	unowned.erase("sourceBuildingKey")
	_check(importer._batch_key(unowned).is_empty(), "Scenery without a building owner keeps its own node")
	for field: String in preload("res://tools/import_worlds.gd").BATCH_EXCLUDED_FIELDS:
		var excluded := _part(0)
		excluded[field] = 1
		_check(importer._batch_key(excluded).is_empty(), "Per-mesh consumer field keeps its own node: " + field)
	for field: String in ["transparent", "terrain", "water"]:
		var excluded := _part(0)
		excluded[field] = true
		_check(importer._batch_key(excluded).is_empty(), "Draw-order or authority mesh keeps its own node: " + field)
	var attributed := _part(0)
	attributed.attributes = {"aSurfId": {}}
	_check(importer._batch_key(attributed).is_empty(), "Custom attributes keep their own node")
	var mismatched := _part(0)
	mismatched.celGeometry.positions = PackedFloat64Array([0, 0, 0])
	_check(importer._batch_key(mismatched).is_empty(), "Inconsistent cel geometry keeps its own node")
	var bare := _part(0)
	bare.normals = []
	bare.celGeometry.normals = PackedFloat64Array()
	_check(not importer._batch_key(bare).is_empty() and importer._batch_key(bare) != key, "A different vertex format never shares a surface")
	var material := _part(0)
	material.albedo = [1, 1, .5]
	_check(importer._batch_key(material) != key, "A different material never shares a surface")
	var tiny := _part(0)
	tiny.albedo = [1, 1, 1.0000000000001]
	_check(importer._batch_key(tiny) != key, "Near-equal doubles never share a material")

func _members(importer: Node) -> void:
	var mesh := ArrayMesh.new()
	var batch: Dictionary = importer._batch_begin(mesh)
	_check(importer._batch_append(batch, _part(0), 7) and importer._batch_append(batch, _part(5), 9), "Two parts append")
	_check(importer._float32_words(PackedFloat64Array([.1])) == null, "Non-Float32 cel geometry rejects instead of rounding")
	var parsed: float = JSON.parse_string("[0.0000018122514120477717]")[0]
	_check(importer._float32_words(PackedFloat64Array([parsed])) != null, "Decimal parser drift still names its source Float32 word")
	importer._batch_finish(batch)
	var members: Dictionary = mesh.get_meta("source_batch", {})
	_check(mesh.get_surface_count() == 1 and members.sources == PackedInt32Array([7, 9]), "One surface retains source member order")
	_check(members.vertex_starts == PackedInt32Array([0, 3, 6]) and members.index_starts == PackedInt32Array([0, 3, 6]), "Member ranges are contiguous")
	_check(members.cel_frames.size() == 32 and members.cel_frames[28] == 5.0, "Each member keeps its own cel frame")
	_check(members.cel_positions.size() == 18 and members.cel_normals.size() == 18, "Each member keeps its local vertices and normals")
	DirAccess.make_dir_recursive_absolute("res://build")
	var path := "res://build/sol-world-mesh-batch.res"
	_check(ResourceSaver.save(mesh, path) == OK, "Batched mesh can be published as a resource")
	var reloaded := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	_check(reloaded != null and reloaded.get_meta("source_batch") == members, "Native reload retains exact member tables")
	if reloaded != null and DisplayServer.get_name() != "headless":
		var arrays := reloaded.surface_get_arrays(0)
		_check(arrays[Mesh.ARRAY_VERTEX][3] == Vector3(5, 0, 0), "Second part keeps its baked vertices")
		_check(arrays[Mesh.ARRAY_INDEX] == PackedInt32Array([0, 2, 1, 3, 5, 4]), "Second part's reflected winding is rebased")
		_check((arrays[SourceCelVertexColors.ARRAY_SLOT] as PackedFloat32Array).size() == 24, "Float32 colours cover every vertex")
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Batch fixture removes its own output")
