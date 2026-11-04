extends RefCounted

const Helper = preload("res://tests/status_suite.gd")

class SpyEffects extends CombatEffects:
	var calls: Array = []
	func point(value: Vector3) -> Array:
		return [value.x, value.y, value.z]
	func spark(at: Vector3, radius: float, color: int, _delay: float = 0) -> void:
		calls.append({"type": "spark", "point": point(at), "radius": radius, "color": color})
	func shock(at: Vector3, radius: float, color: int) -> void:
		calls.append({"type": "shock", "point": point(at), "radius": radius, "color": color})
	func embers(at: Vector3, count: int = 8, spread: float = 2) -> void:
		calls.append({"type": "embers", "point": point(at), "count": count, "spread": spread})
	func crash_smoke(at: Vector3, size: float = 1) -> void:
		calls.append({"type": "smoke", "point": point(at), "size": size})

static func run(h: Node, fixtures: Dictionary) -> void:
	for key: String in ["victimHitGates", "victimHitPrimitives", "bodyShieldHits"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original snapshot hit/guard references: " + key)
			return
	for item: Dictionary in fixtures.victimHitGates:
		var reaction := VictimHitState.reaction(item.previous, item.current, item.hero)
		h._check(reaction.is_empty() == item.result.is_empty(), "Original first observation, healing, empty shield and armor-drop admission")
		Helper.compare(h, reaction, item.result, "Original snapshot defending/shield-loss priority and amplified flash peak")
	var effects := SpyEffects.new()
	for item: Dictionary in fixtures.victimHitPrimitives:
		effects.calls.clear()
		effects.victim(BodyPose.vector(item.origin), item.height, item.kind, item.shielded,
			null if item.camera == null else BodyPose.vector(item.camera))
		Helper.compare(h, effects.calls, item.calls, "Original victim body-height offset, sniper distance clamp and shield/building/ordinary primitives")
	effects.free()
	for item: Dictionary in fixtures.bodyShieldHits:
		var rig := BodyRig.new()
		h.add_child(rig)
		if not rig.configure(item.key):
			h._check(false, "Pack original guard binding: " + item.key)
			rig.free()
			continue
		var material := rig.materials[int(item.material)] as ShaderMaterial
		material.set_shader_parameter("uFlash", item.initial)
		if rig.forms.has("air"):
			rig.form = "air"
		for step: Dictionary in item.steps:
			rig.flash_shield(float(step.strength))
			h._near(float(material.get_shader_parameter("uFlash")), step.flash, "Original entity guard keeps its spawn material and cannot replace a stronger active flash")
		rig.free()
	_production(h, fixtures.bodyShieldHits)

static func _production(h: Node, guards: Array) -> void:
	var matches: Array = guards.filter(func(item): return Content.balance.bodies[item.key].character != null)
	h._check(not matches.is_empty(), "Original body guards contain a rendered pilot for snapshot integration")
	if matches.is_empty():
		return
	var item: Dictionary = matches[0]
	var profile: Dictionary = Content.balance.bodies[item.key]
	var simulation := BattleSimulation.new()
	h.add_child(simulation)
	simulation.set_physics_process(false)
	simulation.world = BattleWorld.new()
	simulation.add_child(simulation.world)
	var owner := Helper.actor(simulation, {"id": 1, "character": profile.character, "side": profile.side, "position": [12, 20, -9],
		"hp": 700, "max_hp": 1000, "shield": 120, "power": 80, "ammo": {"light": 4, "heavy": 2}})
	owner._configure_body(item.key)
	if owner.body == null:
		h._check(false, "Pack the actual original pilot body for snapshot hit production")
		simulation.free()
		return
	var resources := [owner.hp, owner.shield, owner.power, owner.ammo.duplicate(), owner.fire_serial,
		simulation.rng.state, simulation.projectile_rng.state]
	var publish := func(vitals: Dictionary):
		var state := {"id": owner.entity_id, "position": owner.position, "yaw": 0.0, "max_hp": owner.max_hp,
			"max_shield": owner.max_shield, "side": owner.side}
		state.merge(vitals, true)
		simulation.apply_presentation_view({"units": [state], "clock": 10})
	publish.call({"hp": 700, "shield": 120, "defending": true})
	h._check(simulation.world.combat_effects == null, "First observation cannot invent a world hit")
	var report := {"hp": 690, "shield": 100, "defending": true}
	publish.call(report)
	var effects := simulation.world.combat_effects
	h._check(effects != null and effects.effects.size() == 1, "Shield loss wins over simultaneous armor loss and produces one shield contact star")
	if effects == null:
		simulation.free()
		return
	var material := owner.body.materials[int(item.material)] as ShaderMaterial
	var flash := float(material.get_shader_parameter("uFlash"))
	h._check(flash > 0, "Published shield loss reaches the original body guard material")
	publish.call(report)
	publish.call({"hp": 700, "shield": 120, "defending": false})
	h._check(effects.effects.size() == 1 and float(material.get_shader_parameter("uFlash")) == flash, "Duplicate/healing snapshots cannot repeat contact effects or restart a shield flash")
	publish.call({"hp": 680, "shield": 120, "defending": false})
	h._check(effects.effects.size() == 9, "Published armor loss produces the original two stars, five embers and one smoke sprite")
	simulation.apply_presentation_view({"units": [], "clock": 10})
	publish.call({"hp": 600, "shield": 0, "defending": false})
	h._check(effects.effects.size() == 9, "Visibility re-entry establishes a new observed baseline")
	h._check(resources == [owner.hp, owner.shield, owner.power, owner.ammo, owner.fire_serial,
		simulation.rng.state, simulation.projectile_rng.state], "Snapshot fire/smoke and guard flashes cannot settle damage or consume combat resources/RNG")
	simulation.free()
