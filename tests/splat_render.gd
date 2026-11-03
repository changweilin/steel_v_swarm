extends Node

const Raster = preload("res://tests/raster_compare.gd")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Splat raster certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", ["splatPaintRasters"])
	if not fixtures.has("splatPaintRasters") or not Content.balance.get("screenSplats", {}).has("paint"):
		push_error("Regenerate original browser glass raster fixtures")
		get_tree().quit(1)
		return
	var failures := 0
	var index := 0
	DirAccess.make_dir_recursive_absolute("res://build/splat_render")
	for item: Dictionary in fixtures.splatPaintRasters:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(item.viewport.width, item.viewport.height)
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var overlay := BloodSplatOverlay.new()
		viewport.add_child(overlay)
		overlay.size = Vector2(viewport.size)
		if item.kind != "glint":
			overlay.sync_layer("blood", item.entries)
		if item.kind != "blood":
			overlay.sync_layer("glint", item.entries)
		for frame in range(3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) != OK or expected.get_size() != actual.get_size():
			push_error("Invalid source glass raster dimensions")
			get_tree().quit(1)
			return
		var result := Raster.compare(actual, expected)
		if int(result.pixels) > 0:
			failures += 1
			Raster.diagnostic(actual).save_png("res://build/splat_render/native_%d.png" % index)
			expected.save_png("res://build/splat_render/source_%d.png" % index)
			push_error("GLASS_RASTER_MISMATCH case=%d kind=%s pixels=%d maximum=%f" % [index, item.kind, int(result.pixels), float(result.maximum)])
		viewport.free()
		index += 1
	print("GLASS_RENDER_PASS cases=", index, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
