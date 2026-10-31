class_name WildlifePresentation
extends RefCounted

const BindingLifetime = preload("res://scripts/scenery_binding_lifetime.gd")

var states: Array[WildlifeState] = []
var batches: Array = []
var meshes: Dictionary = {}
var profile: Dictionary = {}
var habitat := WildlifeHabitat.new()
var frame := 0
var source_root: Node3D
var retired := false
var ready := false
var generation := 0
var revision := 0
var lifetime: BindingLifetime
var lifetime_id := 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()

func _active() -> bool:
	return not retired and is_instance_valid(source_root) and not source_root.is_queued_for_deletion()

func _current(token: int) -> bool:
	return _active() and token == revision

func _release_binding() -> void:
	states.clear()
	batches.clear()
	meshes.clear()
	profile = {}
	habitat.retire()
	ready = false
	source_root = null
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	lifetime = null
	lifetime_id = 0

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
	_release_binding()

func configure(root: Node3D, source: Dictionary, low: bool, height: Callable, ground_code: Callable, dry_band: Callable, current_water: Callable = Callable(), densities: Dictionary = {}, initial_activity: float = 1.0) -> bool:
	if retired or not is_instance_valid(root) or root.is_queued_for_deletion():
		return false
	generation += 1
	revision += 1
	var token := revision
	_release_binding()
	source_root = root
	habitat = WildlifeHabitat.new()
	lifetime = BindingLifetime.new()
	lifetime_id = lifetime.get_instance_id()
	lifetime.controller = weakref(self)
	lifetime.generation = generation
	root.add_child(lifetime)
	if not _current(token):
		return false
	frame = 0
	for variant: Dictionary in source.variants:
		if bool(variant.low) == low:
			profile = variant
	if profile.is_empty() or int(profile.get("stride", 0)) <= 0:
		push_error("Missing original wildlife power-mode roster")
		return false
	if not densities.is_empty():
		if not source.get("catalogCaptured", false) or not source.get("catalogs") is Array:
			push_error("Original wildlife density selection requires its source route capacity catalog")
			return false
		profile = WildlifePopulation.assemble(profile, source.catalogs, densities)
		if profile.is_empty():
			return false
	habitat.configure(source.footprints, height, ground_code, dry_band, current_water)
	for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		if node.has_meta("source_wildlife_mesh"):
			meshes[int(node.get_meta("source_wildlife_mesh"))] = node
			node.visible = false
			if not _current(token):
				return false
	for spec: Dictionary in profile.states:
		var state := WildlifeState.new()
		state.configure(spec)
		states.append(state)
	for batch: Dictionary in profile.batches:
		for id: int in [int(batch.body)] + batch.limbs.map(func(limb): return int(limb.mesh)):
			var node: MultiMeshInstance3D = meshes.get(id)
			if node == null or node.multimesh == null or (densities.is_empty() and node.multimesh.instance_count != batch.animals.size()):
				push_error("Missing original wildlife body/joint MultiMesh")
				return false
			node.multimesh = MultiMeshCopy.duplicate_of(node.multimesh)
			if not _current(token):
				return false
			if not densities.is_empty():
				node.multimesh.instance_count = batch.animals.size()
				if not _current(token):
					return false
			node.visible = true
			if not _current(token):
				return false
			RenderingServer.instance_set_ignore_culling(node.get_instance(), true)
		batches.append(batch)
	ready = true
	if not densities.is_empty():
		return _write_frame(0, {"activity": initial_activity}, token)
	return true

func advance(delta: float, now: float, weather: Dictionary) -> void:
	if not ready or not _active() or not is_finite(delta) or delta < 0 or not is_finite(now):
		return
	revision += 1
	var token := revision
	frame += 1
	for index in range(states.size()):
		var state := states[index]
		state.elapsed = minf(0.25, state.elapsed + minf(0.25, delta))
		if frame % int(profile.stride) == index % int(profile.stride):
			state.advance(now, state.elapsed)
			state.elapsed = 0
	_write_frame(now, weather, token)

func write(now: float, weather: Dictionary) -> void:
	if not ready or not _active():
		return
	revision += 1
	_write_frame(now, weather, revision)

func _write_frame(now: float, weather: Dictionary, token: int) -> bool:
	var weak: WeakRef = weakref(self)
	var scope := func() -> bool:
		var owner: WildlifePresentation = weak.get_ref()
		return owner != null and owner._current(token)
	for batch: Dictionary in batches:
		for index in range(batch.animals.size()):
			var animal: Dictionary = batch.animals[index]
			var state := states[int(animal.state)]
			var spec: Dictionary = state.spec
			var i := int(animal.i)
			var j := i * 3
			var x := float(state.positions[j])
			var z := float(state.positions[j + 2])
			var ground := float(habitat.probe.call(x, z))
			if not _current(token):
				return false
			if not is_finite(x) or not is_finite(z) or not is_finite(ground):
				if not _store(int(batch.body), index, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO), token):
					return false
				for limb: Dictionary in batch.limbs:
					if not _store(int(limb.mesh), index, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO), token):
						return false
				continue
			var airborne: bool = batch.species == "bird" or bool(spec.get("flying", false))
			var aquatic: bool = batch.species == "fish"
			var activity := float(weather.get("activity", 1)) if airborne else 1.0
			var bounds: Dictionary = profile.bounds
			var visible: bool = x >= float(bounds.minX) and x <= float(bounds.maxX) and z >= float(bounds.minZ) and z <= float(bounds.maxZ) \
				and (index + 0.5) / batch.animals.size() <= activity
			var y := float(state.positions[j + 1])
			if aquatic:
				var water: float = float(profile.waterY) if profile.waterY != null else 0.0
				visible = visible and profile.waterY != null and is_finite(water) and ground < water - 0.4 and habitat.wet_at(x, z, scope)
				if not _current(token):
					return false
				y = maxf(ground + 0.15, minf(water - 0.25, y))
				if not is_finite(y):
					y = 0
			elif not airborne:
				visible = visible and habitat.valid_at(x, z, profile.waterY, scope)
				if not _current(token):
					return false
				y = ground + float(spec.GROUND_OFFSET)
			else:
				y = maxf(ground + 0.4, y)
			var direction := state.heading(i)
			if not airborne and not aquatic:
				direction.y = 0
			var rotation := Quaternion.IDENTITY
			if SourceQuaternion.vector_dot(direction, direction) > 1e-9:
				rotation = SourceQuaternion.from_unit_vectors(Vector3.BACK, SourceQuaternion.vector_normalized(direction))
			var vx := float(state.velocities[j])
			var vz := float(state.velocities[j + 2])
			var moving := minf(1, sqrt(vx * vx + vz * vz) / float(spec.SPEED))
			var hz := float(spec.STRIDE_HZ) if ControlPreferences.truthy(spec.get("STRIDE_HZ")) else float(spec.BOUNCE_HZ) if ControlPreferences.truthy(spec.get("BOUNCE_HZ")) else 2.8
			var stride := (now * hz + float(state.wings[i])) * TAU
			var hop := maxf(0, sin(stride)) * float(spec.get("BOUNCE_AMP", 0)) * moving
			var root := Transform3D(SourceQuaternion.basis(rotation).scaled_local(Vector3.ONE if visible else Vector3.ZERO), Vector3(x, y + hop, z))
			if not _store(int(batch.body), index, root, token):
				return false
			for limb: Dictionary in batch.limbs:
				var local: Quaternion
				if ControlPreferences.truthy(limb.wing):
					local = SourceQuaternion.axis_angle(Vector3.BACK, state.wing_angle(i, now) * float(limb.wing))
				elif limb.tail:
					local = SourceQuaternion.axis_angle(Vector3.UP, state.tail_angle(i, now))
				else:
					local = SourceQuaternion.axis_angle(Vector3.RIGHT, sin(stride) * 0.5 * moving * float(limb.leg))
				local = SourceQuaternion.multiply(local, BodyPose.quaternion(limb.rest))
				var joint := Transform3D(SourceQuaternion.basis(local), BodyPose.vector(limb.pivot))
				if not _store(int(limb.mesh), index, root * joint, token):
					return false
	return _current(token)

func _store(mesh: int, index: int, transform: Transform3D, token: int) -> bool:
	if not _current(token):
		return false
	meshes[mesh].multimesh.set_instance_transform(index, transform)
	return _current(token)
