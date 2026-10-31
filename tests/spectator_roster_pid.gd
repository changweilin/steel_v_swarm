extends "res://tests/run.gd"

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://tests/fixtures/spectator_roster_pid.json")
	_check(fixture.get("formatVersion") == 1 and fixture.get("programs") is Array and fixture.programs.size() == 12,
		"Capture original spectator roster ID membership")
	var values := {"null": null, "zero": 0, "negative-zero": -0.0, "nan": NAN, "false": false,
		"empty": "", "string-zero": "0", "bot": "b2", "number": 1}
	for sample: Dictionary in fixture.programs:
		var row := {"tag": sample.name, "hero": sample.get("hero", true), "act": sample.get("act", true), "side": "STEEL"}
		if sample.mode != "missing":
			row.pid = values[sample.mode]
		var result := SpectatorState.roster([row])
		_check((not result.is_empty()) == bool(sample.included), "Original spectator ID membership: " + str(sample.name))
	print("SPECTATOR_ROSTER_PID assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
