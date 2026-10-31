extends "res://tests/run.gd"

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://tests/fixtures/scope_fov_sequence.json")
	_check(fixture.get("formatVersion") == 1 and fixture.get("programs") is Array and fixture.programs.size() == 3,
		"Capture original continuous FOV programs")
	var camera := Camera3D.new()
	add_child(camera)
	var count := 0
	for program: Dictionary in fixture.programs:
		var fov := 68.0
		for frame: Dictionary in program.frames:
			var delta := str(frame.deltaBits).hex_decode().decode_double(0)
			fov = ScopeState.fov_step(fov, 35.0 if frame.aiming else 68.0, delta)
			var source := str(frame.fovBits).hex_decode().decode_double(0)
			_check(fov == source, "Original continuous FOV: " + str(program.name) + " frame=" + str(count))
			camera.fov = fov
			var expected_camera := str(frame.fovFloatBits).hex_decode().decode_float(0)
			_check(camera.fov == expected_camera, "Source FOV reaches native camera: " + str(program.name) + " frame=" + str(count))
			count += 1
	_check(count == 431, "All source FOV frames were exercised")
	camera.free()
	print("SCOPE_FOV_SEQUENCE assertions=", assertions, " failures=", failures, " frames=", count)
	get_tree().quit(0 if failures == 0 else 1)
