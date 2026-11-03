class_name MinimapMarkerState
extends RefCounted

var bunkers: Dictionary = {}

func remember(rows: Array) -> void:
	for row: Dictionary in rows:
		if row.kind != "bunker":
			continue
		var point: Vector3 = row.position
		remember_coordinates(float(point.x), float(point.z), row.side)

func remember_coordinates(x: float, z: float, side: String) -> void:
	var key := "%d,%d" % [_round_coordinate(x), _round_coordinate(z)]
	bunkers[key] = {"point": Vector2(x, z), "x": x, "z": z, "side": side}

static func _round_coordinate(value: float) -> int:
	var whole := floorf(value)
	return int(whole + 1.0) if value - whole >= 0.5 else int(whole)

static func commands(rows: Array, viewer: String, known: Array, own: Variant, yaw: float) -> Array:
	var rules: Dictionary = Content.balance.minimap.markers
	var templates: Dictionary = rules.templates.get(viewer, rules.templates[""])
	var result: Array = []
	for row: Dictionary in rows:
		if row.neutral or row.kind == "bunker":
			continue
		var family: String = row.kind if row.kind in ["base", "tower"] else "self" if row.hero and row["self"] else "hero" if row.hero else "heli" if row.kind == "heli" else "npc"
		_append(result, templates.get(row.side, templates[""])[family], row.point)
	for row: Dictionary in known:
		_append(result, templates.get(row.side, templates[""]).bunker, row.point)
	if not viewer.is_empty() and own != null:
		_append(result, rules.own, own, -yaw, true)
	var width := float(rules.initialWidth)
	for command: Dictionary in result:
		if not command.fill:
			if command.width != null:
				width = float(command.width)
			command.width = width
	return result

static func _append(result: Array, template: Array, point: Variant, yaw: float = 0, local: bool = false) -> void:
	var x: float
	var y: float
	if point is Vector2:
		x = point.x
		y = point.y
	elif point is Array and point.size() == 2:
		x = float(point[0])
		y = float(point[1])
	else:
		push_error("Minimap marker requires a two-coordinate point")
		return
	for primitive: Dictionary in template:
		var command := primitive.duplicate(true)
		if local:
			command.position = [x, y]
			command.rotation = yaw
		elif command.shape == "rect":
			command.rect[0] += x
			command.rect[1] += y
		elif command.shape == "circle":
			command.center[0] += x
			command.center[1] += y
		result.append(command)
