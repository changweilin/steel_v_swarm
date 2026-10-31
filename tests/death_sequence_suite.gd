extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const ViewTests = preload("res://tests/view_suite.gd")

class FlatWorld extends BattleWorld:
	func visual_surface(_point: Vector3) -> float:
		return 20.0

class ViewHarness extends "res://scripts/main.gd":
	var cues: Array = []
	func _ready() -> void:
		death_sequence.output = _death_command
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _death_command(command: Dictionary) -> void:
		cues.append(command)
		if command.type == "cut":
			death_sequence.finish()

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("deathSequences") or not fixtures.has("deathOverlayOpacity"):
		h._check(false, "Regenerate original death-camera, cancellation and CSS animation references")
		return
	for item: Dictionary in fixtures.deathSequences:
		var sequence := DeathSequenceState.new()
		var draws := {"count": 0}
		var calls: Array = []
		var queries: Array = []
		sequence.random_sample = func():
			var value := float(item.random[int(draws.count) % item.random.size()])
			draws.count += 1
			return value
		sequence.output = func(command):
			var row: Dictionary = command.duplicate()
			if row.get("point") is Vector3:
				row.point = [row.point.x, row.point.y, row.point.z]
			if row.get("frame") is Transform3D:
				row.frame = _matrix(row.frame)
			calls.append(row)
			if command.type == "cut" and not item.deferred:
				sequence.finish()
		var surface := func(point: Vector3):
			queries.append([point.x, point.y, point.z])
			return 20 + maxf(0, point.x - 15) * .04
		var seed: Dictionary = item.input.duplicate(true)
		for key: String in ["position", "velocity", "angles"]:
			seed[key] = BodyPose.vector(seed[key])
		seed.eye = ViewTests.frame(seed.eye)
		h._check(sequence.begin(seed, surface), "Original death sequence begins from the last live view")
		_compare(h, sequence, item.initial, calls, queries, int(draws.count))
		for step: Dictionary in item.steps:
			calls.clear()
			queries.clear()
			if step.action in ["respawn", "cut"]:
				sequence.finish()
			else:
				sequence.advance(float(step.delta), surface)
			_compare(h, sequence, step, calls, queries, int(draws.count))
		# The output lambda captures its own sequence; drop both callbacks so the case is released.
		sequence.output = Callable()
		sequence.random_sample = Callable()
	_overlay(h, fixtures)
	_lifecycle(h)

static func _matrix(frame: Transform3D) -> Array:
	return [frame.basis.x.x, frame.basis.x.y, frame.basis.x.z, 0,
		frame.basis.y.x, frame.basis.y.y, frame.basis.y.z, 0,
		frame.basis.z.x, frame.basis.z.y, frame.basis.z.z, 0, frame.origin.x, frame.origin.y, frame.origin.z, 1]

static func _compare(h: Node, sequence: DeathSequenceState, reference: Dictionary, calls: Array, queries: Array, draws: int) -> void:
	h._check(draws == int(reference.draws), "Original death-camera random order, including zero-delta ground shake")
	Helper.compare(h, calls, reference.calls, "Original synchronous death producers, one-shot climax, engulf and guarded wipe callback")
	Helper.compare(h, queries, reference.queries, "Original standing-surface query order and falling-body seed heights")
	var source := ViewTests.frame(reference.frame)
	h._check(sequence.frame.origin.distance_to(source.origin) <= maxf(.0003, source.origin.length() * .000001)
		and sequence.frame.basis.x.distance_to(source.basis.x) < .00001 and sequence.frame.basis.y.distance_to(source.basis.y) < .00001
		and sequence.frame.basis.z.distance_to(source.basis.z) < .00001, "Original topple, surface clamp, adaptive fall, aerial timeout and held-impact camera frame")
	if reference.state == null:
		h._check(sequence.state.is_empty(), "Original synchronous finish or early respawn releases the sequence")
		return
	var actual: Dictionary = sequence.state.duplicate()
	for key: String in ["eye", "p", "v", "spin"]:
		var point: Vector3 = actual[key]
		actual[key] = [point.x, point.y, point.z]
	Helper.compare(h, actual, reference.state, "Original complete death cinematic state and bounded hold deadlines")

static func _overlay(h: Node, fixtures: Dictionary) -> void:
	for item: Dictionary in fixtures.deathOverlayOpacity:
		var state := DeathOverlayState.new()
		state.receive(item.kind == "alert", item.kind == "flash", 0)
		var actual := state.pulse(float(item.time)) if item.kind == "alert" else state.white(float(item.time))
		h._check(absf(actual - float(item.value)) < .00001, "Original per-keyframe ease-in-out alert pulse and ease-out detonation whiteout")
	var state := DeathOverlayState.new()
	state.receive(true, false, 10)
	state.receive(true, true, 10.2)
	h._check(state.started == 10 and state.flash_at == 10.2, "Climax retriggers whiteout without restarting an already active red pulse")
	state.receive(false, false, 10.3)
	h._check(not state.active and state.white(10.3) > 0, "Ending the cinematic hides its rim while the CSS whiteout completes independently")
	state.clear()
	h._check(not state.active and not state.flash_live, "Room replacement clears both death overlay layers")

static func _lifecycle(h: Node) -> void:
	var view := ViewHarness.new()
	h.add_child(view)
	view.menu = PanelContainer.new()
	view.menu.hide()
	view.add_child(view.menu)
	view.simulation = BattleSimulation.new()
	view.add_child(view.simulation)
	view.simulation.world = FlatWorld.new()
	view.simulation.add_child(view.simulation.world)
	var pilot := BattleUnit.new()
	view.simulation.add_child(pilot)
	pilot.kind = "robot"
	pilot.side = "STEEL"
	pilot.hp = 100
	pilot.position = Vector3(12, 20, -9)
	pilot.camera = Camera3D.new()
	pilot.add_child(pilot.camera)
	pilot.camera.global_position = Vector3(12, 25, -9)
	var mouse_mode := Input.mouse_mode
	view._observe_death_view(pilot)
	view._remember_death_view(pilot)
	var resources := [pilot.hp, pilot.shield, pilot.power, pilot.ammo.duplicate(true), view.simulation.rng.state, view.simulation.projectile_rng.state]
	pilot.hp = 0
	view._observe_death_view(pilot)
	var count := view.cues.size()
	var eye := pilot.camera.global_transform
	h._check(pilot.presentation_camera_owned and pilot.camera.top_level and not view.death_sequence.state.is_empty(),
		"Published death gives the cinematic independent world-space camera ownership")
	view._observe_death_view(pilot)
	pilot.position += Vector3(50, 1, 0)
	pilot.sync_view_camera()
	pilot.target_position = pilot.position + Vector3.RIGHT
	pilot.interpolate(.1)
	h._check(pilot.camera.global_transform == eye and view.cues.size() == count, "Repeated dead publications and physics/snapshot interpolation cannot overwrite or restart the death camera")
	view.death_sequence.finish()
	h._check(pilot.presentation_camera_owned, "The final death view stays pinned until the pilot respawns")
	pilot.hp = 100
	view._observe_death_view(pilot)
	h._check(not pilot.presentation_camera_owned and not pilot.camera.top_level and view.death_sequence.state.is_empty(),
		"Early or completed-cinematic respawn restores ordinary camera updates")
	h._check(resources == [pilot.hp, pilot.shield, pilot.power, pilot.ammo, view.simulation.rng.state, view.simulation.projectile_rng.state],
		"Cinematic lifecycle changes no authority vital/resource state or combat RNG")
	view._reset_death_view()
	h._check(view.death_owner == null and view.death_live.is_empty() and not view.death_was_dead, "Room changes release all cached live/dead camera bindings")
	Input.mouse_mode = mouse_mode
	view.free()
