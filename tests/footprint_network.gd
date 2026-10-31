extends "res://scripts/main.gd"

var fixture_pilot: BattleUnit
var front: BattleUnit
var rear: BattleUnit
var observer: BattleUnit
var elapsed := 0.0
var started_at := 0.0
var warning_seen := false
var normal_seen := false
var shop_checked := false

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 16:
		push_error("NETWORK_FOOTPRINT_TIMEOUT warning=%s normal=%s shop=%s" % [warning_seen, normal_seen, shop_checked])
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
			for unit: BattleUnit in simulation.units.values():
				if unit != fixture_pilot:
					unit.hp = 0
			fixture_pilot.position = Vector3(0, simulation.world.ground_height(0, 0) + 100, 0)
			front = simulation.spawn({"kind": "soldier", "side": "SWARM", "position": fixture_pilot.position + Vector3(0, 0, -30)})
			rear = simulation.spawn({"kind": "soldier", "side": "SWARM", "position": fixture_pilot.position + Vector3(0, 0, -35)})
			observer = simulation.spawn({"kind": "soldier", "side": "STEEL", "position": fixture_pilot.position + Vector3(0, 0, -45)})
			started_at = elapsed
		else:
			simulation.clock += delta
			fixture_pilot.yaw = fixture_pilot.input_state.get("yaw", 0)
			fixture_pilot.pitch = fixture_pilot.input_state.get("pitch", 0)
			var distance := 1500.0 if elapsed - started_at > 5 else 100.0 if elapsed - started_at > 2 else 30.0
			front.position.z = -distance
			rear.position.z = -distance - 5
			observer.position.z = -distance - 15
			if distance > 1000:
				observer.hp = 0
			if not simulation.snapshot().footprint.is_empty():
				push_error("NETWORK_FOOTPRINT_PRIVACY")
				get_tree().quit(1)
		return
	selected_slot = "heavy"
	Input.action_press("aim")
	super._physics_process(delta)

func _receive_state(state: Dictionary) -> void:
	super._receive_state(state)
	if Session.dedicated or simulation == null:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	for unit: Dictionary in state.units:
		if unit.hp > 0 and unit.side != pilot.side and unit.kind == "soldier":
			var offset: Vector3 = unit.position + Vector3.UP * Content.balance.modelGeometry.units.soldier[unit.side].centre - pilot.view_origin()
			yaw = atan2(-offset.x, -offset.z)
			pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
			break
	var footprint: Dictionary = state.get("footprint", {})
	if not footprint.is_empty():
		if footprint.slot != "heavy" or footprint.side != pilot.side or footprint.hits.size() != 2 or simulation.footprint_glows.active.size() != 2:
			push_error("NETWORK_FOOTPRINT_INVALID_ROSTER")
			get_tree().quit(1)
			return
		for id: int in footprint.hits:
			var glow: MeshInstance3D = simulation.footprint_glows.active[id]
			var expected := simulation.footprint_glows.warning if footprint.warn else simulation.footprint_glows.normal
			if glow.material_override != expected or not glow.visible:
				push_error("NETWORK_FOOTPRINT_MATERIAL")
				get_tree().quit(1)
				return
		warning_seen = warning_seen or footprint.warn
		normal_seen = normal_seen or not footprint.warn
		if normal_seen and not shop_checked:
			_overlay(shop, true)
			if not simulation.footprint_glows.active.is_empty():
				push_error("NETWORK_FOOTPRINT_SHOP")
				get_tree().quit(1)
				return
			_overlay(shop, false)
			shop_checked = true
	elif warning_seen and normal_seen and shop_checked and simulation.footprint_glows.active.is_empty():
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_FOOTPRINT_PASS victims=2 warning=true normal=true hidden=true shop=true")
		Session.stop()
		get_tree().quit()
