class_name AquaticPresentation
extends RefCounted

const BindingLifetime = preload("res://scripts/scenery_binding_lifetime.gd")

var systems: Array = []
var meshes: Dictionary = {}
var point_nodes: Dictionary = {}
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
	var previous := systems.duplicate()
	systems.clear()
	meshes.clear()
	point_nodes.clear()
	ready = false
	source_root = null
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	lifetime = null
	lifetime_id = 0
	for system: Dictionary in previous:
		var motion: AquaticDetritus = system.get("motion")
		system.clear()
		if motion != null:
			motion.retire()

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

func configure(root: Node3D, source: Dictionary) -> bool:
	if retired or not is_instance_valid(root) or root.is_queued_for_deletion():
		return false
	generation += 1
	revision += 1
	var token := revision
	_release_binding()
	source_root = root
	lifetime = BindingLifetime.new()
	lifetime_id = lifetime.get_instance_id()
	lifetime.controller = weakref(self)
	lifetime.generation = generation
	root.add_child(lifetime)
	if not _current(token):
		return false
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("source_aquatic_points"):
			point_nodes[int(node.get_meta("source_aquatic_points"))] = node
	for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		if node.has_meta("source_aquatic_mesh"):
			meshes[int(node.get_meta("source_aquatic_mesh"))] = node
	for captured: Dictionary in source.systems:
		if captured.kind not in ["bubble", "fish", "jelly", "detritus"]:
			push_error("Unsupported original aquatic system")
			return false
		var system: Dictionary = captured.duplicate(true)
		if system.kind == "detritus":
			var node: MeshInstance3D = point_nodes.get(int(system.batches[0].id))
			if node == null:
				push_error("Missing original suspended detritus point mesh")
				return false
			var motion := AquaticDetritus.new()
			system.motion = motion
			systems.append(system)
			if not motion.configure(node, system):
				return false
			if not _current(token):
				return false
			continue
		var batches := {}
		for batch: Dictionary in system.batches:
			var node: MultiMeshInstance3D = meshes.get(int(batch.id))
			if node == null or node.multimesh == null or node.multimesh.instance_count != int(batch.count):
				push_error("Missing original aquatic MultiMesh")
				return false
			node.multimesh = MultiMeshCopy.duplicate_of(node.multimesh)
			if not _current(token):
				return false
			RenderingServer.instance_set_ignore_culling(node.get_instance(), true)
			batches[batch.role] = node.multimesh
		system.meshes = batches
		if system.kind == "bubble":
			var random := SourceRng.new(int(system.seed))
			for draw in range(int(system.draws)):
				random.next()
			system.random = random
		systems.append(system)
	ready = true
	return true

func advance(delta: float, now: float) -> void:
	if not ready or not _active():
		return
	var token := revision
	for system: Dictionary in systems:
		if not _current(token):
			return
		match system.kind:
			"bubble":
				_bubbles(system, delta, now)
			"fish":
				_fish(system, now)
			"jelly":
				_jellies(system, now)
			"detritus":
				system.motion.advance(delta, now)

func _bubbles(system: Dictionary, delta: float, now: float) -> void:
	var water := 0
	var swamp := 0
	for part: Dictionary in system.particles:
		if float(part.surfaceY) <= float(part.floorY):
			continue
		part.y = float(part.y) + float(part.riseSpd) * delta
		if float(part.y) >= float(part.surfaceY):
			part.y = part.floorY
			part.wobblePh = system.random.next() * TAU
			system.draws = int(system.draws) + 1
		var x := sin(now * float(part.wobbleSpd) + float(part.wobblePh)) * 0.08
		var z := cos(now * float(part.wobbleSpd) * 1.4 + float(part.wobblePh)) * 0.06
		var depth := clampf((float(part.surfaceY) - float(part.y)) / (float(part.surfaceY) - float(part.floorY) + 1e-4), 0, 1)
		var radius := float(part.baseR) * (1 + 0.35 * (1 - depth))
		var size := Vector3(radius, radius * (1 + 0.15 * sin(now * 5 + float(part.wobblePh))), radius)
		var frame := Transform3D(Basis.IDENTITY.scaled_local(size), Vector3(float(part.x) + x, part.y, float(part.z) + z))
		if not part.isSwamp and water < system.meshes.water.instance_count:
			system.meshes.water.set_instance_transform(water, frame)
			water += 1
		elif part.isSwamp and swamp < system.meshes.swamp.instance_count:
			system.meshes.swamp.set_instance_transform(swamp, frame)
			swamp += 1

func _fish(system: Dictionary, now: float) -> void:
	var mesh: MultiMesh = system.meshes.fish
	var index := 0
	var count := int(system.fishPerSchool)
	for school: Dictionary in system.schools:
		var base := now * (float(school.speed) / float(school.radius)) * float(school.rotDir) + float(school.phaseOff)
		for fish in range(count):
			var angle := base + float(fish) / count * TAU * 0.35 + sin(now + fish) * 0.15
			var radius := float(school.radius) + sin(now * 0.8 + fish * 1.3) * 3.5
			var position := Vector3(float(school.cx) + cos(angle) * radius,
				float(school.swimDepth) + sin(now * 1.5 + fish) * 0.4, float(school.cz) + sin(angle) * radius)
			var heading := angle + (PI / 2 if float(school.rotDir) > 0 else -PI / 2)
			var wag := sin(now * 6.5 + fish * 1.8) * 0.22
			var rotation := SourceQuaternion.axis_angle(Vector3.UP, heading + wag)
			if index < mesh.instance_count:
				mesh.set_instance_transform(index, Transform3D(SourceQuaternion.basis(rotation), position))
				index += 1
	mesh.visible_instance_count = index

func _jellies(system: Dictionary, now: float) -> void:
	var mesh: MultiMesh = system.meshes.jelly
	var index := 0
	for jelly: Dictionary in system.jellies:
		var phase := fmod(now * float(jelly.pulseSpd) + float(jelly.pulsePh), TAU)
		var pulse := sin(phase)
		var radius := 1 - pulse * (0.25 if pulse > 0 else 0.1)
		var height := 1 + pulse * (0.35 if pulse > 0 else 0.1)
		var position := Vector3(float(jelly.x) + sin(now * 0.3 + float(jelly.pulsePh)) * float(jelly.driftR),
			float(jelly.baseY) + sin(now * float(jelly.pulseSpd) * 0.5 + float(jelly.pulsePh)) * 0.6,
			float(jelly.z) + cos(now * 0.25 + float(jelly.pulsePh)) * float(jelly.driftR))
		var rotation := WeaponPresentation.source_rotation({"rotation": [sin(now * 0.5 + float(jelly.pulsePh)) * 0.1,
			0, cos(now * 0.4 + float(jelly.pulsePh)) * 0.1], "order": "XYZ"})
		var size := Vector3(radius, height, radius) * float(jelly.scale)
		if index < mesh.instance_count:
			mesh.set_instance_transform(index, Transform3D(SourceQuaternion.basis(rotation).scaled_local(size), position))
			index += 1
	mesh.visible_instance_count = index
