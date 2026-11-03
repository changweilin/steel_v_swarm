extends Node

signal lobby_changed
signal battle_started(config: Dictionary, roster: Array)
signal battle_launched
signal state_received(state: Dictionary)
signal snapshot_heard
signal body_event_received(event: Dictionary)
signal status_changed(key: String)
signal stopped
signal room_cleared
signal room_returned
signal battle_failed(reason: String)

const WEBSOCKET_BUFFER_BYTES := 1 << 20
const ENET_THROTTLE_INTERVAL_MILLISECONDS := 5000
const ENET_THROTTLE_ACCELERATION := 2

var roster: Array = []
var config: Dictionary = {}
var simulation: BattleSimulation
var chosen_character := "t01"
var chosen_side := "STEEL"
var chosen_mode := "player"
var chosen_name := ""
var active := false
var started := false
var dedicated := false
var snapshot_timer: Timer
var join_timer: Timer
var local_command := {}
var room_random := RandomNumberGenerator.new()
var seats := RoomSeats.new()
var next_player_id := 2
var local_player_id := 1
var resume_token := ""
var resume_endpoint := ""
var connection_address := ""
var connection_port := 0
var reconnecting := false
var retry_failures := 0
var retry_timer: Timer
var pending_snapshot: Dictionary = {}
var closing_transport := false
var leaving := false
var remote_host_id := 0
var phase := "room"
var world_prepared := false
var launch_announced := false
var prepared_map: Dictionary = {}
var round_id := 0
var command_queue := RoomCommandQueue.new()
var snapshot_window := RoomSnapshotWindow.new()
var credential_store := RoomCredential.new()
var deployment := DeploymentPreferences.new()
var failure_reason := ""

func _ready() -> void:
	room_random.randomize()
	command_queue.capacity = int(Content.balance.get("rooms", {}).get("queueCapacity", 0))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_disconnected)
	snapshot_timer = Timer.new()
	snapshot_timer.wait_time = 0.125
	snapshot_timer.timeout.connect(_broadcast_state)
	add_child(snapshot_timer)
	join_timer = Timer.new()
	join_timer.one_shot = true
	join_timer.wait_time = 8.0
	join_timer.timeout.connect(func():
		if leaving:
			stop()
		elif active and (not started or reconnecting) and not is_authority():
			_connection_failed())
	add_child(join_timer)
	retry_timer = Timer.new()
	retry_timer.one_shot = true
	retry_timer.timeout.connect(_retry_connection)
	add_child(retry_timer)

func player_id() -> int:
	return local_player_id

func local_member() -> Dictionary:
	for player: Dictionary in roster:
		if int(player.peer) == local_player_id and not player.get("bot", false):
			return player
	return {}

func story_mode() -> bool:
	return config.has("campaign") and not config.get("quick_restart", false)

func fail_battle(reason: String) -> void:
	if not active or not failure_reason.is_empty():
		return
	if reason.is_empty():
		reason = "Battle preparation did not complete"
	if is_authority():
		for peer: int in _room_peers():
			_receive_failure.rpc_id(peer, reason, round_id)
	_receive_failure(reason, round_id)

@rpc("authority", "call_remote", "reliable")
func _receive_failure(reason: String, match_id: int) -> void:
	if not active or match_id != round_id or not failure_reason.is_empty() or reason.is_empty():
		return
	failure_reason = reason
	command_queue.clear()
	snapshot_timer.stop()
	if simulation != null:
		simulation.set_physics_process(false)
	battle_failed.emit(reason)

func _sync_local_selection() -> void:
	var player := local_member()
	if not player.is_empty():
		chosen_side = player.side
		chosen_character = player.character
		chosen_mode = player.get("mode", "player")
		chosen_name = player.get("name", chosen_name)

# A recovering client parks an OfflineMultiplayerPeer between attempts, whose
# unique ID is 1; it must never settle room or match state while detached.
func is_authority() -> bool:
	return multiplayer.is_server() and not reconnecting

func is_room_host() -> bool:
	if not active:
		return false
	var host_player := seats.host_id if is_authority() else remote_host_id
	return host_player > 0 and host_player == local_player_id

func _room_peers() -> Array[int]:
	var result: Array[int] = []
	for peer: int in multiplayer.get_peers():
		if seats.player_for(peer) > 0:
			result.append(peer)
	return result

static func retry_delay(rules: Dictionary, failures: int) -> float:
	return minf(float(rules.retryMaximumMilliseconds), float(rules.retryBaseMilliseconds) * pow(2, mini(failures, int(rules.retryExponentMaximum)))) / 1000.0

func _endpoint(address: String, port: int) -> String:
	return address if address.begins_with("ws://") or address.begins_with("wss://") else address + ":" + str(port)

func _room_roll() -> float:
	# Godot randf can include 1; source room selection requires an exclusive upper bound.
	return float(room_random.randi()) / 4294967296.0

func _close_transport() -> void:
	closing_transport = true
	command_queue.connected = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	closing_transport = false

func _schedule_retry() -> void:
	_close_transport()
	join_timer.stop()
	if not active or resume_token.is_empty():
		status_changed.emit("failed")
		stop()
		return
	reconnecting = true
	retry_timer.start(retry_delay(Content.balance.rooms, retry_failures))
	retry_failures += 1
	lobby_changed.emit()
	status_changed.emit("connecting")

func _connection_failed() -> void:
	if not active or closing_transport or not retry_timer.is_stopped():
		return
	if leaving:
		stop()
		return
	if reconnecting and not resume_token.is_empty():
		_schedule_retry()
	else:
		status_changed.emit("failed")
		stop()

func _server_disconnected() -> void:
	if not active or closing_transport or not retry_timer.is_stopped():
		return
	if leaving:
		stop()
		return
	if not resume_token.is_empty():
		reconnecting = true
		_schedule_retry()
	else:
		status_changed.emit("disconnected")
		stop()

func _retry_connection() -> void:
	if not active or not reconnecting:
		return
	if _open_transport(connection_address, connection_port) != OK:
		_schedule_retry()

func host(settings: Dictionary, port: int = 8620, transport: String = "offline") -> Error:
	if not Content.balance.get("rooms", {}).has("heroPools") or not Content.balance.get("rooms", {}).has("botNamePrefix") or not Content.balance.get("rooms", {}).has("names") or command_queue.capacity <= 0:
		return ERR_UNAVAILABLE
	if OS.has_feature("solo_web") and transport != "offline":
		return ERR_UNAVAILABLE
	stop()
	_clear_credential(true)
	chosen_mode = "player"
	config = settings.duplicate(true)
	var control_mode: String = settings.get("ctrl", Controls.pref)
	if config.has("campaign"):
		var selection: Dictionary = config.campaign
		if not settings.get("quick_restart", false):
			config = CampaignRules.settings(int(selection.get("index", -1)), selection.get("side", ""), selection.get("pilot", ""), bool(selection.get("swapped", false)))
		if config.is_empty() or not _recipe_worlds_available(config):
			return ERR_UNAVAILABLE
		if not settings.get("quick_restart", false):
			chosen_side = config.campaign.side
			chosen_character = config.campaign.pilot
	config["quick_restart"] = bool(settings.get("quick_restart", false))
	if config.quick_restart and settings.has("env"):
		if not settings.env is Dictionary:
			return ERR_INVALID_PARAMETER
		config["env"] = settings.env.duplicate(true)
	if not settings.get("room_name", config.get("room_name", "")) is String:
		return ERR_INVALID_PARAMETER
	config["room_name"] = RoomMetadata.sanitize(settings.get("room_name", config.get("room_name", "")))
	config["is_public"] = RoomMetadata.public_at_creation(settings.get("is_public", config.get("is_public", true)))
	config["ctrl"] = control_mode if control_mode in Controls.rules.get("modeKeys", []) else Controls.pref
	config["super"] = bool(config.get("super", false)) and not config.has("campaign")
	if config["super"]:
		if not Content.super_available():
			return ERR_UNAVAILABLE
		chosen_side = Content.constants.SUPER_SIDE
	elif chosen_side == Content.constants.SUPER_SIDE:
		return ERR_INVALID_PARAMETER
	var supplied_environment = config.get("env", {})
	if not supplied_environment is Dictionary or not Content.constants.has("SEASON_WEATHER_WEIGHTS"):
		return ERR_INVALID_PARAMETER if not supplied_environment is Dictionary else ERR_UNAVAILABLE
	var environment: Dictionary = supplied_environment
	var difficulty = environment.get("bot_difficulty", Content.constants.DEFAULT_BOT_DIFF)
	if not difficulty is String or not Content.constants.BOT_DIFF.has(difficulty):
		difficulty = Content.constants.DEFAULT_BOT_DIFF
	config["env"] = WeatherRules.resolve_environment(environment, _room_roll)
	config.env["bot_difficulty"] = difficulty
	config["architecture_seed"] = room_random.randi()
	var flip := _room_roll() < 0.5
	if config.has("campaign"):
		config.campaign.swapped = bool(config.campaign.swapped) != flip
	else:
		config["swapped"] = bool(settings.get("swapped", false)) != flip
	var peer: MultiplayerPeer
	if transport == "offline":
		peer = OfflineMultiplayerPeer.new()
	elif transport == "websocket":
		var socket := _websocket_peer()
		var error := socket.create_server(port)
		if error != OK:
			return error
		peer = socket
	else:
		var enet := ENetMultiplayerPeer.new()
		var error := enet.create_server(port)
		if error != OK:
			return error
		peer = enet
	multiplayer.multiplayer_peer = peer
	active = true
	Controls.set_room(config.ctrl)
	if not dedicated:
		chosen_name = RoomMetadata.sanitize(chosen_name)
		seats.add(1, 1, Crypto.new().generate_random_bytes(32).hex_encode(), chosen_side, "player", chosen_character, chosen_name)
		roster.append({"peer": 1, "name": chosen_name, "side": chosen_side, "character": chosen_character, "bot": false, "connected": true, "ready": false, "loaded": false})
	lobby_changed.emit()
	return OK

func quick_restart(port: int = 8620, transport: String = "offline") -> Error:
	if active or dedicated:
		return ERR_ALREADY_IN_USE
	if transport not in ["offline", "enet", "websocket"]:
		return ERR_INVALID_PARAMETER
	var recipe := deployment.restart_recipe()
	if recipe.is_empty():
		return ERR_UNAVAILABLE
	if not _recipe_worlds_available(recipe.settings):
		return ERR_UNAVAILABLE
	chosen_side = recipe.player.side
	chosen_character = recipe.player.ch if recipe.player.ch != null else ""
	if String(recipe.settings.room_name).is_empty():
		recipe.settings.room_name = Content.label("quick_room_name") % chosen_name
	var error := host(recipe.settings, port, transport)
	if error != OK:
		return error
	for bot: Dictionary in recipe.bots:
		var player := seats.add_bot(bot.side, int(config.team_size), Content.constants.BOT_NAMES, Content.balance.rooms.botNamePrefix)
		if player == 0 or not seats.set_bot_character(player, bot.ch if bot.ch != null else "", Content.heroes):
			stop()
			return ERR_INVALID_DATA
	_refresh_room_bots()
	set_ready(true)
	start_battle()
	return OK if started else ERR_CANT_CREATE

func can_quick_restart() -> bool:
	if active or dedicated:
		return false
	var recipe := deployment.restart_recipe()
	return not recipe.is_empty() and _recipe_worlds_available(recipe.settings)

func _recipe_worlds_available(settings: Dictionary) -> bool:
	var alternate := settings.duplicate(true)
	if alternate.has("campaign"):
		alternate.campaign.swapped = not bool(alternate.campaign.get("swapped", false))
	else:
		alternate["swapped"] = not bool(alternate.get("swapped", false))
	for selected: Dictionary in [settings, alternate]:
		var map_data := MatchRecipe.map_for(selected)
		var path := WorldVariant.path(map_data.get("native_world", ""), selected.env)
		if path.is_empty() or not ResourceLoader.exists(path):
			return false
	return true

func join(address: String, port: int, mode: String = "player") -> Error:
	if not Content.balance.get("rooms", {}).has("heroPools") or not Content.balance.get("rooms", {}).has("botNamePrefix") or not Content.balance.get("rooms", {}).has("names") or command_queue.capacity <= 0:
		return ERR_UNAVAILABLE
	if OS.has_feature("solo_web"):
		return ERR_UNAVAILABLE
	if RoomSeats.join_mode(mode) == "spectator" and not Content.balance.get("spectator", {}).has("initialFov"):
		return ERR_UNAVAILABLE
	stop()
	_clear_credential(true)
	chosen_mode = RoomSeats.join_mode(mode)
	connection_address = address
	connection_port = port
	local_player_id = 0
	var error := _open_transport(address, port)
	if error != OK:
		return error
	active = true
	status_changed.emit("connecting")
	return OK

func restore_connection() -> Error:
	if active:
		return ERR_ALREADY_IN_USE
	var error := credential_store.load_save()
	if error != OK:
		push_error("Cannot read room recovery credential: " + error_string(error))
		return error
	if credential_store.record.is_empty():
		return ERR_DOES_NOT_EXIST
	if OS.has_feature("solo_web") or command_queue.capacity <= 0 or not Content.balance.get("rooms", {}).has("heroPools") or not Content.balance.get("rooms", {}).has("names"):
		return ERR_UNAVAILABLE
	var saved := credential_store.record.duplicate()
	stop()
	connection_address = saved.address
	connection_port = int(saved.port)
	resume_endpoint = _endpoint(connection_address, connection_port)
	resume_token = saved.token
	local_player_id = 0
	reconnecting = true
	active = true
	error = _open_transport(connection_address, connection_port)
	if error != OK:
		_schedule_retry()
	status_changed.emit("connecting")
	return OK

func _clear_credential(force: bool = false) -> void:
	var error := credential_store.clear(force)
	if error != OK:
		push_error("Cannot clear room recovery credential: " + error_string(error))

func _websocket_peer() -> WebSocketMultiplayerPeer:
	# A populated snapshot is one message and exceeds the engine's 64 KiB default,
	# which silently starves the client of every state update.
	var socket := WebSocketMultiplayerPeer.new()
	socket.inbound_buffer_size = WEBSOCKET_BUFFER_BYTES
	socket.outbound_buffer_size = WEBSOCKET_BUFFER_BYTES
	return socket

# ENet acknowledges only when its peer polls, so a slow client frame reads as
# congestion. Deceleration would shrink the reliable window to one MTU per round
# trip, leaving one fragmented snapshot ahead of control traffic for ten seconds.
# RoomSnapshotWindow already bounds what this route can queue.
func _retain_reliable_window(peer: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null:
		enet.get_peer(peer).throttle_configure(ENET_THROTTLE_INTERVAL_MILLISECONDS, ENET_THROTTLE_ACCELERATION, 0)

func _open_transport(address: String, port: int) -> Error:
	var peer: MultiplayerPeer
	if address.begins_with("ws://") or address.begins_with("wss://"):
		var socket := _websocket_peer()
		var error := socket.create_client(address)
		if error != OK:
			return error
		peer = socket
	else:
		var enet := ENetMultiplayerPeer.new()
		var error := enet.create_client(address, port)
		if error != OK:
			return error
		peer = enet
	multiplayer.multiplayer_peer = peer
	join_timer.start()
	return OK

func stop() -> void:
	failure_reason = ""
	if snapshot_timer != null:
		snapshot_timer.stop()
	if join_timer != null:
		join_timer.stop()
	if retry_timer != null:
		retry_timer.stop()
	active = false
	resume_token = ""
	resume_endpoint = ""
	reconnecting = false
	leaving = false
	retry_failures = 0
	local_player_id = 1
	next_player_id = 2
	remote_host_id = 0
	phase = "room"
	round_id = 0
	world_prepared = false
	launch_announced = false
	prepared_map = {}
	seats = RoomSeats.new()
	pending_snapshot.clear()
	command_queue.clear()
	snapshot_window.clear()
	_close_transport()
	roster.clear()
	config.clear()
	simulation = null
	active = false
	started = false
	local_command.clear()
	Controls.set_room("")
	lobby_changed.emit()
	stopped.emit()

func leave() -> void:
	if leaving:
		await stopped
		return
	_clear_credential()
	command_queue.clear()
	if not active or is_authority() or reconnecting or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		stop()
		return
	leaving = true
	resume_token = ""
	retry_timer.stop()
	join_timer.start()
	lobby_changed.emit()
	_leave_room.rpc_id(1)
	await stopped

@rpc("any_peer", "call_remote", "reliable")
func _leave_room() -> void:
	if not active or not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	var player := seats.player_for(sender)
	if player > 0:
		seats.erase(player)
		roster = roster.filter(func(entry): return int(entry.peer) != player)
		_publish_membership()
	_leave_complete.rpc_id(sender)

@rpc("authority", "call_remote", "reliable")
func _leave_complete() -> void:
	if leaving:
		stop()

func set_control_mode(mode: String) -> bool:
	if not active or reconnecting or leaving or not is_room_host() or mode not in Controls.rules.get("modeKeys", []):
		return false
	if not is_authority():
		_request_control_mode.rpc_id(1, mode)
		return true
	return _settle_control_mode(mode)

@rpc("any_peer", "call_remote", "reliable")
func _request_control_mode(mode: String) -> void:
	if not active or not is_authority():
		return
	_set_control_mode_for(multiplayer.get_remote_sender_id(), mode)

func _set_control_mode_for(transport: int, mode: String) -> bool:
	if not seats.is_host_transport(transport):
		return false
	return _settle_control_mode(mode)

func pick_side(side: String) -> bool:
	if not active or reconnecting or leaving or story_mode():
		return false
	side = side if side in ["STEEL", "SWARM"] or side == Content.constants.SUPER_SIDE and config.get("super", false) else ""
	if side.is_empty() and not Content.balance.get("spectator", {}).has("initialFov"):
		return false
	if is_authority():
		return _pick_side_for(1, side)
	_side_request.rpc_id(1, side)
	return true

func set_room_info(room_name: String, is_public: bool) -> bool:
	if not active or reconnecting or leaving or not is_room_host():
		return false
	if is_authority():
		return _set_room_info_for(1, room_name, is_public)
	_room_info_request.rpc_id(1, room_name, is_public)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _room_info_request(room_name: String, is_public: bool) -> void:
	if active and is_authority():
		_set_room_info_for(multiplayer.get_remote_sender_id(), room_name, is_public)

func _set_room_info_for(transport: int, room_name: String, is_public: bool) -> bool:
	if not active or not is_authority() or not seats.is_host_transport(transport):
		return false
	config["room_name"] = RoomMetadata.sanitize(room_name)
	config["is_public"] = is_public
	_publish_membership()
	return true

@rpc("any_peer", "call_remote", "reliable")
func _side_request(side: String) -> void:
	if active and is_authority():
		_pick_side_for(multiplayer.get_remote_sender_id(), side)

func _pick_side_for(transport: int, side: String) -> bool:
	if not active or not is_authority() or story_mode():
		return false
	side = side if side in ["STEEL", "SWARM"] or side == Content.constants.SUPER_SIDE and config.get("super", false) else ""
	if side.is_empty() and not Content.balance.get("spectator", {}).has("initialFov"):
		return false
	var player := seats.player_for(transport)
	if player == 0:
		return false
	if not seats.choose_side(player, side, int(config.team_size), config.get("super", false)):
		var member: Dictionary = seats.members[player]
		var error := "room_spectator_side" if member.mode != "player" else "room_side_full_" + side + "_" + str(1 if side == Content.constants.SUPER_SIDE else int(config.team_size))
		notify_player(player, error)
		return false
	_publish_membership()
	return true

func pick_character(character: String) -> bool:
	if not active or phase != "room" or reconnecting or leaving or story_mode():
		return false
	if is_authority():
		return _pick_character_for(1, character)
	_character_request.rpc_id(1, character)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _character_request(character: String) -> void:
	if active and is_authority():
		_pick_character_for(multiplayer.get_remote_sender_id(), character)

func _pick_character_for(transport: int, character: String) -> bool:
	if not active or not is_authority() or phase != "room" or story_mode():
		return false
	var player := seats.player_for(transport)
	if player == 0:
		return false
	if not seats.choose_character(player, character, Content.heroes):
		if seats.members[player].mode == "player":
			notify_player(player, "room_character_invalid")
		return false
	_publish_membership()
	return true

func set_bot_difficulty(key: String) -> bool:
	if not active or reconnecting or leaving or not is_room_host() or story_mode() or not Content.constants.BOT_DIFF.has(key):
		return false
	if is_authority():
		return _settle_bot_difficulty(key)
	_difficulty_request.rpc_id(1, key)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _difficulty_request(key: String) -> void:
	if active and is_authority():
		_set_bot_difficulty_for(multiplayer.get_remote_sender_id(), key)

func _set_bot_difficulty_for(transport: int, key: String) -> bool:
	if not seats.is_host_transport(transport):
		return false
	return _settle_bot_difficulty(key)

func _settle_bot_difficulty(key: String) -> bool:
	if not active or not is_authority() or story_mode() or not Content.constants.BOT_DIFF.has(key):
		return false
	if not config.has("env"):
		config.env = {}
	config.env.bot_difficulty = key
	_publish_membership()
	return true

func edit_bot(operation: String, player: int = 0, value: String = "") -> bool:
	if not active or phase != "room" or reconnecting or leaving or not is_room_host() or story_mode() or operation not in ["add", "remove", "character"]:
		return false
	if is_authority():
		return _edit_bot_for(1, operation, player, value)
	_bot_request.rpc_id(1, operation, player, value)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _bot_request(operation: String, player: int, value: String) -> void:
	if active and is_authority():
		_edit_bot_for(multiplayer.get_remote_sender_id(), operation, player, value)

func _edit_bot_for(transport: int, operation: String, player: int, value: String) -> bool:
	if not active or not is_authority() or phase != "room" or story_mode() or not seats.is_host_transport(transport):
		return false
	var changed := false
	match operation:
		"add":
			if value not in ["SWARM", "STEEL"]:
				return false
			changed = seats.add_bot(value, int(config.team_size), Content.constants.BOT_NAMES, Content.balance.rooms.botNamePrefix) != 0
		"remove": changed = seats.bots.erase(player)
		"character": changed = seats.set_bot_character(player, value, Content.heroes)
	if changed:
		_publish_membership()
	return changed

func _refresh_room_bots() -> void:
	if phase != "room" or story_mode():
		return
	roster = roster.filter(func(player): return not player.get("bot", false))
	for player: int in seats.bots:
		var bot: Dictionary = seats.bots[player]
		roster.append({"peer": player, "side": bot.side, "character": bot.character, "name": bot.name,
			"bot": true, "ready": true, "loaded": true, "connected": true})

func _settle_control_mode(mode: String) -> bool:
	if not active or not is_authority() or mode not in Controls.rules.get("modeKeys", []):
		return false
	config["ctrl"] = mode
	Controls.set_room(mode)
	for peer: int in _room_peers():
		_sync_lobby.rpc_id(peer, config, roster, seats.host_id, phase, round_id)
	lobby_changed.emit()
	return true

func request_start_battle() -> void:
	if not active or started or reconnecting or leaving or not is_room_host():
		return
	if config.get("super", false):
		set_ready(true)
	if is_authority():
		if not seats.all_ready():
			notify_player(local_player_id, "room_not_ready")
			return
		start_battle()
	else:
		_request_start_battle.rpc_id(1)

func set_ready(ready: bool) -> bool:
	if not active or reconnecting or leaving or phase != "room":
		return false
	if is_authority():
		if not seats.set_ready(local_player_id, ready):
			return false
		_publish_membership()
	else:
		_ready_player.rpc_id(1, ready)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _ready_player(ready: bool) -> void:
	if not active or not is_authority():
		return
	var player := seats.player_for(multiplayer.get_remote_sender_id())
	if player > 0 and seats.set_ready(player, ready):
		_publish_membership()

func all_ready() -> bool:
	if is_authority():
		return seats.all_ready()
	var players := 0
	for player: Dictionary in roster:
		if player.get("bot", false) or player.get("mode", "player") != "player" or String(player.get("side", "")).is_empty():
			continue
		players += 1
		if not player.get("ready", false):
			return false
	return players > 0

@rpc("any_peer", "call_remote", "reliable")
func _request_start_battle() -> void:
	if active and is_authority() and seats.is_host_transport(multiplayer.get_remote_sender_id()):
		if not seats.all_ready():
			_notice.rpc_id(multiplayer.get_remote_sender_id(), "room_not_ready")
			return
		start_battle()

func start_battle() -> void:
	if not active or not is_authority() or started or phase != "room" or not seats.all_ready():
		return
	if story_mode():
		var players := roster.filter(func(player): return not player.get("bot", false) and player.get("mode", "player") == "player" and not String(player.side).is_empty())
		if players.size() != 1:
			return
		var player: Dictionary = players[0]
		var battle_roster := CampaignRules.roster(int(config.campaign.index), config.campaign.side, player.character, int(player.peer))
		if battle_roster.is_empty():
			return
		for participant: Dictionary in battle_roster:
			if int(participant.peer) == int(player.peer):
				participant["name"] = player.get("name", "")
		var observers := roster.filter(func(member): return not member.get("bot", false) and member not in players)
		roster = battle_roster + observers
		config.campaign.pilot = player.character
	else:
		var humans := roster.filter(func(player): return not player.get("bot", false) and player.get("mode", "player") == "player" and not String(player.side).is_empty())
		if config.get("super", false) and (humans.size() != 1 or humans[0].side != Content.constants.SUPER_SIDE):
			return
		for side in ["SWARM", "STEEL"]:
			while seats.add_bot(side, int(config.team_size), Content.constants.BOT_NAMES, Content.balance.rooms.botNamePrefix) != 0:
				pass
		_refresh_room_bots()
	round_id += 1
	started = true
	phase = "loading"
	world_prepared = false
	launch_announced = false
	prepared_map = {}
	seats.reset_loaded()
	_publish_membership()
	for peer: int in _room_peers():
		_begin.rpc_id(peer, config, roster, phase, round_id)
	battle_started.emit(config, roster)

func prepare_complete(battle: BattleSimulation, map_data: Dictionary) -> void:
	if not active or not started or leaving or battle != simulation or world_prepared:
		return
	prepared_map = map_data
	world_prepared = true
	if is_authority():
		if not dedicated:
			seats.set_loaded(local_player_id)
		_publish_membership()
		_maybe_launch()
	elif not reconnecting:
		lobby_changed.emit()
		_loaded_player.rpc_id(1, round_id)
		if phase in ["game", "over"]:
			_finish_local_launch()

@rpc("any_peer", "call_remote", "reliable")
func _loaded_player(match_id: int) -> void:
	if not active or not is_authority() or match_id != round_id or phase not in ["loading", "game", "over"]:
		return
	_set_loaded_for(multiplayer.get_remote_sender_id())

func _set_loaded_for(transport: int) -> void:
	if not active or not is_authority():
		return
	var player := seats.player_for(transport)
	if player > 0 and seats.set_loaded(player):
		_publish_membership()
		_maybe_launch()

func _maybe_launch() -> void:
	if not active or not is_authority() or phase != "loading" or not world_prepared or simulation == null or not seats.all_loaded() or not failure_reason.is_empty():
		return
	simulation.bot_difficulty = config.get("env", {}).get("bot_difficulty", Content.constants.DEFAULT_BOT_DIFF)
	var players := roster.filter(func(player): return not String(player.side).is_empty() and (player.get("bot", false) or player.get("mode", "player") == "player"))
	if not simulation.begin_match(prepared_map, players):
		fail_battle(simulation.setup_error)
		return
	for player: Dictionary in roster:
		if player.get("bot", false) and seats.bots.has(int(player.peer)):
			seats.bots[int(player.peer)].character = player.character
		elif seats.members.has(int(player.peer)):
			seats.members[int(player.peer)].character = player.character
	seats.no_human_at = 0
	phase = "game"
	_publish_membership()
	for peer: int in _room_peers():
		_launch.rpc_id(peer, round_id)
	_finish_local_launch()
	snapshot_timer.start()

@rpc("authority", "call_remote", "reliable")
func _launch(match_id: int) -> void:
	if not active or not started or match_id != round_id:
		return
	phase = "game"
	_finish_local_launch()

func _finish_local_launch() -> void:
	if not world_prepared or simulation == null or launch_announced or reconnecting or leaving or phase not in ["game", "over"] or not failure_reason.is_empty():
		return
	launch_announced = true
	simulation.set_physics_process(true)
	battle_launched.emit()
	flush_pending_snapshot()

func _on_connected() -> void:
	if reconnecting and _endpoint(connection_address, connection_port) != resume_endpoint:
		status_changed.emit("failed")
		stop()
		return
	retry_failures = 0
	_register.rpc_id(1, chosen_character, chosen_side, resume_token if reconnecting else "", chosen_mode, chosen_name)

@rpc("any_peer", "call_remote", "reliable")
func _register(character: String, side: String, token: String = "", requested_mode: String = "player", requested_name: String = "") -> void:
	if not active or not is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	_retain_reliable_window(sender)
	if not token.is_empty():
		var token_owner := seats.owner_for(token)
		var selected: Array = roster.filter(func(entry): return int(entry.peer) == token_owner)
		if token_owner == 0 or selected.is_empty():
			_reattach_failed.rpc_id(sender)
			return
		var reclaimed := seats.claim(token, sender)
		if reclaimed.is_empty():
			_reattach_failed.rpc_id(sender)
			return
		var player := int(reclaimed.player)
		selected[0].connected = true
		_identity.rpc_id(sender, player, token, selected[0].character, selected[0].side)
		var previous := int(reclaimed.previous)
		if previous > 1 and previous != sender and multiplayer.get_peers().has(previous):
			_replaced.rpc_id(previous)
		for peer: int in _room_peers():
			_sync_lobby.rpc_id(peer, config, roster, seats.host_id, phase, round_id)
		if started:
			_begin.rpc_id(sender, config, roster, phase, round_id)
			if not failure_reason.is_empty():
				_receive_failure.rpc_id(sender, failure_reason, round_id)
			elif phase in ["game", "over"] and simulation != null:
				_publish_snapshot(sender, player)
		lobby_changed.emit()
		return
	if seats.player_for(sender) != 0:
		return
	var mode := RoomSeats.join_mode(requested_mode)
	if mode == "player" and config.get("super", false) and phase == "room":
		side = Content.constants.SUPER_SIDE
	if mode == "spectator" and not Content.balance.get("spectator", {}).has("initialFov"):
		_notice.rpc_id(sender, "failed")
		return
	var error := seats.admission_error(mode, int(config.team_size), bool(config.get("super", false)))
	if not error.is_empty():
		_notice.rpc_id(sender, error)
		return
	var player_members := seats.members.values().filter(func(member): return member.mode == "player")
	if mode == "player" and story_mode() and (not player_members.is_empty() or side != config.campaign.side or not CampaignRules.valid_selection(int(config.campaign.index), side, character)):
		_notice.rpc_id(sender, "full")
		return
	# Native preselection composes source join -> pickSide -> pickChar only in room.
	if mode == "spectator" or phase != "room":
		side = ""
		character = ""
	elif (not character.is_empty() and not Content.heroes.has(character)) or side not in ["", "SWARM", "STEEL", "SUPER"]:
		return
	elif side == Content.constants.SUPER_SIDE and not config.get("super", false):
		return
	elif not character.is_empty() and side != Content.constants.SUPER_SIDE and (side.is_empty() or Content.heroes[character].side not in [side, "MERC"]):
		return
	var player := next_player_id
	var credential := Crypto.new().generate_random_bytes(32).hex_encode()
	if not seats.add(player, sender, credential, "", mode, "", RoomMetadata.sanitize(requested_name)):
		_notice.rpc_id(sender, "failed")
		return
	next_player_id += 1
	if mode == "player" and not side.is_empty():
		if seats.choose_side(player, side, int(config.team_size), config.get("super", false)):
			seats.choose_character(player, character, Content.heroes)
		else:
			_notice.rpc_id(sender, "room_side_full_" + side + "_" + str(1 if side == Content.constants.SUPER_SIDE else int(config.team_size)))
	var member: Dictionary = seats.members[player]
	roster.append({"peer": player, "name": member.name, "side": member.side, "character": member.character, "mode": mode, "bot": false, "connected": true, "ready": false, "loaded": false})
	_identity.rpc_id(sender, player, credential, member.character, member.side)
	_publish_membership()
	if phase in ["loading", "game"]:
		_begin.rpc_id(sender, config, roster, phase, round_id)
		if not failure_reason.is_empty():
			_receive_failure.rpc_id(sender, failure_reason, round_id)
		elif phase == "game" and simulation != null:
			_publish_snapshot(sender, player)

@rpc("authority", "call_remote", "reliable")
func _identity(player: int, token: String, character: String, side: String) -> void:
	local_player_id = player
	resume_token = token
	resume_endpoint = _endpoint(connection_address, connection_port)
	chosen_character = character
	chosen_side = side
	var error := credential_store.remember(connection_address, connection_port, token)
	if error != OK:
		push_error("Cannot save room recovery credential: " + error_string(error))

@rpc("authority", "call_remote", "reliable")
func _replaced() -> void:
	_clear_credential()
	resume_token = ""
	status_changed.emit("disconnected")
	stop()

@rpc("authority", "call_remote", "reliable")
func _reattach_failed() -> void:
	_clear_credential()
	resume_token = ""
	status_changed.emit("failed")
	stop()

@rpc("authority", "call_remote", "reliable")
func _sync_lobby(settings: Dictionary, players: Array, host_player: int, room_phase: String, match_id: int) -> void:
	if match_id < round_id:
		return
	var returning := started and (room_phase == "room" or match_id != round_id)
	round_id = match_id
	if returning:
		_dispose_match()
	config = settings
	roster = players
	remote_host_id = host_player
	phase = room_phase
	_sync_local_selection()
	Controls.set_room(config.get("ctrl", ""))
	_remember_match()
	join_timer.stop()
	if not started:
		reconnecting = false
	if returning:
		room_returned.emit()
	lobby_changed.emit()
	status_changed.emit("ready")

@rpc("authority", "call_remote", "reliable")
func _begin(settings: Dictionary, players: Array, room_phase: String, match_id: int) -> void:
	if match_id < round_id:
		return
	var retained_battle := reconnecting and started and match_id == round_id
	round_id = match_id
	config = settings
	roster = players
	phase = room_phase
	_sync_local_selection()
	Controls.set_room(config.get("ctrl", ""))
	started = true
	join_timer.stop()
	reconnecting = false
	if not retained_battle:
		world_prepared = false
		launch_announced = false
		prepared_map = {}
	lobby_changed.emit()
	if not retained_battle:
		battle_started.emit(config, roster)
	elif world_prepared:
		_loaded_player.rpc_id(1, round_id)
		_finish_local_launch()
	_flush_commands()
	flush_pending_snapshot()

func flush_pending_snapshot() -> void:
	if pending_snapshot.is_empty() or simulation == null or reconnecting or not launch_announced:
		return
	var state := pending_snapshot
	pending_snapshot = {}
	_snapshot(state)

func notify_player(player: int, key: String) -> void:
	if not is_authority():
		return
	if player == 1 and not dedicated:
		status_changed.emit(key)
		return
	var transport := seats.transport_for(player)
	if transport > 1 and multiplayer.get_peers().has(transport):
		_notice.rpc_id(transport, key)

@rpc("authority", "call_remote", "reliable")
func _notice(key: String) -> void:
	status_changed.emit(key)

func command(data: Dictionary) -> void:
	if not active or simulation == null or not launch_announced or phase != "game" or leaving or chosen_side.is_empty() or chosen_mode != "player" or not failure_reason.is_empty():
		return
	local_command = data
	if is_authority():
		simulation.submit_input(1, data)
	else:
		_send_combat({"kind": "input", "data": data, "match": round_id})

# Input and actions share native reliable order, including a reconnect queue flush.
@rpc("any_peer", "call_remote", "reliable", 2)
func _receive_input(data: Dictionary, match_id: int) -> void:
	if is_authority() and simulation != null and phase == "game" and match_id == round_id and failure_reason.is_empty():
		var player := seats.player_for(multiplayer.get_remote_sender_id())
		if player > 0 and not String(seats.members[player].side).is_empty() and seats.members[player].mode == "player":
			simulation.submit_input(player, data)

func act(type: String, argument: String = "") -> void:
	if not _can_act():
		return
	if is_authority():
		simulation.action(1, type, argument)
	else:
		_send_combat({"kind": "action", "type": type, "argument": argument, "match": round_id})

func _can_act() -> bool:
	return active and launch_announced and simulation != null and phase == "game" and not leaving and not chosen_side.is_empty() and chosen_mode == "player" and failure_reason.is_empty()

func cast_at(slot: String, source_point: Vector2) -> void:
	if not _can_act() or slot not in ["def", "atk"] or not source_point.is_finite():
		return
	if is_authority():
		simulation.cast_player_at(1, slot, source_point)
	else:
		_send_combat({"kind": "cast", "slot": slot, "point": source_point, "match": round_id})

func _combat_connected() -> bool:
	return active and not reconnecting and not leaving and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _send_combat(message: Dictionary) -> void:
	command_queue.connected = _combat_connected()
	command_queue.flush(_deliver_combat)
	command_queue.send(message, _deliver_combat)
	if not command_queue.connected and not reconnecting:
		_server_disconnected()

func _deliver_combat(message: Dictionary) -> bool:
	if int(message.get("match", -1)) != round_id or phase != "game" or not failure_reason.is_empty():
		return true
	if message.kind == "input":
		return rpc_id(1, &"_receive_input", message.data, round_id) == OK
	if message.kind == "cast":
		return rpc_id(1, &"_cast_at", message.slot, message.point, round_id) == OK
	return rpc_id(1, &"_action", message.type, message.argument, round_id) == OK

func _flush_commands() -> void:
	if phase != "game":
		command_queue.clear()
		return
	command_queue.connected = _combat_connected()
	command_queue.flush(_deliver_combat)
	if not command_queue.connected and not reconnecting:
		_server_disconnected()

@rpc("any_peer", "call_remote", "reliable", 2)
func _action(type: String, argument: String, match_id: int) -> void:
	if not is_authority() or simulation == null or phase != "game" or match_id != round_id or not failure_reason.is_empty():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := seats.player_for(sender)
	if player > 0 and not String(seats.members[player].side).is_empty() and seats.members[player].mode == "player":
		simulation.action(player, type, argument)

@rpc("any_peer", "call_remote", "reliable", 2)
func _cast_at(slot: String, source_point: Vector2, match_id: int) -> void:
	if not is_authority() or simulation == null or phase != "game" or match_id != round_id or not failure_reason.is_empty():
		return
	var player := seats.player_for(multiplayer.get_remote_sender_id())
	if player > 0 and not String(seats.members[player].side).is_empty() and seats.members[player].mode == "player":
		simulation.cast_player_at(player, slot, source_point)

func _broadcast_state() -> void:
	if simulation == null or not is_authority() or not launch_announced or not failure_reason.is_empty():
		return
	if simulation.over and phase != "over":
		phase = "over"
		_publish_membership()
	if not simulation.over and seats.abandoned(Time.get_ticks_msec(), float(Content.balance.rooms.noHumanMilliseconds)):
		_clear_room()
		return
	simulation.flush_blood_hurt()
	simulation.flush_blast_feedback()
	for peer in multiplayer.get_peers():
		var player := seats.player_for(peer)
		if player > 0:
			_publish_snapshot(peer, player)
	var battle := simulation
	state_received.emit(_state_for(1))
	if simulation != battle:
		return
	simulation.events.clear()
	if simulation.over:
		snapshot_timer.stop()

# A snapshot queued behind unread ones only delays reliable control traffic on the
# same transport, so a full window skips the send. The state is still built each
# tick because event visibility belongs to the frame that produced the event.
func _publish_snapshot(peer: int, player: int) -> void:
	var state := _state_for(player)
	if snapshot_window.is_full(peer):
		snapshot_window.hold(peer, state.events)
		return
	state.events = snapshot_window.release(peer) + state.events
	snapshot_window.sent(peer, int(state._serial))
	_snapshot.rpc_id(peer, state)

func _state_for(player: int) -> Dictionary:
	var member: Dictionary = seats.members.get(player, {})
	var state := simulation.snapshot(player, String(member.get("side", "")))
	state["_match"] = round_id
	simulation.snapshot_serial += 1
	state["_serial"] = simulation.snapshot_serial
	return state

func broadcast_body_event(event: Dictionary) -> void:
	if simulation == null or not is_authority() or not failure_reason.is_empty():
		return
	var actor: BattleUnit = simulation.units.get(int(event.actor))
	var public_cast: bool = event.type in ["cast", "cast_start"]
	if actor == null and not public_cast:
		return
	for peer: int in multiplayer.get_peers():
		var player := seats.player_for(peer)
		if player == 0 or event.has("only_peer") and int(event.only_peer) != player:
			continue
		var viewer: BattleUnit = simulation.pilots.get(player)
		var side: String = seats.members[player].side
		if public_cast or side.is_empty() or simulation.visible_to_side(actor, side):
			_body_event.rpc_id(peer, ActorSnapshot.event(event, viewer != null and viewer == actor), round_id)

# Short tactical notifications must not wait behind fragmented full snapshots.
@rpc("authority", "call_remote", "reliable", 4)
func _body_event(event: Dictionary, match_id: int) -> void:
	if simulation != null and match_id == round_id and started and failure_reason.is_empty():
		simulation.receive_body_events([event], simulation.presentation_time())
		body_event_received.emit(event)

# Full snapshots exceed ENet's MTU; native reliable fragmentation stays off the input/action channels.
@rpc("authority", "call_remote", "reliable", 3)
func _snapshot(data: Dictionary) -> void:
	var match_id := int(data.get("_match", -1))
	# Receipt, not acceptance: a stale or pending state has still left the transport.
	if multiplayer.get_remote_sender_id() == 1:
		_snapshot_received.rpc_id(1, int(data.get("_serial", -1)), match_id)
	if match_id < round_id or not active or not failure_reason.is_empty() and match_id == round_id:
		return
	if match_id > round_id or not started or simulation == null or reconnecting or not launch_announced:
		if int(pending_snapshot.get("_match", -1)) > match_id:
			return
		pending_snapshot = data
		return
	if simulation != null:
		snapshot_heard.emit()
		if simulation.apply_snapshot(data):
			state_received.emit(data)

@rpc("any_peer", "call_remote", "reliable", 3)
func _snapshot_received(serial: int, match_id: int) -> void:
	if not active or not is_authority() or simulation == null or match_id != round_id:
		return
	var peer := multiplayer.get_remote_sender_id()
	snapshot_window.acknowledge(peer, serial)
	# The timer stops on the final tick; a recipient it skipped still owes that state.
	if snapshot_timer.is_stopped() and failure_reason.is_empty() and snapshot_window.is_held(peer):
		var player := seats.player_for(peer)
		if player > 0:
			_publish_snapshot(peer, player)

func _on_disconnected(peer: int) -> void:
	if not active or closing_transport or not is_authority():
		return
	snapshot_window.forget(peer)
	var registry := seats
	var hold := started and float(Content.balance.rooms.dropMilliseconds) > 0
	var detached := registry.detach(peer, hold)
	if detached.is_empty():
		return
	var player := int(detached.player)
	if hold:
		for entry: Dictionary in roster:
			if int(entry.peer) == player:
				entry.connected = false
		get_tree().create_timer(float(Content.balance.rooms.dropMilliseconds) / 1000.0).timeout.connect(func():
			if registry == seats and registry.expire(player, int(detached.generation)):
				roster = roster.filter(func(entry): return int(entry.peer) != player)
				_publish_membership())
	else:
		roster = roster.filter(func(entry): return int(entry.peer) != player)
	_publish_membership()

func _publish_membership() -> void:
	if active and is_authority() and seats.members.is_empty():
		_clear_room()
		return
	_refresh_room_bots()
	for entry: Dictionary in roster:
		var member: Dictionary = seats.members.get(int(entry.peer), {})
		if not member.is_empty():
			entry["name"] = member.get("name", "")
			entry.side = member.side
			entry.character = member.character
			entry.mode = member.mode
			entry.connected = member.connected
			entry.ready = member.ready
			entry.loaded = member.loaded
	if active:
		for peer: int in _room_peers():
			_sync_lobby.rpc_id(peer, config, roster, seats.host_id, phase, round_id)
	_sync_local_selection()
	_remember_match()
	lobby_changed.emit()

func _remember_match() -> void:
	if active and not dedicated and phase in ["loading", "game", "over"]:
		deployment.record_match(config, roster, local_player_id)

func request_return_to_room() -> void:
	if not active or reconnecting or leaving or not is_room_host():
		return
	if is_authority():
		return_to_room()
	else:
		_return_to_room.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _return_to_room() -> void:
	if active and is_authority() and seats.is_host_transport(multiplayer.get_remote_sender_id()):
		return_to_room()

func return_to_room() -> void:
	if not active or not is_authority() or simulation == null:
		return
	round_id += 1
	_dispose_match()
	_reroll_room_config(_room_roll())
	for member: Dictionary in seats.members.values():
		member.ready = false
		member.loaded = false
	# Battle-only authored rows and departed pilots cannot become room seats.
	roster = roster.filter(func(entry): return seats.members.has(int(entry.peer)) or seats.bots.has(int(entry.peer)))
	room_returned.emit()
	_publish_membership()

func _reroll_room_config(draw: float) -> void:
	if draw < 0.5:
		if config.has("campaign"):
			config.campaign.swapped = not bool(config.campaign.swapped)
		else:
			config["swapped"] = not bool(config.get("swapped", false))
	config["architecture_seed"] = (int(config.get("architecture_seed", 0)) + 1) & 0xffffffff

func _dispose_match() -> void:
	failure_reason = ""
	snapshot_timer.stop()
	if simulation != null:
		simulation.set_physics_process(false)
	simulation = null
	started = false
	phase = "room"
	world_prepared = false
	launch_announced = false
	prepared_map = {}
	if int(pending_snapshot.get("_match", -1)) <= round_id:
		pending_snapshot.clear()
	local_command.clear()
	command_queue.clear()
	snapshot_window.clear()

func _clear_room() -> void:
	_dispose_match()
	pending_snapshot.clear()
	seats = RoomSeats.new()
	roster.clear()
	room_cleared.emit()
	lobby_changed.emit()
