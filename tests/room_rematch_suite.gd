extends RefCounted

const SessionScript = preload("res://scripts/session.gd")
const Helper = preload("res://tests/status_suite.gd")

class RollSession extends SessionScript:
	var fixture_roll := 0.0
	func _room_roll() -> float:
		return fixture_roll

class PacketProbe extends BattleSimulation:
	var snapshots := 0
	var body_packets := 0
	func apply_snapshot(_data: Dictionary) -> bool:
		snapshots += 1
		return true
	func receive_body_events(_received: Array, _now: float) -> void:
		body_packets += 1

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("roomRematchPrograms"):
		h._check(false, "Regenerate original return-to-room references")
		return
	for program: Dictionary in fixtures.roomRematchPrograms:
		var session := RollSession.new()
		h.add_child(session)
		session.dedicated = true
		session.active = true
		session.config = {"team_size": 2, "ctrl": Controls.rules.defaultMode, "architecture_seed": int(program.seed), "env": {"season": "winter"}}
		for index in program.definitions.size():
			var definition: Dictionary = program.definitions[index]
			var player: int = 42 + index
			session.seats.add(player, 1000 + index, "fixture-" + str(index), definition.side if definition.side != null else "", definition.mode, definition.character if definition.character != null else "")
			session.seats.set_ready(player, true)
			session.seats.set_loaded(player)
			if not definition.connected:
				session.seats.detach(1000 + index, true)
			session.roster.append({"peer": player, "side": session.seats.members[player].side, "character": session.seats.members[player].character, "mode": definition.mode, "bot": false})
		session.seats.bots[-1] = {"side": "STEEL", "character": "t02", "name": "fixture-bot"}
		session.phase = program.phase
		session.started = program.phase != "room"
		var registry: RoomSeats = session.seats
		var original_members: Dictionary = registry.members.duplicate(true)
		var original_bots: Dictionary = registry.bots.duplicate(true)
		var source_has_battle := true
		for frame: Dictionary in program.frames:
			session.fixture_roll = float(frame.roll)
			var battle := PacketProbe.new()
			h.add_child(battle)
			battle.set_physics_process(false)
			session.simulation = battle if source_has_battle else null
			session.world_prepared = true
			session.launch_announced = true
			session.pending_snapshot = {"_match": session.round_id}
			session.local_command = {"fire": true}
			var previous_round: int = session.round_id
			var before := session.config.duplicate(true)
			session.local_player_id = 42 + int(frame.who)
			session.request_return_to_room()
			h._check(int(session.config.architecture_seed) == int(frame.config.architectureSeed), "Original rematch uint32 seed increment and wrap")
			h._check(bool(session.config.get("swapped", false)) == (frame.config.bases.SWARM[0] == 3), "Original cumulative side re-roll and strict half threshold")
			if int(frame.who) == 0 and source_has_battle:
				h._check(session.phase == frame.phase and not session.started and session.simulation == null and session.round_id == previous_round + 1, "Original host return ends battle while retaining room")
				h._check(session.snapshot_timer.is_stopped() and not session.world_prepared and not session.launch_announced and session.pending_snapshot.is_empty() and session.local_command.is_empty(), "Return cancels old preparation, snapshots and commands")
				for member: Dictionary in session.seats.members.values():
					h._check(not member.ready and not member.loaded, "Original all-member ready/loaded reset includes held and spectator seats")
			else:
				h._check(session.phase == frame.phase and session.round_id == previous_round and session.config == before, "Original non-host or absent battle cannot reroll the room")
			for player: int in registry.members:
				var actual: Dictionary = registry.members[player].duplicate(true)
				actual.ready = original_members[player].ready
				actual.loaded = original_members[player].loaded
				Helper.compare(h, actual, original_members[player], "Rematch retains logical identity, token, route, generation, role and connection state")
			h._check(session.seats == registry and registry.host_id == 42 and registry.bots == original_bots and session.config.env == {"season": "winter"}, "Original room host, bots and environment survive return")
			battle.free()
			session.simulation = null
			source_has_battle = bool(frame.hasBattle)
		session.free()
	_packet_isolation(h)

static func _packet_isolation(h: Node) -> void:
	var session := SessionScript.new()
	h.add_child(session)
	session.active = true
	session.started = true
	session.phase = "game"
	session.round_id = 9
	session.launch_announced = true
	var battle := PacketProbe.new()
	h.add_child(battle)
	battle.set_physics_process(false)
	session.simulation = battle
	session._snapshot({"_match": 7})
	session._body_event({}, 7)
	session._launch(7)
	session._loaded_player(7)
	h._check(battle.snapshots == 0 and battle.body_packets == 0 and session.pending_snapshot.is_empty(), "Old independent-channel packets cannot reach a new match")
	session._snapshot({"_match": 9})
	session._body_event({}, 9)
	h._check(battle.snapshots == 1 and battle.body_packets == 1, "Current match packets retain native snapshot/event delivery")
	session.reconnecting = true
	session._snapshot({"_match": 9})
	session._sync_lobby({}, [], 42, "room", 10)
	h._check(not session.started and not session.reconnecting and session.simulation == null and session.pending_snapshot.is_empty(), "Reattach to a returned room discards the retained battle")
	session._snapshot({"_match": 9})
	session._begin({}, [], "game", 9)
	h._check(session.phase == "room" and session.round_id == 10 and session.pending_snapshot.is_empty(), "Delayed previous-match begin and final snapshot cannot reopen the battle")
	session._snapshot({"_match": 12})
	session._sync_lobby({}, [], 42, "room", 11)
	h._check(int(session.pending_snapshot.get("_match", -1)) == 12, "Future reliable snapshot survives earlier room control messages")
	session._begin({}, [], "game", 12)
	session.simulation = battle
	session.world_prepared = true
	session._finish_local_launch()
	h._check(battle.snapshots == 2 and session.pending_snapshot.is_empty(), "Early next-match snapshot applies only after matching world preparation and launch")
	session.free()
	battle.free()
