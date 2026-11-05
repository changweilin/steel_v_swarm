extends Node

# Certifies shaders/css_grayscale_group.gdshader against the original radio
# portrait filter (`.dlg-row .dlg-av`): every captured avatar crop and the
# translucent probe at both endpoints and paused transition frames.

const Raster = preload("res://tests/raster_compare.gd")
const FIXTURE := "res://tests/fixtures/dialogue_portrait_filter.json"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Portrait filter certification requires a rendered Godot session")
		get_tree().quit(1)
		return
	var capture: Dictionary = Content.read_json(FIXTURE)
	if int(capture.get("formatVersion", 0)) != 1 or capture.get("rasters", []).is_empty():
		push_error("Capture tools/dialogue_portrait_filter_capture.mjs before native verification")
		get_tree().quit(1)
		return
	var rules: Dictionary = capture.rules
	if rules.inactive != "grayscale(0.75)" or rules.active != "none" or rules.timing != "ease-out":
		push_error("Unexpected original portrait filter rules")
		get_tree().quit(1)
		return
	var failures := _check_frames(capture.frames)
	var size := int(capture.size)
	var page := Color.html(String(capture.page))
	var element := _css_rgb(String(rules.background))
	var probe := Image.new()
	if probe.load_png_from_buffer(Marshalls.base64_to_raw(capture.probe)) != OK:
		push_error("Invalid portrait filter probe")
		get_tree().quit(1)
		return
	var probe_texture := ImageTexture.create_from_image(probe)
	var output := "res://build/dialogue_portrait_filter"
	DirAccess.make_dir_recursive_absolute(output)
	var exact := 0
	var save := OS.get_cmdline_user_args().has("--save")
	for index in range(capture.rasters.size()):
		var item: Dictionary = capture.rasters[index]
		var texture: Texture2D = probe_texture
		if item.image != "probe":
			var path := String(item.image)
			if not path.begins_with("public/"):
				push_error("Unexpected portrait source path " + path)
				failures += 1
				continue
			# Decode the published original bytes: the current imports keep Godot's
			# fix_alpha_border, which rewrites the RGB of low-alpha texels.
			texture = _original_texture("res://" + path.trim_prefix("public/"), String(capture.source.sourceInputs.get(path, "")))
			if texture == null:
				push_error("Missing or changed original portrait " + path)
				failures += 1
				continue
		var viewport := SubViewport.new()
		viewport.size = Vector2i(size, size)
		viewport.disable_3d = true
		viewport.transparent_bg = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var backdrop := ColorRect.new()
		backdrop.size = Vector2(size, size)
		backdrop.color = page
		viewport.add_child(backdrop)
		var group := CanvasGroup.new()
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/css_grayscale_group.gdshader")
		material.set_shader_parameter("amount", float(item.amount))
		material.set_shader_parameter("opacity", float(item.opacity))
		group.material = material
		viewport.add_child(group)
		var background := ColorRect.new()
		background.size = Vector2(size, size)
		background.color = element
		group.add_child(background)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(float(item.offset[0]), float(item.offset[1]), size, size)
		var portrait := TextureRect.new()
		portrait.texture = atlas
		portrait.size = Vector2(size, size)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		group.add_child(portrait)
		for frame in range(3):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var actual := viewport.get_texture().get_image()
		var expected := Image.new()
		if expected.load_png_from_buffer(Marshalls.base64_to_raw(item.png)) != OK or expected.get_size() != actual.get_size():
			push_error("Invalid source portrait filter raster")
			failures += 1
		else:
			var result := Raster.compare(actual, expected)
			var strict := Raster.compare(actual, expected, 0.0)
			if int(strict.pixels) == 0:
				exact += 1
			print("DIALOGUE_PORTRAIT_FILTER case=%d image=%s state=%s pixels=%d inexact=%d maximum=%f" % [
				index, item.image, item.state, int(result.pixels), int(strict.pixels), float(result.maximum)])
			if int(result.pixels) > 0 or save:
				Raster.diagnostic(actual).save_png("%s/native_%d.png" % [output, index])
				expected.save_png("%s/source_%d.png" % [output, index])
			if int(result.pixels) > 0:
				failures += 1
				push_error("DIALOGUE_PORTRAIT_FILTER_MISMATCH case=%d pixels=%d" % [index, int(result.pixels)])
			if item.state == "inactive":
				# Control: the opacity alone must not satisfy the gate.
				material.set_shader_parameter("amount", 0.0)
				for frame in range(3):
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
				var control := Raster.compare(viewport.get_texture().get_image(), expected)
				if int(control.pixels) == 0:
					failures += 1
					push_error("DIALOGUE_PORTRAIT_FILTER_CONTROL_PASSED case=%d" % index)
		viewport.free()
	print("DIALOGUE_PORTRAIT_FILTER cases=%d exact=%d failures=%d" % [capture.rasters.size(), exact, failures])
	get_tree().quit(0 if failures == 0 else 1)

# The filter amount follows the opacity's ease-out progress; a consumer drives
# both from one transition clock. Computed styles serialize six digits.
func _check_frames(programs: Array) -> int:
	var failures := 0
	var opacity: Dictionary = Content.read_json("res://data/dialogue_portrait.json").rules
	var inactive := float(opacity.inactive)
	for program: Array in programs:
		for frame: Dictionary in program:
			var progress := (float(frame.opacity) - inactive) / (float(opacity.active) - inactive)
			var expected := 0.75 * (1.0 - progress)
			if absf(expected - float(frame.amount)) > 2e-6:
				push_error("Portrait filter amount diverges from opacity progress: %s" % frame)
				failures += 1
	return failures

func _original_texture(path: String, digest: String) -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or digest.is_empty():
		return null
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != digest:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _css_rgb(text: String) -> Color:
	var parts := text.trim_prefix("rgb(").trim_suffix(")").split(",")
	return Color8(int(parts[0]), int(parts[1]), int(parts[2]))
