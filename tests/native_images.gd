extends Node

# Native story, loading and logo art acceptance: every authored path decodes
# through the project importer to the original browser raster (or the original
# PNG pixels), and failed or non-texture resources stay unavailable instead of
# crashing mipmap creation.

var failures := 0
var assertions := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	var manifest: Dictionary = Content.read_json("res://data/native_images.json")
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	var images: Dictionary = manifest.get("images", {})
	_check(manifest.get("format") == "native-images-v1", "Native image manifest format")
	for source: String in provenance.inputs:
		if source.begins_with("public/assets/story/") or source.begins_with("public/assets/loading/") or source == "public/assets/logo_flat.png":
			_check(images.has("assets/" + source.trim_prefix("public/assets/")), "Every published original image has one native file: " + source)
	for path: String in images:
		var entry: Dictionary = images[path]
		_check(path == "assets/" + str(entry.source).trim_prefix("public/assets/"), "Native image keeps the authored path: " + path)
		if provenance.inputs.has(entry.source):
			_check(provenance.inputs[entry.source] == entry.sourceSha256, "Native image binds its published original: " + path)
		var bytes := FileAccess.get_file_as_bytes("res://" + path)
		_check(_sha256(bytes) == entry.sha256, "Published native image bytes match the manifest: " + path)
		_check(bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]), "Native image is PNG-encoded: " + path)
		var texture := Content.story_texture(path)
		_check(texture != null, "Native image loads normally: " + path)
		if texture == null:
			continue
		var image := texture.get_image()
		_check(not image.has_mipmaps(), "Ordinary art keeps its imported single level: " + path)
		if entry.encoding == "chromium-jpeg-rgb-png":
			_check(image.get_width() == int(entry.width) and image.get_height() == int(entry.height), "Native image dimensions: " + path)
			image.convert(Image.FORMAT_RGB8)
			_check(_sha256(image.get_data()) == entry.rasterSha256, "Native pixels equal the original decoded raster: " + path)
		else:
			_check(entry.encoding == "original-png" and entry.sha256 == entry.sourceSha256, "An original PNG is published verbatim: " + path)
			var expected := Image.new()
			_check(expected.load_png_from_buffer(bytes) == OK, "Original PNG decodes: " + path)
			image.convert(Image.FORMAT_RGBA8)
			expected.convert(Image.FORMAT_RGBA8)
			_check(image.get_size() == expected.get_size() and image.get_data() == expected.get_data(), "Imported PNG retains every original pixel, including faint alpha edges: " + path)
		var mipmapped := Content.story_texture(path, true)
		_check(mipmapped != null, "Native image loads with mipmaps: " + path)
		if mipmapped == null:
			continue
		var levels := mipmapped.get_image()
		_check(levels.has_mipmaps() and not texture.get_image().has_mipmaps(), "Mipmap generation leaves the ordinary cached texture unchanged: " + path)
		levels.clear_mipmaps()
		var base := texture.get_image()
		_check(levels.get_format() == base.get_format() and levels.get_data() == base.get_data(), "Mipmap generation preserves the base level: " + path)
		_check(Content.story_texture(path) == texture and Content.story_texture(path, true) == mipmapped, "Native art is reused from its cache: " + path)
	var referenced := {}
	_collect(Content.campaign, referenced)
	_collect(Content.read_json("res://data/narrative.json"), referenced)
	_collect(Content.read_json("res://data/campaign_buffer.json").get("rules", {}).get("assets", []), referenced)
	_check(referenced.has("assets/logo_flat.png") and referenced.has("assets/loading/steel_vs_swarm_1.png"), "Original preload metadata references logo and loading art")
	for path: String in referenced:
		_check(images.has(path), "Original art reference has a native image: " + path)
	for pool in ["steel_vs_swarm", "steel_vs_mercenary", "swarm_vs_mercenary"]:
		for index in range(1, 7):
			_check(images.has("assets/loading/%s_%d.png" % [pool, index]), "Original loading pool image is published: %s_%d" % [pool, index])
	# A resource that is not a texture is unavailable in both modes and never cached.
	var font_path := "assets/fonts/NotoSansTC.ttf"
	_check(ResourceLoader.exists("res://" + font_path), "Non-texture guard resource exists")
	_check(Content.story_texture(font_path) == null and Content.story_texture(font_path, true) == null, "A non-texture asset is unavailable art")
	_check(not Content.art_cache.has("res://" + font_path) and not Content.art_cache.has("res://" + font_path + "/mipmaps"), "Unavailable art is not cached")
	_check(Content.story_texture("assets/story/missing.png", true) == null, "Missing story art is unavailable")
	_check(Content.story_texture("res://assets/story/story_ch1_steel.png") == null and Content.story_texture("") == null, "Only authored asset paths resolve")
	_check(Content.campaign_art("missing-id") == null, "Unknown campaign art falls back to no texture")
	print("NATIVE_IMAGES_%s assertions=%d failures=%d images=%d referenced=%d" % ["PASS" if failures == 0 else "FAIL", assertions, failures, images.size(), referenced.size()])
	get_tree().quit(0 if failures == 0 else 1)

func _collect(value: Variant, found: Dictionary) -> void:
	if value is Dictionary:
		for item in value.values():
			_collect(item, found)
	elif value is Array:
		for item in value:
			_collect(item, found)
	elif value is String and value.begins_with("assets/") and value.ends_with(".png") and (value.begins_with("assets/story/") or value.begins_with("assets/loading/") or value == "assets/logo_flat.png"):
		found[value] = true

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
