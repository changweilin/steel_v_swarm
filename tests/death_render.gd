extends Node

const Raster = preload("res://tests/raster_compare.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Death overlay raster certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var fixtures: Dictionary = _captured_fixtures() if OS.get_cmdline_user_args().has("--source-capture") else Content.read_json("res://data/fixtures.json", ["deathOverlayRasters"])
	if not fixtures.has("deathOverlayRasters") or not Content.balance.has("deathOverlay"):
		push_error("Regenerate original browser death rim/whiteout rasters")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://build/death_render")
	var failures := 0
	for index in range(fixtures.deathOverlayRasters.size()):
		var item: Dictionary = fixtures.deathOverlayRasters[index]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(item.viewport.width, item.viewport.height)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var overlay := DeathOverlay.new()
		viewport.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		overlay.size = Vector2(viewport.size)
		overlay.set_process(false)
		if item.kind == "rim":
			overlay.rim.show()
			overlay.rim_material.set_shader_parameter("opacity", float(item.opacity))
		else:
			overlay.flash.show()
			overlay.flash.modulate.a = float(item.opacity)
		for frame in range(3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) != OK or expected.get_size() != actual.get_size():
			push_error("Invalid source death overlay raster dimensions")
			get_tree().quit(1)
			return
		var result := Raster.compare(actual, expected)
		if int(result.pixels) > 0:
			failures += 1
			Raster.diagnostic(actual).save_png("res://build/death_render/native_%d.png" % index)
			expected.save_png("res://build/death_render/source_%d.png" % index)
			push_error("DEATH_RASTER_MISMATCH case=%d kind=%s pixels=%d maximum=%f" % [index, item.kind, int(result.pixels), float(result.maximum)])
		viewport.free()
	print("DEATH_RENDER_PASS" if failures == 0 else "DEATH_RENDER_FAIL", " cases=", fixtures.deathOverlayRasters.size(), " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _captured_fixtures() -> Dictionary:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/death_overlay.json")
	if capture.get("formatVersion") != 1 or not capture.get("source") is Dictionary or not capture.get("fixtures") is Dictionary:
		push_error("Capture original death overlay references before native verification")
		return {}
	var source: Dictionary = capture.source
	if not source.get("inputs") is Dictionary or source.inputs.is_empty() or not source.get("sourceInputs") is Dictionary or source.sourceInputs.is_empty():
		push_error("Missing death overlay source/generator identities")
		return {}
	for path: String in source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		if text.sha256_text() != source.inputs[path]:
			push_error("Stale death overlay generator: " + path)
			return {}
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in source.sourceInputs:
		if provenance.get("inputs", {}).get(path) != source.sourceInputs[path]:
			push_error("Death overlay source differs from imported metadata: " + path)
			return {}
	if capture.get("metadata") != Content.balance.get("deathOverlay"):
		push_error("Original death overlay CSS differs from native metadata")
		return {}
	return capture.fixtures
