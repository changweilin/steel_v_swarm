extends "res://tests/run.gd"

func _value(value: Variant) -> float:
	if value is String:
		match value:
			"NaN": return NAN
			"Infinity": return INF
			"-Infinity": return -INF
	return float(value)

func _double(value: String) -> float:
	return value.hex_decode().decode_double(0)

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://tests/fixtures/scope_nonfinite.json")
	_check(fixture.get("formatVersion") == 1 and fixture.get("samples") is Array and fixture.samples.size() == 49,
		"Capture original non-finite scope and weather formulas")
	for sample: Dictionary in fixture.samples:
		var fire := _value(sample.fire)
		var weather := _value(sample.weather)
		var radius := ScopeState.radius_vmin(fire, weather)
		var stops := ScopeState.weather_stop_components(weather)
		_check(radius == _double(sample.radiusBits), "Original scope radius for " + str(sample.fire) + "/" + str(sample.weather))
		_check(float(stops[0]) == _double(sample.stopBits[0]) and float(stops[1]) == _double(sample.stopBits[1]),
			"Original weather stops for " + str(sample.weather))
	var overlay := ScopeOverlay.new()
	add_child(overlay)
	var state := ScopeState.new()
	state.fire_fog = 0.5
	state.weather_fog = 0.5
	overlay.update_view(state, false)
	if overlay.fire_tween != null:
		overlay.fire_tween.pause()
		overlay.fire_tween.custom_step(0.1)
	if overlay.weather_tween != null:
		overlay.weather_tween.pause()
		overlay.weather_tween.custom_step(0.1)
	var old_stops: Variant = overlay.shader_material.get_shader_parameter("weather_stops")
	state.fire_fog = NAN
	state.weather_fog = NAN
	overlay.update_view(state, false)
	_check(overlay.fire_target == 0 and overlay.weather_target == 0, "NaN fog fades toward zero")
	_check(float(overlay.shader_material.get_shader_parameter("fire_blur")) == 0, "NaN fire fog clears the blur")
	_check(overlay.shader_material.get_shader_parameter("weather_stops") == old_stops,
		"Zero weather target retains the last visible gradient")
	var fire_tween := overlay.fire_tween
	var weather_tween := overlay.weather_tween
	overlay.update_view(state, false)
	_check(is_same(fire_tween, overlay.fire_tween) and is_same(weather_tween, overlay.weather_tween),
		"Repeated NaN inputs do not restart an unchanged fade")
	state.fire_fog = INF
	state.weather_fog = INF
	overlay.update_view(state, true)
	_check(overlay.fire_target == 1 and overlay.weather_target == 1, "Positive infinite density clamps to one")
	_check(float(overlay.shader_material.get_shader_parameter("fire_blur")) == float(Content.balance.view.mask.blurPixels),
		"Positive infinite fire blur uses the clamped density")
	state.fire_fog = -INF
	state.weather_fog = -INF
	overlay.update_view(state, false)
	_check(overlay.fire_target == 0 and overlay.weather_target == 0, "Negative infinite density clamps to zero")
	overlay.clear()
	overlay.free()
	print("SCOPE_NONFINITE assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
