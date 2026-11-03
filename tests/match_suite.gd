extends RefCounted

const StatusHelper = preload("res://tests/status_suite.gd")
const MainScript = preload("res://scripts/main.gd")
const SessionScript = preload("res://scripts/session.gd")

class RelayEffects extends CombatEffects:
	var sparks: Array = []
	func spark(point: Vector3, radius: float, color: int, _delay: float = 0) -> void:
		sparks.append([point, radius, color])

class RelayWorld extends BattleWorld:
	var effects := RelayEffects.new()
	var height_queries: Array = []
	func ground_height(x: float, z: float) -> float:
		height_queries.append(Vector2(x, z))
		return 2.5
	func ensure_combat_effects() -> CombatEffects:
		return effects

class MatchSimulation extends BattleSimulation:
	func _missile_target_altitude(unit: BattleUnit) -> float:
		return unit.position.y

	func _on_third_death(_unit: BattleUnit, _attacker: BattleUnit) -> void:
		pass

	func _collapse_scene(_unit: BattleUnit) -> void:
		pass

	func _drop_scene_loot(_unit: BattleUnit) -> void:
		pass

	func _carrier_shot_down(_unit: BattleUnit) -> void:
		pass

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("matchStatsInit") or not fixtures.has("matchDeaths"):
		h._check(false, "Regenerate original match-stat references before final verification")
		return
	for item: Dictionary in fixtures.matchDeaths:
		var simulation := create(h)
		StatusHelper.compare(h, simulation.match_stats, fixtures.matchStatsInit, "Original regular-match counter columns and initial values")
		var first := actor(simulation, 1, "STEEL", true)
		var target := actor(simulation, 2, item.side, item.role == "hero", item.kind)
		var contributor := actor(simulation, 3, "STEEL", true)
		contributor.position.x = float(Content.constants.ECON.ASSIST.R_M) + 1 if item.distant else 0
		if item.role == "third":
			target.special = {"role": "third", "third": true}
		elif item.role == "hazard":
			target.special = {"role": "hazard", "neutral": true}
		elif item.role == "civilian":
			target.special = {"role": "civilian", "neutral": true, "civil_side": "SWARM", "spy": false, "no_respawn": true}
		elif item.role == "carrier":
			target.special = {"role": "carrier"}
		var killer: BattleUnit
		if item.killer == "hero":
			killer = first
		elif item.killer != "none":
			killer = actor(simulation, 4, item.side if item.killer == "ally" else "GUER" if item.killer == "third" else "STEEL", item.killer == "ally")
		target.hp = 0
		target.assists = {1: true, 3: true}
		simulation._kill_unit(target, killer)
		StatusHelper.compare(h, simulation.match_stats, item.result, "Original hero/NPC/third/environment kills, paid assists, weighted last hits and early-return roles")
		h._check(not simulation.match_stats.has("GUER") and not simulation.match_stats.has("MILI"), "Regular match counters omit third-faction columns")
		simulation.free()
	var authority := create(h)
	authority.match_stats.STEEL.kills = 4
	var packet: Dictionary = bytes_to_var(var_to_bytes(authority.snapshot()))
	packet.stats.STEEL.kills = 5
	h._check(authority.match_stats.STEEL.kills == 4, "Snapshot counters are detached from authority state")
	var replica := create(h)
	replica.authoritative = false
	replica.world = BattleWorld.new()
	replica.add_child(replica.world)
	packet.erase("weather")
	replica.apply_snapshot(packet)
	StatusHelper.compare(h, replica.match_stats, packet.stats, "Replica receives public counter columns")
	packet.stats.STEEL.kills = 6
	h._check(replica.match_stats.STEEL.kills == 5, "Replica counters are detached from decoded packet buffers")
	packet.clock = 9
	replica.apply_snapshot(packet)
	h._check(replica.match_stats.STEEL.kills == 5, "Stale snapshots cannot replace newer match counters")
	authority.apply_snapshot(packet)
	h._check(authority.match_stats.STEEL.kills == 4, "Incoming snapshots cannot overwrite authority counters")
	var victim := actor(replica, 1, "SWARM", true)
	victim.hp = 0
	replica._kill_unit(victim, null)
	h._check(replica.match_stats.SWARM.deaths == 0, "Replica cannot settle match death counters")
	authority.free()
	replica.free()
	_unbalance_publication(h)
	_snapshot_acceptance(h)
	_relay_activation(h)
	_held_fire_events(h)
	print("MATCH_REFERENCE_PASS deaths=", fixtures.matchDeaths.size())

static func create(h: Node) -> MatchSimulation:
	var simulation := MatchSimulation.new()
	h.add_child(simulation)
	simulation.set_physics_process(false)
	simulation.clock = 10
	return simulation

static func actor(simulation: BattleSimulation, id: int, side: String, hero: bool, kind: String = "soldier") -> BattleUnit:
	var unit: BattleUnit
	if hero:
		unit = StatusHelper.actor(simulation, {"id": id, "character": "t05", "kind": "robot", "side": side, "position": [0, 0, 0], "hp": 100, "max_hp": 100})
	else:
		unit = BattleUnit.new()
		simulation.add_child(unit)
		unit.entity_id = id
		unit.side = side
		unit.kind = kind
		unit.hp = 100
		unit.max_hp = 100
		simulation.units[id] = unit
	unit.hit_area = Area3D.new()
	unit.add_child(unit.hit_area)
	return unit

static func _unbalance_publication(h: Node) -> void:
	var simulation := create(h)
	var threshold := WeatherRules.unbalance_threshold(0)
	var unit := actor(simulation, 1, "SWARM", true)
	unit.kind = "drone"
	var clear := func() -> void:
		unit.flying = true
		unit.hp = 1
		unit.position.y = threshold
		unit.air_sink = 0
		unit.lift_lock_until = 0
		unit.status.erase("unbalanced_until")
	var published := func() -> bool:
		return simulation._owner_control_status(unit).unbalanced
	clear.call()
	simulation.clock = 10.0
	h._check(not published.call(), "Airborne units with no sink, lock or status publish balanced")
	unit.air_sink = 1.0
	h._check(published.call(), "Original air sink independently publishes unbalanced")
	unit.position.y = threshold - .001
	h._check(not published.call(), "Original drones below the altitude threshold never publish unbalanced")
	unit.position.y = threshold
	h._check(published.call(), "Original exact drone altitude threshold remains unbalanced")
	unit.flying = false
	h._check(not published.call(), "Grounded units publish balanced")
	unit.flying = true
	unit.hp = 0
	h._check(not published.call(), "Dead units publish balanced")
	clear.call()
	unit.lift_lock_until = 10.0
	h._check(not published.call(), "Original lift lock ends at its exact deadline")
	unit.lift_lock_until = 10.1
	h._check(published.call(), "Original lift lock independently publishes unbalanced")
	clear.call()
	unit.status.unbalanced_until = 10.04
	h._check(not published.call(), "Original rounded-zero unbalLeft publishes balanced")
	unit.status.unbalanced_until = 10.05
	h._check(published.call(), "Original rounded unbalLeft independently publishes unbalanced")
	simulation.free()

static func _snapshot_acceptance(h: Node) -> void:
	var authority := create(h)
	var replica := create(h)
	replica.authoritative = false
	replica.clock = 0
	replica.world = BattleWorld.new()
	replica.add_child(replica.world)
	var session := SessionScript.new()
	h.add_child(session)
	session.active = true
	session.started = true
	session.round_id = 3
	session.launch_announced = true
	session.simulation = replica
	var controls := ControlStatusState.new()
	controls.configure(Content.balance.controls.controlEffects)
	var notices: Array = []
	var clocks: Array = []
	var heard: Array = [0]
	controls.notice.connect(func(text): notices.append(text))
	session.snapshot_heard.connect(func(): heard[0] += 1)
	session.state_received.connect(func(state):
		clocks.append(state.clock)
		controls.observe(state.control_status))
	var packet := func(clock: float, serial: int, frozen: float) -> Dictionary:
		var state: Dictionary = bytes_to_var(var_to_bytes(authority.snapshot()))
		state.erase("weather")
		state.clock = clock
		state.control_status = {"freezeLeft": frozen}
		state["_match"] = 3
		state["_serial"] = serial
		return state
	session._snapshot(packet.call(5.0, 4, 1.0))
	session._snapshot(packet.call(4.0, 3, 0.0))
	session._snapshot(packet.call(5.0, 4, 1.0))
	h._check(clocks == [5.0] and replica.clock == 5.0, "Older and duplicate snapshots reach no presentation consumer")
	h._check(notices.size() == 1 and heard[0] == 3, "Rejected snapshots rearm no notice but still prove delivery to the watchdog")
	session._snapshot(packet.call(5.0, 5, 0.0))
	session._snapshot(packet.call(6.0, 6, 1.0))
	h._check(clocks == [5.0, 5.0, 6.0] and notices.size() == 2, "A later equal-clock publication and valid false/true edges still notify")
	var next := create(h)
	next.authoritative = false
	next.clock = 0
	next.world = BattleWorld.new()
	next.add_child(next.world)
	session.simulation = next
	session.round_id = 4
	var opening: Dictionary = packet.call(0.0, 0, 0.0)
	opening["_match"] = 4
	session._snapshot(opening)
	h._check(clocks.back() == 0.0 and next.clock == 0.0, "A new round accepts its initial clock and serial")
	h.remove_child(session)
	session.free()
	authority.free()
	replica.free()
	next.free()

static func _held_fire_events(h: Node) -> void:
	var simulation := create(h)
	var main := MainScript.new()
	main.simulation = simulation
	h._check(simulation.pilots.is_empty(), "Fixture local actor has no pilot before the first snapshot")
	main._body_event_feedback({"type": "weapon_fire", "actor": 1, "serial": 1})
	main._body_event_feedback({"type": "body_echo", "actor": 1, "serial": 2})
	main._body_event_feedback({"type": "weapon_fire", "actor": 1})
	h._check(main.pending_fire_events.size() == 1 and int(main.pending_fire_events[0].serial) == 1, "Only serialized weapon_fire events received before the pilot exists are held")
	for serial in range(2, main.PENDING_FIRE_LIMIT + 5):
		main._body_event_feedback({"type": "weapon_fire", "actor": 1, "serial": serial})
	h._check(main.pending_fire_events.size() == main.PENDING_FIRE_LIMIT and int(main.pending_fire_events[-1].serial) == main.PENDING_FIRE_LIMIT + 4,
		"Held weapon_fire events stay bounded and keep the newest")
	main.free()
	simulation.free()

static func _relay_activation(h: Node) -> void:
	var simulation := create(h)
	var world := RelayWorld.new()
	simulation.world = world
	simulation.add_child(world)
	var main := MainScript.new()
	main.simulation = simulation
	var position := Vector3(3, 0, -4)
	main._relay_activation({"type": "hurt", "position": position, "side": "STEEL"})
	h._check(world.effects.sparks.is_empty() and world.height_queries.is_empty(), "Only the original relay event emits the activation effect")
	for side: String in ["STEEL", "SWARM", ""]:
		world.effects.sparks.clear()
		main._relay_activation({"type": "relay", "position": position, "side": side})
		var color: int = Color(Content.constants.SIDES[side].color).to_rgba32() >> 8 if not side.is_empty() else 0x66ffe0
		h._check(world.effects.sparks == [[Vector3(3, 11.5, -4), 8.0, color]], "Original relay starburst height, radius and side colour")
	h._check(world.height_queries.back() == Vector2(3, -4), "Original relay effect queries terrain at its own point")
	world.effects.free()
	main.room_world_resources.free()
	main.room_world_prebuild.free()
	main.free()
	simulation.free()
