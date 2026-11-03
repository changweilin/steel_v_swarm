extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const JointTests = preload("res://tests/body_joint_suite.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("bodyCombat") or not Content.balance.bodyRules.has("combat"):
		h._check(false, "Regenerate original body combat-event/charge/material references")
		return
	var section: Dictionary = Content.fixture_registry.get("sections", {}).get("bodyGeometry", {})
	if section.is_empty():
		h._check(false, "Regenerate original body geometry references")
		return
	var baseline: Dictionary = {}
	var rows := 0
	# The geometry section exceeds the whole-suite budget, so only each partition's initial states are kept.
	for part in section.parts.size():
		var items: Array = Content.read_fixture_part("bodyGeometry", part)
		rows += items.size()
		for item: Dictionary in items:
			var states: Dictionary = {}
			for spec: Dictionary in item.nodes:
				states[int(spec.id)] = {"parent": spec.parent, "position": spec.trs.p, "quaternion": spec.trs.q,
					"scale": spec.trs.s, "rotation": spec.trs.r, "visible": spec.visible}
				if spec.has("instances"):
					states[int(spec.id)].instances = spec.instances
			baseline[item.key] = states
		items = []
	h._check(rows == int(section.count), "Every captured body geometry case is consumed in original section order")
	for item: Dictionary in fixtures.bodyCombat:
		var rig := BodyRig.new()
		h.add_child(rig)
		if not rig.configure(item.key):
			h._check(false, "Pack original body combat scene: " + item.key)
			rig.free()
			continue
		var entity: Dictionary = {}
		var events: Array = item.events.duplicate(true)
		var expected: Dictionary = baseline[item.key].duplicate(true)
		for step: Dictionary in item.steps:
			rig.form = step.form
			if step.has("shot"):
				entity.fireFx = events[int(step.shot)]
			if step.get("heavyInput") != null:
				entity.heavyFx = step.heavyInput.duplicate(true)
			if step.get("unitMuzzle") != null:
				BodyCombatFx.fire_unit_motion(rig.forms[rig.form], rig.nodes[int(step.unitMuzzle)], step.now)
			if step.has("unitOnly"):
				BodyCombatFx.unit_motion(rig.poses, rig.forms[rig.form], NAN if step.unitOnly == "nan" else INF)
			else:
				rig.step_combat(entity, step.now, step.delta)
			if step.state == null:
				h._check(entity.get("cfx") == null, "Zero/negative body FX steps preserve lazy clock initialization")
			else:
				Helper.compare(h, entity.cfx, step.state, "Original body recoil/charge/aim clocks: " + item.key)
				var event: Variant = entity.cfx.get("fireEvent")
				h._check(event == null if int(step.event) < 0 else is_same(event, events[int(step.event)]), "Original immutable shot event identity")
			Helper.compare(h, entity.get("heavyFx"), step.heavy, "Original heavy spike expiration")
			if step.heavy == null:
				h._check(entity.get("heavyFx") == null, "Expired body heavy event clears once")
			for form: String in step.forms:
				var owner: Dictionary = rig.forms[form]
				var result: Dictionary = step.forms[form]
				for field: String in result.fields:
					var value: Variant = owner.get(field)
					if value is float and value == INF:
						value = "Infinity"
					Helper.compare(h, value, result.fields[field], "Original active/hidden body combat field: " + field)
				for slot: String in result.indices:
					h._check(int(owner.weaponSequences[slot].index) == int(result.indices[slot]), "Distinct same-time shots advance both morph weapon owners")
				for index in range(result.blink.size()):
					if result.blink[index] == null:
						h._check(owner.blink[index].get("base") == null, "Blink base remains lazy before a positive FX step")
					else:
						h._near(owner.blink[index].base, result.blink[index], "Blink base captures the current finished material once")
				for index in range(result.attacks.size()):
					if result.attacks[index] == null:
						h._check(owner.attacks[index].firedAt == -INF, "Unfired native recoil mount preserves its absent clock")
					else:
						h._near(owner.attacks[index].firedAt, result.attacks[index], "Original rigid recoil mount event clock")
				if result.hair != null:
					for field: String in ["firedAt", "startedAt"]:
						if result.hair[field] == null:
							h._check(owner.hairFlick[field] == -INF, "Unstarted hair burst retains its source absent clock")
						else:
							h._near(owner.hairFlick[field], result.hair[field], "Original hair burst pluck/release producer clock")
			for material: Dictionary in step.materials:
				var native := rig.materials[int(material.id)] as BaseMaterial3D
				h._near(BodyMaterials.emission(native), material.emission, "Original logical double-precision material emission")
				h._near(native.emission_energy_multiplier, material.emission, "Native body glow/blink emission")
			for node: Dictionary in step.nodes:
				expected[int(node.id)] = node
			for id: int in expected:
				var node: Node3D = rig.nodes[id]
				var spec: Dictionary = expected[id]
				JointTests.compare_node(h, rig.poses, node, {"p": spec.position, "q": spec.quaternion, "s": spec.scale, "r": spec.rotation},
					"Original complete body combat pose: " + item.key)
				h._check(node.visible == spec.visible and int(node.get_parent().get_meta("source_id", -1)) == int(spec.parent),
					"Original body muzzle flame and transported attachment state")
				if spec.has("instances"):
					JointTests.compare_instances(h, node, spec.instances, "Body combat preserves tread instance matrices")
		rig.free()
