extends "res://scripts/main.gd"

var elapsed := 0.0
var started_at := -1.0
var fixture_pilot: BattleUnit
var light_seen := false
var heavy_seen := false
var moving_seen := false
var echo_seen := false
var clearing_seen := false
var heavy_fired := false
var cleared := false
var previous_positions: Dictionary = {}

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 16:
		push_error("NETWORK_PROJECTILE_VISUAL_TIMEOUT light=%s heavy=%s moving=%s echo=%s clear=%s" % [light_seen, heavy_seen, moving_seen, echo_seen, clearing_seen])
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
			for unit: BattleUnit in simulation.units.values():
				if unit != fixture_pilot:
					unit.hp = 0
			simulation.fire(fixture_pilot, "light")
		simulation.clock += delta
		if elapsed - started_at > .6 and not heavy_fired:
			fixture_pilot.input_state.aim = true
			simulation.fire(fixture_pilot, "heavy")
			heavy_fired = true
		# Slow the source flight clock to isolate transport/mesh binding from snapshot cadence.
		simulation._tick_projectiles(1.0 / 240)
		simulation._tick_weapon_pose(fixture_pilot, delta)
		if elapsed - started_at > 2 and not cleared:
			simulation.projectiles.clear()
			cleared = true
		if not simulation.snapshot().projectile_view.is_empty() or simulation.world.projectile_visuals != null:
			push_error("NETWORK_PROJECTILE_VISUAL_AUTHORITY_LEAK")
			get_tree().quit(1)
		return
	super._physics_process(delta)
	if simulation == null or simulation.world.projectile_visuals == null:
		return
	var presentation := simulation.world.projectile_visuals
	echo_seen = echo_seen or not presentation.shells.is_empty()
	if light_seen and heavy_seen and moving_seen and echo_seen and clearing_seen:
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_PROJECTILE_VISUAL_PASS light=true heavy=true source_geometry=true moving_pose=true echo=true clear=true private=true")
		Session.stop()
		get_tree().quit()

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if Session.dedicated or simulation == null:
		return
	var presentation := simulation.world.projectile_visuals
	if presentation == null:
		return
	for record: Dictionary in state.projectile_view:
		var model: ProjectileVisual = presentation.rounds[record.id].model
		if model.position != record.position or (model.quaternion * Vector3.BACK).distance_to(record.velocity.normalized()) > .00001 or model.source_root == null:
			push_error("NETWORK_PROJECTILE_VISUAL_SOURCE_POSE_MISMATCH")
			get_tree().quit(1)
			return
		light_seen = light_seen or model.profile.slot == "light"
		heavy_seen = heavy_seen or model.profile.slot == "heavy"
		moving_seen = moving_seen or (previous_positions.has(record.id) and previous_positions[record.id] != record.position)
		previous_positions[record.id] = record.position
	clearing_seen = clearing_seen or (light_seen and heavy_seen and state.projectile_view.is_empty() and presentation.rounds.is_empty())
