class_name CivilianBodyBuilder
extends RefCounted

static func available() -> bool:
	var profiles: Dictionary = Content.balance.get("civilian_visuals", {}).get("profiles", {})
	if profiles.is_empty():
		return false
	for key: String in profiles:
		if not ResourceLoader.exists("res://assets/civilian_parts/%s.scn" % key):
			return false
	return true

static func configure(body: BodyRig, seed_value: int, profession: int, side: String) -> bool:
	if body.source_root != null or not Content.balance.has("civilian_visuals"):
		push_error("Civilian body requires original component resources and an unconfigured rig")
		return false
	var appearance := CivilianRules.appearance(seed_value, profession)
	var long_sleeves: bool = appearance.clothing in ["jacket", "hoodie", "sweater", "coat"]
	var main_key := "main_%s_%s_%s" % [appearance.bottoms, appearance.footwear, "long" if long_sleeves else "short"]
	var keys: Array[String] = [main_key, "hair_%s_%s_%d" % [appearance.hairStyle, appearance.facialHair, int(appearance.age >= 55)],
		"clothes_" + appearance.clothing, "accessory_" + appearance.accessory,
		"profession_%d_%d" % [int(appearance.family), int(appearance.clothing == "professional")], "ring_" + side.to_lower()]
	if appearance.bottoms == "jeans":
		keys.append("jeans")
	if appearance.clothing != "professional":
		keys.append("headwear_" + appearance.headwear)
	for key: String in keys:
		if not Content.balance.civilian_visuals.profiles.has(key) or not ResourceLoader.exists("res://assets/civilian_parts/%s.scn" % key):
			push_error("Missing original civilian component: " + key)
			return false
	body.source_root = Node3D.new()
	body.source_root.set_meta("source_name", "")
	body.source_root.set_meta("source_trs", {"p": [0, 0, 0], "q": [0, 0, 0, 1], "s": [1, 1, 1], "r": [0, 0, 0]})
	body.add_child(body.source_root)
	var main := _part(main_key, appearance)
	body.source_root.add_child(main.root)
	var rig: Dictionary = main.bindings.rig
	for key: String in keys:
		if key == main_key:
			continue
		var part := _part(key, appearance)
		if key.begins_with("ring_"):
			body.source_root.add_child(part.root)
			continue
		for mount: String in ["hips", "head"]:
			for child: Node3D in part.bindings[mount].get_children():
				_disown(child)
				child.reparent(rig[mount], false)
		part.root.free()
	_register(body, body.source_root)
	body.poses.configure(body.nodes)
	body.poses.set_scale(main.bindings.body, Vector3(appearance.widthScale, 1, appearance.widthScale))
	body.poses.set_scale(rig.head, Vector3.ONE * float(appearance.headScale))
	for arm: Node3D in [rig.armL, rig.armR]:
		body.poses.set_position_axis(arm, "x", body.poses.position_axis(arm, "x") * float(appearance.shoulderScale))
	for surface: Node3D in main.bindings.surfaces.values():
		body.poses.set_scale(surface, Vector3(appearance.shoulderScale, 1, 1))
	var bounds := _bounds(main.root)
	var target := float(Content.constants.TARGET_H.civ) * float(appearance.heightScale)
	var factor := target / (bounds.size.y if bounds.size.y != 0 else 1.0)
	body.poses.set_scale(main.root, Vector3.ONE * factor)
	var centre := bounds.get_center()
	body.poses.set_position(main.root, Vector3(-centre.x * factor, -bounds.position.y * factor, -centre.z * factor))
	rig.s = factor
	var radius := maxf(1.1, target * 0.55)
	for child: Node3D in body.source_root.get_children():
		if child == main.root:
			continue
		for ring: Node3D in child.get_children():
			var ring_scale := radius / float(Content.balance.civilian_visuals.rings[side])
			body.poses.set_scale(ring, Vector3(ring_scale, ring_scale, 1))
	var measured := _bounds(main.root, body.source_root)
	var dimensions := {"height": measured.size.y, "top": measured.end.y, "radius": maxf(measured.size.x, measured.size.z) / 2,
		"centre": measured.end.y - measured.size.y / 2}
	body.profile = {"modelKey": "civ", "kind": "civilian", "character": null, "side": side, "static": false,
		"npcShotSlot": "light", "spin": [], "dimensions": dimensions, "appearance": appearance}
	body.forms = {"ground": rig}
	if not Content.balance.get("outline", {}).has("unitWidth"):
		push_error("Missing original civilian outline width rules; regenerate source content")
		return false
	var width := OutlineRules.unit_width(target, Content.balance.outline)
	var inverse_basis := body.source_root.global_basis.inverse()
	for node: Node3D in body.nodes.values():
		if node.get_meta("isOutline", false):
			# Source outlinify runs after all civilian appearance and height scaling.
			node.set_meta("source_outline_uniforms", OutlineRules.local_uniforms(
				inverse_basis * (node.get_parent() as Node3D).global_basis, width, Content.balance.outline))
	return SourceOutlineBinding.install(body.source_root)

static func _part(key: String, appearance: Dictionary) -> Dictionary:
	var root: Node3D = (load("res://assets/civilian_parts/%s.scn" % key) as PackedScene).instantiate()
	var nodes: Dictionary = {}
	_part_nodes(root, nodes)
	var profile: Dictionary = Content.balance.civilian_visuals.profiles[key]
	var materials: Dictionary = {}
	for node: Node3D in nodes.values():
		if not node is MeshInstance3D:
			continue
		var mesh := node as MeshInstance3D
		for index in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(index) as BaseMaterial3D
			var id := int(original.get_meta("source_material_id"))
			if not materials.has(id):
				var material := original.duplicate() as BaseMaterial3D
				var tokens: Dictionary = profile.palette[str(id)]
				if tokens.color != null:
					material.albedo_color = _color(appearance, tokens.color)
				if tokens.emission != null:
					material.emission = _color(appearance, tokens.emission)
				materials[id] = material
			mesh.set_surface_override_material(index, materials[id])
	return {"root": root, "bindings": _decode(profile.bindings, nodes)}

static func _color(appearance: Dictionary, token: Dictionary) -> Color:
	var color := Color.hex((int(appearance[token.slot]) << 8) | 0xff).srgb_to_linear() * float(token.factor)
	color.a = 1
	# Source graph colors are exported through Three.js getHex, including its byte rounding.
	var encoded := color.linear_to_srgb()
	return Color.hex((int(floorf(encoded.r * 255 + .5)) << 24) | (int(floorf(encoded.g * 255 + .5)) << 16)
		| (int(floorf(encoded.b * 255 + .5)) << 8) | 0xff)

static func _decode(value: Variant, nodes: Dictionary) -> Variant:
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_decode(item, nodes))
		return items
	if not value is Dictionary:
		return value
	if value.has("$node"):
		return nodes[int(value["$node"])]
	var result: Dictionary = {}
	for key: String in value:
		result[key] = _decode(value[key], nodes)
	return result

static func _part_nodes(node: Node3D, nodes: Dictionary) -> void:
	nodes[int(String(node.name).trim_prefix("n_"))] = node
	for child: Node3D in node.get_children():
		_part_nodes(child, nodes)

static func _register(body: BodyRig, node: Node3D) -> void:
	var id := body.nodes.size()
	node.name = "n_%d" % id
	node.set_meta("source_id", id)
	body.nodes[id] = node
	for child: Node3D in node.get_children():
		_register(body, child)

static func _bounds(root: Node3D, frame: Node3D = null) -> AABB:
	var inverse := (root if frame == null else frame).global_transform.affine_inverse()
	var initialized := false
	var result := AABB()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_meta("isOutline", false) or mesh.get_meta("teamRing", false) or mesh.get_meta("presentationEffect", false):
			continue
		var bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		result = result.merge(bounds) if initialized else bounds
		initialized = true
	assert(initialized, "Original civilian must contain measurable geometry")
	return result

# Template nodes keep their packed-scene owner, which is freed with the part root.
static func _disown(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_disown(child)
