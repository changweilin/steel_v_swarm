extends Node

# Content.story_texture must reject a failed native decode before mipmap
# generation and keep valid art reusable without corrupting the plain cache.
const VALID := "assets/ui/shot-spark.png"

var assertions := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	Content.art_cache.clear()
	_check(Content.story_texture("") == null, "Empty art path stays unavailable")
	_check(Content.story_texture("res://" + VALID) == null, "Only project-relative source asset paths resolve")
	_check(Content.story_texture("assets/story/__missing__.png", true) == null, "Absent story art stays unavailable")
	_check(Content.art_cache.is_empty(), "Unavailable art is never cached")
	var plain := Content.story_texture(VALID)
	_check(plain != null, "Valid native art loads")
	if plain == null:
		_finish()
		return
	var before := plain.get_image()
	var before_bytes := before.get_data() if before != null else PackedByteArray()
	var mipmapped := Content.story_texture(VALID, true)
	_check(mipmapped != null and mipmapped != plain, "Valid native art loads with mipmaps as a separate texture")
	if mipmapped != null:
		var image := mipmapped.get_image()
		_check(image != null and image.has_mipmaps(), "Mipmapped art carries generated mipmaps")
		_check(Vector2i(image.get_width(), image.get_height()) == Vector2i(plain.get_width(), plain.get_height()) if image != null else false, "Mipmapped art keeps the source dimensions")
	var after := plain.get_image()
	_check(after != null and not after.has_mipmaps() and after.get_data() == before_bytes, "Mipmap generation never mutates the plain cached art")
	_check(Content.story_texture(VALID) == plain, "Plain art is reused from the cache")
	_check(Content.story_texture(VALID, true) == mipmapped, "Mipmapped art is reused from the cache")
	_finish()

func _finish() -> void:
	print("STORY_TEXTURE_PASS " if failures == 0 else "STORY_TEXTURE_FAIL ", assertions, " assertions, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
