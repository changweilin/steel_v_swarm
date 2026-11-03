class_name PipDeathState
extends RefCounted

static func can_prepare(dead: bool, transitioning: bool, game_over: bool, side: String,
		has_config: bool, has_frame: bool, frame_visible: bool) -> bool:
	return dead and not transitioning and not game_over and not side.is_empty() and has_config and has_frame and frame_visible

static func viewport(frame: Dictionary, canvas: Dictionary, client_height: float, rules: Dictionary) -> Dictionary:
	var border := float(rules.border)
	var width := float(frame.width) - border * 2
	var height := float(frame.height) - border * 2
	if width < float(rules.minimum) or height < float(rules.minimum):
		return {}
	var x := float(frame.left) - float(canvas.left) + border
	var y := client_height - (float(frame.top) - float(canvas.top) + border) - height
	return {"x": x, "y": y, "width": width, "height": height}

static func source(rows: Array, side: String, enemy: Vector2) -> Variant:
	return source_coordinates(rows, side, float(enemy.x), float(enemy.y))

static func source_coordinates(rows: Array, side: String, enemy_x: float, enemy_z: float) -> Variant:
	if side.is_empty():
		return null
	var best := INF
	var chosen: Variant = null
	for row: Dictionary in rows:
		if row.kind != "tower" or row.side != side or bool(row.get("dead", false)) or not bool(row.get("mesh", false)):
			continue
		var position: Vector3 = row.position
		var dx := float(position.x) - enemy_x
		var dz := float(position.z) - enemy_z
		var distance := dx * dx + dz * dz
		if distance < best:
			best = distance
			chosen = row
	if chosen != null:
		return chosen
	for row: Dictionary in rows:
		if row.kind == "base" and row.side == side and bool(row.get("mesh", false)):
			return row
	return null

static func eye_position(source_position: Variant, measured_top: Variant, death_position: Vector2,
		ground: float, rules: Dictionary) -> Variant:
	if source_position == null:
		return Vector3(death_position.x, ground + float(rules.groundLift), death_position.y)
	if not source_position is Vector3 or (measured_top != null and not measured_top is float and not measured_top is int):
		push_error("Death-view eye requires a native source position and numeric measured top")
		return null
	var top := float(rules.defaultTop)
	if measured_top != null:
		var measured := float(measured_top)
		if measured != 0 and not is_nan(measured):
			top = measured
	var point: Vector3 = source_position
	return Vector3(point.x, float(point.y) + top + float(rules.sourceLift), point.z)
