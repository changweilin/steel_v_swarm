extends "res://scripts/main.gd"

class ControlsSimulation extends BattleSimulation:
	var recoil_values: Array = []

	func _recoil_next() -> float:
		return float(recoil_values.pop_front()) if not recoil_values.is_empty() else super._recoil_next()

var elapsed := 0.0
var fixture_pilot: BattleUnit
var requested := false
var mode_seen := false
var cast_seen := false
var pulse_seen := false
var view_seen := false
var pulse_at := -1.0
var phase := 0
var trace: Dictionary = {}

func _ready() -> void:
	Controls.persist = false
	Controls.configure(Content.balance.mobile)
	Controls.set_scheme("kbm")
	super._ready()
	network_test = false

func _create_simulation() -> BattleSimulation:
	return ControlsSimulation.new()

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	# The client launches after the authority and owns this deadline.
	if not Session.dedicated and elapsed > 18:
		push_error("NETWORK_CONTROLS_TIMEOUT mode=%s cast=%s pulse=%s view=%s" % [mode_seen, cast_seen, pulse_seen, view_seen])
		get_tree().quit(1)
		return
	if Session.dedicated:
		if simulation == null or not Session.launch_announced:
			return
		if fixture_pilot == null:
			for unit: BattleUnit in simulation.pilots.values():
				if unit.peer_id > 1:
					fixture_pilot = unit
			if fixture_pilot == null:
				return
			simulation.set_physics_process(false)
		if phase == 0 and fixture_pilot.aim_request > 0 and fixture_pilot.defending and fixture_pilot.cast_state.get("slot") == "def":
			phase = 1
			pulse_at = elapsed
		elif phase == 1 and elapsed - pulse_at > 0.8:
			phase = 2
			simulation.clock = 10
			simulation._tick_ability_states(0)
			fixture_pilot.power = fixture_pilot.max_power
			var source := simulation as ControlsSimulation
			source.recoil_values = [0.37]
			var serial := fixture_pilot.fire_serial
			simulation.fire(fixture_pilot, "heavy")
			if fixture_pilot.fire_serial == serial:
				push_error("NETWORK_CONTROLS_AUTHORITY_FIRE")
				get_tree().quit(1)
			pulse_at = elapsed
		elif phase == 2 and elapsed - pulse_at > 0.8:
			phase = 3
			var source := simulation as ControlsSimulation
			source.recoil_values = [0.1, 0.8, 0.4]
			fixture_pilot.recoil.advance(0.04, simulation._recoil_next)
			simulation.clock = 10.04
		return
	super._physics_process(delta)
	if simulation != null and Session.launch_announced and not requested and simulation.pilots.has(Session.player_id()):
		requested = true
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		_unhandled_input(wheel)
		var shield := InputEventKey.new()
		shield.physical_keycode = KEY_F
		shield.pressed = true
		_unhandled_input(shield)
		var gesture := InputEventMouseButton.new()
		gesture.button_index = MOUSE_BUTTON_RIGHT
		gesture.pressed = true
		_unhandled_input(gesture)
	if mode_seen and cast_seen and pulse_seen and view_seen:
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_CONTROLS_PASS bindings=true ordered=true mode=true source=true recoil=true view=true")
		Session.stop()
		get_tree().quit()

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if Session.dedicated or simulation == null:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	mode_seen = mode_seen or aiming and selected_slot == "heavy" and int(state.get("aim_control", {}).get("request", 0)) >= 1
	cast_seen = cast_seen or pilot.defending and pilot.cast_state.get("slot") == InputRules.hold_slot(true)
	if trace.is_empty():
		var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", ["recoilSequences"])
		trace = fixtures.recoilSequences.filter(func(item): return item.name == "pulse" and item.character == pilot.character and not item.flight)[0]
	var current: Dictionary = state.get("recoil", {})
	if current.is_empty() or float(current.get("pitch", 0)) <= 0:
		return
	var expected: Dictionary = trace.steps[1 if current.view_pitch != 0 else 0].result
	for key: String in ["pitch", "yaw", "trauma", "move_factor"]:
		if absf(float(current[key]) - float(expected[key])) > 0.00001:
			push_error("NETWORK_CONTROLS_SOURCE_RECOIL_" + key)
			get_tree().quit(1)
			return
	pulse_seen = true
	if expected.view != null:
		if absf(pilot.recoil.view_pitch - float(expected.view[0])) > 0.00001 or absf(pilot.recoil.view_yaw - float(expected.view[1])) > 0.00001:
			push_error("NETWORK_CONTROLS_PRIVATE_VIEW")
			get_tree().quit(1)
			return
		view_seen = true
