extends "res://tests/run.gd"

func _double(value: String) -> float:
	return value.hex_decode().decode_double(0)

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/minimap_bunker_precision.json")
	_check(capture.get("formatVersion") == 1 and capture.get("frames") is Array and capture.frames.size() == 4,
		"Capture original precise bunker memory snapshots")
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(220, 220)
	add_child(viewport)
	var view = preload("res://scripts/minimap.gd").new()
	viewport.add_child(view)
	view.configure({"bounds": {"minX": -200, "maxX": 200, "minZ": -200, "maxZ": 200}, "lanes": []}, "")
	view.cadence.warm_until = 0
	for index in capture.frames.size():
		var frame: Dictionary = capture.frames[index]
		var previous: Array = view.draw_frame.get("bunkers", []).duplicate(true)
		for row: Dictionary in frame.rows:
			if row.k == "bunker":
				view.markers.remember_coordinates(_double(row.xBits), -_double(row.zBits), row.s)
		_check(view.draw_frame.get("bunkers", []) == previous, "Updated bunker memory leaves the committed frame intact")
		var keys: Array = view.markers.bunkers.keys()
		_check(keys.size() == frame.records.size(), "Original double coordinate deduplication count")
		for i in range(mini(keys.size(), frame.records.size())):
			var expected: Dictionary = frame.records[i]
			var record: Dictionary = view.markers.bunkers[keys[i]]
			_check(keys[i] == expected.key and record.side == expected.side, "Original bunker key, order and side")
			_check(float(record.x) == _double(expected.xBits) and float(record.z) == _double(expected.zBits),
				"Original bunker coordinates survive memory storage")
		_check(view.advance(100 + index * 0.3), "Precise bunker frame is due")
		var commands: Array = view._commands_for(view.draw_frame, view.draw_frame.positions)
		var fills := commands.filter(func(command: Dictionary): return command.shape == "rect" and command.fill and float(command.rect[2]) == 5.0)
		_check(fills.size() == frame.records.size(), "Every remembered bunker has one fill")
		for i in range(mini(fills.size(), frame.records.size())):
			for component in range(4):
				_check(float(fills[i].rect[component]) == _double(frame.records[i].rectBits[component]),
					"Original bunker projection preserves double coordinates")
	view.clear()
	viewport.free()
	print("MINIMAP_BUNKER_PRECISION assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
