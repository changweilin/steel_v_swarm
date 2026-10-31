extends "res://scripts/main.gd"

var elapsed := 0.0
var fixture_peer := 0
var fixture_stage := 0
var requested := false
var alive_at := -1.0
var last_time := -1.0
var flash_seen := false
var owner_velocity_seen := false
var frozen_resources: Array = []

func _ready() -> void:
	super._ready()
	network_test = false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 18:
		_fail("NETWORK_DEATH_TIMEOUT stage=%d" % fixture_stage)
		return
	if simulation == null:
		return
	if Session.dedicated:
		if fixture_peer == 0:
			for pilot: BattleUnit in simulation.pilots.values():
				if pilot.peer_id > 1:
					fixture_peer = pilot.peer_id
					simulation.set_physics_process(false)
		return
	super._physics_process(delta)
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	if fixture_stage in [0, 2] and pilot.alive():
		if alive_at < 0:
			alive_at = elapsed
		if elapsed - alive_at < .3:
			return
		if fixture_stage == 2:
			if pilot.presentation_camera_owned or pilot.camera.top_level or not death_sequence.state.is_empty() or not pilot.flying:
				_fail("Early respawn did not release the old cinematic and establish the new flying view")
				return
			owner_velocity_seen = pilot.velocity.distance_to(Vector3(12, -3, 8)) < .0001
			if not owner_velocity_seen:
				_fail("Authority owner velocity was not delivered for the death-camera launch frame")
				return
		fixture_stage += 1
		alive_at = -1
		last_time = -1
		_kill_fixture.rpc_id(1)
	if not death_sequence.state.is_empty():
		if notice.text != "" or not pilot.presentation_camera_owned or not pilot.camera.top_level:
			_fail("Death snapshots exposed countdown UI or returned camera ownership during the cinematic")
			return
		var eye := pilot.camera.global_transform
		pilot.sync_view_camera()
		if pilot.camera.global_transform != eye:
			_fail("A transported dead actor overwrote its cinematic camera")
			return
		var time := float(death_sequence.state.t)
		if time < last_time:
			_fail("Repeated dead publications restarted the cinematic")
			return
		last_time = time
		if fixture_stage == 1 and time > .4 and not requested:
			requested = true
			fixture_stage = 2
			_respawn_fixture.rpc_id(1, false)
		elif fixture_stage == 3:
			flash_seen = flash_seen or death_overlay.state.flash_live
	elif fixture_stage == 3 and not pilot.alive() and notice.text.begins_with(Content.label("respawn")):
		if not flash_seen or not pilot.presentation_camera_owned or not owner_velocity_seen:
			_fail("Aerial death did not complete its climax, final held view and delayed countdown publication")
			return
		fixture_stage = 4
		_respawn_fixture.rpc_id(1, true)
	elif fixture_stage == 4 and pilot.alive():
		if pilot.presentation_camera_owned or pilot.camera.top_level or not death_sequence.state.is_empty():
			_fail("Completed cinematic did not release its camera on transported respawn")
			return
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_DEATH_PASS snapshots=true ground=true earlyRespawn=true air=true climax=true ownership=true ownerVelocity=true countdown=true resources=true")
		Session.stop()
		get_tree().quit()

@rpc("any_peer", "call_remote", "reliable")
func _kill_fixture() -> void:
	if not Session.dedicated or fixture_peer == 0 or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer:
		return
	var pilot: BattleUnit = simulation.pilots[fixture_peer]
	pilot.status.erase("inv_until")
	simulation._fire_burn(pilot, (pilot.max_hp + pilot.max_shield) * 4)
	if pilot.alive():
		_fail("Authority fixture failed to settle lethal fire damage")
		return
	frozen_resources = _resources(pilot)

@rpc("any_peer", "call_remote", "reliable")
func _respawn_fixture(final: bool) -> void:
	if not Session.dedicated or fixture_peer == 0 or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer:
		return
	var pilot: BattleUnit = simulation.pilots[fixture_peer]
	if _resources(pilot) != frozen_resources:
		_fail("Client death-camera effects changed authority resources or combat RNG")
		return
	simulation.respawn(pilot)
	if not final:
		pilot.flying = true
		pilot.position.y += 60
		pilot.velocity = Vector3(12, -3, 8)

func _resources(pilot: BattleUnit) -> Array:
	return [pilot.hp, pilot.shield, pilot.power, pilot.ammo.duplicate(true), pilot.money, simulation.clock,
		simulation.rng.state, simulation.projectile_rng.state]

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
