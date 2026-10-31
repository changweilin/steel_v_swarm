extends "res://scripts/main.gd"

var elapsed := 0.0
var phase := 0
var approved := 0
var pending_checkpoint := 0
var fixture_pilot: BattleUnit
var frozen_resources: Array = []
var start_yaw := 0.0
var scoped_snapshot: Dictionary = {}
var shot_serial := -1
var shot_origin := Vector3.ZERO
var received_origin := Vector3(INF, INF, INF)
var restored_by_event := false

func _ready() -> void:
	Controls.persist = false
	Controls.configure(Content.balance.mobile)
	super._ready()
	network_test = false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 18:
		_fail("NETWORK_TPS_TIMEOUT phase=%d approved=%d" % [phase, approved])
		return
	if Session.dedicated:
		_server_step(delta)
		return
	super._physics_process(delta)
	if simulation == null or not view_ready:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null or pilot.body == null or pilot.body.source_root == null:
		return
	if phase == 0 and pilot.view_mode == "tps":
		if not _tps_visible(pilot):
			_fail("TPS must render the captured owner body and hide the cockpit")
			return
		var ring := Vector3(pilot.position.x, pilot.body.ring_height(pilot.position.y), pilot.position.z)
		var local := view_frame.affine_inverse() * ring
		var clip := view_projection * Vector4(local.x, local.y, local.z, 1)
		if absf(clip.y / clip.w + .5) > .0002:
			_fail("TPS camera must retain original post-clip team-ring framing")
			return
		start_yaw = yaw
		yaw += .6
		_checkpoint.rpc_id(1, 1)
		phase = 1
	elif phase == 1 and approved >= 1:
		Controls.set_view_pref("fpv")
		_checkpoint.rpc_id(1, 2)
		phase = 2
	elif phase == 2 and approved >= 2:
		if pilot.model.visible or not pilot.cockpit.visible or absf(BotRules.wrap_pi(yaw - start_yaw)) > .001:
			_fail("Leaving TPS must adopt body heading and restore the cockpit")
			return
		Controls.set_view_pref("tps")
		_set_aiming(true)
		phase = 3
	elif phase == 3 and not scoped_snapshot.is_empty() and pilot.view_mode == "fpv":
		if player_view.mode != "fpv" or player_view.restore != "tps" or pilot.model.visible:
			_fail("Scoped TPS must temporarily force FPV and retain its restoration mode")
			return
		_checkpoint.rpc_id(1, 3)
		phase = 4
	elif phase == 4 and approved >= 3 and restored_by_event and pilot.view_mode == "tps" and _tps_visible(pilot):
		if shot_serial < 0 or received_origin.distance_to(shot_origin) > .0002 or pilot.cockpit.accepted_serial != shot_serial:
			_fail("Immediate last-heavy feedback must preserve the authority body muzzle and acceptance identity")
			return
		# Replay the real older scoped snapshot after the separate fire channel.
		_receive_state(scoped_snapshot)
		if aiming or player_view.mode != "tps":
			_fail("An older snapshot must not undo immediate empty-heavy restoration")
			return
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_TPS_PASS body=true ring=true heading=true modes=true muzzle=true empty_heavy=true stale_snapshot=true resources=true")
		Session.stop()
		get_tree().quit()

func _server_step(delta: float) -> void:
	if simulation == null:
		return
	if fixture_pilot == null:
		for unit: BattleUnit in simulation.pilots.values():
			if unit.peer_id > 1:
				fixture_pilot = unit
		if fixture_pilot == null:
			return
		simulation.set_physics_process(false)
		frozen_resources = _resources()
	# Isolate view/input transport from autonomous world movement and damage.
	simulation.clock += delta
	fixture_pilot.yaw = float(fixture_pilot.input_state.get("yaw", fixture_pilot.yaw))
	fixture_pilot.pitch = float(fixture_pilot.input_state.get("pitch", fixture_pilot.pitch))
	fixture_pilot.advance_player_view(delta, fixture_pilot.input_state.get("move", Vector2.ZERO))
	fixture_pilot.rotation.y = fixture_pilot.facing_yaw()
	simulation._tick_view_fov(fixture_pilot, delta)
	simulation._tick_weapon_pose(fixture_pilot, delta)
	simulation._tick_authority_body(fixture_pilot, delta)
	if pending_checkpoint == 1 and fixture_pilot.view_mode == "tps" and absf(BotRules.wrap_pi(fixture_pilot.yaw - fixture_pilot.facing_yaw())) > .4:
		if _resources() != frozen_resources or fixture_pilot.input_state.has("view_target"):
			_fail("TPS idle camera turning must retain body heading, authority resources and ordinary input")
			return
		var state := fixture_pilot.snapshot()
		if state.yaw != fixture_pilot.facing_yaw() or state.view_yaw != fixture_pilot.yaw:
			_fail("Snapshots must distinguish physical body heading from camera heading")
			return
		_approve(1)
	elif pending_checkpoint == 2 and fixture_pilot.view_mode == "fpv":
		if _resources() != frozen_resources:
			_fail("Changing view mode must not spend combat resources or RNG")
			return
		_approve(2)
	elif pending_checkpoint == 3 and fixture_pilot.input_state.get("aim", false) and fixture_pilot.input_state.get("view_restore") == "tps":
		var definition := Content.weapon(fixture_pilot.character, "heavy")
		fixture_pilot.ammo.heavy = 1
		var before_power := fixture_pilot.power
		var before_serial := fixture_pilot.fire_serial
		var expected := simulation._launch_pose(fixture_pilot, "heavy", definition.range, null, false, "tps")
		var cockpit := simulation._launch_pose(fixture_pilot, "heavy", definition.range, null, false, "fpv")
		if expected.origin.distance_to(cockpit.origin) < .01:
			_fail("TPS fixture must distinguish source body and cockpit ports")
			return
		simulation.fire(fixture_pilot, "heavy")
		var accepted: Array = simulation.events.filter(func(event): return event.type == "weapon_fire" and int(event.actor) == fixture_pilot.entity_id)
		if accepted.size() != 1 or fixture_pilot.fire_serial != before_serial + 1 or fixture_pilot.ammo.heavy != 0 or absf(fixture_pilot.power - before_power + float(definition.heavyMp)) > .00001:
			_fail("Last scoped heavy shot must settle exactly one accepted round")
			return
		var event: Dictionary = accepted[0]
		if event.muzzle.distance_to(expected.origin) > .0002 or fixture_pilot.view_mode != "tps" or fixture_pilot.input_state.aim:
			_fail("Empty-heavy restoration must select the body muzzle before the FPV camera changes")
			return
		# Only the immediate channel may supply this fire notification.
		simulation.events.erase(event)
		_expect_shot.rpc_id(Session.seats.transport_for(fixture_pilot.peer_id), int(event.serial), event.muzzle)
		_approve(3)

func _resources() -> Array:
	return [fixture_pilot.hp, fixture_pilot.shield, fixture_pilot.power, fixture_pilot.money,
		fixture_pilot.ammo.duplicate(true), fixture_pilot.fire_serial, simulation.rng.state, simulation.projectile_rng.state]

func _tps_visible(pilot: BattleUnit) -> bool:
	return player_view.mode == "tps" and pilot.model.visible and not pilot.cockpit.visible

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if not Session.dedicated and phase == 3 and state.get("aim_control", {}).get("on", false):
		scoped_snapshot = state.duplicate(true)

func _body_event_feedback(event: Dictionary) -> void:
	super._body_event_feedback(event)
	if not Session.dedicated and phase == 4 and event.get("empty_heavy", false):
		received_origin = event.muzzle
		restored_by_event = not aiming and player_view.mode == "tps"

@rpc("any_peer", "call_remote", "reliable")
func _checkpoint(stage: int) -> void:
	if Session.dedicated and fixture_pilot != null and Session.seats.player_for(multiplayer.get_remote_sender_id()) == fixture_pilot.peer_id and stage == approved + 1:
		pending_checkpoint = stage

func _approve(stage: int) -> void:
	approved = stage
	pending_checkpoint = 0
	_accept_checkpoint.rpc_id(Session.seats.transport_for(fixture_pilot.peer_id), stage)

@rpc("authority", "call_remote", "reliable")
func _accept_checkpoint(stage: int) -> void:
	approved = stage

@rpc("authority", "call_remote", "reliable")
func _expect_shot(serial: int, origin: Vector3) -> void:
	shot_serial = serial
	shot_origin = origin

func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
