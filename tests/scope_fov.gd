extends "res://tests/run.gd"

func _double(value: String) -> float:
	return value.hex_decode().decode_double(0)

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://tests/fixtures/scope_fov.json")
	_check(fixture.get("formatVersion") == 1 and fixture.get("samples") is Array and fixture.samples.size() == 11,
		"Capture original player FOV easing and snap")
	for sample: Dictionary in fixture.samples:
		var actual := ScopeState.fov_step(_double(sample.currentBits), _double(sample.wantedBits), _double(sample.deltaBits))
		var expected := _double(sample.resultBits)
		_check(actual == expected, "Original FOV easing: " + str(sample) + " actual=" + str(actual))
	print("SCOPE_FOV assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
