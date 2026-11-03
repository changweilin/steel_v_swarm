extends "res://scripts/main.gd"

var elapsed := 0.0
var started_at := -1.0
var fixture_pilot: BattleUnit
var air_started := false
var ground_restored := false
var ground_seen := false
var air_seen := false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 16:
		push_error("NETWORK_CAMERA_TIMEOUT")
		get_tree().quit(1)
		return
	if Session.dedicated:
		if simulation == null or simulation.pilots.is_empty():
			return
		if fixture_pilot == null:
			for pilot: BattleUnit in simulation.pilots.values():
				if pilot.peer_id > 1:
					fixture_pilot = pilot
			if fixture_pilot == null:
				return
			simulation.set_physics_process(false)
			fixture_pilot.position = Vector3(0, simulation.world.ground_height(0, 0) + 100, 0)
			started_at = elapsed
		fixture_pilot.yaw = fixture_pilot.input_state.get("yaw", 0)
		fixture_pilot.pitch = fixture_pilot.input_state.get("pitch", 0)
		if elapsed - started_at > .8 and not air_started:
			# This fixture isolates camera binding; charged movement has its own source oracle.
			fixture_pilot.flying = true
			fixture_pilot.refresh_collision()
			air_started = true
		elif elapsed - started_at > 1.6 and not ground_restored:
			fixture_pilot.flying = false
			fixture_pilot.refresh_collision()
			ground_restored = true
		return
	yaw = .7
	pitch = -.2
	super._physics_process(delta)

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if Session.dedicated or simulation == null:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	var spec: Dictionary = Content.balance.cameraProfiles[pilot.character]["air" if pilot.flying else "ground"]
	var expected := Vector3(0, spec.eye, -spec.forward)
	if not pilot.view_offset_ready or pilot.view_offset.distance_to(expected) > 0.0001:
		push_error("NETWORK_CAMERA_SOURCE_ANCHOR_MISSING")
		get_tree().quit(1)
		return
	if pilot.camera.global_position.distance_to(pilot.view_origin()) > 0.0001 or pilot.camera.near != Content.balance.cameraRules.near:
		push_error("NETWORK_CAMERA_RENDERER_OR_NEAR_MISMATCH")
		get_tree().quit(1)
		return
	if pilot.flying:
		air_seen = true
	else:
		if ground_seen and air_seen:
			print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
			print("NETWORK_CAMERA_PASS ground=true air=true restored=true near=true renderer=true")
			Session.stop()
			get_tree().quit()
		ground_seen = true
