extends "res://scripts/main.gd"

var elapsed := 0.0
var remote_actor := 0
var fixture_peer := 0
var requested := false
var verified := false
var expected_serial := -1
var expected_indices: Dictionary = {}
var replay: Array = []
var actor: BattleUnit
var npc: BattleUnit
var artillery_fixture: BattleUnit
var tower: BattleUnit
var base_fixture: BattleUnit
var expected_statics: Dictionary = {}
var expected_npc_serial := -1
var expected_npc_muzzle := -1
var expected_npc_attacks: Array = []
var frozen_resources: Array = []
var clone_fixture: BattleUnit
var kami_fixture: BattleUnit
var hyper_fixture: BattleUnit
var civilian_fixture: BattleUnit
var expected_companions: Dictionary = {}
var remote_report: Dictionary = {}
var remote_verified := false
var screen_report: Dictionary = {}
var death_report: Dictionary = {}
var fixture_ids: Dictionary = {}

func _ready() -> void:
	super._ready()
	network_test = false

func _receive_state(packet: Dictionary) -> void:
	if not Session.dedicated:
		for record: Dictionary in packet.units:
			for key: String in ["owner_id", "offset", "definition", "camp_index", "aggro_id", "body_fixture", "npc_body_fixture", "artillery_body_fixture", "static_body_fixture", "companion_body_fixture"]:
				if record.get("special", {}).has(key):
					_fail("NETWORK_BODY_PRIVATE_ROLE_FIELD " + key)
					return
	super._receive_state(packet)

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if elapsed > 18:
		_fail("NETWORK_BODY_TIMEOUT")
		return
	if Session.dedicated:
		_server_step()
		return
	super._physics_process(delta)
	if simulation == null:
		return
	if fixture_ids.is_empty():
		return
	actor = simulation.units.get(int(fixture_ids.actor))
	npc = simulation.units.get(int(fixture_ids.npc))
	artillery_fixture = simulation.units.get(int(fixture_ids.artillery))
	tower = simulation.units.get(int(fixture_ids.tower))
	base_fixture = simulation.units.get(int(fixture_ids.base))
	clone_fixture = simulation.units.get(int(fixture_ids.clone))
	kami_fixture = simulation.units.get(int(fixture_ids.kami))
	hyper_fixture = simulation.units.get(int(fixture_ids.hyper))
	civilian_fixture = simulation.units.get(int(fixture_ids.civilian))
	if actor == null or actor.body_presentation == null or not actor.body_presentation.sampled:
		return
	if npc == null or npc.body_presentation == null or not npc.body_presentation.sampled:
		return
	if artillery_fixture == null or artillery_fixture.body_presentation == null or not artillery_fixture.body_presentation.sampled:
		return
	for unit: BattleUnit in [tower, base_fixture]:
		if unit == null or unit.body_presentation == null or not unit.body_presentation.sampled:
			return
	for unit: BattleUnit in [clone_fixture, kami_fixture, hyper_fixture, civilian_fixture]:
		if unit == null or unit.body_presentation == null or not unit.body_presentation.sampled:
			return
	if not requested:
		requested = true
		_request_body.rpc_id(1)
	if expected_serial < 0 or actor.body_presentation.accepted_event < expected_serial:
		return
	if expected_npc_serial < 0 or npc.body_presentation.accepted_event < expected_npc_serial:
		return
	if npc.body_presentation.presented_shot < expected_npc_serial:
		return
	if expected_companions.is_empty() or clone_fixture.body_presentation.accepted_event < int(expected_companions.clone_serial):
		return
	if clone_fixture.body_presentation.presented_shot < int(expected_companions.clone_serial):
		return
	if artillery_fixture.body_presentation.presented_shot < int(expected_companions.artillery_serial):
		return
	for form: Dictionary in clone_fixture.body.forms.values():
		if int(form.weaponSequences.light.index) < 0:
			return
	for unit: BattleUnit in [tower, base_fixture]:
		if not expected_statics.has(unit.entity_id) or unit.body_presentation.accepted_event < int(expected_statics[unit.entity_id].serial):
			return
		if unit.body_presentation.presented_shot < int(expected_statics[unit.entity_id].serial):
			return
	if not verified:
		var arc := _artillery_pitch()
		if arc.is_empty() or not is_finite(float(arc.get("aim", arc.get("v", NAN)))):
			_fail("Transported howitzer shots must aim their actual handheld or mechanical barrel")
			return
		if _indices(actor) != expected_indices:
			_fail("Distinct same-clock network shots must advance both morph owners")
			return
		var before := _indices(actor)
		var clone_before := _indices(clone_fixture)
		if civilian_fixture.body.profile.appearance != expected_companions.civilian or not hyper_fixture.body.forms.is_empty() or kami_fixture.body.forms.is_empty():
			_fail("Civilian identity and carrier chassis/rig binding changed in transit")
			return
		if not hyper_fixture.body_presentation.carrier_motion.sampled or not kami_fixture.body_presentation.carrier_motion.sampled:
			_fail("Carrier attitude must advance on the native presented body")
			return
		var npc_index := npc.body.npc_muzzle_index
		if npc_index != expected_npc_muzzle or _npc_attacks() != expected_npc_attacks or npc.body.motion.values.is_empty():
			_fail("Live NPC body must preserve transported barrel and recoil events while driving its captured rig")
			return
		for unit: BattleUnit in [tower, base_fixture]:
			var expected: Dictionary = expected_statics[unit.entity_id]
			if not unit.body.profile["static"] or absf(float(unit.rotation.y) + float(unit.body.rotation.y)) > .00001 or unit.body.npc_muzzle_index != int(expected.muzzle) or _attack_flags(unit) != expected.attacks:
				_fail("Static body binding must preserve independent mounts without rotating the building")
				return
		for gun: int in expected_statics[base_fixture.entity_id].aim:
			var wanted: Vector3 = expected_statics[base_fixture.entity_id].aim[gun]
			var aim: Dictionary = base_fixture.body_presentation.entity.get("_gunAim", {}).get(gun, {})
			if aim.is_empty() or Vector3(aim.x, aim.y, aim.z).distance_to(wanted) > .00001:
				_fail("Each base gun must retain its own transported target")
				return
		var effect_count := simulation.world.combat_effects.effects.size()
		var arc_before := arc.duplicate()
		simulation.receive_body_events(replay, BodyPresentation.time_now())
		for event: Dictionary in replay:
			if event.type == "shot":
				simulation.present_shot(event)
		if simulation.world.combat_effects.effects.size() != effect_count:
			_fail("Immediate/snapshot replay must not allocate another NPC discharge or impact")
			return
		if _artillery_pitch() != arc_before:
			_fail("Replayed artillery events must not change the barrel angle or restart its hold")
			return
		if _indices(actor) != before or _indices(clone_fixture) != clone_before or npc.body.npc_muzzle_index != npc_index:
			_fail("Replayed body transport events advanced an emitter twice")
			return
		for unit: BattleUnit in [tower, base_fixture]:
			if unit.body.npc_muzzle_index != int(expected_statics[unit.entity_id].muzzle):
				_fail("Replayed static shot advanced a barrel twice")
				return
		verified = true
		_expand_body.rpc_id(1)
	if verified and not remote_verified and not remote_report.is_empty():
		if screen_report.is_empty() or splat_overlay == null or splat_overlay.last_serial < int(screen_report.blood_serial):
			return
		if death_report.is_empty() or presentation_frame.last_serial < int(death_report.death_serial):
			return
		if int(simulation.hero_report_serials.get(actor.entity_id, -1)) < int(remote_report.body_serial):
			return
		if not actor.remote_burst_driven:
			_fail("Transported hero reports must use remote source dispatch")
			return
		var effects := simulation.world.combat_effects.effects.size()
		var pending := simulation.remote_bursts.pending.size()
		var glass_sequence := splat_overlay.state.sequence
		if glass_sequence != 1 or float(screen_report.amount) != 30:
			_fail("Authority must merge same-attacker losses into one transported cockpit spray")
			return
		var poses: Array = []
		for unit: BattleUnit in [actor, clone_fixture]:
			poses.append(unit.body_presentation.entity.get("fireFx"))
		simulation.receive_body_events([remote_report], BodyPresentation.time_now())
		simulation.present_world_events([remote_report])
		simulation.present_world_events([screen_report])
		var stop_remaining := presentation_frame.remaining
		var stop_pending := presentation_frame.pending.size()
		simulation.present_world_events([death_report])
		if presentation_frame.remaining != stop_remaining or presentation_frame.pending.size() != stop_pending:
			_fail("Transported death replay renewed a native presentation stop")
			return
		if splat_overlay.state.sequence != glass_sequence:
			_fail("Snapshot replay created another native glass spray")
			return
		if simulation.world.combat_effects.effects.size() != effects or simulation.remote_bursts.pending.size() != pending:
			_fail("Transport replay allocated another remote discharge or burst callback")
			return
		for index in range(2):
			var unit: BattleUnit = [actor, clone_fixture][index]
			if not is_same(unit.body_presentation.entity.get("fireFx"), poses[index]):
				_fail("Transport replay restarted an owner or same-pilot clone fire pose")
				return
		remote_verified = true
	if remote_verified and actor.body.form == "air" and actor.body.morph.m > .5 and BodyReferenceMotion.phase(actor.body.forms.air.shield) > .2:
		if actor.model != actor.body or actor.body.motion.values.is_empty() or not is_same(actor.body.forms.ground.shield.state, actor.body.forms.air.shield.state):
			_fail("Live remote hero must bind the captured rig, locomotion and shared shield state")
			return
		print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
		print("NETWORK_BODY_PASS body=true npc=true artillery=true tower=true base=true clone=true kami=true hyper=true civilian=true remote=true glass=true hitstop=true events=true replay=true morph=true shield=true resources=true")
		Session.stop()
		get_tree().quit()

func _server_step() -> void:
	if simulation == null or actor != null:
		return
	var viewer: BattleUnit
	for unit: BattleUnit in simulation.pilots.values():
		if unit.peer_id > 1:
			viewer = unit
	if viewer == null:
		return
	simulation.set_physics_process(false)
	var character := ""
	for key: String in Content.heroes:
		if Content.heroes[key].kind == "morph" and Content.heroes[key].side == viewer.side:
			character = key
			break
	if character.is_empty():
		_fail("Body transport fixture requires an original same-faction morph pilot")
		return
	actor = simulation.spawn({"character": character, "kind": Content.heroes[character].kind, "side": viewer.side,
		"peer": -99071, "position": viewer.position + Vector3(5, 0, 0), "special": {"body_fixture": true}})
	remote_actor = actor.entity_id
	npc = simulation.spawn({"kind": "tank", "side": viewer.side, "position": viewer.position + Vector3(-5, 0, 0),
		"special": {"npc_body_fixture": true}})
	artillery_fixture = simulation.spawn({"kind": "howitzer", "side": viewer.side, "position": viewer.position + Vector3(-12, 0, 0),
		"special": {"artillery_body_fixture": true}})
	tower = simulation.spawn({"kind": "tower", "side": viewer.side, "position": viewer.position + Vector3(20, 0, 0),
		"special": {"static_body_fixture": "tower"}})
	base_fixture = simulation.spawn({"kind": "base", "side": viewer.side, "position": viewer.position + Vector3(-30, 0, 0),
		"special": {"static_body_fixture": "base"}})
	clone_fixture = simulation.spawn({"character": character, "kind": actor.kind, "side": viewer.side,
		"peer": actor.peer_id, "position": viewer.position + Vector3(8, 0, 0),
		"special": {"role": "clone", "owner_id": actor.entity_id, "companion_body_fixture": "clone"}})
	kami_fixture = simulation.spawn({"kind": "kami", "side": viewer.side, "yaw": 1.2, "position": viewer.position + Vector3(10, 8, 0),
		"special": {"role": "carrier", "model_key": "%s_%s_kami" % [viewer.side.to_lower(), character],
			"hp": Content.balance.carrier.hp.kami, "companion_body_fixture": "kami"}})
	hyper_fixture = simulation.spawn({"kind": "hyper", "side": viewer.side, "yaw": -.8, "position": viewer.position + Vector3(-10, 10, 0),
		"special": {"role": "carrier", "model_key": viewer.side.to_lower() + "_hyper",
			"hp": Content.balance.carrier.hp.hyper, "companion_body_fixture": "hyper"}})
	civilian_fixture = simulation._spawn_civilian(viewer.side, false, 13, {"x": viewer.position.x + 12, "z": viewer.position.z})
	civilian_fixture.special.companion_body_fixture = "civilian"
	fixture_peer = viewer.peer_id
	_fixture_roster.rpc_id(Session.seats.transport_for(fixture_peer), {"actor": actor.entity_id, "npc": npc.entity_id, "artillery": artillery_fixture.entity_id,
		"tower": tower.entity_id, "base": base_fixture.entity_id, "clone": clone_fixture.entity_id, "kami": kami_fixture.entity_id,
		"hyper": hyper_fixture.entity_id, "civilian": civilian_fixture.entity_id})
	simulation.apply_presentation_view(simulation.snapshot(fixture_peer))
	frozen_resources = _resources()

@rpc("authority", "call_remote", "reliable")
func _fixture_roster(ids: Dictionary) -> void:
	fixture_ids = ids

@rpc("any_peer", "call_remote", "reliable")
func _request_body() -> void:
	if not Session.dedicated or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer or actor == null:
		return
	var delivered: Array = []
	for slot: String in ["light", "light", "heavy"]:
		var event := {"type": "weapon_fire", "actor": actor.entity_id, "slot": slot, "side": actor.side, "clock": simulation.clock}
		simulation._emit_body_event(event)
		delivered.append(event)
	var hero_serial := simulation.body_event_serial
	for index in range(2):
		var event := {"type": "shot", "actor": npc.entity_id, "start": npc.eye(), "end": actor.eye(), "side": npc.side}
		simulation._emit_body_event(event)
		delivered.append(event)
	var npc_serial := simulation.body_event_serial
	var clone_event := {"type": "shot", "actor": clone_fixture.entity_id, "kind": clone_fixture.kind,
		"start": clone_fixture.position, "end": actor.eye(), "side": clone_fixture.side, "companion": true}
	simulation._emit_body_event(clone_event)
	delivered.append(clone_event)
	var companions := {"clone_serial": simulation.body_event_serial, "civilian": civilian_fixture.body.profile.appearance}
	var artillery_event := {"type": "shot", "actor": artillery_fixture.entity_id, "kind": artillery_fixture.kind,
		"start": artillery_fixture.eye(), "end": actor.eye() + Vector3(80, 0, -40), "side": artillery_fixture.side}
	simulation._emit_body_event(artillery_event)
	delivered.append(artillery_event)
	companions.artillery_serial = simulation.body_event_serial
	var statics: Dictionary = {}
	for unit: BattleUnit in [tower, base_fixture]:
		var aims: Dictionary = {}
		for gun in range(2):
			var point := actor.global_position + Vector3((-4 if gun == 0 else 4), 30 * (gun + 1), 10)
			var event := {"type": "shot", "actor": unit.entity_id, "kind": unit.kind,
				"start": unit.eye(), "end": point, "gun": gun, "side": unit.side}
			simulation._emit_body_event(event)
			delivered.append(event)
			aims[gun] = point
		statics[unit.entity_id] = {"serial": simulation.body_event_serial, "muzzle": unit.body.npc_muzzle_index,
			"attacks": _attack_flags(unit), "aim": aims}
	if _resources() != frozen_resources:
		_fail("Presentation events changed authority resources or combat RNG")
		return
	for event: Dictionary in delivered:
		simulation.events.erase(event)
	_expect_body.rpc_id(Session.seats.transport_for(fixture_peer), hero_serial, _indices(actor), delivered,
		npc_serial, npc.body.npc_muzzle_index, _npc_attacks(), statics, companions)

@rpc("authority", "call_remote", "reliable")
func _expect_body(serial: int, indices: Dictionary, delivered: Array, npc_serial: int, npc_muzzle: int, npc_attacks: Array, statics: Dictionary, companions: Dictionary) -> void:
	expected_serial = serial
	expected_indices = indices
	replay = delivered
	expected_npc_serial = npc_serial
	expected_npc_muzzle = npc_muzzle
	expected_npc_attacks = npc_attacks
	expected_statics = statics
	expected_companions = companions

@rpc("any_peer", "call_remote", "reliable")
func _expand_body() -> void:
	if not Session.dedicated or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer or actor == null:
		return
	var definition := Content.weapon(actor.character, "light", 1)
	var report := {"type": "shot", "hero_report": true, "actor": actor.entity_id, "slot": "light", "side": actor.side,
		"start": actor.eye(), "end": actor.eye() + Vector3(0, 0, 120), "hit": false,
		"direction": Vector3.FORWARD, "range": definition.range, "area": definition.area}
	simulation._emit_body_event(report)
	simulation.events.erase(report)
	if _resources() != frozen_resources:
		_fail("Remote presentation report changed authority resources or combat RNG")
		return
	var viewer: BattleUnit = simulation.pilots[fixture_peer]
	simulation._record_blood_hurt(viewer, actor, 10)
	simulation._record_blood_hurt(viewer, actor, 20)
	simulation.flush_blood_hurt()
	var sprays: Array = simulation.events.filter(func(event): return event.type == "screen_hurt" and int(event.peer) == fixture_peer)
	if sprays.size() != 1 or _resources() != frozen_resources:
		_fail("Merged cockpit presentation changed authority resources or emitted duplicate source records")
		return
	simulation._report_death(tower)
	var death: Dictionary = simulation.events.back()
	if _resources() != frozen_resources:
		_fail("Death presentation report changed authority resources or combat RNG")
		return
	_expect_remote.rpc_id(Session.seats.transport_for(fixture_peer), report, sprays[0], death)
	actor.position.y += float(Content.constants.MORPH.GROUND_Y) + 1
	actor.flying = true
	actor.defending = true
	actor.status.shield_expand_until = simulation.clock + 3

@rpc("authority", "call_remote", "reliable")
func _expect_remote(report: Dictionary, spray: Dictionary, death: Dictionary) -> void:
	remote_report = report
	screen_report = spray
	death_report = death

func _resources() -> Array:
	return [actor.hp, actor.shield, actor.power, actor.ammo.duplicate(true), actor.money, actor.fire_serial,
		npc.hp, npc.shield, npc.power, npc.money, npc.npc_cooldown,
		artillery_fixture.hp, artillery_fixture.npc_cooldown,
		tower.hp, tower.npc_cooldown, base_fixture.hp, base_fixture.gun_cooldowns.duplicate(),
		clone_fixture.hp, clone_fixture.shield, clone_fixture.ammo.duplicate(true), kami_fixture.hp, hyper_fixture.hp, civilian_fixture.hp,
		simulation.rng.state, simulation.projectile_rng.state]

func _npc_attacks() -> Array:
	return _attack_flags(npc)

func _artillery_pitch() -> Dictionary:
	var gun: Variant = artillery_fixture.body.forms.get(artillery_fixture.body.form, {}).get("gunR")
	return {"aim": gun.aim} if gun is Dictionary else artillery_fixture.body_presentation.entity.get("_arcPitch", {}).duplicate()

func _attack_flags(unit: BattleUnit) -> Array:
	return unit.body.forms.ground.get("attacks", []).map(func(attack): return is_finite(float(attack.firedAt)))

func _indices(unit: BattleUnit) -> Dictionary:
	var indices: Dictionary = {}
	for form: String in unit.body.forms:
		indices[form] = {}
		for slot: String in unit.body.forms[form].weaponSequences:
			indices[form][slot] = unit.body.forms[form].weaponSequences[slot].index
	return indices

func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
