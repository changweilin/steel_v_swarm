extends "res://tests/run.gd"

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://tests/fixtures/minimap_bunker_rounding.json")
	_check(fixture.get("formatVersion") == 1 and fixture.get("cases") is Array and fixture.cases.size() == 15,
		"Capture original bunker rounding boundaries")
	for sample: Dictionary in fixture.cases:
		var value := str(sample.valueBits).hex_decode().decode_double(0)
		var markers := MinimapMarkerState.new()
		markers.remember_coordinates(value, value, "STEEL")
		_check(markers.bunkers.keys() == [sample.key], "Original bunker key near half boundary: " + str(sample.valueBits))
		var record: Dictionary = markers.bunkers.values()[0]
		_check(record.x == value and record.z == value, "Rounding does not alter remembered coordinates")
	print("MINIMAP_BUNKER_ROUNDING assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
