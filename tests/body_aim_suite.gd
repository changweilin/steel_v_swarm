extends RefCounted

const JointTests = preload("res://tests/body_joint_suite.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("bodyAiming"):
		h._check(false, "Regenerate original world stabilization/weapon-axis body references")
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
				states[int(spec.id)] = {"parent": spec.parent, "position": spec.trs.p, "quaternion": spec.trs.q, "scale": spec.trs.s, "visible": spec.visible}
				if spec.has("instances"):
					states[int(spec.id)].instances = spec.instances
			baseline[item.key] = states
		items = []
	h._check(rows == int(section.count), "Every captured body geometry case is consumed in original section order")
	for item: Dictionary in fixtures.bodyAiming:
		var rig := BodyRig.new()
		h.add_child(rig)
		if not rig.configure(item.key):
			h._check(false, "Pack original world-aim body scene: " + item.key)
			rig.free()
			continue
		var owner: Dictionary = rig.forms[item.form]
		var expected: Dictionary = baseline[item.key].duplicate(true)
		for step: Dictionary in item.steps:
			for update: Dictionary in step.updates:
				var node: Node3D = rig.nodes[int(update.id)]
				if update.has("rotation"):
					rig.poses.set_rotation(node, update.rotation)
				if update.has("position"):
					rig.poses.set_position(node, BodyPose.vector(update.position))
				if update.has("scale"):
					rig.poses.set_scale(node, BodyPose.vector(update.scale))
			BodyAimPose.stabilize(rig.poses, owner)
			BodyAimPose.forward(rig.poses, owner, step.state)
			for spec: Dictionary in step.nodes:
				expected[int(spec.id)] = spec
			for id: int in expected:
				var node: Node3D = rig.nodes[id]
				var spec: Dictionary = expected[id]
				var frame := Transform3D(SourceQuaternion.basis(BodyPose.quaternion(spec.quaternion)).scaled_local(BodyPose.vector(spec.scale)), BodyPose.vector(spec.position))
				h._check(node.position.distance_to(frame.origin) < .0002 and node.basis.x.distance_to(frame.basis.x) < .0002
					and node.basis.y.distance_to(frame.basis.y) < .0002 and node.basis.z.distance_to(frame.basis.z) < .0002,
					"Original world stabilizer/weapon-axis result at native transform precision: " + item.key)
				h._check(node.visible == spec.visible and int(node.get_parent().get_meta("source_id", -1)) == int(spec.parent),
					"World aim correction preserves the authored hierarchy and visibility")
				if spec.has("instances"):
					JointTests.compare_instances(h, node, spec.instances, "World aim correction preserves all instance poses")
		rig.free()
