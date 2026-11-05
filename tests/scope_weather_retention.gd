extends "res://tests/run.gd"

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/scope_values.json")
	_check(capture.get("formatVersion") == 1 and capture.get("programs") is Array and capture.programs.size() == 2,
		"Capture original weather-gradient retention programs")
	if failures == 0:
		var provenance: Dictionary = Content.read_json("res://data/provenance.json")
		for path: String in capture.source.inputs:
			var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
			_check(text.sha256_text() == capture.source.inputs[path], "Current weather retention capture input: " + path)
		for path: String in capture.source.sourceInputs:
			_check(provenance.get("inputs", {}).get(path) == capture.source.sourceInputs[path], "Original weather retention source identity: " + path)
	if failures == 0:
		for program_index in capture.programs.size():
			var overlay := ScopeOverlay.new()
			add_child(overlay)
			var state := ScopeState.new()
			for index in capture.programs[program_index].size():
				var frame: Dictionary = capture.programs[program_index][index]
				failure_scope = "program=" + str(program_index) + " frame=" + str(index)
				state.fire_fog = float(frame.fire)
				state.weather_fog = float(frame.weather)
				overlay.update_view(state, bool(frame.scoped))
				if overlay.weather_tween != null and overlay.weather_tween.is_valid():
					overlay.weather_tween.pause()
					overlay.weather_tween.custom_step(1.0 if index == 0 else 0.1)
				var material := overlay.shader_material
				_check(float(material.get_shader_parameter("radius_vmin")) == float(frame.radius),
					"Scope radius follows the current input independently")
				_check(bool(material.get_shader_parameter("scoped")) == bool(frame.scoped),
					"Scope mode follows the current input independently")
				_check(bool(material.get_shader_parameter("weather_retained"))
					and bool(material.get_shader_parameter("weather_scoped")) == bool(frame.gradient.scoped),
					"Weather gradient retains its original mode during fade-out")
				if frame.gradient.scoped:
					_check(float(material.get_shader_parameter("weather_inner_vmin")) == float(frame.gradient.stops[0])
						and float(material.get_shader_parameter("weather_outer_vmin")) == float(frame.gradient.stops[1]),
						"Scoped weather retains both original stops during fade-out")
				else:
					var expected := Vector2(frame.gradient.stops[0], frame.gradient.stops[1])
					_check(material.get_shader_parameter("weather_stops") == expected,
						"Unscoped weather retains both original stops during fade-out")
				if index in [0, 1]:
					_check(overlay.weather_opacity > 0, "Weather remains visible during its fade")
			overlay.clear()
			overlay.free()
	print("SCOPE_WEATHER_RETENTION assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
