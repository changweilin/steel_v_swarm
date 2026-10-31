class_name SpectatorState
extends RefCounted

signal notice(message: String)

var rules: Dictionary = {}
var mode := ""
var pid := ""
var _position_vector := Vector3.ZERO
var _position_x := 0.0
var _position_y := 0.0
var _position_z := 0.0
var position: Vector3:
	get:
		return _position_vector
	set(value):
		_position_vector = value
		_position_x = float(value.x)
		_position_y = float(value.y)
		_position_z = float(value.z)
var camera_position := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var fov := 0.0
var camera_fov := 0.0
var _anchor_position := Vector3.ZERO
var _anchor_x := 0.0
var _anchor_y := 0.0
var _anchor_z := 0.0
var anchor: Vector3:
	get:
		return _anchor_position
	set(value):
		_anchor_position = value
		_anchor_x = float(value.x)
		_anchor_y = float(value.y)
		_anchor_z = float(value.z)
var anchor_ok := false
var follow_yaw := 0.0
var hidden: Dictionary = {}

func configure(metadata: Dictionary, center: Vector3, ceiling: float, initial_fov: float) -> void:
	rules = metadata
	mode = str(rules.camera.VIEWS[0])
	pid = ""
	_position_x = float(center.x)
	_position_y = minf(float(center.y) + float(rules.startHeight), ceiling)
	_position_z = float(center.z)
	_position_vector = Vector3(_position_x, _position_y, _position_z)
	camera_position = Vector3.ZERO
	yaw = 0.0
	pitch = rules.startPitch
	fov = initial_fov
	camera_fov = initial_fov
	anchor = Vector3.ZERO
	anchor_ok = false
	follow_yaw = 0.0
	hidden = {}

static func source_pid(player: int) -> String:
	return "b" + str(-player) if player < 0 else str(player)

static func roster(actors: Array) -> Array:
	var result: Array = []
	for actor: Dictionary in actors:
		if not actor.get("hero", false) or not ControlPreferences.truthy(actor.get("pid")) or actor.get("act", true) == false:
			continue
		# Native IDs use only decimal digits and the lowercase source bot prefix.
		# Insert after equal keys, matching the original stable Array.sort.
		var index := result.size()
		while index > 0:
			var prior: Dictionary = result[index - 1]
			var before := str(actor.pid) < str(prior.pid) if actor.side == prior.side else str(actor.side) < str(prior.side)
			if not before:
				break
			index -= 1
		result.insert(index, actor)
	return result

func _nearest(list: Array) -> Dictionary:
	var nearest: Dictionary = list[0]
	var nearest_distance := _distance_squared_xyz(_position_x, _position_y, _position_z, nearest.position)
	for index in range(1, list.size()):
		var actor: Dictionary = list[index]
		var distance := _distance_squared_xyz(_position_x, _position_y, _position_z, actor.position)
		if not (nearest_distance <= distance):
			nearest = actor
			nearest_distance = distance
	return nearest

static func _distance_squared(first: Vector3, second: Vector3) -> float:
	# Three.js compares scalar doubles without rounding the squared distance to Vector3 precision.
	return _distance_squared_xyz(float(first.x), float(first.y), float(first.z), second)

static func _distance_squared_xyz(x: float, y: float, z: float, second: Vector3) -> float:
	var dx := x - float(second.x)
	var dy := y - float(second.y)
	var dz := z - float(second.z)
	return dx * dx + dy * dy + dz * dz

func target(actors: Array) -> Dictionary:
	for actor: Dictionary in roster(actors):
		if str(actor.pid) == pid:
			return actor
	return {}

func target_name(actor: Dictionary) -> String:
	var side := str(actor.get("side", ""))
	var character := str(actor.get("ch", ""))
	if rules.names.has(character + ":" + side):
		return str(rules.names[character + ":" + side])
	return str(actor.get("pid", rules.unknownName)) + str(rules.sideSuffix.get(side, ""))

func _announce(actor: Dictionary) -> void:
	if mode == "god":
		notice.emit(rules.ui.god)
	else:
		notice.emit(str(rules.ui.follow).replace("{view}", str(rules.camera.NAMES[mode])).replace("{name}", target_name(actor)))

func select_mode(value: String, actors: Array) -> void:
	var next := value if value in rules.camera.VIEWS else str(rules.camera.VIEWS[0])
	var none := false
	if next != "god" and pid.is_empty():
		var list := roster(actors)
		if list.is_empty():
			next = "god"
			none = true
		else:
			pid = str(_nearest(list).pid)
			anchor_ok = false
	var previous := mode
	mode = next
	if mode == "god":
		pid = ""
		anchor_ok = false
		if previous != "god":
			pitch = minf(pitch, rules.camera.ORBIT_PITCH)
	elif previous == "god" or previous == "fpv":
		pitch = 0.0 if mode == "fpv" else float(rules.camera.TPS_PITCH if mode == "tps" else rules.camera.ORBIT_PITCH)
	if none:
		notice.emit(rules.ui.noneMode)
	else:
		_announce(target(actors))

func cycle(actors: Array) -> void:
	var index: int = rules.camera.VIEWS.find(mode)
	select_mode(str(rules.camera.VIEWS[(0 if index < 0 else index + 1) % rules.camera.VIEWS.size()]), actors)

func follow(step: Variant, actors: Array) -> void:
	if step == null:
		select_mode("god", actors)
		return
	var list := roster(actors)
	if list.is_empty():
		notice.emit(rules.ui.noneFollow)
		return
	var actor: Dictionary
	if int(step) == 0 and pid.is_empty():
		actor = _nearest(list)
	else:
		var index := -1
		for i in list.size():
			if str(list[i].pid) == pid:
				index = i
				break
		actor = list[posmod(0 if index < 0 else index + int(step), list.size())]
	if pid != str(actor.pid):
		anchor_ok = false
	pid = str(actor.pid)
	if mode == "god":
		select_mode("fpv", actors)
	else:
		_announce(actor)

func zoom(wheel_delta: float) -> void:
	var factor: float = rules.camera.FOV_STEP if wheel_delta > 0 else 1.0 / float(rules.camera.FOV_STEP)
	fov = clampf(fov * factor, rules.camera.FOV_MIN, rules.camera.FOV_MAX)

# Same HUD contract as the source player panel. Unknown private clocks stay null.
func hud(actors: Array, side: String = "") -> Variant:
	if not side.is_empty():
		return null
	var actor := target(actors)
	var view_name: String = rules.camera.NAMES.get(mode, rules.camera.NAMES.god)
	if actor.is_empty():
		return {"spec": true, "follow": false, "who": rules.ui.hudFree.get(mode, rules.ui.hudFree.god), "hp": 0, "max": 1}
	var character := str(actor.get("ch", ""))
	var display: Dictionary = rules.display.get(character, {})
	var raw_abilities: Variant = actor.get("ab")
	var ab: Dictionary = {}
	if ControlPreferences.truthy(raw_abilities):
		if not raw_abilities is Dictionary:
			push_error("Spectator ability levels must be a dictionary")
			return null
		ab = raw_abilities
	var raw_power: Variant = actor.get("mp")
	if raw_power != null and not raw_power is float and not raw_power is int:
		push_error("Spectator power must be numeric or null")
		return null
	var power := 0.0 if raw_power == null else float(raw_power)
	var raw_cooldowns: Variant = _source_or(actor.get("cds"), [])
	var result := {"spec": true, "follow": true,
		"who": str(rules.ui.hudFollow["unknown" if display.is_empty() else "character"]).replace("{name}", target_name(actor)).replace("{machine}", str(display.get("machine", ""))).replace("{view}", view_name),
		"ch": character, "hp": actor.hp, "max": actor.max, "dead": ControlPreferences.truthy(actor.get("dead")), "rs": _source_or(actor.get("rs"), 0),
		"upg": _source_or(actor.get("up"), null), "money": _source_or(actor.get("money"), 0), "kn": _source_or(actor.get("kn"), 0), "atBase": false, "aiming": false,
		"sp": _source_or(actor.get("sp"), 0), "msp": _source_or(actor.get("maxSp"), 1),
		"mp": power, "mm": _source_or(actor.get("mm"), 1),
		"lift": null, "mobil": null, "morph": null, "emp": _source_or(actor.get("emp"), 0), "stealth": 0}
	if not display.is_empty():
		result.code = display.code
		result.machine = display.machine
	for slot: String in ["light", "heavy"]:
		var level: float = _source_or(ab.get(slot), 1)
		var weapon: Dictionary = Content.local_weapon(character, slot, level) if Content.heroes.has(character) else {}
		result[slot] = {"name": weapon.get("name", rules.unknownName), "lvl": level if not weapon.is_empty() else 0,
			"ammo": null, "mag": weapon.get("mag", 0), "reload": 0, "reloadMax": weapon.get("reload", 0)}
	for slot: String in ["def", "atk"]:
		var level: float = _source_or(ab.get(slot), 1)
		var ability: Dictionary = Content.local_ability(character, slot, level) if Content.heroes.has(character) else {}
		if ability.is_empty():
			result[slot] = {"name": rules.unknownName, "lvl": 0, "cd": 0, "cdMax": 0, "mp": 0, "ready": false}
			continue
		if not raw_cooldowns is Array:
			push_error("Spectator cooldowns must be an array")
			return null
		var cooldowns: Array = raw_cooldowns
		var index := 0 if slot == "def" else 1
		var cooldown: float = _source_or(cooldowns[index], 0) if cooldowns.size() > index else 0.0
		var cost := floorf(float(ability.mp) + 0.5)
		result[slot] = {"name": ability.name, "lvl": level, "cd": cooldown,
			"cdMax": ability.cd if ability.get("cd", 0) else rules.abilityFallbackCd, "mp": cost, "ready": cooldown <= 0 and power >= cost}
	return result

static func _source_or(value: Variant, fallback: Variant) -> Variant:
	return value if ControlPreferences.truthy(value) else fallback

# Actors are presentation rows with interpolated positions, not authority units.
# Visibility commands retain the prior row until its FPV body has been restored.
func advance(delta: float, actors: Array, axis: Dictionary, rising: bool, descending: bool,
		surface: Callable, ceiling: float, pull: Callable, precise_pull: Callable = Callable()) -> Array:
	var actor := target(actors)
	if not pid.is_empty() and actor.is_empty():
		select_mode("god", actors)
	var view := mode if not actor.is_empty() else "god"
	var hide: Dictionary = actor if view == "fpv" else {}
	var visibility: Array = []
	if not hidden.is_empty() and not is_same(hidden, hide):
		visibility.append({"actor": hidden, "visible": not hidden.get("dead", false)})
		hidden = {}
	var c: Dictionary = rules.camera
	if not actor.is_empty():
		var profile: Dictionary = rules.profiles.get(str(actor.get("ch", "")), rules.fallbacks.get(str(actor.side), rules.fallbacks[""]))
		var height: float = profile.height
		var point: Vector3 = actor.position
		if view in c.LOCK_VIEWS or not anchor_ok or sqrt(_distance_squared_xyz(_anchor_x, _anchor_y, _anchor_z, point)) > float(c.SNAP_M):
			anchor = point
			anchor_ok = true
		else:
			var weight := 1.0 - exp(-maxf(0.0, float(c.POS_K)) * maxf(0.0, delta))
			_anchor_x += (float(point.x) - _anchor_x) * weight
			_anchor_y += (float(point.y) - _anchor_y) * weight
			_anchor_z += (float(point.z) - _anchor_z) * weight
			_anchor_position = Vector3(_anchor_x, _anchor_y, _anchor_z)
		var target_yaw: Variant = actor.get("ry")
		if target_yaw == null:
			target_yaw = follow_yaw
		follow_yaw = CameraPose.angle_step(follow_yaw, float(target_yaw), c.FPV_YAW_K if view == "fpv" else c.YAW_K, maxf(0.0, delta))
		_position_x = _anchor_x
		_position_y = _anchor_y
		_position_z = _anchor_z
		_position_vector = Vector3(_position_x, _position_y, _position_z)
		if view == "fpv":
			var eye: Dictionary = profile.air if float(actor.get("heroY", 0)) > float(c.FLY_M) else profile.ground
			yaw = follow_yaw
			if not actor.get("dead", false):
				visibility.append({"actor": actor, "visible": false})
			hidden = actor
			var head_forward := height * float(eye.f)
			camera_position = Vector3(_anchor_x - sin(yaw) * head_forward,
				_anchor_y + height * float(eye.e), _anchor_z - cos(yaw) * head_forward)
		else:
			if view == "tps":
				yaw = follow_yaw
			var distance := maxf(c.MIN_DIST, height * float(c.DIST_F))
			var aim_y := _anchor_y + height * float(c.AIM_F)
			var cosine_pitch := cos(pitch)
			var aim := [_anchor_x, aim_y, _anchor_z]
			var camera := [_anchor_x + sin(yaw) * distance * cosine_pitch,
				aim_y - sin(pitch) * distance, _anchor_z + cos(yaw) * distance * cosine_pitch]
			camera_position = Vector3(camera[0], camera[1], camera[2])
			var pulled: Array
			if precise_pull.is_valid():
				pulled = precise_pull.call(aim, camera)
			else:
				var result: Vector3 = pull.call(Vector3(aim[0], aim[1], aim[2]), Vector3(camera[0], camera[1], camera[2]))
				pulled = [float(result.x), float(result.y), float(result.z)]
			var floor_height: float = float(surface.call(Vector3(pulled[0], pulled[1], pulled[2]))) + float(c.FLOOR_M)
			if float(pulled[1]) < floor_height:
				pulled[1] = floor_height
			camera_position = Vector3(pulled[0], pulled[1], pulled[2])
	else:
		var forward_x := -sin(yaw)
		var forward_z := -cos(yaw)
		var speed: float = float(c.MOVE_MPS) * (float(c.BOOST_F) if axis.boost else 1.0)
		var normalization := 1.0 / float(axis.mag) if float(axis.mag) > 1.0 else 1.0
		var step := normalization * speed * delta
		_position_x += (forward_x * float(axis.f) - forward_z * float(axis.r)) * step
		_position_z += (forward_z * float(axis.f) + forward_x * float(axis.r)) * step
		if rising:
			_position_y += speed * delta
		if descending:
			_position_y -= speed * delta
		var floor_height: float = float(surface.call(Vector3(_position_x, _position_y, _position_z))) + float(c.FLOOR_M)
		if _position_y < floor_height:
			_position_y = floor_height
		if _position_y > ceiling:
			_position_y = maxf(floor_height, ceiling)
		_position_vector = Vector3(_position_x, _position_y, _position_z)
		camera_position = position
	if absf(camera_fov - fov) > float(rules.fovThreshold):
		camera_fov = fov
	return visibility
