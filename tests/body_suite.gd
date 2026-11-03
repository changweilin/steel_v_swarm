extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const ViewTests = preload("res://tests/view_suite.gd")
const MorphTests = preload("res://tests/body_morph_suite.gd")
const LocomotionTests = preload("res://tests/locomotion_suite.gd")
const GaitTests = preload("res://tests/body_gait_suite.gd")
const JointTests = preload("res://tests/body_joint_suite.gd")
const CombatTests = preload("res://tests/body_combat_suite.gd")
const AimTests = preload("res://tests/body_aim_suite.gd")
const AnatomicalTests = preload("res://tests/body_anatomical_suite.gd")
const FrameTests = preload("res://tests/body_frame_suite.gd")
const PresentationTests = preload("res://tests/body_presentation_suite.gd")
const AuthorityTests = preload("res://tests/authority_body_suite.gd")
const NpcTests = preload("res://tests/npc_body_suite.gd")
const CloneTests = preload("res://tests/clone_body_suite.gd")
const CarrierTests = preload("res://tests/carrier_body_suite.gd")
const CivilianTests = preload("res://tests/civilian_body_suite.gd")
const BodyViewTests = preload("res://tests/body_view_suite.gd")
const NpcShotTests = preload("res://tests/npc_shot_suite.gd")
const HeroShotTests = preload("res://tests/hero_shot_suite.gd")
const RemoteShotTests = preload("res://tests/remote_shot_suite.gd")
const SpriteTests = preload("res://tests/combat_sprite_suite.gd")
const VictimTests = preload("res://tests/victim_hit_suite.gd")
const FirstPersonShieldTests = preload("res://tests/first_person_shield_suite.gd")
const HurtTests = preload("res://tests/hurt_overlay_suite.gd")
const BloodTests = preload("res://tests/blood_splat_suite.gd")
const SplatPaintTests = preload("res://tests/splat_paint_suite.gd")
const PresentationFrameTests = preload("res://tests/presentation_frame_suite.gd")
const DestructionTests = preload("res://tests/destruction_suite.gd")
const DeathSequenceTests = preload("res://tests/death_sequence_suite.gd")
const BlastFeedbackTests = preload("res://tests/blast_feedback_suite.gd")
const SceneDamageTests = preload("res://tests/scene_damage_suite.gd")
const MobileDamageTests = preload("res://tests/mobile_damage_suite.gd")
const DamageFxTests = preload("res://tests/damage_fx_suite.gd")
const MissilePresentationTests = preload("res://tests/missile_presentation_suite.gd")
const MissileViewRayTests = preload("res://tests/missile_view_ray_suite.gd")
const BodyRemovalTests = preload("res://tests/body_removal_suite.gd")
const DissolveTests = preload("res://tests/dissolve_suite.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not Content.balance.has("bodies") or not Content.balance.has("bodyRules"):
		h._check(false, "Regenerate original body rig/shield metadata")
		return
	for key: String in ["bodyWeapons", "bodyShield"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original body oracle: " + key)
			return
	var geometry: Dictionary = Content.fixture_registry.get("sections", {}).get("bodyGeometry", {})
	if geometry.is_empty():
		h._check(false, "Regenerate original body oracle: bodyGeometry")
		return
	var baseline: Dictionary = {}
	var rows := 0
	# The geometry section exceeds the whole-suite budget, so each captured partition
	# is decoded, checked and released before the next one is read.
	for part in geometry.parts.size():
		var items: Array = Content.read_fixture_part("bodyGeometry", part)
		rows += items.size()
		for item: Dictionary in items:
			_check_geometry(h, item, baseline)
		items = []
	h._check(rows == int(geometry.count), "Every captured body geometry case is consumed in original section order")
	for item: Dictionary in fixtures.bodyWeapons:
		var rig := BodyRig.new()
		h.add_child(rig)
		if not rig.configure(item.key):
			h._check(false, "Pack original body weapon scene: " + item.key)
			rig.free()
			continue
		rig.source_root.position = h._reference_vector(item.position)
		rig.source_root.rotation.y = item.yaw
		var previous: Dictionary = {}
		var expected_states: Dictionary = baseline[item.key].duplicate(true)
		for step: Dictionary in item.steps:
			if step.has("slot"):
				var event: Dictionary = previous if step.duplicate else {"slot": step.slot, "t0": step.t0}
				rig.fire(event)
				previous = event
				rig.pose_payloads(step.t0)
			elif step.has("spin"):
				rig.spin(step.spin)
			else:
				rig.pose_payloads(step.now)
			if step.has("forms"):
				for form: String in step.forms:
					var owner: Dictionary = rig.forms[form]
					var emitter_index := 0
					for track: Dictionary in owner.get("referenceMotion", {}).get("fire", []):
						for emitter: Dictionary in track.get("emitters", []):
							var expected: Dictionary = step.forms[form].emitters[emitter_index]
							var entry: Dictionary = owner.weaponSequences[expected.slot].entries[int(expected.index)]
							h._check(is_same(emitter.entry, entry), "Native rig metadata preserves the original shared emitter entry")
							if expected.at == null:
								h._check(float(emitter.entry.firedAt) == -INF, "Unfired emitter retains the source absent clock")
							else:
								h._near(float(emitter.entry.firedAt), expected.at, "Original event updates the motion emitter clock through shared identity")
							emitter_index += 1
					for slot: String in step.forms[form].indices:
						h._check(int(owner.weaponSequences[slot].index) == int(step.forms[form].indices[slot]),
							"Original distinct same-clock shots versus immutable duplicate event")
					for slot: String in step.forms[form].muzzles:
						var expected: Dictionary = step.forms[form].muzzles[slot]
						if expected.point == null or expected.fxOnly:
							h._check(not rig.next_muzzle(slot, form).is_finite(), "Effect-only body marker requires the original caller fallback")
						else:
							h._check(rig.next_muzzle(slot, form).distance_to(h._reference_vector(expected.point)) < .0002,
								"Original next body-mounted muzzle follows the current hierarchy")
			for spec: Dictionary in step.nodes:
				expected_states[int(spec.id)] = spec
			for spec: Dictionary in expected_states.values():
				var node: Node3D = rig.nodes[int(spec.id)]
				var q: Array = spec.quaternion
				var basis := Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled_local(h._reference_vector(spec.scale))
				compare_transform(h, node.transform, Transform3D(basis, h._reference_vector(spec.position)), "Original body payload/spinner/transport local pose")
				if spec.has("instances"):
					JointTests.compare_instances(h, node, spec.instances, "Weapon events preserve all body instance poses")
				h._check(node.visible == spec.visible, "Original body event visibility")
				var parent: int = node.get_parent().get_meta("source_id", -1)
				h._check(parent == int(spec.parent), "Original combat joint/flame reparent keeps its local pose")
		rig.free()
	for item: Dictionary in fixtures.bodyShield:
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/reference_shield.gdshader")
		var strength := ShieldPresentation.hit_strength(item.drop)
		h._near(strength, item.strength, "Original shield-drop flash mapping")
		material.set_shader_parameter("uTime", 3.0)
		material.set_shader_parameter("uFlash", strength)
		for step: Dictionary in item.steps:
			ShieldPresentation.step(material, step.delta)
			h._near(float(material.get_shader_parameter("uTime")), step.time, "Original shield shader clock")
			h._near(float(material.get_shader_parameter("uFlash")), step.flash, "Original shield flash linear decay and floor")
	MorphTests.run(h, fixtures, baseline)
	LocomotionTests.run(h, fixtures)
	GaitTests.run(h, fixtures)
	CombatTests.run(h, fixtures)
	AimTests.run(h, fixtures)
	AnatomicalTests.run(h, fixtures, baseline)
	FrameTests.run(h, fixtures, baseline)
	PresentationTests.run(h, fixtures, baseline)
	AuthorityTests.run(h, fixtures, baseline)
	NpcTests.run(h, fixtures, baseline)
	CloneTests.run(h, fixtures, baseline)
	CarrierTests.run(h, fixtures)
	CivilianTests.run(h, fixtures)
	BodyViewTests.run(h, fixtures)
	NpcShotTests.run(h, fixtures)
	HeroShotTests.run(h, fixtures)
	RemoteShotTests.run(h, fixtures)
	SpriteTests.run(h, fixtures)
	VictimTests.run(h, fixtures)
	FirstPersonShieldTests.run(h, fixtures)
	HurtTests.run(h, fixtures)
	BloodTests.run(h, fixtures)
	SplatPaintTests.run(h, fixtures)
	PresentationFrameTests.run(h, fixtures)
	DestructionTests.run(h, fixtures)
	DeathSequenceTests.run(h, fixtures)
	BlastFeedbackTests.run(h, fixtures)
	SceneDamageTests.run(h, fixtures)
	MobileDamageTests.run(h, fixtures)
	DamageFxTests.run(h, fixtures)
	MissilePresentationTests.run(h, fixtures)
	MissileViewRayTests.run(h, fixtures)
	BodyRemovalTests.run(h, fixtures)
	DissolveTests.run(h, fixtures)


static func _check_geometry(h: Node, item: Dictionary, baseline: Dictionary) -> void:
	baseline[item.key] = initial_states(item.nodes)
	var rig := BodyRig.new()
	h.add_child(rig)
	var phase := func(index): return float(item.materials[index].uniforms.uTime) / float(Content.balance.bodyRules.shield.timeWindow)
	if not rig.configure(item.key, phase):
		h._check(false, "Pack original body scene: " + item.key)
		rig.free()
		return
	h._check(rig.nodes.size() == item.nodes.size(), "Original complete body hierarchy including hidden/outline/combat nodes: " + item.key)
	var source_graph: Dictionary = Content.read_json("res://data/bodies/%s.json" % item.key)
	h._check(source_graph.has("celPrograms") and source_graph.has("celSamplers"), "Regenerate original cel shader programs and typed sampler data")
	var cel_data := rig.source_root.get_meta("source_cel_data") as SourceCelData
	h._check(cel_data != null, "Source material programs use a shared native Resource")
	if cel_data != null:
		Helper.compare(h, cel_data.programs, source_graph.get("celPrograms", []), "Original cel shader source and every referenced Three chunk survive packing")
		Helper.compare(h, cel_data.samplers, source_graph.get("celSamplers", []), "Original cel gradient/field sampler precision survives packing")
	for spec: Dictionary in item.nodes:
		var node: Node3D = rig.nodes[int(spec.id)]
		compare_transform(h, node.transform, ViewTests.frame(spec.matrix), "Original body endpoint local transform")
		h._check(node.visible == spec.visible and node.get_meta("source_name") == spec.name, "Original body visibility and named rig binding")
		if spec.has("helper"):
			Helper.compare(h, node.get_meta("source_helper", {}), spec.helper, "Disabled source rig-preview helpers retain graph identity and explicit unavailable visualization")
			h._check(not node.visible and not node is GeometryInstance3D, "Disabled source skeleton guides cannot become substitute combat geometry")
		for flag: String in spec.flags:
			h._check(node.get_meta(flag) == spec.flags[flag], "Original body outline/ring/occlusion flag")
		if spec.has("outlineUniforms"):
			Helper.compare(h, node.get_meta("source_outline_uniforms", {}), spec.outlineUniforms,
				"Original retained outline nodes preserve world-scale-adjusted vertex expansion uniforms")
		if spec.has("outlines"):
			var shells: Array = node.get_meta("source_outline_shells", [])
			h._check(shells.size() == spec.outlines.size(), "Deferred outline geometry never adds nodes to the authored body rig")
			for index in range(mini(shells.size(), spec.outlines.size())):
				Helper.compare(h, shells[index].uniforms, spec.outlines[index].uniforms, "Original deferred outline uniforms")
				Helper.compare(h, shells[index].matrix, spec.outlines[index].matrix, "Original deferred outline local transform")
				h._check(shells[index].child_index == spec.outlines[index].childIndex, "Deferred shells retain original child traversal order")
				h._check(shells[index].same_geometry == spec.outlines[index].sameGeometry,
					"Deferred shells preserve the source smooth-normal geometry choice")
				h._check(shells[index].geometry is ArrayMesh and int(shells[index].geometry.get_meta("source_geometry_id")) == int(spec.outlines[index].mesh),
					"Deferred outline geometry retains the original selected normal mesh")
		if spec.has("mesh"):
			var mesh := node as MeshInstance3D
			var instanced := node as MultiMeshInstance3D
			var geometry: Mesh = instanced.multimesh.mesh if instanced != null else mesh.mesh
			Helper.compare(h, geometry.get_meta("source_custom_attributes", {}), source_graph.meshes[int(spec.mesh)].get("attributes", {}),
				"Original paint, surface identity and wind vertex attributes survive model packing")
			for surface in range(geometry.get_surface_count()):
				var material: Material = geometry.surface_get_material(surface) if instanced != null else mesh.get_active_material(surface)
				var material_id: int = material.get_meta("source_material_id")
				var description: Dictionary = source_graph.materials[material_id]
				var source_geometry: Dictionary = source_graph.meshes[int(spec.mesh)]
				var colour_values: Array = source_geometry.get("color", [])
				var native_colours: Variant = geometry.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
				if not description.get("vertexColors", false) or colour_values.is_empty():
					h._check(native_colours == null or native_colours.is_empty(), "Ignored source vertex colours cannot leak into native instance tint")
				else:
					var components := int(source_geometry.get("colorSize", 3))
					h._check(native_colours != null and native_colours.size() == colour_values.size() / components, "Original RGB/RGBA vertex colour count")
					if native_colours != null:
						for vertex in range(mini(native_colours.size(), colour_values.size() / components)):
							for component in range(components):
								h._check(absf(native_colours[vertex][component] - float(colour_values[vertex * components + component])) <= 1.0 / 255 + .000001,
									"Original vertex colour and alpha survive native vertex-buffer precision")
				if spec.flags.get("isOutline", false):
					h._check(material.get_meta("source_outline", false) and is_same(material.get_meta("source_original_material"), rig.materials[material_id]),
						"Native outline shaders retain the original scene-local material identity")
				else:
					h._check(is_same(material, rig.materials[material_id]), "Rendered body surfaces share the scene-local rig material table")
			var box: AABB = node.global_transform * (instanced.multimesh.get_aabb() if instanced != null else mesh.get_aabb())
			h._check(box.position.distance_to(h._reference_vector(spec.worldBounds[0])) < .0002
				and box.end.distance_to(h._reference_vector(spec.worldBounds[1])) < .0002, "Original complete body mesh bounds: " + item.key)
			if spec.has("instances"):
				JointTests.compare_instances(h, node, spec.instances, "Original complete body instances")
				for index in range(spec.get("instanceColors", []).size()):
					var expected: Array = spec.instanceColors[index]
					var color := instanced.multimesh.get_instance_color(index)
					h._check(Vector3(color.r, color.g, color.b).distance_to(Vector3(expected[0], expected[1], expected[2])) < .00001, "Original body instance color")
	for index in range(item.materials.size()):
		var spec: Dictionary = item.materials[index]
		if spec.has("cel"):
			var source_material: Material = rig.materials[index]
			Helper.compare(h, SourceCelData.material_source(source_material), spec.cel, "Original cel defines, options and typed material uniforms survive packing")
			h._check(source_material.get_meta("source_cel_data", null) == cel_data, "All scene materials retain the same immutable shader/sampler Resource")
			if cel_data != null:
				Helper.compare(h, cel_data.programs[int(spec.cel.program)], source_graph.celPrograms[int(spec.cel.program)], "Material program indices resolve through the retained source bundle")
				h._check(cel_data.sampler_images.size() == source_graph.celSamplers.size(), "Material retains source sampler images independently of its hierarchy")
		if spec.get("type") != "shield":
			continue
		var material := rig.materials[index] as ShaderMaterial
		h._check(material != null, "Original shield material has a native shader")
		if material == null:
			continue
		for uniform: String in spec.uniforms:
			if uniform in ["uPattern", "uColor", "uAccent"]:
				continue
			h._near(float(material.get_shader_parameter(uniform)), spec.uniforms[uniform], "Original shield uniform: " + uniform)
	var other := BodyRig.new()
	h.add_child(other)
	if other.configure(item.key, phase):
		for index in range(rig.materials.size()):
			h._check(not is_same(rig.materials[index], other.materials[index]), "Body materials are private to each native scene instance")
		for id: int in rig.nodes:
			if not rig.nodes[id] is MultiMeshInstance3D:
				continue
			var first := rig.nodes[id] as MultiMeshInstance3D
			var second := other.nodes[id] as MultiMeshInstance3D
			h._check(not is_same(first.multimesh, second.multimesh), "Track instance transforms are private to each body")
	other.free()
	rig.free()

static func initial_states(nodes: Array) -> Dictionary:
	var result: Dictionary = {}
	for spec: Dictionary in nodes:
		result[int(spec.id)] = {"id": spec.id, "parent": spec.parent, "position": spec.trs.p,
			"quaternion": spec.trs.q, "scale": spec.trs.s, "visible": spec.visible}
		if spec.has("instances"):
			result[int(spec.id)].instances = spec.instances
	return result

static func compare_transform(h: Node, actual: Transform3D, expected: Transform3D, label: String) -> void:
	h._check(actual.origin.distance_to(expected.origin) < .0002 and actual.basis.x.distance_to(expected.basis.x) < .0002
		and actual.basis.y.distance_to(expected.basis.y) < .0002 and actual.basis.z.distance_to(expected.basis.z) < .0002, label)
