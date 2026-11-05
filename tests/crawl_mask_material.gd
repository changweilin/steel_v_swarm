extends Node

# Certifies shaders/campaign_crawl_mask.gdshader against the original
# `.prologue-crawl-viewport` mask rasters, independently of CampaignCinematic.

const Raster = preload("res://tests/raster_compare.gd")
const FIXTURE := "res://tests/fixtures/campaign_crawl_mask.json"
const MASK := preload("res://shaders/campaign_crawl_mask.gdshader")

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Crawl mask certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var capture: Dictionary = Content.read_json(FIXTURE)
	if int(capture.get("formatVersion", 0)) != 1 or capture.get("programs", []).size() != 6:
		push_error("Capture tools/campaign_crawl_mask_capture.mjs before native verification")
		get_tree().quit(1)
		return
	var stops := parse_mask(String(capture.mask))
	if stops.is_empty():
		push_error("Unexpected original crawl mask: " + String(capture.mask))
		get_tree().quit(1)
		return
	var save := OS.get_cmdline_user_args().has("--save")
	var output := "res://build/crawl_mask_material"
	if save:
		DirAccess.make_dir_recursive_absolute(output)
	var failures := 0
	var exact := 0
	var backdrop := Color(capture.backdrop[0], capture.backdrop[1], capture.backdrop[2], capture.backdrop[3])
	for index in range(capture.programs.size()):
		var sample: Dictionary = capture.programs[index]
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(sample.png)) != OK:
			push_error("Invalid source crawl mask raster %d" % index)
			failures += 1
			continue
		var size := Vector2i(sample.size[0], sample.size[1])
		var material := _material(stops, Vector2(0.0, size.y)) if sample.enabled else null
		var actual := await _render(size, backdrop, sample.layers, material)
		if expected.get_size() != actual.get_size():
			push_error("Crawl mask raster %d has different dimensions" % index)
			failures += 1
			continue
		var result := Raster.compare(actual, expected)
		var strict := Raster.compare(actual, expected, 0.0)
		if int(strict.pixels) == 0:
			exact += 1
		print("CRAWL_MASK_MATERIAL case=%d size=%s enabled=%s pixels=%d inexact=%d maximum=%f" % [
			index, size, sample.enabled, int(result.pixels), int(strict.pixels), float(result.maximum)])
		if save or int(result.pixels) > 0:
			if not DirAccess.dir_exists_absolute(output):
				DirAccess.make_dir_recursive_absolute(output)
			Raster.diagnostic(actual).save_png("%s/native_%d.png" % [output, index])
			expected.save_png("%s/source_%d.png" % [output, index])
		if int(result.pixels) > 0:
			failures += 1
			push_error("CRAWL_MASK_MATERIAL_MISMATCH case=%d pixels=%d" % [index, int(result.pixels)])
		if sample.enabled:
			# Control: the unmasked contents must not satisfy the gate.
			var control := Raster.compare(await _render(size, backdrop, sample.layers, null), expected)
			if int(control.pixels) == 0:
				failures += 1
				push_error("CRAWL_MASK_MATERIAL_CONTROL_PASSED case=%d" % index)
	failures += await _check_box(stops, backdrop)
	var scaled := await _check_scaled(String(capture.mask), output, save)
	failures += int(scaled.failures)
	print("CRAWL_MASK_MATERIAL cases=%d exact=%d failures=%d" % [capture.programs.size() + int(scaled.cases),
		exact + int(scaled.exact), failures])
	get_tree().quit(0 if failures == 0 else 1)

# Device-scale captures (tools/crawl_mask_material_capture.mjs). The contents are
# opaque, so each unmasked raster is exactly the layer the mask applies to; using
# it isolates the mask from Chromium's snapping of fractional device rectangles.
func _check_scaled(mask: String, output: String, save: bool) -> Dictionary:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/crawl_mask_material.json")
	var programs: Array = capture.get("programs", [])
	var result := {"cases": 0, "exact": 0, "failures": 0}
	if int(capture.get("formatVersion", 0)) != 1 or programs.size() != 8 or String(capture.get("mask", "")) != mask:
		push_error("Capture tools/crawl_mask_material_capture.mjs before native verification")
		result.failures = 1
		return result
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in capture.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		if text.sha256_text() != capture.source.inputs[path]:
			push_error("Stale device-scale crawl mask capture: " + path)
			result.failures += 1
	for path: String in capture.source.sourceInputs:
		if provenance.inputs.get(path) != capture.source.sourceInputs[path]:
			push_error("Device-scale crawl mask capture predates original input: " + path)
			result.failures += 1
	if int(result.failures) > 0:
		return result
	var stops := parse_mask(mask)
	var backdrop := Color(capture.backdrop[0], capture.backdrop[1], capture.backdrop[2], capture.backdrop[3])
	for index in range(0, programs.size(), 2):
		var control: Dictionary = programs[index]
		var sample: Dictionary = programs[index + 1]
		var contents := Image.new()
		var expected := Image.new()
		if control.enabled or not sample.enabled or control.scale != sample.scale or control.size != sample.size \
				or contents.load_png_from_buffer(Marshalls.base64_to_raw(control.png)) != OK \
				or expected.load_png_from_buffer(Marshalls.base64_to_raw(sample.png)) != OK \
				or contents.get_size() != expected.get_size() \
				or expected.get_size() != Vector2i(roundi(sample.size[0] * sample.scale), roundi(sample.size[1] * sample.scale)):
			push_error("Invalid device-scale crawl mask program %d" % index)
			result.failures += 1
			continue
		contents.convert(Image.FORMAT_RGBA8)
		var size := expected.get_size()
		var layer := [{"texture": ImageTexture.create_from_image(contents), "rect": [0, 0, size.x, size.y]}]
		var actual := await _render(size, backdrop, layer, _material(stops, Vector2(0.0, size.y)))
		var compared := Raster.compare(actual, expected)
		var strict := Raster.compare(actual, expected, 0.0)
		result.cases += 1
		if int(strict.pixels) == 0:
			result.exact += 1
		print("CRAWL_MASK_MATERIAL scale=%s size=%s pixels=%d inexact=%d maximum=%f" % [
			sample.scale, size, int(compared.pixels), int(strict.pixels), float(compared.maximum)])
		if save or int(compared.pixels) > 0:
			if not DirAccess.dir_exists_absolute(output):
				DirAccess.make_dir_recursive_absolute(output)
			Raster.diagnostic(actual).save_png("%s/native_scaled_%d.png" % [output, index / 2])
			expected.save_png("%s/source_scaled_%d.png" % [output, index / 2])
		if int(compared.pixels) > 0:
			result.failures += 1
			push_error("CRAWL_MASK_MATERIAL_MISMATCH scale=%s pixels=%d" % [sample.scale, int(compared.pixels)])
		if int(Raster.compare(contents, expected).pixels) == 0:
			result.failures += 1
			push_error("CRAWL_MASK_MATERIAL_CONTROL_PASSED scale=%s" % sample.scale)
	return result

# Returns {offsets, alphas} for a top-to-bottom four-stop black alpha gradient,
# the only shape this material implements; anything else is rejected.
static func parse_mask(mask: String) -> Dictionary:
	var body := mask.strip_edges()
	if not body.begins_with("linear-gradient(") or not body.ends_with(")"):
		return {}
	var pattern := RegEx.create_from_string("rgba?\\(0, 0, 0(?:, ([\\d.]+))?\\) ([\\d.]+)%")
	var matches := pattern.search_all(body)
	var remainder := pattern.sub(body.substr(16, body.length() - 17), "", true).replace(",", "").strip_edges()
	if matches.size() != 4 or not remainder.is_empty():
		return {}
	var offsets := Vector4()
	var alphas := Vector4()
	for i in range(4):
		var found := matches[i]
		alphas[i] = 1.0 if found.get_string(1).is_empty() else found.get_string(1).to_float()
		offsets[i] = found.get_string(2).to_float() / 100.0
		if i > 0 and offsets[i] < offsets[i - 1]:
			return {}
	return {"offsets": offsets, "alphas": alphas}

static func _material(stops: Dictionary, box: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = MASK
	material.set_shader_parameter("mask_box", box)
	material.set_shader_parameter("stop_offsets", stops.offsets)
	material.set_shader_parameter("stop_alphas", stops.alphas)
	return material

func _render(size: Vector2i, backdrop: Color, layers: Array, material: ShaderMaterial) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(size)
	background.color = backdrop
	viewport.add_child(background)
	var group := CanvasGroup.new()
	group.material = material
	viewport.add_child(group)
	for item: Dictionary in layers:
		if item.has("texture"):
			var image := TextureRect.new()
			image.texture = item.texture
			image.size = Vector2(item.rect[2], item.rect[3])
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			group.add_child(image)
			continue
		var panel := ColorRect.new()
		panel.position = Vector2(item.rect[0], item.rect[1])
		panel.size = Vector2(item.rect[2], item.rect[3])
		panel.color = Color(item.rgba[0], item.rgba[1], item.rgba[2], item.rgba[3])
		group.add_child(panel)
	for frame in range(3):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.free()
	return image

# The mask box need not cover the render target: rows outside it are clipped,
# and rows inside follow the box rather than the target.
func _check_box(stops: Dictionary, backdrop: Color) -> int:
	var size := Vector2i(24, 90)
	var box := Vector2(10.0, 64.0)
	var white := [{"rect": [0, 0, size.x, size.y], "rgba": [1.0, 1.0, 1.0, 1.0]}]
	var offset := await _render(size, backdrop, white, _material(stops, box))
	var reference := await _render(Vector2i(size.x, 64), backdrop, white, _material(stops, Vector2(0.0, 64.0)))
	var failures := 0
	for y in range(size.y):
		var expected := backdrop if y < 10 or y >= 74 else reference.get_pixel(0, y - 10)
		var actual := offset.get_pixel(size.x - 1, y)
		if actual.to_rgba32() != expected.to_rgba32():
			failures += 1
			push_error("CRAWL_MASK_MATERIAL_BOX row=%d native=%s expected=%s" % [y, actual, expected])
	return failures
