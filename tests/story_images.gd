extends Node

# Native campaign art acceptance: every authored story path decodes through the
# project importer to the exact raster the original browser decoded, and failed
# or non-texture resources stay unavailable instead of crashing mipmap creation.

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
	var manifest: Dictionary = Content.read_json("res://data/story_images.json")
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	var images: Dictionary = manifest.get("images", {})
	_check(manifest.get("format") == "story-native-png-v1", "Native story manifest format")
	var originals: Array = provenance.inputs.keys().filter(func(path: String): return path.begins_with("public/assets/story/"))
	_check(images.size() == originals.size() and images.size() > 0, "Every original story input has one native encoding")
	for path: String in images:
		var entry: Dictionary = images[path]
		_check(provenance.inputs.get(entry.source) == entry.sourceSha256, "Native story art binds its published original: " + path)
		_check(path == "assets/" + str(entry.source).trim_prefix("public/assets/"), "Native story art keeps the authored path: " + path)
		var bytes := FileAccess.get_file_as_bytes("res://" + path)
		_check(_sha256(bytes) == entry.sha256, "Published native story bytes match the manifest: " + path)
		_check(bytes.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]), "Native story art is PNG-encoded: " + path)
	var referenced := {}
	_collect(Content.campaign, referenced)
	_collect(Content.read_json("res://data/narrative.json"), referenced)
	_check(not referenced.is_empty(), "Campaign metadata references story art")
	for path: String in referenced:
		_check(images.has(path), "Campaign art path has a native encoding: " + path)
		if not images.has(path):
			continue
		var entry: Dictionary = images[path]
		var texture := Content.story_texture(path)
		_check(texture != null, "Campaign art loads normally: " + path)
		var mipmapped := Content.story_texture(path, true)
		_check(mipmapped != null, "Campaign art loads with mipmaps: " + path)
		if texture == null or mipmapped == null:
			continue
		var image := texture.get_image()
		_check(not image.has_mipmaps(), "Ordinary campaign art keeps its imported single level: " + path)
		_check(image.get_width() == int(entry.width) and image.get_height() == int(entry.height), "Native story art dimensions: " + path)
		image.convert(Image.FORMAT_RGB8)
		_check(_sha256(image.get_data()) == entry.rasterSha256, "Native story pixels equal the original decoded raster: " + path)
		var levels := mipmapped.get_image()
		_check(levels.has_mipmaps() and not texture.get_image().has_mipmaps(), "Mipmap generation leaves the ordinary cached texture unchanged: " + path)
		levels.clear_mipmaps()
		levels.convert(Image.FORMAT_RGB8)
		_check(_sha256(levels.get_data()) == entry.rasterSha256, "Mipmap generation preserves the base level: " + path)
		_check(Content.story_texture(path) == texture and Content.story_texture(path, true) == mipmapped, "Story art is reused from its cache: " + path)
	# A resource that is not a texture is unavailable in both modes and never cached.
	var font_path := "assets/fonts/NotoSansTC.ttf"
	_check(ResourceLoader.exists("res://" + font_path), "Non-texture guard resource exists")
	_check(Content.story_texture(font_path) == null and Content.story_texture(font_path, true) == null, "A non-texture asset is unavailable art")
	_check(not Content.art_cache.has("res://" + font_path) and not Content.art_cache.has("res://" + font_path + "/mipmaps"), "Unavailable art is not cached")
	_check(Content.story_texture("assets/story/missing.png", true) == null, "Missing story art is unavailable")
	_check(Content.story_texture("res://assets/story/story_ch1_steel.png") == null and Content.story_texture("") == null, "Only authored asset paths resolve")
	_check(Content.campaign_art("missing-id") == null, "Unknown campaign art falls back to no texture")
	print("STORY_IMAGES_%s assertions=%d failures=%d images=%d referenced=%d" % ["PASS" if failures == 0 else "FAIL", assertions, failures, images.size(), referenced.size()])
	get_tree().quit(0 if failures == 0 else 1)

func _collect(value: Variant, found: Dictionary) -> void:
	if value is Dictionary:
		for item in value.values():
			_collect(item, found)
	elif value is Array:
		for item in value:
			_collect(item, found)
	elif value is String and value.begins_with("assets/story/"):
		found[value] = true

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
