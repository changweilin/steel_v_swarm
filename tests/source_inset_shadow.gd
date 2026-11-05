extends Node

# Binds SourceInsetShadow through the accepted death_rim_present material, as the
# death overlay will, and compares every captured browser rim raster.

const Raster = preload("res://tests/raster_compare.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Source inset shadow certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var capture: Dictionary = Content.read_json("res://tests/fixtures/death_overlay.json")
	var rules: Dictionary = Content.balance.get("deathOverlay", {})
	if capture.get("metadata") != rules or not capture.get("fixtures", {}).has("deathOverlayRasters"):
		push_error("Capture original death overlay references before native verification")
		get_tree().quit(1)
		return
	var failures := 0
	var cases := 0
	var output := "res://build/source_inset_shadow"
	DirAccess.make_dir_recursive_absolute(output)
	for index in range(capture.fixtures.deathOverlayRasters.size()):
		var item: Dictionary = capture.fixtures.deathOverlayRasters[index]
		if item.kind != "rim":
			continue
		cases += 1
		var size := Vector2i(item.viewport.width, item.viewport.height)
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var shadow := SourceInsetShadow.new()
		add_child(shadow)
		if not shadow.build(size, float(rules.blur), float(rules.spread)):
			failures += 1
			viewport.free()
			shadow.free()
			continue
		var rim := ColorRect.new()
		rim.size = Vector2(size)
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/death_rim_present.gdshader")
		material.set_shader_parameter("shadow_texture", shadow.texture)
		material.set_shader_parameter("target_size", Vector2(size))
		material.set_shader_parameter("canvas_size", Vector2(size))
		material.set_shader_parameter("padding", 0.0)
		var color: Array = rules.color
		material.set_shader_parameter("rim_color", Color(color[0], color[1], color[2], color[3]))
		material.set_shader_parameter("opacity", float(item.opacity))
		rim.material = material
		viewport.add_child(rim)
		for frame in range(3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) != OK or expected.get_size() != actual.get_size():
			push_error("Invalid source death rim raster")
			failures += 1
		else:
			var result := Raster.compare(actual, expected)
			print("SOURCE_INSET_SHADOW case=%d pixels=%d maximum=%f" % [index, int(result.pixels), float(result.maximum)])
			if int(result.pixels) > 0:
				failures += 1
				Raster.diagnostic(actual).save_png("%s/native_%d.png" % [output, index])
				push_error("SOURCE_INSET_SHADOW_MISMATCH case=%d pixels=%d" % [index, int(result.pixels)])
		viewport.free()
		shadow.free()
	print("SOURCE_INSET_SHADOW cases=", cases, " failures=", failures)
	get_tree().quit(0 if failures == 0 and cases > 0 else 1)
