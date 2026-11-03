extends "res://tests/scenery_binding_retirement.gd"

class CallbackMotion extends SceneryMotion:
	var callback: Callable
	func advance(_delta: float, _now: float, _weather: Dictionary) -> void:
		callback.call()

class CountingWildlife extends WildlifePresentation:
	var calls := 0
	func advance(_delta: float, _now: float, _weather: Dictionary) -> void:
		calls += 1

var hosts: Array[SceneryPresentation] = []

func _clocks() -> Array:
	return [SceneryPresentation.wind_time, SceneryPresentation.wind_phase, SceneryPresentation.wave_phase,
		SceneryPresentation.gust_phase, SceneryPresentation.wildlife_activity]

func _scene(spec: Dictionary) -> Dictionary:
	# Native probes isolate cache/observer ownership; they are not an authored camp or map.
	var root := _sheet(spec)
	var pivot: Node3D = root.get_node("Pivot")
	pivot.set_meta("source_motion_id", int(spec.id))
	var owned: MeshInstance3D = pivot.get_child(0)
	owned.set_meta("source_building_key", "b")
	var other := MeshInstance3D.new()
	other.mesh = QuadMesh.new()
	other.set_meta("source_building_key", "c")
	root.add_child(other)
	var landmark := MeshInstance3D.new()
	landmark.mesh = QuadMesh.new()
	landmark.set_meta("source_camp_landmark", {"x": 0, "z": 0, "r": 2})
	root.add_child(landmark)
	var batch := MultiMeshInstance3D.new()
	var input := MultiMesh.new()
	input.transform_format = MultiMesh.TRANSFORM_3D
	input.mesh = QuadMesh.new()
	input.instance_count = 1
	input.set_instance_transform(0, Transform3D.IDENTITY)
	batch.multimesh = input
	batch.set_meta("source_camp_building_batch", true)
	root.add_child(batch)
	return {"root": root, "pivot": pivot, "owned": owned, "other": other,
		"landmark": landmark, "batch": batch, "input": input}

func _bind_host(info: Dictionary, spec: Dictionary, train_spec: Dictionary = {}) -> SceneryPresentation:
	var train_sources: Array = []
	if not train_spec.is_empty():
		var path := SceneryTrainMotion.create_path(train_spec)
		info.root.add_child(path)
		private_resources.append(weakref(path.curve))
		train_sources.append(train_spec)
	var host := SceneryPresentation.new()
	hosts.append(host)
	_check(host.configure(info.root, train_sources, [spec]), "Bind native source root, motion/train owners and camp caches")
	for motion: SceneryMotion in host.motions:
		held_motions.append(motion)
		for material: Material in motion.materials:
			private_resources.append(weakref(material))
	for train: SceneryTrainMotion in host.trains:
		held_trains.append(train)
	private_resources.append(weakref(info.batch.multimesh))
	_check(host.owned_meshes.size() == 2 and host.landmarks.size() == 1 and host.batches.size() == 1,
		"Populate all native host cache families before retirement checks")
	_check(info.batch.multimesh != info.input and info.input.get_instance_transform(0) == Transform3D.IDENTITY,
		"Host cache owns a private instance buffer without rewriting its input")
	return host

func _closed_host(host: SceneryPresentation, spec: Dictionary) -> void:
	var before := [host.revision, host.generation, _clocks()]
	var fresh := Node3D.new()
	_check(not host.configure(fresh, [], [spec]), "Terminal hosts reject later source admission before RNG or binding allocation")
	host.advance(999, {"windFreq": 9, "waveSpeed": 9})
	host.clear_camps([{"x": 0, "z": 0}], {"b": true, "c": true})
	host.retire()
	_check(host.retired and not host.ready and not host.can_advance() and host.source_root == null,
		"Deleted source roots close retained native scenery hosts")
	_check(host.owned_meshes.is_empty() and host.landmarks.is_empty() and host.batches.is_empty()
		and host.motions.is_empty() and host.trains.is_empty(), "Terminal hosts release every cache and child-controller reference")
	_check(before == [host.revision, host.generation, _clocks()] and fresh.get_child_count() == 0,
		"Late host commands cannot mutate shared clocks, closed epochs or native observers")
	fresh.free()

func _host_lifetimes(spec: Dictionary, train_spec: Dictionary) -> void:
	var info := _scene(spec)
	var host := _bind_host(info, spec, train_spec)
	host.advance(.125, {})
	var before := [_clocks(), host.generation, host.motions[0].elapsed, host.motions[0].materials[0],
		host.trains[0].distance, host.trains[0].visual.transform, info.batch.multimesh]
	remove_child(info.root)
	await get_tree().process_frame
	_check(host.ready and not host.retired and before == [_clocks(), host.generation, host.motions[0].elapsed,
		host.motions[0].materials[0], host.trains[0].distance, host.trains[0].visual.transform, info.batch.multimesh],
		"Staging detachment retains host clocks, constructor phases, materials and private instance buffers")
	add_child(info.root)
	var copy: Node = info.root.duplicate()
	add_child(copy)
	copy.free()
	_check(not host.retired and host.source_root == info.root, "A duplicated source-root observer cannot close the original host")
	var cached_nodes: Array = host.owned_meshes.b
	var cached_landmark: Dictionary = host.landmarks[0]
	info.root.free()
	_check(cached_nodes.is_empty() and cached_landmark.is_empty(), "Root deletion seals external aliases of owned-node lists and landmark records")
	_closed_host(host, spec)
	info = _scene(spec)
	host = _bind_host(info, spec)
	var replacement := _scene(spec)
	_check(host.configure(replacement.root, [], [spec]), "Rebind a host to a replacement native source root")
	private_resources.append(weakref(replacement.batch.multimesh))
	private_resources.append(weakref(host.motions[0].materials[0]))
	info.root.free()
	_check(not host.retired and host.ready and host.source_root == replacement.root,
		"Deletion of an old source-root binding cannot retire the new root or caches")
	replacement.root.free()
	_closed_host(host, spec)
	info = _scene(spec)
	host = _bind_host(info, spec)
	var clock := _clocks()
	info.root.queue_free()
	host.advance(1, {})
	_check(_clocks() == clock and not host.can_advance(), "Queued source roots cannot spend another shared-clock step")
	await get_tree().process_frame
	_closed_host(host, spec)

func _callbacks(spec: Dictionary) -> void:
	var first := _scene(spec)
	var latest := _scene(spec)
	var host := SceneryPresentation.new()
	hosts.append(host)
	var configuring := host
	first.root.child_entered_tree.connect(func(_child: Node) -> void:
		_check(configuring.configure(latest.root, [], [spec]), "A newer source root can replace reentrant admission"), CONNECT_ONE_SHOT)
	_check(not host.configure(first.root, [], [spec]) and host.source_root == latest.root and host.ready,
		"Cancelled source admission cannot append old bindings to the new root")
	first.root.free()
	latest.root.free()
	_closed_host(host, spec)
	first = _scene(spec)
	host = SceneryPresentation.new()
	hosts.append(host)
	var retiring := host
	first.pivot.child_entered_tree.connect(retiring.retire.unbind(1), CONNECT_ONE_SHOT)
	_check(not host.configure(first.root, [], [spec]) and host.retired,
		"Host retirement during child admission seals the partially configured leaf owner")
	first.root.free()
	_closed_host(host, spec)
	first = _scene(spec)
	host = _bind_host(first, spec)
	var clearing := host
	first.owned.visibility_changed.connect(clearing.retire, CONNECT_ONE_SHOT)
	host.clear_camps([], {"b": true, "c": true})
	_check(host.retired and first.other.visible, "Camp-clear retirement prevents stale later cache writes")
	first.root.free()
	_closed_host(host, spec)
	first = _scene(spec)
	latest = _scene(spec)
	host = _bind_host(first, spec)
	var replacing := host
	first.owned.visibility_changed.connect(func() -> void:
		_check(replacing.configure(latest.root, [], [spec]), "Camp callback can admit a newer source root"), CONNECT_ONE_SHOT)
	host.clear_camps([], {"b": true, "c": true})
	_check(host.source_root == latest.root and latest.owned.visible and first.other.visible,
		"Old camp clearing cannot alter either remaining old nodes or the replacement root")
	first.root.free()
	latest.root.free()
	_closed_host(host, spec)
	first = _scene(spec)
	host = _bind_host(first, spec)
	var independent := host
	first.owned.visibility_changed.connect(func() -> void:
		independent.clear_camps([], {"c": true}), CONNECT_ONE_SHOT)
	host.clear_camps([], {"b": true, "c": true})
	_check(not first.owned.visible and not first.other.visible, "Independent reentrant camp events preserve both visibility removals")
	host.clear_camps([{"x": 0, "z": 0}], {})
	_check(not first.landmark.visible and first.batch.multimesh.get_instance_transform(0).basis.determinant() == 0,
		"An active host completes ordinary landmark and private instance-buffer clearance")
	_check(first.input.get_instance_transform(0) == Transform3D.IDENTITY,
		"Native camp-buffer clearance preserves the original shared input")
	first.root.free()
	_closed_host(host, spec)

func _frame_and_world(spec: Dictionary) -> void:
	var info := _scene(spec)
	var host := _bind_host(info, spec)
	var first := CallbackMotion.new()
	var second := CallbackMotion.new()
	var counts := {"later": 0}
	first.callback = host.retire
	second.callback = func(): counts.later += 1
	host.motions = [first, second]
	host.advance(.125, {})
	_check(host.retired and counts.later == 0, "Frame retirement stops every later scenery controller")
	info.root.free()
	_closed_host(host, spec)
	info = _scene(spec)
	host = _bind_host(info, spec)
	var world := BattleWorld.new()
	world.scenery_view = host
	var wildlife := CountingWildlife.new()
	world.wildlife_view = wildlife
	add_child(world)
	info.root.free()
	var clocks := _clocks()
	world.step_scenery(.25, {})
	_check(wildlife.calls == 0 and _clocks() == clocks, "World rejects subordinate frame updates after source-host deletion")
	world.free()
	info = _scene(spec)
	host = _bind_host(info, spec)
	world = BattleWorld.new()
	world.scenery_view = host
	wildlife = CountingWildlife.new()
	world.wildlife_view = wildlife
	add_child(world)
	info.root.queue_free()
	clocks = _clocks()
	world.step_scenery(.25, {})
	_check(wildlife.calls == 0 and _clocks() == clocks, "World rejects subordinate updates before a queued source root is deleted")
	await get_tree().process_frame
	world.free()
	info = _scene(spec)
	var next := _scene(spec)
	host = _bind_host(info, spec)
	world = BattleWorld.new()
	world.scenery_view = host
	wildlife = CountingWildlife.new()
	world.wildlife_view = wildlife
	add_child(world)
	var switching := host
	var callback := CallbackMotion.new()
	callback.callback = func():
		_check(switching.configure(next.root, [], [spec]), "A frame callback can admit a replacement source root")
	host.motions = [callback]
	world.step_scenery(.125, {})
	private_resources.append(weakref(next.batch.multimesh))
	private_resources.append(weakref(host.motions[0].materials[0]))
	_check(wildlife.calls == 0 and host.source_root == next.root, "World stops the old frame before subordinate updates after root replacement")
	world.step_scenery(.125, {})
	_check(wildlife.calls == 1, "The next complete frame can advance the replacement root normally")
	info.root.free()
	next.root.free()
	world.free()
	var fresh := SceneryPresentation.new()
	var before := SceneryPresentation.wind_time
	fresh.advance(.125, {})
	_check(SceneryPresentation.wind_time == before + .125, "An unbound fresh owner retains the existing clock-only fixture contract")
	fresh.retire()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scenery host retirement qualification requires a real renderer")
		get_tree().quit(1)
		return
	var rotor := _capture("res://tests/fixtures/scenery_rotor.json")
	var trains := _capture("res://tests/fixtures/train_motion.json")
	if failures == 0:
		preload("res://tests/scenery_motion_suite.gd").run(self, rotor.referencePrograms)
		preload("res://tests/train_suite.gd").run(self, trains)
		var spec: Dictionary = rotor.referencePrograms.waterfallMotionPrograms[0].motions[0]
		await _host_lifetimes(spec, trains.trainPrograms[0].spec)
		_callbacks(spec)
		await _frame_and_world(spec)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for resource: WeakRef in private_resources:
		_check(resource.get_ref() == null, "Retained closed hosts release private materials, native curves and duplicated instance buffers")
	hosts.clear()
	held_motions.clear()
	held_trains.clear()
	print("SCENERY_HOST_RETIREMENT assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
