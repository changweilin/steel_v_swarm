extends "res://scripts/main.gd"

const Mobile = preload("res://tests/mobile_suite.gd")

var elapsed := 0.0
var phase := 0
var fixture_pilot: BattleUnit
var frozen_resources: Array = []
var baseline_yaw := 0.0
var trace: Dictionary = {}
var fixture_points: Array = []
var accepted := false

func _ready() -> void:
	Controls.persist = false
	Controls.configure(Content.balance.mobile)
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", ["viewLocks"])
	for item: Dictionary in fixtures.viewLocks:
		if item.yaw == 0 and item.pitch == 0:
			trace = item
			break
	super._ready()
	network_test = false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 18:
		push_error("NETWORK_VIEW_TIMEOUT phase=%d target=%d accepted=%s" % [phase, view_lock.target, accepted])
		get_tree().quit(1)
		return
	if Session.dedicated:
		_server_step()
		return
	super._physics_process(delta)
	if simulation == null or not view_ready or touch_controls == null or not touch_controls.visible:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	if phase == 0:
		baseline_yaw = yaw
		var origin := view_frame.origin
		var basis := view_frame.basis
		for row: Dictionary in trace.steps[0].candidates:
			fixture_points.append({"id": row.id, "eligible": row.eligible,
				"point": origin + basis * (Mobile.vector3(row.point) - Mobile.vector3(trace.eye))})
		_lock_touch(true)
		phase = 1
	elif phase == 1 and view_lock.lit and view_lock.target == int(trace.steps[0].result.target):
		_lock_touch(false)
		_lock_touch(true)
		phase = 2
	elif phase == 2 and view_lock.lit and view_lock.target == int(trace.steps[3].result.target):
		_overlay(shop, true)
		if view_lock.hold or view_lock.target != 0 or not touch_controls.held.is_empty():
			_fail("Shop entry must release the actual native view-lock pointer")
			return
		_overlay(shop, false)
		var aim: Vector2 = touch_controls.buttons.aim.get_global_rect().get_center()
		_touch(1, aim, true)
		_touch(1, aim, false)
		phase = 3
	elif phase == 3 and accepted and aiming and scope_state.weather_fog == 1:
		var expected := roundf(ScopeState.radius_vmin(0, 1) * 10) / 10
		var bound := float(scope_overlay.shader_material.get_shader_parameter("radius_vmin"))
		if absf(bound - expected) > 0.00001 or view_lock.hold or view_lock.target != 0:
			_fail("Native scope material must use the same density/radius as original acquisition")
			return
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_VIEW_PASS touch=true cycle=true release=true pose=true scope=true resources=true target_rpc=false")
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
		baseline_yaw = fixture_pilot.yaw
		frozen_resources = _resources()
		# This fixture controls only the public presentation density. Full weather
		# profile settlement is covered by the original weather oracle separately.
		simulation.weather_dynamics.effectiveFog = 1.0
	var input := fixture_pilot.input_state
	if phase == 0 and fixture_pilot.aim_request > 0 and input.get("aim", false) and BotRules.wrap_pi(float(input.get("yaw", baseline_yaw)) - baseline_yaw) < -0.0001:
		if _resources() != frozen_resources or input.has("view_target") or input.has("view_lock"):
			_fail("View assistance must send only ordinary pose input and retain authority resources/weapon lock")
			return
		phase = 1
		_accept_view_input.rpc_id(Session.seats.transport_for(fixture_pilot.peer_id))

func _resources() -> Array:
	return [fixture_pilot.hp, fixture_pilot.shield, fixture_pilot.power, fixture_pilot.money,
		fixture_pilot.ammo.duplicate(true), fixture_pilot.lock_target, fixture_pilot.fire_serial, simulation.rng.state]

# Source-authored scalar candidates isolate frontend input/transport from map
# placement. Production entity visibility/centres and native LOS are separate gates.
func _view_candidates(pilot: BattleUnit) -> Array:
	return fixture_points if not fixture_points.is_empty() else super._view_candidates(pilot)

func _view_point(id: int) -> Vector3:
	for row: Dictionary in fixture_points:
		if int(row.id) == id:
			return row.point
	return Vector3(INF, INF, INF)

func _view_obstruction(_start: Vector3, _end: Vector3) -> float:
	return INF

@rpc("authority", "call_remote", "reliable")
func _accept_view_input() -> void:
	accepted = true

func _lock_touch(down: bool) -> void:
	_touch(0, touch_controls.buttons.lock.get_global_rect().get_center(), down)

func _touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	Input.parse_input_event(event)

func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
