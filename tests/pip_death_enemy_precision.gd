extends "res://tests/run.gd"

const DeathState = preload("res://scripts/pip_death_state.gd")

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/pip_death_enemy_precision.json")
	_check(capture.get("formatVersion") == 1 and capture.get("programs") is Array and capture.programs.size() == 8,
		"Original death-view enemy precision capture is available")
	for sample: Dictionary in capture.programs:
		var rows: Array = []
		for source_row: Dictionary in sample.rows:
			var point: Array = source_row.position
			rows.append({"id": source_row.id, "kind": source_row.kind, "side": source_row.side,
				"position": Vector3(point[0], point[1], point[2]), "dead": source_row.get("dead", false), "mesh": true})
		var x := str(sample.enemyBits[0]).hex_decode().decode_double(0)
		var z := str(sample.enemyBits[1]).hex_decode().decode_double(0)
		var selected: Variant = DeathState.source_coordinates(rows, "STEEL", x, z)
		_check(selected != null and selected.id == sample.selected, "Unrounded enemy coordinates preserve source selection: " + str(sample.name))
		if sample.name == "x-above":
			var legacy: Variant = DeathState.source(rows, "STEEL", Vector2(x, z))
			_check(legacy != null and legacy.id == 1, "Legacy Vector2 retains its rounded tie behavior")
		if sample.name == "exact-tie":
			var legacy: Variant = DeathState.source(rows, "STEEL", Vector2(x, z))
			_check(legacy != null and legacy.id == selected.id, "Legacy Vector2 retains source tie order")
	print("PIP_DEATH_ENEMY_PRECISION assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
