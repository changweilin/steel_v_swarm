extends Node

# Transport acceptance only: probes record delivery at the authority seam. They
# do not construct terrain, settle combat or certify populated-match readiness.
const SessionScript = preload("res://scripts/session.gd")

class WireProbe extends BattleSimulation:
	var received: Array = []
	var received_snapshots: Array = []
	func submit_input(peer: int, command: Dictionary) -> void:
		received.append({"peer": peer, "kind": "input", "n": int(command.yaw)})
	func action(peer: int, _type: String, argument: String = "") -> void:
		received.append({"peer": peer, "kind": "action", "n": int(argument)})
	func cast_player_at(peer: int, _slot: String, point: Vector2) -> bool:
		received.append({"peer": peer, "kind": "cast", "n": int(point.x)})
		return true
	func snapshot(peer: int = 0, _side: Variant = null) -> Dictionary:
		return {"recipient": peer, "events": []}
	func apply_snapshot(data: Dictionary) -> bool:
		received_snapshots.append(data.duplicate(true))
		return true

var authority: Node
var client: Node
var authority_probe: WireProbe
var client_probe: WireProbe
var branches: Array[Node] = []
var failures := 0
var assertions := 0
var begins := 0
var transport := "enet"
var result_prefix := "RECOVERY_TRANSPORT_RESULT"

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func _session(branch_name: String) -> Node:
	var branch := Node.new()
	branch.name = branch_name
	add_child(branch)
	branches.append(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var session := SessionScript.new()
	session.name = "Session"
	branch.add_child(session)
	return session

func _probe(session: Node) -> WireProbe:
	var probe := WireProbe.new()
	session.get_parent().add_child(probe)
	probe.set_physics_process(false)
	session.simulation = probe
	return probe

func _wait_until(predicate: Callable, description: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var complete: bool = predicate.call()
	_check(complete, description)
	return complete

func _run() -> void:
	var port := 19870
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--websocket":
			transport = "websocket"
		if argument.begins_with("--port="):
			port = argument.trim_prefix("--port=").to_int()
	authority = _session("Authority")
	client = _session("Client")
	authority.dedicated = true
	var error: Error = authority.host({"team_size": 1, "env": {"season": "summer", "time": "day", "weather": "clear"}}, port, transport)
	_check(error == OK, "Open real authority transport")
	if error != OK:
		_finish()
		return
	var address := "ws://127.0.0.1:%d" % port if transport == "websocket" else "127.0.0.1"
	error = client.join(address, port)
	_check(error == OK, "Open real client transport")
	if error != OK:
		_finish()
		return
	if not await _wait_until(func(): return client.local_player_id > 1 and not client.roster.is_empty(), "Initial logical seat admitted"):
		_finish()
		return
	var player: int = client.local_player_id
	var token: String = client.resume_token
	var route: int = authority.seats.transport_for(player)
	var registry: RoomSeats = authority.seats
	authority_probe = _probe(authority)
	client.battle_started.connect(func(_settings, _players):
		begins += 1
		client_probe = _probe(client)
		# Open only the command gate; no world-preparation success is asserted.
		client.launch_announced = true)
	authority.started = true
	authority.phase = "game"
	authority.round_id = 7
	authority._begin.rpc_id(route, authority.config, authority.roster, "game", 7)
	if not await _wait_until(func(): return client.started and client.launch_announced, "Initial authority begin received"):
		_finish()
		return
	client.act("aim", "-1")
	if not await _wait_until(func(): return authority_probe.received.size() == 1, "Live command reaches the logical seat"):
		_finish()
		return
	_check(authority_probe.received == [{"peer": player, "kind": "action", "n": -1}], "Physical route never replaces logical command identity")
	authority_probe.received.clear()
	client._server_disconnected()
	if not await _wait_until(func(): return not registry.members[player].connected, "Authority holds disconnected seat"):
		_finish()
		return
	var retained_probe := client_probe
	var count: int = int(Content.balance.rooms.queueCapacity) + 5
	var expected: Array = []
	for index in count:
		var kind: String = ["action", "cast", "input"][index % 3]
		if kind == "action":
			client.act("aim", str(index))
		elif kind == "cast":
			client.cast_at("def", Vector2(index, -index))
		else:
			var command := {"yaw": float(index), "move": Vector2.ZERO}
			client.command(command)
			command.yaw = -999.0
		if index >= 5:
			expected.append({"peer": player, "kind": kind, "n": index})
	_check(authority_probe.received.is_empty() and client.command_queue.pending.size() == count - 5, "Disconnected mixed commands retain only the source latest-N budget")
	if not await _wait_until(func(): return authority_probe.received.size() >= expected.size(), "Reclaimed route flushes queued commands"):
		_finish()
		return
	_check(authority_probe.received == expected, "Real transport preserves bounded FIFO, immutable input and once-only replay")
	_check(client.local_player_id == player and client.resume_token == token and client_probe == retained_probe and begins == 1, "Same-process recovery retains seat, credential and replica")
	_check(authority.seats == registry and registry.player_for(route) == 0 and registry.transport_for(player) != route, "Recovery revokes the old physical route")
	if not await _wait_until(func(): return not client_probe.received_snapshots.is_empty(), "Recovery snapshot follows seat reclaim"):
		_finish()
		return
	_check(client_probe.received_snapshots[-1].recipient == player and client_probe.received_snapshots[-1]._match == 7, "Recovered snapshot uses logical recipient and current match")
	# All three combat RPCs use reliable channel 2. A current sentinel is a wire
	# barrier for the stale calls preceding it; no arbitrary sleep proves absence.
	client._receive_input.rpc_id(1, {"yaw": -2.0}, 6)
	client._action.rpc_id(1, "aim", "-3", 6)
	client._cast_at.rpc_id(1, "def", Vector2(-4, 0), 6)
	client.act("aim", "999")
	expected.append({"peer": player, "kind": "action", "n": 999})
	if not await _wait_until(func(): return authority_probe.received.size() >= expected.size(), "Current command follows stale-round packets"):
		_finish()
		return
	_check(authority_probe.received == expected, "Old-round input, action and cast never reach settlement")
	client._server_disconnected()
	client.act("aim", "-10")
	client.cast_at("def", Vector2(-11, 0))
	if not await _wait_until(func(): return not registry.members[player].connected, "Second disconnect is held before authority returns to room"):
		_finish()
		return
	authority.return_to_room()
	if not await _wait_until(func(): return client.round_id == 8 and not client.reconnecting, "Disconnected client recovers into the returned room"):
		_finish()
		return
	_check(client.phase == "room" and not client.started and client.simulation == null and client.command_queue.pending.is_empty(), "Room return cancels the retained replica and old-round commands")
	_check(client.local_player_id == player and client.resume_token == token and authority_probe.received == expected, "Returning recovery preserves credentials without replaying the old queue")
	authority.simulation = authority_probe
	authority.started = true
	authority.phase = "game"
	authority._begin.rpc_id(registry.transport_for(player), authority.config, authority.roster, "game", 8)
	if not await _wait_until(func(): return client.started and client.launch_announced, "New-round command gate opens after begin"):
		_finish()
		return
	_check(begins == 2 and client_probe != retained_probe, "New round creates exactly one new replica")
	client._receive_input.rpc_id(1, {"yaw": -12.0}, 7)
	client._action.rpc_id(1, "aim", "-13", 7)
	client._cast_at.rpc_id(1, "def", Vector2(-14, 0), 7)
	client.act("aim", "1000")
	expected.append({"peer": player, "kind": "action", "n": 1000})
	if not await _wait_until(func(): return authority_probe.received.size() >= expected.size(), "New round accepts its current sentinel"):
		_finish()
		return
	_check(authority_probe.received == expected, "Recovered rematch rejects all old-round combat routes")
	await client.leave()
	_check(not client.active and client.credential_store.record.is_empty() and client.command_queue.pending.is_empty(), "Explicit leave is acknowledged and clears client recovery")
	_check(authority.active and not authority.started and authority.seats.members.is_empty(), "Final-human leave clears the room while preserving its listener")
	_finish.call_deferred()

func _finish() -> void:
	for session: Node in [client, authority]:
		if is_instance_valid(session):
			session.stop()
	for branch: Node in branches:
		var path := branch.get_path()
		branch.free()
		get_tree().set_multiplayer(null, path)
	print(result_prefix, " transport=", transport, " assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
