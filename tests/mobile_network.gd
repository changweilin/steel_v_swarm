extends "res://scripts/main.gd"

var elapsed := 0.0
var phase := 0
var requested := false
var input_confirmed := false
var forced_seen := false
var released_seen := false
var free_seen := false
var fixture_pilot: BattleUnit
var input_at := 0.0

func _ready() -> void:
	Controls.persist = false
	Controls.configure(Content.balance.mobile)
	super._ready()
	network_test = false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 18:
		push_error("NETWORK_MOBILE_TIMEOUT phase=%d forced=%s released=%s free=%s" % [phase, forced_seen, released_seen, free_seen])
		get_tree().quit(1)
		return
	if Session.dedicated:
		_server_step()
		return
	super._physics_process(delta)
	if simulation == null or not simulation.pilots.has(Session.player_id()):
		return
	if not requested and Controls.room == "pad" and touch_controls.visible:
		requested = true
		forced_seen = not Controls.set_scheme("kbm") and Session.is_room_host() and not Session.set_control_mode("invalid")
		Controls.set_value("levelMove", true)
		Controls.set_value("invertX", true)
		Controls.set_value("invertY", true)
		var before := Vector2(yaw, pitch)
		var point := touch_controls.size / 2
		_touch(3, point, true)
		var drag := InputEventScreenDrag.new()
		drag.index = 3
		drag.position = point + Vector2(20, -12)
		Input.parse_input_event(drag)
		_touch(3, drag.position, false)
		var expected := Vector2(20, -12) * float(Content.balance.mobile.look.TOUCH_RAD_PX)
		if Vector2(yaw, pitch).distance_to(before + expected) > 0.00001:
			_fail("Native touch drag must pass through the shared inversion exactly once")
			return
		_touch(1, touch_controls.movement_rect.get_center() + Vector2.UP * touch_controls.movement_rect.size.y / 2, true)
		_touch(2, touch_controls.buttons.jump.get_global_rect().get_center(), true)
		phase = 1
	elif phase == 1 and Controls.room == "kbm":
		released_seen = not touch_controls.visible and touch_controls.held.is_empty() and touch_controls.state.axis == Vector2.ZERO and touch_controls.state.held.is_empty()
		phase = 2
	elif phase == 2 and Controls.room == "any":
		free_seen = Controls.set_scheme("pad") and touch_controls.visible
		_touch(4, touch_controls.buttons.aim.get_global_rect().get_center(), true)
		_touch(4, touch_controls.buttons.aim.get_global_rect().get_center(), false)
		phase = 3
	elif phase == 3 and Controls.room == "pad" and aiming and aim_request > 0:
		_touch(5, touch_controls.buttons.fire.get_global_rect().get_center(), true)
		phase = 4
	elif phase == 4 and input_confirmed:
		_overlay(menu, true)
		var cleared := touch_controls.held.is_empty() and touch_controls.state.held.is_empty() and not touch_controls.visible
		if not forced_seen or not released_seen or not free_seen or not cleared or not Controls.values.levelMove or not Controls.values.invertX or not Controls.values.invertY:
			_fail("Native control modes, private preferences and overlay release must survive authority broadcasts")
			return
		phase = 5
	elif phase == 5 and released_seen and Controls.room == "any":
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_MOBILE_PASS touch=true mode=true host=true release=true level_move=true private=true aim=true")
		Session.stop()
		get_tree().quit()

func _server_step() -> void:
	if simulation == null:
		return
	if fixture_pilot == null:
		for unit: BattleUnit in simulation.pilots.values():
			if unit.peer_id > 1:
				fixture_pilot = unit
		if fixture_pilot == null:
			return
		simulation.set_physics_process(false)
	var input := fixture_pilot.input_state
	if phase == 0 and input.get("level_move", false) and input.get("jump_held", false) and input.get("move", Vector2.ZERO).y < -0.99:
		input_at = elapsed
		phase = 1
		Session._settle_control_mode("kbm")
	elif phase == 1 and elapsed - input_at > 0.4 and input.get("move", Vector2.ONE) == Vector2.ZERO and not input.get("jump_held", true):
		phase = 2
		Session._settle_control_mode("any")
	elif phase == 2 and fixture_pilot.aim_request > 0 and input.get("aim", false):
		phase = 3
		input_at = elapsed
		Session._settle_control_mode("pad")
	elif phase == 3 and input.get("fire", false):
		phase = 4
		_mark_input_received.rpc_id(Session.seats.transport_for(fixture_pilot.peer_id))
	elif phase == 4 and not input.get("fire", true) and not input.get("jump_held", true):
		phase = 5
		Session._settle_control_mode("any")

@rpc("authority", "call_remote", "reliable")
func _mark_input_received() -> void:
	input_confirmed = true

func _touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	Input.parse_input_event(event)

func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
