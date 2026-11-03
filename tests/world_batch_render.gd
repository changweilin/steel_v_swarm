extends Node

# Compares a batched world against an unbatched pack of one capture, using views of its
# building batches. Run on a real driver with --baseline=<res> --candidate=<res>.
const SIZE := Vector2i(960, 540)
const VIEWS := 8
const SETTLE_FRAMES := 4
const CHANNEL_TOLERANCE := 2
const MAXIMUM_DIFFERING_DENOMINATOR := 100000

func _ready() -> void:
	_run.call_deferred()

func _argument(prefix: String) -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return ""

func _run() -> void:
	var baseline_path := _argument("--baseline=")
	var candidate_path := _argument("--candidate=")
	if DisplayServer.get_name() == "headless" or baseline_path.is_empty() or candidate_path.is_empty():
		push_error("World batch rendering needs a real driver, --baseline and --candidate")
		get_tree().quit(2)
		return
	var candidate := ResourceLoader.load(candidate_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var baseline := ResourceLoader.load(baseline_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if candidate == null or baseline == null:
		push_error("Cannot load the compared worlds")
		get_tree().quit(2)
		return
	var candidate_scene: Node3D = candidate.scene.instantiate()
	var views := _views(candidate_scene)
	if views.is_empty():
		candidate_scene.free()
		push_error("Candidate world has no building batches")
		get_tree().quit(2)
		return
	var candidate_images := await _render(candidate_scene, views)
	var baseline_images := await _render(baseline.scene.instantiate(), views)
	var total := 0
	var maximum := 0
	for index in range(views.size()):
		var result := _compare(baseline_images[index], candidate_images[index])
		print("WORLD_BATCH_VIEW index=", index, " differing=", result.differing, " max_delta=", result.maximum)
		total += result.differing
		maximum = maxi(maximum, result.maximum)
		if result.differing > 0:
			DirAccess.make_dir_recursive_absolute("res://artifacts/sol")
			baseline_images[index].save_png("res://artifacts/sol/world-batch-baseline-%d.png" % index)
			candidate_images[index].save_png("res://artifacts/sol/world-batch-candidate-%d.png" % index)
	print("WORLD_BATCH_RENDER views=", views.size(), " differing=", total, " pixels=", SIZE.x * SIZE.y * views.size(), " max_delta=", maximum)
	# Coplanar distant parts depth-fight per draw; 35 isolated pixels of 4.1M were measured.
	get_tree().quit(0 if total * MAXIMUM_DIFFERING_DENOMINATOR <= SIZE.x * SIZE.y * views.size() else 1)

func _views(scene: Node3D) -> Array[Transform3D]:
	var batches: Array[Node] = scene.find_children("SourceBatch_*", "MeshInstance3D", true, false)
	var result: Array[Transform3D] = []
	if batches.is_empty():
		return result
	for view in range(VIEWS):
		var box: AABB = batches[view * batches.size() / VIEWS].mesh.get_aabb()
		var center := box.get_center()
		var eye := center + Vector3(1, .6, 1).normalized() * maxf(60, box.size.length() * 1.2)
		result.append(Transform3D.IDENTITY.translated(eye).looking_at(center, Vector3.UP))
	return result

func _render(scene: Node3D, views: Array[Transform3D]) -> Array[Image]:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .6
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-.9, .6, 0)
	viewport.add_child(light)
	viewport.add_child(scene)
	var camera := Camera3D.new()
	camera.far = 8000
	viewport.add_child(camera)
	camera.make_current()
	var images: Array[Image] = []
	for view: Transform3D in views:
		camera.global_transform = view
		for frame in range(SETTLE_FRAMES):
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	viewport.free()
	return images

func _compare(a: Image, b: Image) -> Dictionary:
	var first := a.get_data()
	var second := b.get_data()
	var differing := 0
	var maximum := 0
	for offset in range(0, first.size(), 4):
		var delta := maxi(absi(first[offset] - second[offset]), maxi(absi(first[offset + 1] - second[offset + 1]), absi(first[offset + 2] - second[offset + 2])))
		maximum = maxi(maximum, delta)
		if delta > CHANNEL_TOLERANCE:
			differing += 1
	return {"differing": differing, "maximum": maximum}
