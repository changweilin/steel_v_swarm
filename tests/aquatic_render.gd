extends Node

const Raster = preload("res://tests/raster_compare.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Aquatic point raster certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var fixtures: Dictionary = _captured_fixtures() if OS.get_cmdline_user_args().has("--source-capture") else Content.read_json("res://data/fixtures.json", ["aquaticPointRasters"])
	if not fixtures.has("aquaticPointRasters"):
		push_error("Regenerate original PointsMaterial WebGL raster references")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://build/aquatic_render")
	var failures := 0
	for index in range(fixtures.aquaticPointRasters.size()):
		var item: Dictionary = fixtures.aquaticPointRasters[index]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(item.width, item.height)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var world_environment := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color.BLACK
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		world_environment.environment = environment
		viewport.add_child(world_environment)
		var camera := Camera3D.new()
		camera.position.z = float(item.depth)
		camera.fov = float(item.fov)
		camera.near = 0.1
		camera.far = 100
		viewport.add_child(camera)
		camera.current = true
		viewport.add_child(AquaticDetritus.create_node(item.source))
		for frame in range(3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) != OK or expected.get_size() != actual.get_size():
			push_error("Invalid original aquatic point raster dimensions")
			get_tree().quit(1)
			return
		var result := Raster.compare(actual, expected)
		if int(result.pixels) > 0:
			failures += 1
			Raster.diagnostic(actual).save_png("res://build/aquatic_render/native_%d.png" % index)
			expected.save_png("res://build/aquatic_render/source_%d.png" % index)
			push_error("AQUATIC_RASTER_MISMATCH case=%d pixels=%d maximum=%f" % [index, int(result.pixels), float(result.maximum)])
		viewport.free()
	print("AQUATIC_RENDER_PASS" if failures == 0 else "AQUATIC_RENDER_FAIL", " cases=", fixtures.aquaticPointRasters.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _captured_fixtures() -> Dictionary:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/aquatic_points.json")
	if capture.get("formatVersion") != 1 or not capture.get("source") is Dictionary or not capture.get("fixtures") is Dictionary:
		push_error("Capture original aquatic point rasters before native verification")
		return {}
	if not capture.source.get("inputs") is Dictionary or capture.source.inputs.is_empty() or not capture.source.get("sourceInputs") is Dictionary or capture.source.sourceInputs.is_empty() \
			or not capture.fixtures.get("aquaticPointRasters") is Array or capture.fixtures.aquaticPointRasters.is_empty():
		push_error("Aquatic point capture requires source identities and nonempty raster cases")
		return {}
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in capture.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		if text.sha256_text() != capture.source.inputs[path]:
			push_error("Stale aquatic point capture input: " + path)
			return {}
	for path: String in capture.source.sourceInputs:
		if provenance.get("inputs", {}).get(path) != capture.source.sourceInputs[path]:
			push_error("Aquatic point source differs from imported metadata: " + path)
			return {}
	return capture.fixtures
