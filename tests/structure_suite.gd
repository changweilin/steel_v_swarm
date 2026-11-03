class_name StructureSuite
extends RefCounted

const SupportRay = preload("res://scripts/source_support_ray.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	references(h, fixtures)
	scenery_references(h, fixtures)
	await blasts(h, fixtures.structureBlasts)
	await physics(h)
	await tunnel_impacts(h)
	await support_physics(h, fixtures)

static func references(h: Node, fixtures: Dictionary) -> void:
	var layers := StructureLayers.new()
	for fixture: Dictionary in fixtures.projectileSurfaces:
		layers.configure([], fixture.decks, fixture.tunnels)
		layers.configure_supports(fixture.get("blockers", []), fixture.get("roofs", []))
		var surface := layers.projectile_surface(h._reference_vector(fixture.point), fixture.ground)
		h._check(absf(surface - fixture.result) < 0.00001, "Original surfaceAt at the launch muzzle: " + fixture.name)
	if not fixtures.has("supportQueries") or not fixtures.has("supportClearance") or not fixtures.has("flightSupportSurfaces") or not fixtures.has("structurePads"):
		h._check(false, "Regenerate source blocker-top and polygon-roof references")
		return
	var world := BattleWorld.new()
	world.native_data = NativeWorldData.new()
	for fixture: Dictionary in fixtures.structurePads:
		world.native_data.structure_pads = fixture.pads
		var pad: Variant = world.pad_height(fixture.kind, fixture.x, fixture.z)
		h._check((pad == null) == (fixture.result == null), "Original tower/base strict platform-anchor bounds and first match")
		if pad != null and fixture.result != null:
			h._near(pad, fixture.result, "Original tower/base anchor retains zero and below-ground heights")
	world.free()
	for fixture: Dictionary in fixtures.flightSupportSurfaces:
		layers.configure([], fixture.decks, fixture.tunnels)
		layers.configure_supports(fixture.get("blockers", []), fixture.get("roofs", []))
		h._near(layers.projectile_surface(Vector3(fixture.point[0], INF, fixture.point[1]), fixture.ground), fixture.result,
			"Original infinite-altitude surface query retains buildings, roofs and structural layers")
	for fixture: Dictionary in fixtures.supportClearance:
		h._check(CampRules.cleared_buildings(fixture.records, fixture.camps) == fixture.buildings,
			"Original buildingNear and buildingBounds select complete source-owned volumes")
	for fixture: Dictionary in fixtures.supportQueries:
		layers.configure_supports(fixture.blockers, fixture.roofs)
		var point := Vector2(fixture.point[0], fixture.point[1])
		var top: Variant = layers.blocker_top(point, fixture.margin)
		var roof: Variant = layers.roof_platform_top(point)
		h._check((top == null) == (fixture.top == null), "Original blocker top presence: " + fixture.name)
		if top != null and fixture.top != null:
			h._near(top, fixture.top, "Original rotated/circular blocker highest top")
		h._check((roof == null) == (fixture.roof == null), "Original polygon roof/hole/edge/active selection: " + fixture.name)
		if roof != null and fixture.roof != null:
			h._near(roof, fixture.roof, "Original highest active polygon roof")
	layers.configure([])
	var previous: Array = []
	for fixture: Dictionary in fixtures.structureSeparation:
		if fixture.slabs != previous:
			layers.configure(fixture.slabs)
			previous = fixture.slabs
		var result := layers.separated(int(fixture.level), Vector2(fixture.impact[0], fixture.impact[1]), Vector2(fixture.target[0], fixture.target[1]), int(fixture.target_level))
		h._check(result == fixture.result, "Original slab blast separation: " + fixture.name)
	previous = []
	layers.configure([])
	for fixture: Dictionary in fixtures.structureLevels:
		if fixture.slabs != previous:
			layers.configure(fixture.slabs)
			previous = fixture.slabs
		h._check(layers.unit_level(fixture.spec, Vector2(fixture.point[0], fixture.point[1])) == int(fixture.result), "Original _unitLev hero/NPC policy")
	for fixture: Dictionary in fixtures.structureClient:
		layers.configure([], fixture.decks, fixture.tunnels)
		var point: Vector3 = h._reference_vector(fixture.point)
		var planar := Vector2(point.x, point.z)
		var deck: Variant = layers.deck_height(planar, Content.balance.structure.deckMargin)
		h._check((deck == null) == (fixture.deck == null), "Original client deck query presence: " + fixture.name)
		if deck != null and fixture.deck != null:
			h._near(deck, fixture.deck, "Original client deck height")
		var tunnel := layers.tunnel_at(planar)
		h._check(tunnel.is_empty() == fixture.tunnel.is_empty(), "Original client lowest tunnel/open-ramp selection")
		if not tunnel.is_empty() and not fixture.tunnel.is_empty():
			h._near(tunnel.floor, fixture.tunnel.floor, "Original tunnel floor interpolation")
			h._near(tunnel.ceil, fixture.tunnel.ceil, "Original tunnel ceiling interpolation")
			h._check(tunnel.open == fixture.tunnel.open, "Original open approach tag")
		h._check(layers.player_level(point, fixture.surface, fixture.ground) == int(fixture.result.level), "Original client bridge/tunnel/rooftop level")
		h._near(layers.player_reference(point, fixture.surface, fixture.ground), fixture.result.reference, "Original client standing-height reference")
	for fixture: Dictionary in fixtures.structureWorlds:
		h._check(Content.structures.has(fixture.key), "Imported native map structure profile exists")
		layers.configure(Content.structures[fixture.key])
		h._check(layers.slabs.size() == int(fixture.count), "Original uploader and accepted slab count")
		for probe: Dictionary in fixture.probes:
			var point := Vector2(probe.point[0], probe.point[1])
			h._check(layers.inferred_level(point) == int(probe.level), "Native map source ribbon precedence: " + fixture.key)
			h._check(layers.separated(2, point, point, 0) == probe.separation, "Native map source blast-grid registration")

static func support_physics(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("supportCaptures"):
		h._check(false, "Regenerate original roof polygon/triangulation captures")
		return
	for fixture: Dictionary in fixtures.supportCaptures:
		var root := Node3D.new()
		root.position = Vector3(4096, 0, 4096)
		h.add_child(root)
		var body := StaticBody3D.new()
		body.collision_layer = 1024
		root.add_child(body)
		# Query-only context: original fixture shapes supply all physical support.
		var simulation := BattleSimulation.new()
		h.add_child(simulation)
		simulation.set_physics_process(false)
		simulation.world = BattleWorld.new()
		simulation.world.native_data = NativeWorldData.new()
		simulation.add_child(simulation.world)
		for platform: Dictionary in fixture.captured.roofPlatforms:
			var vertices := PackedVector3Array()
			for offset in range(0, platform.faces.size(), 3):
				vertices.append(Vector3(platform.faces[offset], platform.faces[offset + 1], platform.faces[offset + 2]))
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(vertices)
			shape.backface_collision = true
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.disabled = platform.active == false
			body.add_child(collision)
		await h.get_tree().physics_frame
		await h.get_tree().physics_frame
		for probe: Dictionary in fixture.probes:
			var query := PhysicsRayQueryParameters3D.create(root.global_position + Vector3(probe.point[0], 100, probe.point[1]),
				root.global_position + Vector3(probe.point[0], -100, probe.point[1]), 1024)
			var space := root.get_world_3d().direct_space_state
			var native := space.intersect_ray(query)
			var original := native.duplicate()
			var original_from := query.from
			var original_to := query.to
			var hit := SupportRay.refine(space, query, native)
			h._check(native == original and query.from == original_from and query.to == original_to,
				"Support refinement cannot mutate the original ray or native hit buffer")
			h._check(hit.is_empty() == (probe.result == null), "Original roof courtyard and native concave support presence: " + fixture.name)
			if not hit.is_empty() and probe.result != null:
				h._near(hit.position.y, probe.result, "Original highest active roof survives source triangulation and native physics")
				h._check(hit.rid == native.rid and hit.shape == native.shape and hit.collider == native.collider
					and hit.normal == native.normal and hit.get("face_index", -1) == native.get("face_index", -1)
					and hit.position.x == native.position.x and hit.position.z == native.position.z,
					"Local support refinement preserves the original native hit identity, face and normal")
			var surface := simulation._projectile_surface(root.global_position + Vector3(probe.point[0], 99.99, probe.point[1]))
			h._check(is_finite(surface) == (probe.result != null), "Authority support query preserves original roof/hole/active presence")
			if is_finite(surface) and probe.result != null:
				h._near(surface, probe.result, "Authority launch support retains original roof height within the unchanged tolerance")
				for offset: float in [-.005, 0.0, .1, 1.0]:
					var near_point := root.global_position + Vector3(probe.point[0], float(probe.result) + offset, probe.point[1])
					h._near(simulation._projectile_surface(near_point), probe.result,
						"Authority refinement retains the original segment limit near roof contact")
			query.exclude = [body.get_rid()]
			h._check(SupportRay.intersect(space, query).is_empty(), "Support refinement retains native excluded-body filtering")
		simulation.free()
		root.free()
		await h.get_tree().physics_frame

static func scenery_references(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("sceneryClearance"):
		h._check(false, "Regenerate original whole-scenery clearAround references")
		return
	var matrices = preload("res://tests/quaternion_suite.gd")
	for fixture: Dictionary in fixtures.sceneryClearance:
		var root := Node3D.new()
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh = BoxMesh.new()
		batch.multimesh.instance_count = fixture.matrices.size()
		for index in range(fixture.matrices.size()):
			batch.multimesh.set_instance_transform(index, matrices.frame(fixture.matrices[index]))
		var original := batch.multimesh
		batch.set_meta("source_camp_building_batch", true)
		root.add_child(batch)
		var landmarks: Array[MeshInstance3D] = []
		for spec: Dictionary in fixture.landmarks:
			var node := MeshInstance3D.new()
			node.mesh = BoxMesh.new()
			if not spec.has("key"):
				node.set_meta("source_camp_landmark", spec)
			root.add_child(node)
			landmarks.append(node)
		var presentation := SceneryPresentation.new()
		h._check(presentation.configure(root), "Bind original building batches and unkeyed landmark roster")
		presentation.clear_camps(fixture.camps, {})
		presentation.clear_camps(fixture.camps, {})
		for index in range(fixture.matrices.size()):
			h._check(batch.multimesh.get_instance_transform(index).is_equal_approx(matrices.frame(fixture.result.matrices[index])),
				"Original instanced clearAround overlap, rotation, mirror, zero-scale and repeated calls")
			h._check(original.get_instance_transform(index).is_equal_approx(matrices.frame(fixture.matrices[index])),
				"Camp visual clearance cannot mutate the imported shared MultiMesh")
		for index in range(landmarks.size()):
			h._check(landmarks[index].visible == fixture.result.visible[index], "Original landmark clearance retains keyed ownership and strict circle boundary")
		root.free()

static func blasts(h: Node, fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	h.add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [], {"time": "day", "weather": "clear"}, true)
	if not h._require_prepared_match(sim, "Structure layered blast"):
		return
	sim.set_physics_process(false)
	for unit: BattleUnit in sim.units.values():
		unit.side = "STEEL"
	var owner := BattleUnit.new()
	owner.side = "STEEL"
	for fixture: Dictionary in fixtures:
		sim.world.layers.configure(fixture.slabs)
		var targets := {}
		for spec: Dictionary in fixture.targets:
			var target := sim.spawn({"kind": "soldier", "side": spec.side, "lane": 0, "position": Vector3(spec.point[0], 0, spec.point[1])})
			target.hp = 1000
			target.armor = 0
			target.shield = 0
			targets[int(spec.id)] = target
		sim.blast(owner, {"dmg": 20.0, "r": 30.0, "pen": 0.0}, Vector3(fixture.impact[0], 1, fixture.impact[1]), fixture.friendly, true, int(fixture.level))
		for id: int in targets:
			var expected := 0.0
			for hit: Dictionary in fixture.hits:
				if int(hit.id) == id:
					expected = hit.amount
			h._check(absf((1000 - targets[id].hp) - expected) < 0.001, "Original layered blast target/damage: " + fixture.name)
			sim.units.erase(targets[id].entity_id)
			targets[id].queue_free()
	owner.free()
	sim.queue_free()
	await h.get_tree().process_frame

static func physics(h: Node) -> void:
	var sim := BattleSimulation.new()
	h.add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 901, "side": "STEEL", "character": "t03", "bot": false},
		{"peer": 902, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not h._require_prepared_match(sim, "Structure bridge physics"):
		return
	sim.set_physics_process(false)
	# Source fixtures assume flat ground at y=0; keep every height relative to the authored terrain.
	var base := sim.world.ground_height(0, 0)
	var owner: BattleUnit = sim.pilots[901]
	var target: BattleUnit = sim.pilots[902]
	owner.position = Vector3(0, base + 0.1, 20)
	target.position = Vector3(0, base + 10.1, 0)
	var deck := {"x1": -40.0, "z1": 0.0, "y1": base + 10, "x2": 40.0, "z2": 0.0, "y2": base + 10, "hw": 8.0}
	sim.world.layers.configure([[-40.0, 0.0, 40.0, 0.0, 8.0, 1, 0]], [deck])
	var platform := StaticBody3D.new()
	platform.collision_layer = 1 | 16
	platform.position = Vector3(0, base + 9.5, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 1, 16)
	collision.shape = shape
	platform.add_child(collision)
	sim.world.add_child(platform)
	await h.get_tree().physics_frame
	await h.get_tree().physics_frame
	h._check(sim._unit_level(target) == 1, "Authority derives a human hero's bridge layer from native support")
	h._check(absf(sim._missile_target_altitude(target) - 0.1) < 0.001, "Bridge height reference remains the standing deck")
	target.shield = 0
	var health := target.hp
	# Relative blast impacts stay in the source height-above-surface frame.
	sim.blast(owner, {"dmg": 20.0, "r": 30.0}, Vector3(0, 1, 0), false, true, 0)
	h._near(target.hp, health, "Ground blast directly below the same bridge cannot cross its layer")
	sim.blast(owner, {"dmg": 20.0, "r": 30.0}, Vector3(0, 1, 12), false, true, 0)
	h._check(target.hp < health, "Source side overflow still reaches bridge heroes")
	target.hp = health
	sim.blast(owner, {"dmg": 20.0, "r": 30.0}, Vector3(0, 1, 0), false, true, -1)
	h._check(target.hp < health, "Absent impact level deliberately bypasses structural separation")
	target.hp = health
	var tower := sim.spawn({"kind": "tower", "side": "SWARM", "lane": 0, "position": Vector3(0, base + 10, 0)})
	tower.shield = 0
	var tower_health := tower.hp
	var def: Dictionary = Content.weapon(owner.character, "heavy").duplicate(true)
	def.dmg = 20.0
	def.r = 30.0
	def.pen = 0.0
	var round := ProjectileMotion.ballistic(Vector3(4, base + 20, 0), Vector3(0, -200, 0), 100)
	round.actor = owner.entity_id
	round.side = owner.side
	round.definition = def
	sim.projectiles.append(round)
	sim._tick_projectiles(0.1)
	h._check(sim.projectiles.is_empty() and tower.hp < tower_health, "Physical bridge impact reports source level zero and reaches bridge structures")
	h._near(target.hp, health, "Physical bridge impact retains source hero layer isolation")
	sim.world.layers.configure([])
	h._check(sim._unit_level(target) == 0 and absf(sim._missile_target_altitude(target) - 10.1) < 0.001, "Rooftop without a matching deck uses terrain height reference")
	var rooftop_shooter := sim.spawn({"kind": "robot", "side": "STEEL", "character": "t04", "position": Vector3(0, base + 10.1, 0)})
	sim.fire(rooftop_shooter, "light")
	h._check(sim.projectiles.size() == 1, "A verified rooftop permits an authority kinetic launch")
	if sim.projectiles.is_empty():
		sim.queue_free()
		await h.get_tree().process_frame
		return
	var frame: Dictionary = sim.projectiles[0].shooter_frame
	h._check(absf(frame.altitude - 10.1) < 0.001 and frame.position == rooftop_shooter.position and frame.eye_y == rooftop_shooter.position.y + rooftop_shooter.view_eye_height(),
		"Launch height frame retains source rooftop terrain reference and absolute hero eye")
	rooftop_shooter.position += Vector3(300, -9, 400)
	rooftop_shooter.flying = true
	h._check(sim.projectiles[0].shooter_frame == frame and frame.position != rooftop_shooter.position,
		"Movement and morph changes cannot rewrite a launched shooter's height frame")
	sim.queue_free()
	await h.get_tree().process_frame

static func tunnel_impacts(h: Node) -> void:
	var sim := BattleSimulation.new()
	h.add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 911, "side": "STEEL", "character": "t03", "bot": false},
		{"peer": 912, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not h._require_prepared_match(sim, "Structure tunnel impacts"):
		return
	sim.set_physics_process(false)
	var base := sim.world.ground_height(0, 0)
	var owner: BattleUnit = sim.pilots[911]
	var target: BattleUnit = sim.pilots[912]
	for unit: BattleUnit in sim.units.values():
		unit.position = Vector3(400, 0, 400)
	owner.position = Vector3(0, base + 0.1, 40)
	target.position = Vector3(0, base + 0.1, 0)
	var tunnel := {"x1": -40.0, "z1": 0.0, "fy1": base, "x2": 40.0, "z2": 0.0, "fy2": base, "hw": 8.0, "cy1": base + 4, "cy2": base + 4, "open": false}
	# Native positive Z is the source negative-lateral gallery side (bit 2).
	sim.world.layers.configure([[-40.0, 0.0, 40.0, 0.0, 8.0, 2, 2]], [], [tunnel])
	var gallery := sim.spawn({"kind": "soldier", "side": "SWARM", "lane": 0, "position": Vector3(0, base + 0.1, 12)})
	var solid := sim.spawn({"kind": "soldier", "side": "SWARM", "lane": 0, "position": Vector3(0, base + 0.1, -12)})
	var portal := sim.spawn({"kind": "soldier", "side": "SWARM", "lane": 0, "position": Vector3(50, base + 0.1, 0)})
	for unit in [target, gallery, solid, portal]:
		unit.hp = 1000
		unit.shield = 0
		unit.armor = 0
	await h.get_tree().physics_frame
	await h.get_tree().physics_frame
	h._check(sim._unit_level(target) == 2, "Authority classifies a human below a covered ceiling")
	target.position.y = base + 4
	h._check(sim._unit_level(target) == 0, "Human at the ceiling has exited the tunnel layer")
	target.is_bot = true
	h._check(sim._unit_level(target) == 2, "Source bots retain inferred ribbon level without a human report")
	target.is_bot = false
	target.position.y = base + 0.1
	sim.blast(owner, {"dmg": 20.0, "r": 80.0}, Vector3(0, 1, 0), false, true, 2)
	h._check(target.hp < 1000 and gallery.hp < 1000, "Same tunnel and open gallery side receive blast")
	h._near(solid.hp, 1000, "Solid tunnel flank prevents cross-layer blast")
	h._near(portal.hp, 1000, "Tunnel portal allows sight but prevents cross-layer blast")
	for unit in [target, gallery, solid]:
		unit.hp = 1000
	# Exercise the real physical warhead endpoint, not a direct blast call.
	var def: Dictionary = Content.weapon(owner.character, "heavy").duplicate(true)
	def.dmg = 20.0
	def.r = 30.0
	def.pen = 0.0
	def.projectile.arm = {}
	var round := ProjectileMotion.ballistic(Vector3(4, base + 2, 0), Vector3(0, -200, 0), 100)
	round.actor = owner.entity_id
	round.side = owner.side
	round.definition = def
	sim.projectiles.append(round)
	sim._tick_projectiles(0.02)
	h._check(sim.projectiles.is_empty() and target.hp < 1000 and gallery.hp < 1000, "Physical lob impact settles covered-tunnel layer and relative body bands")
	h._near(solid.hp, 1000, "Physical lob cannot leak through the solid tunnel side")
	for unit in [target, gallery, solid]:
		unit.hp = 1000
	# Authority missiles keep the source altitude frame.
	var missile := {"actor": owner.entity_id, "side": owner.side, "target": target.entity_id,
		"position": Vector3(0, 1, 1), "origin": Vector3(0, 1, 1), "speed": 110.0,
		"dmg": 20.0, "pen": 0.0, "r": 30.0, "hp": 1.0, "ttl": 5.0, "range": 100.0}
	sim._launch_missile(missile)
	sim._tick_missiles(0.02)
	h._check(sim.missiles.is_empty() and target.hp < 1000 and gallery.hp < 1000, "SAM proximity fuse inherits target tunnel layer")
	h._near(solid.hp, 1000, "SAM target-level fuse preserves solid-side isolation")
	for unit in [target, gallery, solid]:
		unit.hp = 1000
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.position = Vector3(0, base + 1, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.1, 2, 2)
	collision.shape = shape
	wall.add_child(collision)
	sim.world.add_child(wall)
	await h.get_tree().physics_frame
	await h.get_tree().physics_frame
	missile = missile.duplicate(true)
	missile.erase("components")
	missile.position = Vector3(-2, 1, 0)
	missile.lost = true
	missile.velocity_components = [200.0, 0.0, 0.0]
	sim._launch_missile(missile)
	sim._tick_missiles(0.02)
	h._check(sim.missiles.is_empty() and solid.hp < 1000, "SAM obstacle blast deliberately omits layer separation")
	sim.queue_free()
	await h.get_tree().process_frame
