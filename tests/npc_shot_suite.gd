extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const Frames = preload("res://tests/view_suite.gd")

class BudgetEffects extends CombatEffects:
	var freed: Array = []
	var fades: Array = []
	func _ready() -> void:
		pass
	func _drop(effect: Dictionary) -> void:
		freed.append(effect.id)
	func _pose(effect: Dictionary, fraction: float, _delta: float = 0.0) -> void:
		fades.append({"id": effect.id, "f": fraction, "delta": effect.age})

static func run(h: Node, fixtures: Dictionary) -> void:
	for key: String in ["npcShotEffects", "combatBursts", "npcArtillery", "npcEffectBudget", "npcShotStyles", "npcShotReports"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original NPC shot/arc/effect-budget references")
			return
	for item: Dictionary in fixtures.npcShotStyles:
		Helper.compare(h, NpcShotMotion.style(item.kind, item.wid), item.result, "Original kind/weapon presentation overrides, empty IDs and base/tower priority")
	for item: Dictionary in fixtures.npcShotReports:
		Helper.compare(h, NpcShotMotion.report_style(item.event, item.actor), item.result, "Original event kind override retains the actual actor's weapon fallback")
	for item: Dictionary in fixtures.npcArtillery:
		var arc := NpcShotMotion.artillery(BodyPose.vector(item.origin), BodyPose.vector(item.target))
		_point(h, arc.velocity, item.velocity, "Original lowest reachable artillery charge and low-angle velocity")
		h._near(arc.flight, item.flight, "Original artillery flight time including zero horizontal range")
		var rig := BodyRig.new()
		rig.forms = {"ground": {"gunR": {"comp": .55, "aim": 0.0}} if item.mount == "gun" else {}}
		if item.mount == "turret":
			var pivot := Node3D.new()
			rig.add_child(pivot)
			rig.mounts.pitch = pivot
		var entity: Dictionary = {}
		NpcShotMotion.aim(rig, entity, arc.angle, 10)
		if item.aim != null:
			h._near(rig.forms.ground.gunR.aim, item.aim, "Original handheld howitzer compensation follows its actual launch angle")
		if item.arc != null:
			Helper.compare(h, entity._arcPitch, item.arc, "Original mechanical artillery pitch override and hold deadline")
		else:
			h._check(not entity.has("_arcPitch"), "Handheld/missing mounts do not invent a turret pitch override")
		rig.free()
	var effects := CombatEffects.new()
	h.add_child(effects)
	effects.random_sample = func(): return .25
	for item: Dictionary in fixtures.npcShotEffects + fixtures.combatBursts:
		effects.low_power = item.low
		for index in range(int(item.padding)):
			effects.effects.append({"obj": null})
		var queries: Array = []
		var clip := func(origin: Vector3, target: Vector3):
			var obstruction := func(start: Vector3, end: Vector3):
				if item.wall == null or start.x == end.x:
					return {}
				var fraction := (float(item.wall) - start.x) / (end.x - start.x)
				return {"position": start.lerp(end, fraction)} if fraction >= 0 and fraction <= 1 else {}
			var result := NpcShotMotion.clip(origin, target, obstruction)
			queries.append({"from": [origin.x, origin.y, origin.z], "to": [target.x, target.y, target.z],
				"result": {"to": [result.to.x, result.to.y, result.to.z], "cut": result.cut}})
			return result
		if not item.has("effect"):
			effects.npc(BodyPose.vector(item.origin), BodyPose.vector(item.target), item.kind, null, "STEEL", clip,
				BodyPose.vector(item.motion.velocity) if item.motion != null else null,
				float(item.motion.gravity) if item.motion != null else 0.0, float(item.motion.flight) if item.motion != null else 0.0)
		else:
			var colors: Dictionary = Content.balance.npcShots.colors.get(item.get("side", ""), Content.balance.npcShots.colors[""])
			match item.effect:
				"muzzle": effects.muzzle(BodyPose.vector(item.origin), item.heavy, item.side)
				"shot": effects.shot(BodyPose.vector(item.origin), BodyPose.vector(item.target), item.heavy, item.side, item.heavy)
				"impact": effects.impact(BodyPose.vector(item.origin), item.radius, int(colors.col), int(colors.hot), item.heavy)
				"explosion": effects.explosion(BodyPose.vector(item.origin), item.radius, int(colors.col))
				"boom": effects.blast_burst(BodyPose.vector(item.origin), item.ground, item.radius, item.kami, item.sam)
		var created: Array = effects.effects.slice(int(item.padding))
		h._check(created.size() == item.initial.size(), "Original combat style branching and nested crowded-effect gates: " + str(item.get("kind", item.get("effect"))))
		Helper.compare(h, queries, item.queries, "Original obstacle-only clipping and eight ballistic chords")
		for index in range(mini(created.size(), item.initial.size())):
			h._near(created[index].duration, item.initial[index].ttl, "Original NPC flash, launch, beam and compressed-flight durations")
			_effect(h, created[index], item.initial[index])
		for step: Dictionary in item.samples:
			for index in range(mini(created.size(), step.effects.size())):
				effects._pose(created[index], maxf(0, 1 - float(step.progress)), .016)
				_effect(h, created[index], step.effects[index])
		for effect: Dictionary in created:
			effects._drop(effect)
		effects.effects.clear()
	effects.free()
	for item: Dictionary in fixtures.npcEffectBudget:
		var budget := BudgetEffects.new()
		for index in range(int(item.count)):
			budget.effects.append({"id": index, "ttl": .1 * (index % 3 + 1), "age": 0.0})
		budget.advance(item.delta)
		Helper.compare(h, budget.freed, item.freed, "Original global effect budget evicts oldest entries before reverse-order expiry")
		Helper.compare(h, budget.fades, item.fades, "Original effect remaining-life fraction and zero-delta updates")
		var remaining: Array = budget.effects.map(func(effect): return {"id": effect.id, "ttl": effect.ttl, "age": effect.age})
		Helper.compare(h, remaining, item.remaining, "Original effect expiry never settles combat")
		budget.free()

static func _effect(h: Node, effect: Dictionary, reference: Dictionary) -> void:
	var node: Node3D = effect.obj
	h._check(effect.type == reference.type and node.visible == reference.visible, "Original NPC primitive identity and delayed visibility")
	_point(h, node.position, reference.position, "Original NPC primitive position")
	_point(h, node.scale, reference.scale, "Original NPC primitive expansion/shrink")
	var rotation := BodyPose.quaternion(reference.quaternion)
	h._check(absf(node.quaternion.dot(rotation)) > .999999, "Original NPC primitive orientation")
	if reference.opacity != null:
		var material := (node as GeometryInstance3D).material_override as ShaderMaterial
		h._near(float(material.get_shader_parameter("opacity")), reference.opacity, "Original NPC primitive fade curve")
		var tint: Vector3 = material.get_shader_parameter("tint")
		var encoded := Color(tint.x, tint.y, tint.z).linear_to_srgb()
		h._check(int(encoded.to_rgba32() >> 8) == int(reference.color), "Original NPC primitive linear material colour")
		if reference.roll != null:
			# Unassigned uniforms read back as null; sprites that never set roll keep the shader default.
			var roll: Variant = material.get_shader_parameter("roll")
			if roll == null:
				roll = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), "roll")
			h._check(roll != null, "Original sprite material declares a billboard roll")
			if roll != null:
				h._near(float(roll), reference.roll, "Original starburst billboard roll from an independent visual stream")
	if reference.has("instances"):
		var batch := node as MultiMeshInstance3D
		h._check(batch.multimesh.instance_count == reference.instances.size(), "Original bounded NPC beam ring count")
		for index in range(reference.instances.size()):
			var actual := batch.multimesh.get_instance_transform(index)
			var expected := Frames.frame(reference.instances[index])
			h._check(actual.origin.distance_to(expected.origin) < .0001 and actual.basis.is_equal_approx(expected.basis), "Original batched beam-ring travel and expansion")
		for index in range(reference.instanceColors.size()):
			var color := batch.multimesh.get_instance_color(index)
			_point(h, Vector3(color.r, color.g, color.b), reference.instanceColors[index], "Original linear per-instance beam-ring core/side colours")
	if reference.has("nodes"):
		var model := node as ProjectileVisual
		for row: Dictionary in reference.nodes:
			var part := model.nodes[int(row.id)] as MeshInstance3D
			_point(h, part.position, row.position, "Original NPC age/speed projectile attachment position")
			_point(h, part.scale, row.scale, "Original NPC age/speed projectile tail scale")
			h._near((part.get_active_material(0) as BaseMaterial3D).albedo_color.a, row.opacity, "Original NPC projectile opacity pulse")

static func _point(h: Node, actual: Vector3, expected: Array, label: String) -> void:
	var point := BodyPose.vector(expected)
	h._check(actual.distance_to(point) <= maxf(.0001, point.length() * .000001), label)
