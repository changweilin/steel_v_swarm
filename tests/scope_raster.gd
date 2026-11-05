extends "res://tests/run.gd"

const Raster = preload("res://tests/raster_compare.gd")

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/scope_raster.json")
	_check(DisplayServer.get_name() != "headless", "Scope raster qualification requires a rendered session")
	_check(capture.get("formatVersion") == 1 and capture.get("source") is Dictionary and capture.get("cases") is Array,
		"Capture original scope CSS and HUD callbacks before raster qualification")
	if failures > 0:
		_finish_scope_raster()
		return
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in capture.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == capture.source.inputs[path], "Scope raster generator is current: " + path)
	for path: String in capture.source.sourceInputs:
		_check(provenance.get("inputs", {}).get(path) == capture.source.sourceInputs[path], "Scope raster matches imported source: " + path)
	if failures > 0:
		_finish_scope_raster()
		return
	var output := "res://build/scope_raster"
	_check(DirAccess.make_dir_recursive_absolute(output) == OK, "Create scope raster evidence directory")
	var report: Array = []
	for index in range(capture.cases.size()):
		var item: Dictionary = capture.cases[index]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(item.viewport.width, item.viewport.height)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var background := Image.new()
		var decoded := background.load_png_from_buffer(Marshalls.base64_to_raw(item.background)) == OK
		_check(decoded, "Decode the source browser test background")
		if not decoded:
			viewport.free()
			continue
		var base := TextureRect.new()
		base.texture = ImageTexture.create_from_image(background)
		base.size = Vector2(viewport.size)
		viewport.add_child(base)
		var overlay := ScopeOverlay.new()
		overlay.page_texture = base.texture
		viewport.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		overlay.size = Vector2(viewport.size)
		var state := ScopeState.new()
		state.fire_fog = float(item.fire)
		state.weather_fog = float(item.weather)
		overlay.update_view(state, bool(item.scoped))
		for tween: Tween in [overlay.fire_tween, overlay.weather_tween]:
			if tween != null and tween.is_valid():
				tween.pause()
				tween.custom_step(1)
		# The chained blur targets need their warmup before the final pass switches to them.
		for frame in range(ScopeOverlay.BLUR_WARMUP_FRAMES + 3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		_check(overlay.split_wanted() == bool(overlay.shader_material.get_shader_parameter("blur_split")),
			"Scope blur passes are active exactly when the overlay is large enough and blurred: case=%d" % index)
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		var valid := expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) == OK and expected.get_size() == actual.get_size()
		_check(valid, "Original scope raster has matching dimensions")
		if valid:
			var result := Raster.compare(actual, expected)
			var bytes := _opaque_bytes(actual, expected)
			report.append({"case": index, "scoped": item.scoped, "fire": item.fire, "weather": item.weather,
				"viewport": item.viewport, "pixels": result.pixels, "maximum": result.maximum, "opaqueBytes": bytes})
			_check(int(result.pixels) == 0, "Original scope/ring, fire/weather gradients, blur and ordered composition: case=%d pixels=%d maximum=%f" %
				[index, int(result.pixels), float(result.maximum)])
			Raster.diagnostic(actual).save_png(output + "/native_%d.png" % index)
			expected.save_png(output + "/source_%d.png" % index)
		viewport.free()
	var file := FileAccess.open(output + "/report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	_finish_scope_raster()

func _opaque_bytes(actual: Image, expected: Image) -> Dictionary:
	return preload("res://tests/opaque_canvas_witness.gd").compare(actual, expected)

func _finish_scope_raster() -> void:
	print("SCOPE_RASTER assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
