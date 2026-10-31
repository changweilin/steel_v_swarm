extends RefCounted

static func run(h: Node, fixtures: Dictionary) -> void:
	var steps := 0
	for fixture: Dictionary in fixtures.burstSchedules:
		var queue := BurstPresentationQueue.new()
		for step: Dictionary in fixture.steps:
			steps += 1
			for shot: Dictionary in step.get("shots", []):
				queue.schedule(Content.weapon(shot.character, shot.slot, int(shot.level)), step.now,
					{"token": shot.token, "fail": shot.get("fail", false)})
			# Normalize exact deadlines to native arithmetic; JSON decimal parsing can shift an absolute deadline by one ULP.
			var now: float = step.now
			if step.has("boundary"):
				now = step.boundary.at + step.boundary.gap * int(step.boundary.index) + step.offset
			var actual := queue.take_due(now)
			h._check(actual.size() == step.fired.size(), "Original burst callback count: " + fixture.name)
			for index in range(mini(actual.size(), step.fired.size())):
				var expected: Dictionary = step.fired[index]
				var item: Dictionary = actual[index]
				h._check(item.payload.token == expected.token and item.index == expected.index and item.count == expected.count and item.payload.fail == expected.fail,
					"Original backward burst insertion order and captured tier: " + fixture.name)
			h._check(queue.pending.size() == step.pending.size(), "Original consumed callbacks cannot replay, including failures")
			for index in range(mini(queue.pending.size(), step.pending.size())):
				var item: Dictionary = queue.pending[index]
				var expected: Dictionary = step.pending[index]
				h._near(item.at, expected.at, "Original inclusive burst deadline")
				h._check(item.index == expected.index and item.count == expected.count, "Original retained pending order")
	var invalid := BurstPresentationQueue.new()
	invalid.schedule(Content.weapon("t06", "light"), NAN, {})
	invalid.schedule({"burst": {"count": 4, "gap": 0}}, 0, {})
	h._check(invalid.pending.is_empty() and invalid.take_due(NAN).is_empty(), "Non-finite clocks and invalid intervals cannot enqueue or consume echoes")
	print("BURST_SCHEDULE_REFERENCE_PASS sequences=", fixtures.burstSchedules.size(), " steps=", steps)
	poses(h, fixtures.burstWeaponPoses)
	await integration(h)

static func poses(h: Node, fixtures: Array) -> void:
	var frames := 0
	var maximum_error := 0.0
	# CockpitRig.update_view reads its owner's BattleSimulation parent.
	var sim := BattleSimulation.new()
	h.add_child(sim)
	sim.set_physics_process(false)
	for fixture: Dictionary in fixtures:
		var pose := AuthorityWeaponPose.new()
		pose.configure(fixture.character)
		var unit := BattleUnit.new()
		sim.add_child(unit)
		unit.configure({"id": 9901, "character": fixture.character, "kind": Content.heroes[fixture.character].kind,
			"side": "STEEL", "position": Vector3.ZERO})
		unit.ensure_cockpit()
		var rig := unit.cockpit
		var serial := 0
		for frame: Dictionary in fixture.frames:
			frames += 1
			var camera := CockpitSuite.matrix(frame.camera)
			unit.flying = frame.flying
			unit.camera.global_transform = camera
			for launch: Dictionary in frame.launches:
				var error := pose.muzzle(camera, launch.slot, frame.flying).distance_to(h._reference_vector(launch.point))
				maximum_error = maxf(maximum_error, error)
				h._check(error < 0.0001, "Original next accepted muzzle after burst echoes: %s/%s frame=%d error=%s" % [fixture.character, fixture.form, frames, error])
				serial += 1
				var definition := Content.weapon(fixture.character, launch.slot, int(frame.level))
				h._check(pose.fire(serial, launch.slot, frame.now, definition), "New gameplay serial survives multiple presentation echoes")
				h._check(not pose.fire(serial, launch.slot, frame.now, definition), "Duplicate accepted fire never schedules another burst")
				var event := {"serial": serial, "slot": launch.slot, "clock": frame.now, "level": frame.level}
				rig.fire_feedback(event)
				rig.fire_feedback(event)
			var definition := Content.weapon(fixture.character, frame.slot, int(frame.level))
			var deadline: float = NAN if frame.reloadEnd == null else frame.reloadEnd
			pose.advance(frame.dt, frame.now, frame.slot, frame.flying, definition, deadline, frame.suppression)
			unit.upgrades.lw = int(frame.level) - 1
			unit.upgrades.hw = int(frame.level) - 1
			unit.reload_at = {} if frame.reloadEnd == null else {frame.slot: deadline}
			rig.control = {"elevation": frame.suppression}
			rig.update_view(unit, frame.slot, frame.slot == "heavy", frame.dt, frame.now)
			h._check(pose.accepted_serial == frame.acceptedSerial and rig.accepted_serial == frame.acceptedSerial,
				"Presentation echoes cannot advance the gameplay acceptance serial")
			h._check(pose.weapons.last_serial == frame.serial and rig.weapons.last_serial == frame.serial,
				"Original accepted plus echo visual marks")
			h._check(pose.bursts.pending.size() == frame.pending and rig.bursts.pending.size() == frame.pending, "Source frame consumes only due echoes")
			var form := "air" if frame.flying and pose.profile.motion.has("air") else "ground"
			for slot: String in ["light", "heavy"]:
				h._check(pose.weapons.sequences[form][slot].index == frame.indices[slot] and rig.weapons.sequences[form][slot].index == frame.indices[slot],
					"Original slot and barrel progression through mixed burst batches")
			var expected := CockpitSuite.matrix(frame.matrix)
			for actual: Transform3D in [pose.gun, rig.gun.transform]:
				h._check(actual.origin.distance_to(expected.origin) < 0.00001 and CockpitSuite.basis_error(actual.basis, expected.basis) < 0.00001,
					"Original echo reset, source mirrors, reload and gun-root pose")
			h._near(pose.kick, frame.kick, "Original echo kick uses current execution time")
			h._near(rig.kick, frame.kick, "Client echo kick matches the same source sequence")
			for actual: Vector3 in [pose.current_muzzle(camera), rig.gun.to_global(rig.muzzle_cache[rig.current_cache])]:
				var error := actual.distance_to(h._reference_vector(frame.current))
				maximum_error = maxf(maximum_error, error)
				h._check(error < 0.0001, "Original burst current port and fallback alias: %s/%s frame=%d error=%s" % [fixture.character, fixture.form, frames, error])
		unit.free()
	sim.free()
	print("BURST_POSE_REFERENCE_PASS sequences=", fixtures.size(), " frames=", frames, " maximum_error=", maximum_error)

static func integration(h: Node) -> void:
	var sim := BattleSimulation.new()
	h.add_child(sim)
	var map_data := Content.map_variant(0, 1)
	map_data.erase("native_world")
	await sim.setup(map_data, [{"peer": 992, "side": "STEEL", "character": "t06", "bot": false}], {"time": "day", "weather": "clear"}, true)
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[992]
	actor.position = Vector3(0, 100, 0)
	actor.input_state = {"slot": "light"}
	actor.ensure_cockpit()
	var rig := actor.cockpit
	var definition := Content.weapon(actor.character, "light")
	var before: int = actor.ammo.light
	sim.fire(actor, "light")
	var event: Dictionary = sim.events.filter(func(item): return item.type == "weapon_fire" and int(item.actor) == actor.entity_id)[0]
	rig.fire_feedback(event)
	h._check(actor.ammo.light == before - 1 and sim.projectiles.size() == 1 and definition.burst.count > 1, "A high-rate burst launches and spends exactly one authoritative round")
	var hp := actor.hp
	var power := actor.power
	var combat_rng := sim.rng.state
	var spread_rng := sim.projectile_rng.state
	var events := sim.events.size()
	actor.input_state.slot = "heavy"
	actor.upgrades.lw = 3
	for index in range(1, int(definition.burst.count)):
		var delta: float = definition.burst.gap
		sim.clock += delta
		sim._tick_weapon_pose(actor, delta)
		rig.update_view(actor, "heavy", false, delta, sim.clock)
		h._check(actor.weapon_pose.weapons.last_slot == "light" and rig.weapons.last_slot == "light", "Queued echoes retain the fired slot after switching and upgrading")
		h._check(not rig.flash_heavy and is_equal_approx(rig.flash_ttl, maxf(0, Content.balance.cockpitRules.flash.duration - delta)),
			"Light echo refreshes the source flash before the frame's TTL decay, even after selecting heavy")
	h._check(actor.hp == hp and actor.power == power and actor.ammo.light == before - 1 and sim.events.size() == events and sim.projectiles.size() == 1,
		"Echoes cannot settle damage, spend resources, append combat events or spawn damaging rounds")
	h._check(sim.rng.state == combat_rng and sim.projectile_rng.state == spread_rng, "Echoes never consume combat or spread RNG")
	h._check(actor.fire_serial == 1 and actor.weapon_pose.weapons.last_serial == definition.burst.count and rig.weapons.last_serial == definition.burst.count,
		"Separate immutable gameplay and visual serials")
	var state: Dictionary = sim.snapshot(992).weapon_pose
	h._check(state.serial == 1 and state.visual_serial == definition.burst.count and sim.snapshot().weapon_pose.is_empty(), "Private pose distinguishes accepted and echo marks without global leakage")
	sim.clock = actor.fire_at.light
	sim.fire(actor, "light")
	rig.fire_feedback(sim.events.filter(func(item): return item.type == "weapon_fire" and int(item.actor) == actor.entity_id)[-1])
	h._check(actor.fire_serial == 2 and rig.accepted_serial == 2 and actor.ammo.light == before - 2, "Next real shot is accepted after the presentation serial has advanced")
	var visual_serial := actor.weapon_pose.weapons.last_serial
	actor.hp = 0
	sim.clock += 2
	sim._tick_weapon_pose(actor, 2)
	rig.update_view(actor, "light", false, 2, sim.clock)
	h._check(actor.weapon_pose.bursts.pending.is_empty() and rig.bursts.pending.is_empty() and actor.weapon_pose.weapons.last_serial == visual_serial and rig.weapons.last_serial == visual_serial,
		"Death consumes pending self echoes without a fire mark, and cannot replay them after respawn")
	h._check(not rig.visible and sim.snapshot(992).weapon_pose.is_empty(), "Dead self presentation remains hidden")
	sim.queue_free()
	await h.get_tree().process_frame
