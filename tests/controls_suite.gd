extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const BotTests = preload("res://tests/bot_suite.gd")
const LocalCastTests = preload("res://tests/local_cast_suite.gd")
const AbilityTargetTests = preload("res://tests/ability_target_suite.gd")
const LocalFeedbackTests = preload("res://tests/local_feedback_suite.gd")
const LocalDefenseTests = preload("res://tests/local_defense_suite.gd")
const LocalStatusTests = preload("res://tests/local_status_suite.gd")
const ControlEffectTests = preload("res://tests/control_effect_suite.gd")
const StatusIconTests = preload("res://tests/status_icon_suite.gd")

class ReferenceSimulation extends BattleSimulation:
	var values: Array = []
	var draws := 0
	var casts: Array = []

	func _recoil_next() -> float:
		draws += 1
		return float(values.pop_front())

	func cast(unit: BattleUnit, slot: String, _point: Vector3 = Vector3(INF, INF, INF)) -> bool:
		if not unit.cast_state.is_empty():
			return false
		casts.append(slot)
		return true

static func run(h: Node, fixtures: Dictionary) -> void:
	LocalCastTests.run(h, fixtures)
	AbilityTargetTests.run(h, fixtures)
	LocalFeedbackTests.run(h, fixtures)
	LocalDefenseTests.run(h, fixtures)
	LocalStatusTests.run(h, fixtures)
	ControlEffectTests.run(h, fixtures)
	StatusIconTests.run(h, fixtures)
	for key: String in ["controlsLook", "controlsMoving", "controlsNumpad", "controlsStance", "recoilSequences", "recoilGates"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original controls/recoil oracle: " + key)
			return
	for item: Dictionary in fixtures.controlsLook:
		var angles := InputRules.look(item.yaw, item.pitch, Vector2(item.change[0], item.change[1]), item.frozen, item.invertX, item.invertY, item.get("system", false))
		h._check(angles.distance_to(Vector2(item.result[0], item.result[1])) < 0.00001, "Original mouse look freeze/inversion/pitch clamp")
	for item: Dictionary in fixtures.controlsMoving:
		h._check(InputRules.moving({"move": Vector2(item.motion[0], item.motion[1]), "jump_held": item.held, "vertical": item.vertical}) == bool(item.result), "Original move-input threshold and held vertical keys")
	h._check(InputRules.moving({"move": Vector2(.02, 0), "move_mag": .02 + 1e-12}) and not InputRules.moving({"move": Vector2(.03, 0), "move_mag": .02}),
		"Original move threshold reads the double stick magnitude, not the published Float32 vector")
	for item: Dictionary in fixtures.controlsNumpad:
		var change := Vector2.ZERO if item.paused else InputRules.numpad(item.keys) * float(Content.balance.controls.numpadLookSpeed) * float(item.delta)
		if item.result.is_empty():
			h._check(change == Vector2.ZERO, "Original paused/neutral numpad look")
		else:
			h._check(change.distance_to(Vector2(item.result[0][0], item.result[0][1])) < 0.00001, "Original numpad diagonal and overlapping-key sum")
	for item: Dictionary in fixtures.controlsStance:
		var simulation := context(h)
		var unit := actor(simulation, "t01")
		unit.defending = item.defending
		unit.hp = 0 if item.dead else unit.hp
		if item.casting:
			unit.cast_state = {"slot": "def"}
		if not item.shop:
			simulation.action(1, "cast_stance")
		Helper.compare(h, simulation.casts, item.slots, "Original direct RMB gesture selects current shield stance")
		simulation.free()
	for item: Dictionary in fixtures.recoilSequences:
		var simulation := context(h)
		var unit := actor(simulation, item.character)
		unit.flying = item.flight
		var direction := Vector3(item.direction[0], item.direction[1], item.direction[2])
		var seed_before := simulation.rng.state
		var resource_before := [unit.hp, unit.shield, unit.power, unit.money, unit.ammo.duplicate()]
		for step: Dictionary in item.steps:
			simulation.clock = step.now
			simulation.values = step.randoms.duplicate()
			simulation.draws = 0
			match step.kind:
				"fire", "echo":
					var definition := Content.weapon(unit.character, step.slot)
					simulation._apply_recoil(unit, definition, step.slot, direction, step.kind == "echo")
				"decay": unit.recoil.advance(step.delta, simulation._recoil_next)
				"release": unit.recoil.release_fire()
			compare(h, unit.recoil, step.result)
			var impulse := unit.velocity if unit.flying else Vector3(unit.impulse_velocity.x, unit.velocity.y, unit.impulse_velocity.y)
			h._check(impulse.distance_to(Vector3(step.result.velocity[0], step.result.velocity[1], step.result.velocity[2])) < 0.0001, "Original primary/echo reverse kick stays separate from controlled movement")
			h._check(simulation.draws == int(step.draws), "Original recoil/shake random draw count")
			h._check(simulation.rng.state == seed_before, "View recoil randomness never consumes combat RNG")
			h._check([unit.hp, unit.shield, unit.power, unit.money, unit.ammo] == resource_before, "Recoil/echo consumes no second damage or weapon resource budget")
		unit.recoil.clear_active()
		h._check(not unit.recoil.active() and unit.recoil.echoes.pending.is_empty(), "Death clears active recoil and queued echoes")
		simulation.free()
	for item: Dictionary in fixtures.recoilGates:
		var recoil := RecoilState.new()
		var simulation := BattleSimulation.new()
		h.add_child(simulation)
		var unit := BattleUnit.new()
		simulation.add_child(unit)
		unit.entity_id = 7
		unit.recoil = recoil
		simulation.units[unit.entity_id] = unit
		for step: Dictionary in item.steps:
			simulation.clock = step.now
			simulation.events.clear()
			if step.get("release", false):
				recoil.release_fire()
			else:
				h._check(recoil.gate(item.definition, "heavy", step.now, step.get("moving", false)) == bool(step.ready), "Original settle/steady/rail hold-release gate")
			simulation._sync_body_charge(unit)
			if not step.has("chargeEvents") or not step.has("charging"):
				h._check(false, "Regenerate original charge-notification transitions")
			else:
				var notifications: Array = simulation.events.filter(func(event): return event.type == "heavy_charge").map(func(event): return event.on)
				Helper.compare(h, notifications, step.chargeEvents, "Original idempotent steady/rail charge begin/cancel/complete events")
				h._check(unit.body_charge_on == step.charging, "Original shared charge notification latch")
			compare(h, recoil, step.result)
		simulation.free()
	mode_lifecycle(h)
	print("CONTROLS_REFERENCE_PASS look=", fixtures.controlsLook.size(), " recoil=", fixtures.recoilSequences.size())

static func compare(h: Node, recoil: RecoilState, expected: Dictionary) -> void:
	var fields := expected.duplicate(true)
	for key: String in ["groundFactor", "airFactor", "velocity", "view"]:
		fields.erase(key)
	Helper.compare(h, recoil.snapshot(), fields, "Original recoil state")
	h._near(recoil.movement_factor(false), expected.groundFactor, "Original ground input recoil penalty")
	h._near(recoil.movement_factor(true), expected.airFactor, "Original airborne input penalty discount")
	if expected.view != null:
		h._near(recoil.view_pitch, expected.view[0], "Original combined pitch/shake")
		h._near(recoil.view_yaw, expected.view[1], "Original combined yaw/shake")
		h._near(recoil.shake.z, expected.view[2], "Original combined roll shake")

static func context(h: Node) -> ReferenceSimulation:
	var simulation := ReferenceSimulation.new()
	h.add_child(simulation)
	simulation.set_physics_process(false)
	simulation.world = BotTests.FlatWorld.new()
	simulation.add_child(simulation.world)
	simulation.clock = 10
	return simulation

static func actor(simulation: BattleSimulation, character: String) -> BattleUnit:
	var unit := BattleUnit.new()
	simulation.add_child(unit)
	var side := "SWARM" if Content.heroes[character].side == "SWARM" else "STEEL"
	unit.configure({"id": 1, "peer": 1, "character": character, "side": side, "kind": Content.heroes[character].kind, "position": Vector3.ZERO})
	simulation.pilots[1] = unit
	simulation.units[1] = unit
	return unit

static func mode_lifecycle(h: Node) -> void:
	var simulation := context(h)
	var unit := actor(simulation, "t01")
	simulation.action(1, "aim", "on:2")
	simulation.action(1, "aim", "off:1")
	h._check(unit.input_state.aim and unit.aim_request == 2, "Reliable aim requests ignore stale replay")
	simulation.submit_input(1, {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "fire": false})
	h._check(unit.input_state.aim and unit.input_state.slot == "heavy", "Movement updates preserve authoritative weapon mode")
	simulation._set_human_aim(unit, false)
	simulation.submit_input(1, {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "fire": true})
	h._check(not unit.input_state.aim and unit.input_state.slot == "light", "Empty-heavy fallback survives subsequent movement packets")
	unit.status.freeze_until = 11
	simulation.action(1, "defend", "toggle")
	h._check(not unit.defending, "Frozen body cannot toggle shield stance")
	unit.status.freeze_until = 0
	simulation.action(1, "defend", "toggle")
	simulation.action(1, "cast_stance")
	h._check(unit.defending and simulation.casts == [InputRules.hold_slot(true)], "Adjacent shield/gesture actions retain ordered stance dispatch")
	unit.hp = 0
	simulation.action(1, "aim", "on:3")
	h._check(unit.aim_request == 3 and not unit.input_state.aim, "Dead-body aim requests acknowledge without enabling weapons")
	simulation.free()
