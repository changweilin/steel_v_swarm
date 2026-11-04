extends RefCounted

const GraphImport = preload("res://tools/import_cockpits.gd")
const ViewTests = preload("res://tests/view_suite.gd")

class RecordedEffects extends CombatEffects:
	var stages: Array = []
	var order: Array = []
	func _ready() -> void:
		pass
	func victim(_point: Vector3, _height: float, _kind: String, _shielded: bool, _camera: Variant = null) -> void:
		order.append("victim")
	func scene_damage_burst(_id: int, _kind: String, _point: Vector3, _height: float, _radius: float, destination: int) -> void:
		stages.append(destination)
		order.append("damage")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("sceneDamageGeometry") or not fixtures.has("sceneDamageStages") or not fixtures.has("sceneDamageObservations"):
		h._check(false, "Regenerate original scene-damage geometry and health-band fixtures")
		return
	for item: Dictionary in fixtures.sceneDamageStages:
		h._check(SceneDamageGeometry.health_stage(float(item.hp), float(item.maximum), item.collapsed) == int(item.stage),
			"Original damage stages retain inclusive thresholds, invalid maxima and collapsed precedence")
	for hp: float in [NAN, INF, -INF]:
		h._check(SceneDamageGeometry.health_stage(hp, 100) == 0 and SceneDamageGeometry.health_stage(hp, 100, true) == 3,
			"Invalid observed health cannot deform an intact model; collapsed state remains authoritative")
	for item: Dictionary in fixtures.sceneDamageGeometry:
		var graph := build_graph(item.graph)
		var root: Node3D = graph.root
		h.add_child(root)
		var damage := SceneDamageGeometry.new()
		_compare(h, damage, graph, item.initial)
		for step: Dictionary in item.steps:
			damage.apply(root, item.kind, int(item.id), item.dimensions, int(step.stage), item.neutral)
			if step.get("late", false):
				var original: MeshInstance3D = graph.nodes.part0
				var late := original.duplicate() as MeshInstance3D
				late.mesh = original.mesh.duplicate() as Mesh
				late.mesh.set_meta("source_geometry_id", -100)
				late.material_override = original.get_active_material(0).duplicate() as Material
				late.name = "late"
				late.position = Vector3(8, 0, 0)
				root.add_child(late)
			_compare(h, damage, graph, step.result)
		# Original imported resources remain usable by another instance after damage/heal.
		for index in range(item.graph.meshes.size()):
			var original: ArrayMesh = graph.originals[index]
			var arrays := original.surface_get_arrays(0)
			_vectors(h, arrays[Mesh.ARRAY_VERTEX], item.graph.meshes[index].position, "Damage never edits an imported mesh resource")
		for index in range(graph.materials.size()):
			var material: BaseMaterial3D = graph.materials[index]
			var reference := Color.hex((int(item.graph.materials[index].color) << 8) | 0xff)
			reference.a = float(item.graph.materials[index].opacity)
			h._check(material.albedo_color.is_equal_approx(reference), "Private damage tint leaves shared imported materials unchanged")
		root.free()
	_observations(h, fixtures)
	_production(h, fixtures)
	print("SCENE_DAMAGE_REFERENCE_PASS geometry=", fixtures.sceneDamageGeometry.size(), " stages=", fixtures.sceneDamageStages.size())

static func _observations(h: Node, fixtures: Dictionary) -> void:
	for item: Dictionary in fixtures.sceneDamageObservations:
		var graph := build_graph(item.graph)
		var unit := BattleUnit.new()
		h.add_child(unit)
		unit.entity_id = 42
		unit.kind = item.kind
		if item.hero:
			unit.character = Content.heroes.keys().filter(func(key): return Content.heroes[key].kind == item.kind)[0]
		unit.hp = 100
		unit.max_hp = 100
		unit.special = {"neutral": true}
		unit.model = graph.root
		unit.add_child(unit.model)
		unit.geometry_override = {"height": 6.0, "radius": 3.0}
		var effects := RecordedEffects.new()
		unit.present_scene_damage({"hp": 100.0, "max_hp": 100.0}, effects)
		var resources := [unit.hp, unit.max_hp, unit.shield, unit.power, unit.money, unit.ammo.duplicate(true)]
		for step: Dictionary in item.steps:
			effects.stages.clear()
			unit.present_scene_damage({"hp": float(step.hp), "max_hp": 100.0, "special": {"collapsed": item.collapsed}}, effects, step.initial)
			var stage := unit.mobile_damage.stage if item.mobile else unit.scene_damage.stage
			h._check(stage == int(step.stage) and effects.stages == step.bursts,
				"Original observed damage bands emit one destination burst, skip corpse/collapsed changes and restore after healing")
			h._check(resources == [unit.hp, unit.max_hp, unit.shield, unit.power, unit.money, unit.ammo],
				"Observed geometry damage cannot settle health, shields, power, money or ammunition")
		effects.free()
		unit.free()

static func _production(h: Node, fixtures: Dictionary) -> void:
	for authoritative: bool in [true, false]:
		for item: Dictionary in fixtures.sceneDamageObservations:
			var simulation := BattleSimulation.new()
			simulation.authoritative = authoritative
			h.add_child(simulation)
			simulation.set_physics_process(false)
			var world := BattleWorld.new()
			simulation.world = world
			simulation.add_child(world)
			var effects := RecordedEffects.new()
			world.combat_effects = effects
			world.add_child(effects)
			var graph := build_graph(item.graph)
			var unit := BattleUnit.new()
			simulation.add_child(unit)
			unit.entity_id = 42
			unit.kind = item.kind
			if item.hero:
				unit.character = Content.heroes.keys().filter(func(key): return Content.heroes[key].kind == item.kind)[0]
			unit.hp = 100
			unit.max_hp = 100
			unit.special = {"neutral": true}
			unit.geometry_override = {"height": 6.0, "radius": 3.0}
			unit.model = graph.root
			unit.add_child(unit.model)
			simulation.present_victim_snapshot(unit, {"hp": 100.0, "max_hp": 100.0, "shield": 0.0, "max_shield": 0.0, "side": unit.side})
			var resources := [unit.hp, unit.max_hp, unit.shield, unit.money, unit.power, simulation.clock, simulation.rng.state, simulation.projectile_rng.state]
			for step: Dictionary in item.steps:
				effects.order.clear()
				if step.initial:
					simulation.victim_reports.erase(unit.entity_id)
				simulation.present_victim_snapshot(unit, {"hp": float(step.hp), "max_hp": 100.0, "shield": 0.0, "max_shield": 0.0, "side": unit.side,
					"special": {"collapsed": item.collapsed}})
				var stage := unit.mobile_damage.stage if item.mobile else unit.scene_damage.stage
				h._check(effects.order == step.order and stage == int(step.stage),
					"Authority and replica publication retain original victim-before-damage ordering and visibility baselines")
				h._check(resources == [unit.hp, unit.max_hp, unit.shield, unit.money, unit.power, simulation.clock, simulation.rng.state, simulation.projectile_rng.state],
					"Shared damage presentation leaves authority resources, time and combat RNG unchanged")
			simulation.free()

static func build_graph(data: Dictionary) -> Dictionary:
	var materials: Array[Material] = []
	for spec: Dictionary in data.materials:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.hex((int(spec.color) << 8) | 0xff)
		material.albedo_color.a = float(spec.opacity)
		material.set_meta("source_transparent", spec.transparent)
		materials.append(material)
	var builder := GraphImport.new()
	var nodes: Array[Node3D] = []
	var by_name: Dictionary = {}
	var originals: Dictionary = {}
	for spec: Dictionary in data.nodes:
		var node: Node3D = MultiMeshInstance3D.new() if spec.has("instances") else MeshInstance3D.new() if spec.has("mesh") else Node3D.new()
		node.name = spec.name if not str(spec.name).is_empty() else "root"
		node.transform = ViewTests.frame(spec.matrix)
		for flag: String in spec.flags:
			node.set_meta(flag, spec.flags[flag])
		if spec.has("mesh"):
			var geometry := builder._mesh(data.meshes[int(spec.mesh)], spec.materials, data.materials, materials, spec.flags.get("materialArray", false))
			geometry.set_meta("source_geometry_id", int(spec.mesh))
			geometry.set_meta("source_indices", data.meshes[int(spec.mesh)].indices)
			geometry.set_meta("source_indexed", not data.meshes[int(spec.mesh)].indices.is_empty())
			if node is MultiMeshInstance3D:
				var instances := MultiMesh.new()
				instances.transform_format = MultiMesh.TRANSFORM_3D
				instances.mesh = geometry
				instances.instance_count = spec.instances.size()
				for index in range(spec.instances.size()):
					instances.set_instance_transform(index, ViewTests.frame(spec.instances[index]))
				node.multimesh = instances
			else:
				(node as MeshInstance3D).mesh = geometry
			node.set_meta("material_count", spec.materials.size())
			originals[int(spec.mesh)] = geometry
		if int(spec.parent) >= 0:
			nodes[int(spec.parent)].add_child(node)
		nodes.append(node)
		by_name[spec.name] = node
	builder.free()
	return {"root": nodes[0], "nodes": by_name, "originals": originals, "materials": materials}

static func _compare(h: Node, damage: SceneDamageGeometry, graph: Dictionary, expected: Dictionary) -> void:
	h._check(damage.stage == int(expected.stage), "Original repeated/unknown stage acceptance")
	for index in range(expected.nodes.size()):
		var node: MeshInstance3D = graph.nodes["part%d" % index]
		var reference: Dictionary = expected.nodes[index]
		var arrays := node.mesh.surface_get_arrays(0)
		_vectors(h, arrays[Mesh.ARRAY_VERTEX], reference.positions, "Original per-geometry, root-space dent and complete repair")
		_vectors(h, arrays[Mesh.ARRAY_NORMAL], reference.normals, "Original deformed indexed/non-indexed vertex normals")
		for material_index in range(int(node.get_meta("material_count"))):
			var material := node.get_active_material(material_index) as BaseMaterial3D
			var colour := material.albedo_color.srgb_to_linear()
			var source: Array = reference.colours[material_index]
			h._check(Vector3(colour.r, colour.g, colour.b).distance_to(Vector3(source[0], source[1], source[2])) < .00002,
				"Original linear-space tint and grouped/shared material bindings")
	if expected.cracks == null:
		h._check(damage.cracks == null, "Undamaged/unsupported geometry allocates no scar mesh")
		return
	h._check(damage.cracks != null and damage.cracks.visible == bool(expected.cracks.visible), "Original scars hide on repair and reappear on later damage")
	if damage.cracks != null:
		var positions := PackedVector3Array()
		if damage.cracks.mesh.get_surface_count() > 0:
			positions = damage.cracks.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_vectors(h, positions, expected.cracks.positions, "Original stable surface-face order, upward-area gates and barycentric scar segments")

static func _vectors(h: Node, actual: PackedVector3Array, expected: Array, label: String) -> void:
	h._check(actual.size() * 3 == expected.size(), label + " count")
	for index in range(mini(actual.size(), int(expected.size() / 3))):
		h._check(actual[index].distance_to(Vector3(expected[index * 3], expected[index * 3 + 1], expected[index * 3 + 2])) < .0003, label)
