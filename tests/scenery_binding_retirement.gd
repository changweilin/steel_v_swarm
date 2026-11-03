extends "res://tests/run.gd"

var held_motions: Array[SceneryMotion] = []
var held_trains: Array[SceneryTrainMotion] = []
var private_resources: Array[WeakRef] = []

func _capture(path: String) -> Dictionary:
	var result: Dictionary = Content.read_json(path)
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	_check(result.formatVersion == 1, "Load original scenery source programs")
	for input: String in result.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + input).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == result.source.inputs[input], "Current scenery producer: " + input)
	for input: String in result.source.sourceInputs:
		_check(provenance.inputs[input] == result.source.sourceInputs[input], "Original scenery input matches imported metadata: " + input)
	return result

func _sheet(spec: Dictionary) -> Node3D:
	# The quad isolates borrowed-node/material lifetime, not original waterfall geometry.
	var root := SceneryMotion.create_anchor(spec)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.get_node("Pivot").add_child(mesh)
	add_child(root)
	return root

func _bind(root: Node3D, spec: Dictionary, phase: float = .2) -> SceneryMotion:
	var motion := SceneryMotion.new()
	_check(motion.configure(root.get_node("Pivot"), spec, phase), "Bind captured waterfall state to a native borrowed pivot")
	held_motions.append(motion)
	for material: Material in motion.materials:
		private_resources.append(weakref(material))
	return motion

func _closed_motion(motion: SceneryMotion, spec: Dictionary) -> void:
	var before := [motion.revision, motion.generation, motion.elapsed, motion.angle, motion.angles.duplicate()]
	var fresh := Node3D.new()
	_check(not motion.configure(fresh, spec), "A retired scenery binding rejects new pivots before material acquisition")
	motion.advance(1, 99999, {})
	motion.retire()
	_check(motion.retired and not motion.ready and motion.pivot == null and motion.spec.is_empty() and motion.materials.is_empty(),
		"Deleted scenery pivots close retained controllers and private material references")
	_check(before == [motion.revision, motion.generation, motion.elapsed, motion.angle, motion.angles]
		and fresh.get_child_count() == 0, "Late scenery binding/frame calls preserve closed state and allocate no observer")
	fresh.free()

func _motion_lifetimes(spec: Dictionary) -> void:
	var root := _sheet(spec)
	var motion := _bind(root, spec)
	motion.advance(.125, 0, {})
	var before := [motion.elapsed, motion.angle, motion.pivot.transform, motion.materials[0], motion.generation]
	remove_child(root)
	await get_tree().process_frame
	_check(not motion.retired and motion.ready and before == [motion.elapsed, motion.angle, motion.pivot.transform, motion.materials[0], motion.generation],
		"A detached staging tree retains its exact scenery phase, transform, material and binding")
	add_child(root)
	var copy := root.duplicate()
	add_child(copy)
	copy.free()
	_check(not motion.retired and motion.pivot == root.get_node("Pivot"), "Deleting a duplicated scenery observer cannot close the original binding")
	motion.advance(.125, 0, {})
	_check(motion.elapsed == float(before[0]) + .125, "Reattachment resumes the same waterfall clock without a new random phase")
	root.free()
	_closed_motion(motion, spec)
	root = _sheet(spec)
	motion = _bind(root, spec)
	var replacement := _sheet(spec)
	_check(motion.configure(replacement.get_node("Pivot"), spec, .3), "Rebind an active controller to a new native pivot")
	private_resources.append(weakref(motion.materials[0]))
	root.free()
	_check(not motion.retired and motion.pivot == replacement.get_node("Pivot"), "Deleting the previous pivot cannot close its replacement binding")
	replacement.free()
	_closed_motion(motion, spec)
	root = _sheet(spec)
	motion = _bind(root, spec)
	var elapsed := motion.elapsed
	motion.pivot.queue_free()
	motion.advance(1, 10, {})
	_check(motion.elapsed == elapsed, "Queued scenery pivots reject animation before native deletion")
	await get_tree().process_frame
	_closed_motion(motion, spec)
	root.free()
	root = _sheet(spec)
	motion = SceneryMotion.new()
	_check(motion.configure(root.get_node("Pivot"), spec), "Create an independently retained scenery lifetime observer")
	var weak: WeakRef = weakref(motion)
	motion = null
	_check(weak.get_ref() == null, "A pivot's deletion observer cannot retain its controller")
	await get_tree().process_frame
	_check(root.get_node("Pivot").get_child_count() == 1, "Releasing a controller removes its obsolete observer without deleting the borrowed sheet")
	root.free()
	root = _sheet(spec)
	motion = _bind(root, spec)
	get_tree().paused = true
	root.free()
	_check(motion.retired, "Native deletion closes borrowed scenery bindings during SceneTree pause")
	get_tree().paused = false
	_closed_motion(motion, spec)
	root = _sheet(spec)
	motion = _bind(root, spec)
	motion.retire()
	_check(is_instance_valid(root.get_node("Pivot")), "Explicit controller retirement does not destroy borrowed scenery geometry")
	root.free()
	_closed_motion(motion, spec)
	_check(spec.kind == "waterfall_sheet" and not spec.is_empty(), "Binding retirement cannot mutate imported source motion metadata")

func _train_root(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	var path := SceneryTrainMotion.create_path(spec)
	root.add_child(path)
	private_resources.append(weakref(path.curve))
	add_child(root)
	return root

func _bind_train(root: Node3D, spec: Dictionary) -> SceneryTrainMotion:
	var train := SceneryTrainMotion.new()
	_check(train.configure(root, spec, .2), "Bind original native train polyline and visual")
	held_trains.append(train)
	return train

func _closed_train(train: SceneryTrainMotion, spec: Dictionary) -> void:
	var before := [train.revision, train.generation, train.distance, train.direction, train.orientation]
	var fresh := Node3D.new()
	_check(not train.configure(fresh, spec), "A retired train rejects later path acquisition")
	train.advance(1)
	train.retire()
	_check(train.retired and not train.ready and train.path == null and train.follower == null
		and train.visual == null and train.spec.is_empty(), "Deleted train visuals close retained controllers and path references")
	_check(before == [train.revision, train.generation, train.distance, train.direction, train.orientation]
		and fresh.get_child_count() == 0, "Late train calls cannot resume clocks or allocate a native observer")
	fresh.free()

func _train_lifetimes(spec: Dictionary) -> void:
	var root := _train_root(spec)
	var train := _bind_train(root, spec)
	train.advance(.125)
	var before := [train.distance, train.direction, train.orientation, train.follower.transform, train.visual.transform, train.generation]
	remove_child(root)
	add_child(root)
	var copy := root.duplicate()
	add_child(copy)
	copy.free()
	_check(not train.retired and train.visual.is_inside_tree(), "Deleting a duplicated train observer cannot close the original binding")
	_check(not train.retired and before == [train.distance, train.direction, train.orientation, train.follower.transform, train.visual.transform, train.generation],
		"Native train transfers retain phase, direction, source orientation and follower/model transforms")
	root.free()
	_closed_train(train, spec)
	root = _train_root(spec)
	train = _bind_train(root, spec)
	var replacement := _train_root(spec)
	_check(train.configure(replacement, spec, .3), "Rebind a live train to its replacement native path")
	root.free()
	_check(not train.retired and train.visual.is_inside_tree(), "A retired previous train path cannot close its replacement")
	replacement.free()
	_closed_train(train, spec)
	root = _train_root(spec)
	train = _bind_train(root, spec)
	var distance := train.distance
	train.visual.queue_free()
	train.advance(1)
	_check(train.distance == distance, "Queued train visuals reject later movement before native deletion")
	await get_tree().process_frame
	_closed_train(train, spec)
	root.free()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scenery binding retirement qualification requires a real renderer")
		get_tree().quit(1)
		return
	var rotor := _capture("res://tests/fixtures/scenery_rotor.json")
	var trains := _capture("res://tests/fixtures/train_motion.json")
	if failures == 0:
		preload("res://tests/scenery_motion_suite.gd").run(self, rotor.referencePrograms)
		preload("res://tests/train_suite.gd").run(self, trains)
		var sheet: Dictionary
		for spec: Dictionary in rotor.referencePrograms.waterfallMotionPrograms[0].motions:
			if spec.kind == "waterfall_sheet":
				sheet = spec
				break
		_check(not sheet.is_empty(), "Load captured original waterfall sheet metadata")
		if not sheet.is_empty():
			await _motion_lifetimes(sheet)
		await _train_lifetimes(trains.trainPrograms[0].spec)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for resource: WeakRef in private_resources:
		_check(resource.get_ref() == null, "Deleted borrowed roots release private waterfall materials and native curves while controllers remain retained")
	held_motions.clear()
	held_trains.clear()
	print("SCENERY_BINDING_RETIREMENT assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
