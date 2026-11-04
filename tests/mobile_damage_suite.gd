extends RefCounted

const GeometryTests = preload("res://tests/scene_damage_suite.gd")
const ViewTests = preload("res://tests/view_suite.gd")

class RecordedEffects extends CombatEffects:
	var bursts := 0
	func _ready() -> void:
		pass
	func victim(_point: Vector3, _height: float, _kind: String, _shielded: bool, _camera: Variant = null) -> void:
		pass
	func scene_damage_burst(_id: int, _kind: String, _point: Vector3, _height: float, _radius: float, _stage: int) -> void:
		bursts += 1

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("mobileDamageGeometry"):
		h._check(false, "Regenerate original mobile damage tint, scar and release fixtures")
		return
	for item: Dictionary in fixtures.mobileDamageGeometry:
		var graph := GeometryTests.build_graph(item.graph)
		var root: Node3D = graph.root
		h.add_child(root)
		var damage := MobileDamageGeometry.new()
		_compare(h, damage, graph, item.initial)
		for step: Dictionary in item.steps:
			if step.get("move", false):
				var joint: Node3D = graph.nodes.part0
				joint.position.y += .5
				joint.rotation.z += .25
				var batch: MultiMeshInstance3D = graph.nodes.part8
				batch.multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(8, 4, 2)))
			if step.get("release", false):
				damage.release()
			else:
				damage.apply(root, item.kind, int(step.stage))
			_compare(h, damage, graph, step.result)
			for spec: Dictionary in item.graph.nodes:
				if not spec.has("mesh"):
					continue
				var node: Node3D = graph.nodes[spec.name]
				var geometry := ViewOcclusion._geometry(node)
				GeometryTests._vectors(h, geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], item.graph.meshes[int(spec.mesh)].position,
					"Mobile scars never deform shared vertices, skinning or instance geometry")
		damage.release(true)
		root.free()
	_lifecycle(h, fixtures.mobileDamageGeometry)
	print("MOBILE_DAMAGE_REFERENCE_PASS fixtures=", fixtures.mobileDamageGeometry.size())

static func _lifecycle(h: Node, fixtures: Array) -> void:
	var reference: Dictionary = fixtures.filter(func(item): return item.kind == "robot" and item.indexed)[0]
	var graph := GeometryTests.build_graph(reference.graph)
	var simulation := BattleSimulation.new()
	h.add_child(simulation)
	simulation.set_physics_process(false)
	var world := BattleWorld.new()
	simulation.world = world
	simulation.add_child(world)
	var effects := RecordedEffects.new()
	world.combat_effects = effects
	world.add_child(effects)
	var unit := BattleUnit.new()
	simulation.add_child(unit)
	unit.entity_id = 42
	unit.kind = "robot"
	unit.character = Content.heroes.keys().filter(func(key): return Content.heroes[key].kind == "robot")[0]
	unit.hp = 100
	unit.max_hp = 100
	unit.model = graph.root
	unit.add_child(unit.model)
	unit.geometry_override = {"height": 6.0, "radius": 3.0}
	simulation.units[unit.entity_id] = unit
	var resources := [unit.hp, unit.shield, unit.money, unit.power, unit.ammo.duplicate(true), simulation.clock, simulation.rng.state, simulation.projectile_rng.state]
	var publish := func(health: float):
		simulation.apply_presentation_view({"units": [{"id": unit.entity_id, "hp": health, "max_hp": 100.0, "shield": 0.0, "max_shield": 0.0, "side": unit.side}], "clock": 10.0})
	publish.call(100)
	h._check(not unit.mobile_damage.initialized and effects.bursts == 0, "An intact first observation caches parts without allocating scars or tint")
	publish.call(25)
	h._check(unit.mobile_damage.scars.size() == 12 and effects.bursts == 1, "Published heavy damage binds the original bounded scar roster once")
	simulation.apply_presentation_view({"units": [], "clock": 10.0})
	h._check(unit.mobile_damage.scars.is_empty() and unit.mobile_damage.stage == -1, "Leaving authority team visibility restores materials and releases mobile scars")
	publish.call(20)
	h._check(unit.mobile_damage.stage == 2 and unit.mobile_damage.scars.size() == 12 and effects.bursts == 1,
		"Visibility re-entry rebuilds current damage without replaying a hidden damage burst")
	(graph.nodes.part0 as Node3D).free()
	publish.call(0)
	h._check(unit.mobile_damage.stage == 3 and effects.bursts == 2, "A lethal hero publication retains stage-three damage and tolerates removed articulated parts")
	publish.call(100)
	h._check(unit.mobile_damage.stage == 0 and unit.mobile_damage.scars.all(func(scar): return not is_instance_valid(scar.node) or not scar.node.visible),
		"Respawn/healing clears scar visibility without rewriting shared geometry")
	unit.mobile_damage.release(true)
	h._check(unit.mobile_damage.scars.is_empty(), "Explicit mobile damage release tolerates a previously removed part")
	h._check(resources == [unit.hp, unit.shield, unit.money, unit.power, unit.ammo, simulation.clock, simulation.rng.state, simulation.projectile_rng.state],
		"Mobile damage, visibility and healing presentation never settle combat resources or RNG")
	simulation.free()

static func _compare(h: Node, damage: MobileDamageGeometry, graph: Dictionary, reference: Dictionary) -> void:
	h._check(damage.stage == int(reference.stage), "Original repeated-stage and release-before-allocation behavior")
	var batch: MultiMeshInstance3D = graph.nodes.part8
	for index in range(reference.instances.size()):
		var frame := ViewTests.frame(reference.instances[index])
		h._check(batch.multimesh.get_instance_transform(index).is_equal_approx(frame), "Material copy/release preserves animated instance buffers")
	for index in range(reference.colours.size()):
		var node: GeometryInstance3D = graph.nodes["part%d" % index]
		var colours: Array = reference.colours[index]
		for surface in range(colours.size()):
			var material := ViewOcclusion._material(node, surface) as BaseMaterial3D
			var actual := material.albedo_color.srgb_to_linear()
			var expected: Array = colours[surface]
			h._check(Vector3(actual.r, actual.g, actual.b).distance_to(Vector3(expected[0], expected[1], expected[2])) < .00002,
				"Original opaque-only linear tint, excluded flags, shared material clone and exact release binding")
	h._check(damage.scars.size() == reference.scars.size(), "Original ordered eligible-part cap and material-array/skinned exclusions")
	for index in range(mini(damage.scars.size(), reference.scars.size())):
		var scar: Dictionary = damage.scars[index]
		var expected: Dictionary = reference.scars[index]
		var node: MeshInstance3D = scar.node
		h._check(str(node.get_parent().name) == str(expected.owner), "Original local scar attaches to the matching articulated part")
		h._check(node.visible == bool(expected.visible) and int(scar.draw_count) == int(expected.count),
			"Original damage strength controls visibility and half-buffer light-damage draw range")
		h._near((node.material_override as BaseMaterial3D).albedo_color.a, float(expected.opacity), "Original per-stage scar opacity")
		GeometryTests._vectors(h, scar.vertices, expected.positions, "Original indexed/non-indexed stride, barycentric segments and local normal offset")
		var frame := ViewTests.frame(expected.world)
		h._check(node.global_position.distance_to(frame.origin) < .0003 and node.global_basis.x.distance_to(frame.basis.x) < .0003
			and node.global_basis.y.distance_to(frame.basis.y) < .0003 and node.global_basis.z.distance_to(frame.basis.z) < .0003,
			"Local scars follow animated joints without editing geometry or recomputing their pattern")
