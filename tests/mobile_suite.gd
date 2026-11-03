extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const ControlsTests = preload("res://tests/controls_suite.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	if not Content.balance.mobile.has("kindPresentation"):
		h._check(false, "Regenerate original spectator/player touch button presentation")
		return
	var kind_preferences := ControlPreferences.new()
	kind_preferences.persist = false
	kind_preferences.configure(Content.balance.mobile)
	var kind_controls := NativeTouchControls.new()
	h.add_child(kind_controls)
	kind_controls.configure(kind_preferences)
	for kind: String in ["", "mech", "drone", "morph", "robot", ""]:
		kind_controls.set_kind(kind if not kind.is_empty() else "mech")
		kind_controls.set_spectating(kind.is_empty())
		var expected: Dictionary = Content.balance.mobile.kindPresentation[kind]
		h._check(kind_controls.buttons.jump.text == expected.jump and kind_controls.buttons.special.text == expected.special and kind_controls.buttons.swap.text == expected.swap,
			"Original observer rise/view/follow labels and restored player controls")
		for action: String in expected.hidden:
			h._check(kind_controls.buttons[action].visible == (not expected.hidden[action]), "Original observer/player button visibility: " + action)
		h._check(kind_controls.buttons.swap.disabled == (not kind.is_empty()), "Only observer target cycling enables the implemented swap path")
	kind_controls.free()
	kind_preferences.free()
	for key: String in ["mobileDevice", "mobilePreferences", "mobileTouchPreferences", "mobileModes", "mobilePower", "touchMirrors", "touchRotations", "touchPrograms", "gyroPrograms", "mobileFlight"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original mobile/control oracle: " + key)
			return
	for item: Dictionary in fixtures.mobileDevice:
		h._check(ControlPreferences.device_scheme(item.touch, item.coarse, item.noHover, Vector2(item.width, item.height)) == item.result, "Original touch/hybrid/coarse/screen-size device selection")
	for item: Dictionary in fixtures.mobilePreferences:
		h._check(ControlPreferences.source_bool(item.value) == item.result, "Original strict boolean preference normalization")
	for item: Dictionary in fixtures.touchMirrors:
		Helper.compare(h, NativeTouchControls.mirror_state(item.cd, item.ready, item.locked, item.charges), item.result,
			"Original pad HUD cooldown threshold, binary half-ties, charges, ready and locked state")
	for item: Dictionary in fixtures.touchRotations:
		var preferences := ControlPreferences.new()
		preferences.persist = false
		preferences.configure(Content.balance.mobile)
		var controls := NativeTouchControls.new()
		h.add_child(controls)
		controls.configure(preferences)
		controls.enabled = true
		controls.rotate_shown = false
		controls.rotate_hint.hide()
		for step: Dictionary in item.steps:
			if step.kind in ["initial", "resize"]:
				controls._update_rotate_hint(step.portrait, step.kind == "resize")
			elif step.kind == "dismiss":
				controls.rotate_hint.position = Vector2.ZERO
				controls.rotate_hint.size = Vector2(300, 60)
				controls._down(17, Vector2(10, 10), 0)
			elif step.kind == "timeout":
				controls.rotate_timer.timeout.emit()
			Helper.compare(h, {"visible": controls.rotate_hint.visible, "shown": controls.rotate_shown}, step.result,
				"Original once-per-match portrait hint, timeout, dismiss and rotation re-entry")
		h._check(absf(controls.rotate_timer.wait_time * 1000 - float(item.delay)) < 0.001, "Native hint timer retains source wall-time duration")
		controls.enabled = false
		controls.begin_match()
		h._check(not controls.rotate_shown, "A new match rearms its own portrait hint")
		controls.enabled = true
		controls._update_rotate_hint(true)
		h._check(controls.rotate_shown and controls.rotate_hint.visible, "A later portrait match shows its own hint")
		controls.free()
		preferences.free()
	for item: Dictionary in fixtures.mobilePower:
		var preferences := ControlPreferences.new()
		preferences.persist = false
		preferences.configure(Content.balance.mobile)
		preferences.device_pick = "pad" if item.pad else "kbm"
		preferences.power_pref = item.saved
		var path := "user://mobile_power_fixture.cfg"
		preferences.persist = true
		h._check(preferences.save(path) == OK, "Persist unset or explicitly saved power state")
		var initial := ControlPreferences.new()
		initial.configure(Content.balance.mobile)
		initial.device_pick = preferences.device_pick
		initial.load_save(path)
		h._check(initial.power_pref == item.saved and initial.low_power() == preferences.low_power(), "Reload preserves unset versus explicit off and invalid stored values")
		initial.free()
		preferences.persist = false
		var notifications: Array = []
		preferences.changed.connect(func(): notifications.append("controls"))
		preferences.power_changed.connect(func(): notifications.append("power"))
		for step: Dictionary in item.steps:
			notifications.clear()
			var before = preferences.power_pref
			if step.kind == "scheme":
				preferences.device_pick = "pad" if step.pad else "kbm"
			elif step.kind == "set":
				preferences.set_low_power(step.on)
			h._check(preferences.low_power() == step.result and preferences.power_pref == step.saved,
				"Original low-power unset, explicit-off, strict saved strings and touch-scheme transitions")
			h._check(notifications.count("controls") == 0 and notifications.count("power") == int(not is_same(before, preferences.power_pref)),
				"Presentation preference changes never reset held controls or publish room settings")
		preferences.persist = true
		h._check(preferences.save(path) == OK, "Persist explicit low-power preference using native ConfigFile")
		var restored := ControlPreferences.new()
		restored.configure(Content.balance.mobile)
		restored.load_save(path)
		h._check(restored.power_pref == preferences.power_pref and restored.low_power(), "Explicit power preference survives reload")
		preferences.free()
		restored.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for item: Dictionary in fixtures.mobileTouchPreferences:
		var path := "user://mobile_preferences_fixture.cfg"
		var file := ConfigFile.new()
		for key: String in item.saved:
			# ConfigFile erases a key set to null; the source clamps Number(null), so persist "".
			file.set_value("input", key, "" if item.saved[key] == null else item.saved[key])
		h._check(file.save(path) == OK, "Prepare a native preference fixture without touching player settings")
		var preferences := ControlPreferences.new()
		preferences.configure(Content.balance.mobile)
		preferences.load_save(path)
		Helper.compare(h, preferences.values, item.result, "Original sensitivity clamp, invalid source and legacy screen handedness")
		h._check(preferences.save(path) == OK, "Native control preference persistence")
		var restored := ControlPreferences.new()
		restored.configure(Content.balance.mobile)
		restored.load_save(path)
		Helper.compare(h, restored.values, item.result, "Native persisted controls retain original effective preferences")
		preferences.free()
		restored.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for item: Dictionary in fixtures.mobileModes:
		var preferences := ControlPreferences.new()
		preferences.persist = false
		preferences.configure(Content.balance.mobile)
		preferences.pref = item.pref
		preferences.device_pick = item.device
		for step: Dictionary in item.steps:
			var accepted := true
			match step.kind:
				"pref": accepted = preferences.set_pref(step.value)
				"scheme": accepted = preferences.set_scheme(step.value)
				"room": preferences.set_room(step.value)
			if step.kind != "room":
				h._check(accepted == step.accepted, "Original room restriction rejects individual scheme changes")
			Helper.compare(h, {"pref": preferences.pref, "mode": preferences.mode(), "scheme": preferences.scheme(), "locked": not preferences.room.is_empty()}, step.result, "Original preference/room/scheme layers")
		preferences.free()
	for item: Dictionary in fixtures.touchPrograms:
		var state := TouchState.new(Content.balance.mobile.look)
		state.sensitivity = item.sensitivity
		var events: Array = []
		state.command.connect(func(action, on): events.append({"type": "command", "action": action, "on": on}))
		state.look.connect(func(change): events.append({"type": "look", "change": [change.x, change.y]}))
		state.haptic.connect(func(milliseconds): events.append({"type": "haptic", "milliseconds": milliseconds}))
		for step: Dictionary in item.steps:
			events.clear()
			var id := int(step.get("id", 1))
			var point := vector(step.get("point", [0, 0]))
			match step.kind:
				"lookDown": state.look_down(id, point, step.at)
				"button": state.button_down(step.action, id, point, step.at)
				"stick": state.stick_down(step.movement, id, point, Vector2(70, 70), 70)
				"move": state.move(id, point)
				"up": state.up(id, point, step.at, step.get("cancel", false))
				"tick": state.tick(step.delta, step.at)
				"reset": state.reset()
				"blocked": state.set_blocked(step.value)
			Helper.compare(h, events, step.events, "Original touch dispatch order: " + item.name)
			var held: Dictionary = {}
			for pointer: int in state.held:
				held[str(pointer)] = state.held[pointer]
			var move: Vector2 = state.move_stick.vector
			var look: Vector2 = state.look_stick.vector
			Helper.compare(h, {"axis": [state.axis.x, state.axis.y], "lookId": state.look_id, "fireArm": state.fire_arm,
				"lookFire": state.look_fire, "tapAt": state.tap_at, "movement": [move.x, move.y],
				"lookStick": [look.x, look.y], "held": held, "taps": state.taps.keys()}, step.result, "Original touch state: " + item.name)
			h._check(state.held.size() == step.result.held.size(), "Touch release removes all original held pointers")
	for item: Dictionary in fixtures.gyroPrograms:
		var state := GyroState.new(Content.balance.mobile.look)
		state.sensitivity = item.sensitivity
		state.invert = item.invert
		state.start(item.source, 1000)
		var outputs: Array = []
		var failures: Array = []
		state.look.connect(func(change): outputs.append([change.x, change.y]))
		state.failed.connect(func(reason): failures.append(reason))
		for step: Dictionary in item.steps:
			outputs.clear()
			failures.clear()
			match step.kind:
				"motion": state.motion(vector3(step.rate) * PI / 180.0, step.delta, true, deg_to_rad(item.screenAngle))
				"orient": state.orientation(GyroState.sensor_forward(vector3(step.gravity), vector3(step.magnetic)), step.at)
				"reset": state.reset_basis()
				"watchdog": state.watchdog(step.at)
			Helper.compare(h, outputs, step.outputs, "Original gyro axes/dead-zone/gain/pitch sign: " + item.name)
			h._check((not failures.is_empty()) == bool(step.failed), "Original gyro watchdog and forced-source failure")
			Helper.compare(h, {"active": state.active, "path": state.path, "have": state.have, "raw": [state.raw.x, state.raw.y],
				"accumulated": [state.accumulated.x, state.accumulated.y], "events": state.events, "usable": state.usable}, step.result, "Original gyro baseline/jump/wrap/fallback: " + item.name)
	h._check(GyroState.sensor_forward(Vector3.ZERO, Vector3.ONE) == Vector3.ZERO, "Missing gravity never fabricates a sensor orientation")
	h._check(GyroState.sensor_forward(Vector3.DOWN, Vector3.UP) == Vector3.ZERO, "Parallel magnetic/gravity readings cannot establish heading")
	for item: Dictionary in fixtures.mobileFlight:
		var motion := vector(item.motion)
		var direction := InputRules.movement_basis(item.yaw, item.pitch, true, item.level) * Vector3(motion.x, 0, motion.y)
		h._check(direction.distance_to(vector3(item.result)) < 0.00001, "Original level-move flight preserves horizontal strafe and pitch-relative forward motion")
	var simulation: BattleSimulation = ControlsTests.context(h)
	var unit: BattleUnit = ControlsTests.actor(simulation, "t01")
	for value: Variant in [true, false, "true", 1, {}, Vector2.ONE]:
		simulation.submit_input(1, {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "level_move": value})
		h._check(bool(unit.input_state.level_move) == (value is bool and value), "Only an explicit input boolean enables authority level-move")
	unit.hp = 0
	simulation.submit_input(1, {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "fire": true})
	h._check(not unit.input_state.fire, "Dead input cannot leave a live firing request queued for respawn")
	simulation.free()

static func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func vector3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
