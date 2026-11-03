extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const JointTests = preload("res://tests/body_joint_suite.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("bodyBipeds") or not fixtures.has("bodyAerials") or not fixtures.has("bodyQuads") or not fixtures.has("bodyVehicles"):
		h._check(false, "Regenerate original complete biped/hop/aerial/quad/vehicle traces")
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
	var hopping := 0
	var walking := 0
	var flying := 0
	var quadrupeds := 0
	var wheeled := 0
	var tracked := 0
	var cephalopods := 0
	for item: Dictionary in fixtures.bodyBipeds + fixtures.bodyAerials + fixtures.bodyQuads + fixtures.bodyVehicles:
		var rig := BodyRig.new()
		h.add_child(rig)
		if not rig.configure(item.key):
			h._check(false, "Pack original gait body scene: " + item.key)
			rig.free()
			continue
		var owner: Dictionary = rig.forms[item.form]
		var state: Dictionary = item.initial.duplicate(true)
		var entity: Dictionary = {}
		var expected: Dictionary = baseline[item.key].duplicate(true)
		if item.kind == "aerial":
			flying += 1
		elif item.kind == "quad":
			quadrupeds += 1
			if item.cephalopod:
				cephalopods += 1
		elif item.kind == "wheeled":
			wheeled += 1
		elif item.kind == "tracked":
			tracked += 1
		elif item.hop:
			hopping += 1
		else:
			walking += 1
		for step: Dictionary in item.steps:
			owner.merge(step.get("pose", {}), true)
			state.accel = step.acceleration
			if step.get("travelOnly", false):
				var inputs := {"delta": step.delta, "now": step.now, "speed": step.speed, "forward": step.forward, "yawRate": step.yawRate}
				inputs[step.invalid] = -0.1 if step.value == "negative" else NAN if step.value == "nan" else INF
				BodyGaitVehicle.travel(rig.poses, state, owner, inputs.delta, inputs.now, inputs.speed, inputs.forward, inputs.yawRate)
			elif item.kind == "biped":
				BodyGaitBiped.step(rig.poses, state, owner, step.delta, step.now, step.speed, step.yawRate)
			elif item.kind == "quad":
				BodyGaitQuad.step(rig.poses, state, owner, step.delta, step.now, step.speed, step.yawRate)
			elif item.kind == "aerial":
				BodyGaitAerial.step(rig.poses, state, owner, step.delta, step.now, step.forward, step.lateral, step.yawRate)
			else:
				BodyGaitVehicle.step(rig.poses, state, owner, step.delta, step.now, step.speed, step.forward, step.yawRate)
			if not step.get("travelOnly", false):
				BodySpeciesPose.aim_held(rig.poses, owner)
				if step.get("castInput") != null:
					entity.castFx = step.castInput.duplicate(true)
				BodyCastPose.step(rig.poses, state, owner, entity, step.now)
				if step.has("jump"):
					BodyJumpPose.step(rig.poses, state, owner, {"heroY": step.jump}, step.delta)
				BodySpeciesPose.step(rig.poses, state, owner, step.delta, step.now, step.speed)
			if step.castResult == null:
				h._check(entity.get("castFx") == null, "Original future/expired cast event clears at its duration edge")
			else:
				Helper.compare(h, entity.get("castFx"), step.castResult, "Original active cast presentation event")
			Helper.compare(h, state, step.state, "Original complete gait state: " + item.key + "/" + item.form)
			Helper.compare(h, owner.get("limbP"), step.profile, "Original lazily selected human/animal limb profile")
			for index in range(step.tracks.size()):
				var track: Dictionary = owner.tracks[index]
				h._near(track.travel, step.tracks[index].travel, "Original signed tread travel and reverse turning")
				JointTests.compare_node(h, rig.poses, track.pose, step.tracks[index].pose, "Original retained track scratch pose")
			for index in range(step.jets.size()):
				var jet: Dictionary = owner.jets[index]
				var first := jet.m1 as BaseMaterial3D
				var second := jet.m2 as BaseMaterial3D
				h._near(first.albedo_color.a, step.jets[index].opacity1, "Original jet flame opacity")
				h._near(second.albedo_color.a, step.jets[index].opacity2, "Original jet core opacity")
				h._near(first.emission_energy_multiplier, step.jets[index].emission, "Original jet thrust emission")
			for spec: Dictionary in step.nodes:
				expected[int(spec.id)] = spec
			for id: int in expected:
				var spec: Dictionary = expected[id]
				var node: Node3D = rig.nodes[id]
				Helper.compare(h, rig.poses.rotation(node), spec.rotation, "Original gait logical Euler: " + item.key)
				var frame := Transform3D(Basis(BodyPose.quaternion(spec.quaternion)).scaled_local(BodyPose.vector(spec.scale)), BodyPose.vector(spec.position))
				h._check(node.position.distance_to(frame.origin) < .0002 and node.basis.x.distance_to(frame.basis.x) < .0002
					and node.basis.y.distance_to(frame.basis.y) < .0002 and node.basis.z.distance_to(frame.basis.z) < .0002,
					"Original complete gait joint pose: " + item.key)
				h._check(node.visible == spec.visible and int(node.get_parent().get_meta("source_id", -1)) == int(spec.parent),
					"Gait preserves the complete authored hierarchy and visibility")
				if spec.has("instances"):
					JointTests.compare_instances(h, node, spec.instances, "Original complete track-shoe motion")
		rig.free()
	h._check(walking > 0 and hopping > 0 and flying > 0 and quadrupeds > 0 and wheeled > 0 and tracked > 0 and cephalopods > 0,
		"Source body traces cover biped/hop/aerial/quad/wheeled/tracked rigs")
