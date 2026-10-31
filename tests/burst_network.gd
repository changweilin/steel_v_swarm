extends "res://scripts/main.gd"

var elapsed := 0.0
var started_at := -1.0
var fixture_pilot: BattleUnit
var initial_ammo := 0
var accepted := 0
var first_seen := false
var second_seen := false
var authority_echo_seen := false
var client_echo_seen := false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 16:
		push_error("NETWORK_BURST_TIMEOUT first=%s second=%s authority=%s client=%s" % [first_seen, second_seen, authority_echo_seen, client_echo_seen])
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
			initial_ammo = fixture_pilot.ammo.light
			started_at = elapsed
			for unit: BattleUnit in simulation.units.values():
				if unit != fixture_pilot:
					unit.hp = 0
		simulation.clock += delta
		fixture_pilot.yaw = fixture_pilot.input_state.get("yaw", 0)
		fixture_pilot.pitch = fixture_pilot.input_state.get("pitch", 0)
		if accepted == 0 or (accepted == 1 and elapsed - started_at > .8):
			simulation.fire(fixture_pilot, "light")
			accepted = fixture_pilot.fire_serial
		simulation._tick_weapon_pose(fixture_pilot, delta)
		if accepted > 0 and (fixture_pilot.ammo.light != initial_ammo - accepted or simulation.projectiles.size() != accepted or fixture_pilot.weapon_pose.accepted_serial != accepted):
			push_error("NETWORK_BURST_EXTRA_AUTHORITY_SPENDING")
			get_tree().quit(1)
		if not simulation.snapshot().weapon_pose.is_empty() or fixture_pilot.cockpit != null:
			push_error("NETWORK_BURST_PRIVATE_POSE_OR_SERVER_MESH_LEAK")
			get_tree().quit(1)
		return
	selected_slot = "heavy" if first_seen else "light"
	super._physics_process(delta)
	if simulation == null:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null or pilot.cockpit == null:
		return
	var count := int(Content.weapon(pilot.character, "light").burst.count)
	client_echo_seen = client_echo_seen or (pilot.cockpit.accepted_serial == 2 and pilot.cockpit.weapons.last_serial == count * 2)
	if first_seen and second_seen and authority_echo_seen and client_echo_seen:
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_BURST_PASS accepted=true echoes=true slot_capture=true duplicate_rejection=true next_shot=true single_spending=true private_pose=true")
		Session.stop()
		get_tree().quit()

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if Session.dedicated or simulation == null:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null or pilot.cockpit == null:
		return
	for event: Dictionary in state.events:
		if event.type != "weapon_fire" or int(event.actor) != pilot.entity_id:
			continue
		if event.slot != "light" or int(event.level) != 1 or pilot.cockpit.accepted_serial != int(event.serial):
			push_error("NETWORK_BURST_ACCEPTED_EVENT_MISMATCH")
			get_tree().quit(1)
			return
		var visual_serial := pilot.cockpit.weapons.last_serial
		var pending := pilot.cockpit.bursts.pending.size()
		pilot.cockpit.fire_feedback(event)
		if pilot.cockpit.weapons.last_serial != visual_serial or pilot.cockpit.bursts.pending.size() != pending:
			push_error("NETWORK_BURST_DUPLICATE_REQUEUED")
			get_tree().quit(1)
			return
		first_seen = first_seen or int(event.serial) == 1
		second_seen = second_seen or int(event.serial) == 2
	var pose: Dictionary = state.weapon_pose
	if not pose.is_empty() and int(pose.serial) == 2 and int(pose.visual_serial) == 2 * int(Content.weapon(pilot.character, "light").burst.count):
		authority_echo_seen = true
