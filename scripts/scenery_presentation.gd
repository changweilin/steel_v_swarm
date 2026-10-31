class_name SceneryPresentation
extends RefCounted

const BindingLifetime = preload("res://scripts/scenery_binding_lifetime.gd")

var owned_meshes: Dictionary = {}
var batches: Array[MultiMeshInstance3D] = []
var landmarks: Array = []
var trains: Array[SceneryTrainMotion] = []
var motions: Array[SceneryMotion] = []
var source_root: Node3D
var bound := false
var ready := false
var retired := false
var generation := 0
var revision := 0
var lifetime: BindingLifetime
var lifetime_id := 0
static var wind_time := 0.0
static var wind_phase := 0.0
static var wave_phase := 0.0
static var gust_phase := 0.0
static var wildlife_activity := 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()

func _active() -> bool:
	return not retired and (not bound or (is_instance_valid(source_root) and not source_root.is_queued_for_deletion()))

func _current(token: int) -> bool:
	return _active() and token == revision

func _same_binding(token: int) -> bool:
	return _active() and token == generation

func can_advance() -> bool:
	return _active() and (not bound or ready)

func _release_bindings() -> void:
	var old_motions := motions.duplicate()
	var old_trains := trains.duplicate()
	for nodes: Array in owned_meshes.values():
		nodes.clear()
	owned_meshes.clear()
	batches.clear()
	for record: Dictionary in landmarks:
		record.clear()
	landmarks.clear()
	motions.clear()
	trains.clear()
	ready = false
	source_root = null
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	lifetime = null
	lifetime_id = 0
	for motion: SceneryMotion in old_motions:
		motion.retire()
	for train: SceneryTrainMotion in old_trains:
		train.retire()

func _retire_binding(binding_generation: int, binding_instance: int) -> void:
	if generation != binding_generation or lifetime_id != binding_instance:
		return
	lifetime = null
	retire()

func retire() -> void:
	if retired:
		return
	retired = true
	generation += 1
	revision += 1
	_release_bindings()

func configure(root: Node3D, train_sources: Array = [], motion_sources: Array = []) -> bool:
	if retired or not is_instance_valid(root) or root.is_queued_for_deletion():
		return false
	generation += 1
	revision += 1
	var token := revision
	_release_bindings()
	source_root = root
	bound = true
	lifetime = BindingLifetime.new()
	lifetime_id = lifetime.get_instance_id()
	lifetime.controller = weakref(self)
	lifetime.generation = generation
	root.add_child(lifetime)
	if not _current(token):
		return false
	var random := RandomNumberGenerator.new()
	random.randomize()
	var phases := {}
	var pivots := {}
	for node: Node3D in root.find_children("*", "Node3D", true, false):
		if node.has_meta("source_motion_id"):
			pivots[int(node.get_meta("source_motion_id"))] = node
	for source: Dictionary in motion_sources:
		if not pivots.has(int(source.id)):
			push_error("Missing original scenery motion pivot")
			return false
		var motion := SceneryMotion.new()
		motions.append(motion)
		var phase: Variant = null
		if source.has("clockGroup"):
			var clock := int(source.clockGroup)
			if not phases.has(clock):
				phases[clock] = _random_phase(random)
			phase = phases[clock]
		if not motion.configure(pivots[int(source.id)], source, phase):
			return false
		if not _current(token):
			return false
	if not train_sources.is_empty():
		for source: Dictionary in train_sources:
			var train := SceneryTrainMotion.new()
			trains.append(train)
			if not train.configure(root, source, _random_phase(random)):
				return false
			if not _current(token):
				return false
	for node: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		var key: String = node.get_meta("source_building_key", "")
		if not key.is_empty():
			if not owned_meshes.has(key):
				owned_meshes[key] = []
			owned_meshes[key].append(node)
		if node.has_meta("source_camp_landmark"):
			landmarks.append({"node": node, "spec": node.get_meta("source_camp_landmark")})
		if node.get_meta("source_camp_building_batch", false):
			var batch := node as MultiMeshInstance3D
			if batch == null or batch.multimesh == null:
				push_error("Original instanced building clearance requires its source MultiMesh")
				return false
			batch.multimesh = MultiMeshCopy.duplicate_of(batch.multimesh)
			if not _current(token):
				return false
			batches.append(batch)
	ready = true
	return true

static func _random_phase(random: RandomNumberGenerator) -> float:
	var phase := random.randf()
	while phase >= 1.0:
		phase = random.randf()
	return phase

func advance(delta: float, weather: Dictionary) -> void:
	if not can_advance():
		return
	revision += 1
	var token := revision
	# Original stepCelWind integrates elapsed time independently of weather frequency.
	var step := clampf(delta, 0, 0.25) if is_finite(delta) else 0.0
	wind_time += step
	wind_phase += step * float(weather.get("windFreq", 1))
	wave_phase += step * float(weather.get("waveSpeed", 1))
	gust_phase += step * WeatherRules.wind_profile(weather).w
	wildlife_activity = WeatherRules.wildlife_activity(weather)
	for train: SceneryTrainMotion in trains:
		train.advance(delta)
		if not _current(token):
			return
	for motion: SceneryMotion in motions:
		motion.advance(delta, wind_time, weather)
		if not _current(token):
			return

func clear_camps(camps: Array, buildings: Dictionary) -> void:
	if not can_advance():
		return
	var token := generation
	for key: String in buildings:
		for node: GeometryInstance3D in owned_meshes.get(key, []):
			if is_instance_valid(node):
				node.visible = false
				if not _same_binding(token):
					return
	var radius: float = Content.constants.THIRD.BLD_CLEAR_R
	for landmark: Dictionary in landmarks:
		var node: GeometryInstance3D = landmark.node
		if not is_instance_valid(node) or not node.visible:
			continue
		var spec: Dictionary = landmark.spec
		for camp: Dictionary in camps:
			var dx := float(spec.x) - float(camp.x)
			var dz := float(spec.z) + float(camp.z)
			if sqrt(dx * dx + dz * dz) - float(spec.r) < radius:
				node.visible = false
				if not _same_binding(token):
					return
				break
	for batch: MultiMeshInstance3D in batches:
		if not is_instance_valid(batch):
			continue
		for index in range(batch.multimesh.instance_count):
			var frame := batch.multimesh.get_instance_transform(index)
			if CampRules.clears_building_instance(frame, camps):
				batch.multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
				if not _same_binding(token):
					return
