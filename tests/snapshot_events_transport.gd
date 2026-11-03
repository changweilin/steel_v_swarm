extends "res://tests/room_recovery_transport.gd"

const Cases = preload("res://tests/snapshot_events_suite.gd")
const CastCases = preload("res://tests/cast_events_suite.gd")
const FieldCases = preload("res://tests/field_events_suite.gd")
const WindowCases = preload("res://tests/room_snapshot_window_suite.gd")

class BackpressureProbe extends WireProbe:
	func snapshot(peer: int = 0, _side: Variant = null) -> Dictionary:
		return {"recipient": peer, "events": events.duplicate(true), "over": over}

var recipients: Dictionary = {}
var replicas: Dictionary = {}
var body_reports: Dictionary = {}

func _run() -> void:
	result_prefix = "SNAPSHOT_EVENTS_TRANSPORT_RESULT"
	var port := 19870
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--websocket":
			transport = "websocket"
		if argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", Content.fixture_sections_for(Cases))
	authority = _session("Authority")
	authority.dedicated = true
	var error: Error = authority.host({"team_size": 1, "env": {"season": "summer", "time": "day", "weather": "clear"}}, port, transport)
	_check(error == OK, "Open real snapshot authority transport")
	if error != OK:
		_finish()
		return
	var address := "ws://127.0.0.1:%d" % port if transport == "websocket" else "127.0.0.1"
	for side: String in ["", "STEEL", "SWARM"]:
		var recipient := _session("Observer" if side.is_empty() else side)
		recipients[side] = recipient
		body_reports[side] = []
		recipient.body_event_received.connect(func(event): body_reports[side].append(event.duplicate(true)))
		recipient.chosen_side = side
		recipient.chosen_character = "s01" if side == "SWARM" else "t01"
		recipient.battle_started.connect(func(_settings, _players):
			replicas[side] = _probe(recipient)
			recipient.launch_announced = true)
		error = recipient.join(address, port, "spectator" if side.is_empty() else "player")
		_check(error == OK, "Open snapshot recipient transport")
		if error != OK or not await _wait_until(func(): return recipient.local_player_id > 1 and not recipient.roster.is_empty(), "Snapshot recipient admitted with its source vision role"):
			_finish()
			return
	authority.started = true
	authority.phase = "game"
	authority.round_id = 7
	for recipient: Node in recipients.values():
		authority._begin.rpc_id(authority.seats.transport_for(recipient.local_player_id), authority.config, authority.roster, "game", 7)
	if not await _wait_until(func(): return replicas.size() == 3, "Snapshot command gates open for both factions and observer"):
		_finish()
		return
	for item: Dictionary in fixtures.snapshotEvents:
		var simulation := Cases.context(self, item)
		authority.simulation = simulation
		for expected: Dictionary in item.snapshots:
			var side: String = "" if expected.side == null else expected.side
			var recipient: Node = recipients[side]
			var replica: WireProbe = replicas[side]
			var count := replica.received_snapshots.size()
			var player: int = recipient.local_player_id
			authority._snapshot.rpc_id(authority.seats.transport_for(player), authority._state_for(player))
			if not await _wait_until(func(): return replica.received_snapshots.size() == count + 1, "Current source event frame arrives through native reliable snapshot channel"):
				_finish()
				return
			var packet: Dictionary = replica.received_snapshots[-1]
			_check(packet._match == 7 and packet.vision_side == side, "Recipient keeps its match and vision identity")
			Cases.check_packet(self, packet, expected)
		authority.simulation = null
		simulation.free()
	await _cast_cases()
	await _field_cases()
	WindowCases.run(self)
	await _backpressure_case()
	_finish.call_deferred()

# Ticks inside one frame outrun every acknowledgement, which is the slow-client case
# without relying on machine timing. The final tick must survive a closed window.
func _backpressure_case() -> void:
	var probe := BackpressureProbe.new()
	authority.add_child(probe)
	probe.set_physics_process(false)
	authority.simulation = probe
	authority.launch_announced = true
	authority.snapshot_timer.start()
	authority.snapshot_timer.paused = true
	for side: String in recipients:
		replicas[side].received_snapshots.clear()
	var limit := RoomSnapshotWindow.MAXIMUM_UNACKNOWLEDGED
	var delivered := func(count: int) -> bool:
		return recipients.keys().all(func(side): return replicas[side].received_snapshots.size() >= count)
	var acknowledged := func() -> bool:
		return recipients.values().all(func(recipient):
			return not authority.snapshot_window.is_full(authority.seats.transport_for(recipient.local_player_id)) and authority.snapshot_window.unacknowledged[authority.seats.transport_for(recipient.local_player_id)].is_empty())
	var serial_before: int = probe.snapshot_serial
	for index in limit + 3:
		probe.events.append({"type": "wave", "n": index})
		authority._broadcast_state()
	_check(probe.events.is_empty(), "Authority event frames still clear on every tick")
	await _wait_until(delivered.bind(limit), "Burst delivers only the bounded snapshot window")
	await _wait_until(acknowledged, "Delivered snapshots return their credit")
	for side: String in recipients:
		_check(replicas[side].received_snapshots.size() == limit, "A full window defers surplus ticks instead of queueing them")
	probe.events.append({"type": "wave", "n": limit + 3})
	authority._broadcast_state()
	await _wait_until(delivered.bind(limit + 1), "Catch-up snapshot follows returned credit")
	var expected: Array = range(limit + 4)
	for side: String in recipients:
		var reports: Array = []
		var serials: Array = []
		for packet: Dictionary in replicas[side].received_snapshots:
			serials.append(packet._serial)
			for event: Dictionary in packet.events:
				reports.append(int(event.n))
		_check(reports == expected, "Deferred reports arrive once in publication order")
		var ordered: bool = serials[0] > serial_before
		for index in range(1, serials.size()):
			ordered = ordered and serials[index] > serials[index - 1]
		_check(ordered, "Recipient serials stay strictly increasing across deferred ticks")
	await _wait_until(acknowledged, "Catch-up snapshot returns its credit")
	for side: String in recipients:
		replicas[side].received_snapshots.clear()
	for index in limit:
		authority._broadcast_state()
	probe.over = true
	probe.events.append({"type": "wave", "n": 100})
	authority._broadcast_state()
	_check(authority.snapshot_timer.is_stopped(), "Final tick still stops the broadcast timer")
	var finished := func() -> bool:
		return recipients.keys().all(func(side):
			var packets: Array = replicas[side].received_snapshots
			return not packets.is_empty() and packets[-1].over)
	await _wait_until(finished, "A deferred recipient still receives the final state")
	await _wait_until(acknowledged, "Final snapshot returns its credit")
	for side: String in recipients:
		var packets: Array = replicas[side].received_snapshots
		_check(packets.size() == limit + 1 and packets[-1].events.map(func(event): return int(event.n)) == [100], "The final state and its reports reach each recipient exactly once")
	authority.simulation = null
	probe.free()

func _field_cases() -> void:
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", Content.fixture_sections_for(FieldCases))
	for item: Dictionary in fixtures.fieldEvents:
		var simulation := FieldCases.context(self, item)
		authority.simulation = simulation
		for frame_index in item.frames.size():
			FieldCases.advance(simulation, item, frame_index)
			var frame: Dictionary = item.frames[frame_index]
			FieldCases.check_lifecycle(self, simulation, frame)
			var expected_packets := {"": [], "STEEL": [], "SWARM": []}
			for side: String in recipients:
				replicas[side].received_snapshots.clear()
			simulation.events.append({"type": "flashbang_detonate", "actor": 0, "only_peer": -99, "position": Vector3.ZERO, "radius": 1.0})
			for expected: Dictionary in frame.snapshots:
				var side: String = "" if expected.side == null else expected.side
				expected_packets[side].append(expected)
				var player: int = recipients[side].local_player_id
				authority._snapshot.rpc_id(authority.seats.transport_for(player), authority._state_for(player))
			if not await _wait_until(func(): return recipients.keys().all(func(side): return replicas[side].received_snapshots.size() == expected_packets[side].size()), "Original field lifecycle reports arrive through native reliable snapshots"):
				authority.simulation = null
				FieldCases.dispose(simulation)
				return
			for side: String in recipients:
				for index in expected_packets[side].size():
					var packet: Dictionary = replicas[side].received_snapshots[index]
					_check(packet._match == 7 and packet.vision_side == side, "Field report recipient and match identity")
					_check(packet.events.all(func(event): return not event.has("only_peer")), "Public field routing cannot expose private notices over the network")
					FieldCases.check_packet(self, packet, expected_packets[side][index])
		authority.simulation = null
		FieldCases.dispose(simulation)

func _cast_cases() -> void:
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", Content.fixture_sections_for(CastCases))
	for item: Dictionary in fixtures.castEvents:
		var simulation := CastCases.context(self, item)
		authority.simulation = simulation
		var expected_packets := {"": [], "STEEL": [], "SWARM": []}
		for side: String in recipients:
			replicas[side].received_snapshots.clear()
			body_reports[side].clear()
		for expected: Dictionary in item.snapshots:
			var side: String = "" if expected.side == null else expected.side
			expected_packets[side].append(expected)
			var player: int = recipients[side].local_player_id
			authority._snapshot.rpc_id(authority.seats.transport_for(player), authority._state_for(player))
		var body_events: Array = simulation.events.filter(func(event): return event.has("body_serial"))
		for event: Dictionary in body_events:
			authority.broadcast_body_event(event)
		var weapon := {"type": "weapon_fire", "actor": 72, "body_serial": 100000, "empty_heavy": true, "aim_request": 99}
		authority.broadcast_body_event(weapon)
		var private: Dictionary = body_events[0].duplicate(true)
		private.only_peer = recipients.STEEL.local_player_id
		authority.broadcast_body_event(private)
		# Same-channel final report is a barrier for negative privacy/stale checks.
		for recipient: Node in recipients.values():
			authority._body_event.rpc_id(authority.seats.transport_for(recipient.local_player_id), body_events[0], 6)
		authority.broadcast_body_event(body_events[0])
		var expected_counts := {}
		for side: String in recipients:
			var weapon_visible: bool = not item.removed and (side.is_empty() or side == item.side or item.pulse)
			expected_counts[side] = body_events.size() + 1 + int(weapon_visible) + int(side == "STEEL")
		if not await _wait_until(func():
			return recipients.keys().all(func(side): return replicas[side].received_snapshots.size() == expected_packets[side].size() and body_reports[side].size() == expected_counts[side]),
			"Original cast snapshots and reliable reports arrive for each recipient without stale/private leakage"):
			authority.simulation = null
			CastCases.dispose(simulation)
			return
		for side: String in recipients:
			for index in expected_packets[side].size():
				var packet: Dictionary = replicas[side].received_snapshots[index]
				_check(packet._match == 7 and packet.vision_side == side, "Cast snapshots retain round and recipient identity")
				CastCases.check_packet(self, packet, expected_packets[side][index])
			for index in body_events.size():
				CastCases.check_event(self, body_reports[side][index], item.events[index])
			for event: Dictionary in body_reports[side]:
				_check(not event.has("only_peer") or side == "STEEL", "Public cast fast path preserves explicit owner-only delivery")
				if event.type == "weapon_fire":
					_check(not event.has("empty_heavy") and not event.has("aim_request"), "Nonowner weapon reports retain private-field sanitization")
		authority.simulation = null
		CastCases.dispose(simulation)

func _finish() -> void:
	for recipient: Node in recipients.values():
		if is_instance_valid(recipient):
			recipient.stop()
	super._finish()
