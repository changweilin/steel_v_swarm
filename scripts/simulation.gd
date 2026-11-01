class_name BattleSimulation
extends Node3D

const SupportRay = preload("res://scripts/source_support_ray.gd")
const CarrierLaunchTrig = preload("res://scripts/source_carrier_trig.gd")

signal result(winner: String)
signal message(peer: int, key: String)
signal body_event(event: Dictionary)
signal unit_spawned(unit: BattleUnit)
signal self_hurt
signal screen_hurt(event: Dictionary)
signal death_presented(event: Dictionary)
signal view_snapshot_ready(state: Dictionary)
signal unit_view_removed(model: Node3D)
signal setup_progress
signal failure_reported(reason: String)

var setup_complete := false
var setup_error := ""
var prepared_map: Dictionary = {}
var prepared_environment: Dictionary = {}

var world: BattleWorld
var units: Dictionary = {}
var pilots: Dictionary = {}
var clock := 0.0
var wave := 0
var next_wave := 0.0
var over := false
var winner := ""
var next_id := 1
var authoritative := true
var match_initialized := false
var rng := SourceRng.new(42)
var events: Array = []
var body_event_serial := 0
var terminal_event_serials: Dictionary = {}
var hero_report_serials: Dictionary = {}
var hero_pose_serials: Dictionary = {}
var remote_bursts := BurstPresentationQueue.new()
var victim_reports: Dictionary = {}
var owned_defense: Variant = null
var retired_bodies: Dictionary = {}
var dissolve_ghosts: Array[RetiredBody] = []
var hurt_bearings := HurtBearingLog.new()
var blood_event_serial := 0
var death_event_serial := 0
var notice_event_serial := 0
var presented_death_serial := -1
var blast_event_serial := 0
var presented_blast_serials: Dictionary = {}
var pending_blast_feedback: Array[Dictionary] = []
var body_clock_offset := NAN
var match_stats: Dictionary = {"SWARM": {"kills": 0, "deaths": 0, "creepKills": 0, "assists": 0},
	"STEEL": {"kills": 0, "deaths": 0, "creepKills": 0, "assists": 0}}
var projectiles: Array[Dictionary] = []
var projectile_rng := SourceRng.new(4242)
var recoil_random := RandomNumberGenerator.new()
var fire_controls: Dictionary = {}
var missiles: Array[Dictionary] = []
var missile_bodies: Dictionary = {}
var missile_presentations: Dictionary = {}
var pending_missile_view: Array = []
var missile_view_pending := false
var footprint_glows: FootprintGlows
var skill_glows: FootprintGlows
var lock_glow: LockGlowPresentation
var vision_until: Dictionary = {"SWARM": 0.0, "STEEL": 0.0}
var reflecting := false
var fogs: Array[Dictionary] = []
var cubic_cages: Array[Dictionary] = []
var next_field_id := 1
var fog_view: Array = []
var autonomous_summons: Array[int] = []
var hologram_decoys: Array[int] = []
var carrier_states: Dictionary = {}
var npc_phase_sequence := 0
var weather_fog := 0.0
var weather_start: Dictionary = {}
var weather_schedule: Dictionary = {}
var weather_vector: Dictionary = {}
var weather_dynamics: Dictionary = {}
var weather_surface: Dictionary = {}
var weather_seed := 0
var weather_elapsed := 0.0
var weather_last_freeze_step := -1
var lightning_timer := 0.0
var creep_upgrades: Dictionary = {"STEEL": [], "SWARM": []}
var npc_index: Array = []
var npc_index_active := false
var authority_accumulator := 0.0
var simulation_tick := 0
var wave_anchors: Dictionary = {}
var npc_structures: Array = []
var authority_bounds: Dictionary = {}
var fire_fields: Array[Dictionary] = []
var weather_scars: Array[Dictionary] = []
var loots: Array[Dictionary] = []
var hazard_blockers: Array = []
var mines: Array[Dictionary] = []
var relay_states: Array[Dictionary] = []
# Highest serial published by the authority or accepted by this round's replica.
var snapshot_serial := -1
var airdrops: Array[Dictionary] = []
var next_airdrop := 0.0
var camps: Array[Dictionary] = []
var civilian_respawns: Array[Dictionary] = []
var bot_brains: Dictionary = {}
var bot_tower_sites: Array = []
var bot_holds: Dictionary = {}
var bot_difficulty := ""
var balance_profile: BalanceDefinitions
var client_weapons := ClientWeaponDefinitions.new()
var siege := false
var super_mode := false
var super_random := RandomNumberGenerator.new()
var last_super_spawn: Variant = null
var super_spawns: Dictionary = {}
var defending_side := ""
var siege_left: Dictionary = {}
var siege_open: Dictionary = {"SWARM": 0, "STEEL": 0}
var boss_left: Dictionary = {}
var siege_talk_until: Dictionary = {}
const SUMMON_KINDS := ["drone_wingman", "assault_rover", "heli_squad", "main_battle_tank", "veteran_squad", "carnival_heli"]

func weapon_definition(character: String, slot: String, level: float = 1) -> Dictionary:
	return balance_profile.weapon(character, slot, level) if balance_profile != null else Content.weapon(character, slot, level)

func ability_definition(character: String, slot: String, level: float = 1) -> Dictionary:
	return balance_profile.ability(character, slot, level) if balance_profile != null else Content.ability(character, slot, level)

func client_weapon_definition(unit: BattleUnit, slot: String) -> Dictionary:
	if unit.is_pilot() and unit.peer_id == Session.player_id():
		return client_weapons.own_weapon(unit.character, slot, unit.combat_level("light"), unit.combat_level("heavy"))
	return Content.local_weapon(unit.character, slot, unit.combat_level(slot))

func hero_speed(character: String, flying: bool = false) -> float:
	if balance_profile != null:
		return balance_profile.speed(character, flying)
	return float(Content.heroes[character].flySpeed if flying else Content.heroes[character].speed)

func balance_multiplier(stat: String) -> float:
	return balance_profile.preferences.multiplier(stat) if balance_profile != null else 1.0

func bot_profile(character: String) -> Dictionary:
	return balance_profile.bot_profile(character) if balance_profile != null else Content.balance.bot.profiles[character]

func bounty_for_kind(kind: String) -> float:
	return float(Content.constants.ECON.BOUNTY.get(kind, 0)) * balance_multiplier("bounty")

func respawn_delay(kind: String, deaths: int) -> float:
	var times: Dictionary = Content.constants.UNITS[kind].respawn
	return (float(times.base) + float(times.perDeath) * deaths) * balance_multiplier("respawn")

func _ready() -> void:
	# Godot enables an overridden _physics_process on entry, but world preparation can
	# wait or fail before setup; Session cannot stop a battle it has not yet adopted.
	set_physics_process(false)

func setup(map_data: Dictionary, roster: Array, env: Dictionary, authority: bool, wait_for_launch: bool = false, prepared_world: BattleWorld = null) -> void:
	setup_complete = false
	setup_error = ""
	prepared_map = {}
	prepared_environment = {}
	set_physics_process(false)
	authoritative = authority
	if not map_data.get("native_world") is String or WorldVariant.identity(map_data.native_world, env).is_empty():
		_setup_failed("Missing authored native world identity; road-only worlds cannot initialize a match")
		return
	for key: String in ["weather", "hazard_visuals", "hazard_volumes", "playerView"]:
		if not Content.balance.has(key):
			_setup_failed("Missing original match metadata: " + key)
			return
	if not map_data.get("lane_turns") is Array:
		_setup_failed("Missing original lane turns for match hazard generation")
		return
	if not Session.dedicated and not Content.balance.has("geometryLod"):
		_setup_failed("Missing original geometry LOD rules; regenerate source content")
		return
	if not Content.constants.has("SLOPE") or not Content.balance.get("movement", {}).has("slope") or not Content.balance.get("movement", {}).has("climb"):
		_setup_failed("Missing original slope/climb traversal metadata; regenerate source content")
		return
	if not Session.dedicated and not CombatEffects.available():
		_setup_failed("Missing original combat effect scenes/textures; regenerate and pack NPC effects/projectiles")
		return
	if not Session.dedicated and not AuthoredCombatEffect.available():
		_setup_failed("Missing original hero discharge/fan scenes; regenerate and pack weapon effects/projectiles")
		return
	if not Session.dedicated and not FirstPersonShield.available():
		_setup_failed("Missing original first-person shield scenes; regenerate and pack camera shields")
		return
	if not Session.dedicated and not Content.balance.get("screenSplats", {}).has("paint"):
		_setup_failed("Missing original blood/glint gradient and filter metadata; regenerate source content")
		return
	if not Session.dedicated and not Content.balance.get("presentationFrame", {}).has("deathEffects"):
		_setup_failed("Missing original hitstop/death metadata; regenerate source content")
		return
	if not Session.dedicated and not Content.balance.has("deathOverlay"):
		_setup_failed("Missing original death-cinematic overlay metadata; regenerate source content")
		return
	if not Session.dedicated and not HeadMarks.available():
		_setup_failed("Missing original faction head-marker textures; regenerate source content")
		return
	if not Session.dedicated and not VitalBar.available():
		_setup_failed("Missing original overhead HP/shield bar templates; regenerate source content")
		return
	if not Session.dedicated and not MinimapWindow.available():
		_setup_failed("Missing original minimap window rules; regenerate source content")
		return
	recoil_random.randomize()
	authority_bounds = map_data.get("authority_bounds", {}).duplicate()
	if prepared_world != null:
		var prepared_key: Dictionary = prepared_world.get_meta("room_prebuild_identity", {})
		if not prepared_world.build_complete or prepared_world.get_parent() != self or prepared_key.get("map") != map_data or prepared_key.get("environment") != env:
			_setup_failed("Prepared native world does not match the selected map/environment")
			return
		world = prepared_world
	else:
		world = BattleWorld.new()
		add_child(world)
	world.build_progress.connect(func(): setup_progress.emit())
	world.missile_view_collision = missile_view_collision
	if prepared_world == null:
		await world.build(map_data, env)
	else:
		# Native collision bodies need to enter the destination physics space.
		for frame in range(2):
			await get_tree().physics_frame
			if not is_inside_tree() or is_queued_for_deletion():
				return
			setup_progress.emit()
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(world) or world.is_queued_for_deletion():
		return
	if not world.build_complete:
		_setup_failed(world.build_error)
		return
	var world_error := _match_world_error(map_data, env)
	if not world_error.is_empty():
		_setup_failed(world_error)
		return
	_setup_weather(map_data, env)
	world.prepare_lane_surface()
	bot_tower_sites = map_data.get("tower_sites", []).duplicate(true)
	bot_difficulty = env.get("bot_difficulty", Content.constants.DEFAULT_BOT_DIFF)
	siege = bool(map_data.config.get("siege", false))
	super_mode = bool(map_data.config.get("super", false)) and not siege
	if super_mode:
		super_random.randomize()
		match_stats[Content.constants.SUPER_SIDE] = {"kills": 0, "deaths": 0, "creepKills": 0, "assists": 0}
		vision_until[Content.constants.SUPER_SIDE] = 0.0
	var source_defender: Variant = map_data.config.get("defSide")
	defending_side = source_defender if source_defender is String else ""
	if not defending_side.is_empty() and (defending_side not in ["SWARM", "STEEL"] or bot_tower_sites.is_empty() or world.lane_points.is_empty()):
		_setup_failed("Missing original campaign defender/tower-site configuration")
		return
	for side: String in creep_upgrades:
		creep_upgrades[side].resize(world.paths.size())
		creep_upgrades[side].fill(0)
	prepared_map = map_data.duplicate(true)
	prepared_environment = env.duplicate(true)
	setup_complete = true
	if not authoritative:
		set_physics_process(not wait_for_launch)
		return
	if not wait_for_launch:
		begin_match(map_data, roster)

func _setup_failed(reason: String) -> void:
	if not setup_error.is_empty():
		return
	setup_complete = false
	setup_error = reason
	push_error(reason)
	failure_reported.emit(reason)

func begin_match(map_data: Dictionary, roster: Array) -> bool:
	if not authoritative or match_initialized:
		return false
	if not setup_complete or not setup_error.is_empty():
		_setup_failed("Cannot initialize a match before successful native world preparation")
		return false
	if map_data != prepared_map:
		_setup_failed("Match map changed after native world preparation")
		return false
	var world_error := _match_world_error(map_data, prepared_environment)
	if not world_error.is_empty():
		_setup_failed(world_error)
		return false
	# Resolve every structure anchor before spawning any unit or spending combat RNG.
	var structures: Array[Dictionary] = []
	for info in map_data.structures:
		var data: Dictionary = info.duplicate()
		data.position = Vector3(info.position[0], info.position[1], info.position[2])
		data.position.y = world.structure_height(str(data.kind), data.position.x, data.position.z)
		if not is_finite(data.position.y):
			_setup_failed("Structure has no verified standing surface")
			return false
		structures.append(data)
	for data: Dictionary in structures:
		spawn(data)
	_setup_siege_counts()
	next_wave = Content.constants.GAME.FIRST_WAVE_DELAY_S
	next_airdrop = Content.constants.AIRDROP.INTERVAL_S
	_prefill_lanes(map_data)
	_seed_scene_hazards(map_data)
	if not _populate_heroes(map_data, roster):
		return false
	match_initialized = true
	set_physics_process(true)
	return true

func _match_world_error(map_data: Dictionary, env: Dictionary) -> String:
	if not is_instance_valid(world) or world.is_queued_for_deletion() or world.get_parent() != self or not world.build_complete or not world.build_error.is_empty():
		return "Native world preparation is incomplete"
	if not world.native_data is NativeWorldData or world.native_data.scene == null:
		return "Missing original native world data; road-only worlds cannot initialize a match"
	var native: NativeWorldData = world.native_data
	var base: Variant = map_data.get("native_world")
	if not base is String or not WorldVariant.matches_identity(native.source.get("identity", {}), WorldVariant.identity(base, env)):
		return "Native world identity does not match the prepared match"
	if not native.slabs_captured or not native.supports_captured or not native.climbs_captured:
		return "Missing original structure, support or traversal capture for match initialization"
	if not native.structure_pads.get("tower") is Array or not native.structure_pads.get("base") is Array:
		return "Missing original tower/base platform anchors for match initialization"
	if native.bounds != map_data.get("bounds") or world.bounds != native.bounds:
		return "Native world bounds do not match the prepared match"
	if native.terrain_grid < 2 or native.terrain_heights.size() != native.terrain_grid * native.terrain_grid or native.water_profile.is_empty() or world.authority_height_grid.is_empty():
		return "Missing original terrain/water/weather profile for match initialization"
	if not native.water_profile.has("obstacles"):
		return "Missing original environment obstacles for match initialization"
	var lanes: Array = map_data.get("lanes", [])
	if lanes.is_empty() or world.paths.size() != lanes.size() or world.lane_points != lanes or native.lane_heights.size() != lanes.size():
		return "Incomplete original lane geometry for match initialization"
	for index in lanes.size():
		if not native.lane_heights[index] is Array or native.lane_heights[index].size() != lanes[index].size():
			return "Incomplete original lane heights for match initialization"
	return ""

func _populate_heroes(map_data: Dictionary, roster: Array) -> bool:
	if not authoritative or world == null or world.paths.is_empty():
		return false
	var slots := {"SWARM": 0, "STEEL": 0, "SUPER": 0}
	var bot_index := 0
	for player in roster:
		var previous: Array = pilots.values().map(func(unit): return {"side": unit.side, "character": unit.character})
		var character := RoomRoles.choose(player.side, player.get("character", ""), previous, rng.next)
		if character.is_empty():
			_setup_failed("No original character is available for the selected faction")
			return false
		player.character = character
		var hero: Dictionary = Content.heroes[player.character]
		var data: Dictionary = player.duplicate()
		data.kind = hero.kind
		data.spawn_slot = slots[player.side]
		data.lane = (bot_index if player.get("bot", false) else int(slots[player.side])) % world.paths.size()
		data.position = _super_spawn_position(int(player.peer)) if player.side == Content.constants.SUPER_SIDE else world.spawn_position(player.side, slots[player.side], hero.kind == "drone" and not player.get("bot", false))
		if player.side == defending_side:
			var plan := SiegeRules.slot_plan(int(map_data.config.teamSize))
			var slot: int = slots[player.side]
			var stage: int = int(plan[slot]) if slot < plan.size() else int(Content.constants.SIEGE.BASE)
			var same_stage := plan.slice(0, slot).count(stage)
			var base: Vector3 = world.bases[defending_side]
			var anchor := SiegeRules.anchor(defending_side, stage, same_stage, bot_tower_sites[0], world.lane_points[0], Vector2(base.x, base.z))
			data.special = {"boss": true, "boss_segment": 0, "siege_stage": stage}
			data.position = Vector3(anchor.x, _npc_surface(anchor) + 0.1, anchor.y) if anchor.is_finite() else Vector3(INF, INF, INF)
			bot_holds[int(player.peer)] = {"x": anchor.x, "z": anchor.y, "r": float(Content.constants.UNITS.tower.range) * float(Content.constants.BOSS.ZONE_F)}
		if not data.position.is_finite():
			_setup_failed("Hero spawn has no verified standing surface")
			return false
		var unit := spawn(data)
		pilots[int(player.peer)] = unit
		if unit.special.get("boss", false):
			var stage: int = int(unit.special.siege_stage)
			siege_left[unit.side][stage] += 1
			boss_left[unit.side][stage] += 1
			siege_open[unit.side] = SiegeRules.open_stage(siege_left[unit.side])
		slots[player.side] += 1
		if unit.is_bot:
			_create_bot_brain(unit)
			if not setup_error.is_empty():
				return false
			bot_index += 1
	_refresh_siege_locks()
	return true

func _super_spawn_position(peer: int, hover: bool = false) -> Vector3:
	var guns: Array = []
	for unit: BattleUnit in units.values():
		if unit.kind in ["tower", "base"] and unit.hp > 0:
			guns.append({"kind": unit.kind, "side": unit.side, "x": unit.position.x, "z": unit.position.z})
	for side: String in ["SWARM", "STEEL"]:
		if not guns.any(func(gun): return gun.kind == "base" and gun.side == side):
			var base: Vector3 = world.bases[side]
			guns.append({"kind": "base", "side": side, "x": base.x, "z": base.z})
	var blockers := hazard_blockers.map(func(obstacle): return {"x": obstacle.x, "z": obstacle.z, "r": obstacle.radius})
	var point := SuperRules.spawn_point(super_random.randf, authority_bounds, world.lane_points, guns, blockers, _terrain_blocked, super_spawns.get(peer, last_super_spawn))
	last_super_spawn = point
	super_spawns[peer] = point
	var surface := _npc_surface(point)
	return Vector3(point.x, surface + (float(Content.constants.FLIGHT.HOVER_M) if hover else 0.1), point.y) if is_finite(surface) else Vector3(INF, INF, INF)

func _setup_siege_counts() -> void:
	var count: int = Content.constants.SIEGE.STAGES.size()
	for side: String in ["SWARM", "STEEL"]:
		siege_left[side] = []
		boss_left[side] = []
		siege_talk_until[side] = []
		for stage in range(count):
			siege_left[side].append(0)
			boss_left[side].append(0)
			siege_talk_until[side].append(0.0)
		for unit: BattleUnit in units.values():
			var stage: int = int(unit.special.get("siege_stage", -1))
			if unit.side == side and stage >= 0 and stage < count:
				siege_left[side][stage] += 1
		siege_open[side] = SiegeRules.open_stage(siege_left[side])

func siege_locked(unit: BattleUnit) -> bool:
	var stage: int = int(unit.special.get("siege_stage", -1))
	return siege and stage > int(siege_open.get(unit.side, 0)) if stage >= 0 else bool(unit.special.get("siege_locked", false))

func _refresh_siege_locks() -> void:
	for unit: BattleUnit in units.values():
		if unit.special.has("siege_stage"):
			unit.special.siege_locked = siege_locked(unit)

func _siege_hp_floor(unit: BattleUnit) -> float:
	var stage: int = int(unit.special.get("siege_stage", -1))
	var left: Array = boss_left.get(unit.side, [])
	var until: Array = siege_talk_until.get(unit.side, [])
	if not siege or unit.is_hero() or stage < 0 or stage >= left.size():
		return 0.0
	return float(Content.constants.SIEGE.BLD_HP_FLOOR) if int(left[stage]) > 0 or clock < float(until[stage]) else 0.0

func _ally_bot_damage_factor(unit: BattleUnit, attacker: BattleUnit) -> float:
	if defending_side.is_empty() or attacker == null or not attacker.is_hero() or attacker.peer_id >= 0 or attacker.side == defending_side or unit.side != defending_side:
		return 1.0
	if unit.special.get("boss", false):
		return float(Content.constants.STORY_MAP.ALLY_BOT_BOSS_F)
	return float(Content.constants.STORY_MAP.ALLY_BOT_BLD_F) if unit.kind in ["tower", "base"] else 1.0

func _siege_fell(unit: BattleUnit) -> void:
	var stage: int = int(unit.special.get("siege_stage", -1))
	var left: Array = siege_left.get(unit.side, [])
	if stage < 0 or stage >= left.size():
		return
	left[stage] = maxi(0, int(left[stage]) - 1)
	var opened := SiegeRules.open_stage(left)
	var previous: int = int(siege_open[unit.side])
	if opened != previous:
		siege_open[unit.side] = opened
		_refresh_siege_locks()
		if siege:
			events.append({"type": "siege", "actor": 0, "side": unit.side, "stage": previous})

func _boss_fell(unit: BattleUnit) -> void:
	var stage: int = int(unit.special.get("siege_stage", -1))
	var left: Array = boss_left.get(unit.side, [])
	if stage < 0 or stage >= left.size():
		return
	left[stage] = maxi(0, int(left[stage]) - 1)
	if int(left[stage]) > 0:
		return
	siege_talk_until[unit.side][stage] = clock + SiegeRules.talk_seconds(stage)
	events.append({"type": "siege_talk", "actor": 0, "side": unit.side, "stage": stage})

func _boss_sync(unit: BattleUnit) -> void:
	if not authoritative or not unit.special.get("boss", false) or unit.special.get("role") == "clone":
		return
	# Current source SQUAD.N is one. Clones are not squad HP segments.
	var segment := SiegeRules.segment_of(maxf(0, unit.hp) / unit.max_hp if unit.max_hp > 0 else 1.0)
	var previous: int = int(unit.special.get("boss_segment", 0))
	if segment <= previous:
		return
	for step in range(previous, segment):
		for item: String in Content.constants.ECON.UPGRADES:
			var definition: Dictionary = Content.constants.ECON.UPGRADES[item]
			if int(unit.upgrades.get(item, 0)) >= int(definition.max):
				continue
			var fraction := unit.hp / unit.max_hp if item == "hp" and unit.max_hp > 0 else 0.0
			unit.upgrades[item] = int(unit.upgrades.get(item, 0)) + 1
			_apply_upgrade(unit, item)
			if item == "hp":
				unit.hp = minf(unit.max_hp, floorf(unit.max_hp * fraction + 0.5))
	unit.special.boss_segment = segment
	if unit.alive():
		unit.shield = unit.max_shield
		unit.status.inv_until = maxf(float(unit.status.get("inv_until", 0)), clock + SiegeRules.invulnerability(segment))
	unit.refresh_body_scale()
	events.append({"type": "boss_segment", "actor": unit.entity_id, "peer": unit.peer_id, "side": unit.side, "segment": segment})

func _seed_scene_hazards(map_data: Dictionary) -> void:
	if not map_data.has("lane_turns") or not Content.balance.has("hazard_visuals") or not Content.balance.has("hazard_volumes") or not Content.balance.has("playerView"):
		push_error("Missing original hazard generation/model metadata; regenerate migration data")
		return
	var bases := {}
	for side: String in ["SWARM", "STEEL"]:
		bases[side] = [float(world.bases[side].x), float(world.bases[side].z)]
	var state := {"lanes": world.lane_points, "cumulative": world.lane_distances, "turns": map_data.lane_turns,
		"bases": bases, "bounds": authority_bounds, "towers": []}
	for unit: BattleUnit in units.values():
		if unit.kind == "tower":
			state.towers.append({"x": unit.position.x, "z": unit.position.z})
	var scene_seed := weather_seed ^ (int(map_data.config.get("teamSize", 5)) << 20)
	var random := SourceRng.new(scene_seed)
	SceneRules.seed_mines(random, state)
	SceneRules.seed_hazards(random, state, world.wet_at, map_data.config.get("venue", {}).get("mix", {}))
	SceneRules.seed_vehicles(random, state, world.wet_at)
	SceneRules.ensure_connectivity(state)
	SceneRules.seed_field_sites(random, state)
	SceneRules.prune_corridors(state, world.native_data.corridors)
	for mine: Dictionary in state.mines:
		mine.id = next_id
		next_id += 1
		mines.append(mine)
	hazard_blockers = state.blockers
	for entry: Dictionary in state.actors:
		var surface := world.source_height(entry.x, entry.z)
		if not is_finite(surface):
			push_error("Hazard has no original terrain anchor")
			continue
		if entry.kind == "ship" and world.water_y != null:
			surface = maxf(surface, world.water_y)
		var point := Vector3(entry.x, surface, entry.z)
		if entry.kind in ["fire", "forestfire", "grassfire", "factoryfire"]:
			_spawn_fire(entry.kind, point, entry.scale)
			continue
		var unit := spawn({"kind": entry.kind, "side": "", "position": point,
			"special": {"role": "hazard", "neutral": true, "hp": entry.hp, "armor": entry.armor,
				"scale": entry.scale, "electric": entry.electric, "vehicle": entry.vehicle, "invulnerable": entry.invulnerable,
				"relay_charge": 0.0, "relay_side": ""}})
		if entry.kind == "relay":
			entry.id = unit.entity_id
	# The original corridor prune removes visible relay actors but retains its capture roster.
	for entry: Dictionary in state.relays:
		if not entry.has("id"):
			entry.id = next_id
			next_id += 1
		relay_states.append({"id": entry.id, "position": Vector3(entry.x, 0, entry.z), "charge": 0.0, "side": ""})
	if _camp_content_ready():
		for camp: Dictionary in CampRules.seed(random, state, _terrain_blocked):
			_spawn_camp(camp)
		world.clear_camp_columns(camps)
		_seed_civilians()

func _camp_content_ready() -> bool:
	var profiles: Dictionary = Content.balance.get("companions", {})
	var keys: Array[String] = []
	for side: String in ["GUER", "MILI"]:
		for kind: String in ["bunker"] + Content.constants.THIRD.COMP[side]:
			if not BodyRig.available(BodyRig.entity_key(side, kind)):
				push_error("Missing original camp body rig: " + BodyRig.entity_key(side, kind))
				return false
			keys.append("%s_%s" % [side.to_lower(), kind])
	for key: String in keys:
		if not profiles.has(key):
			push_error("Original camp/civilian content is unavailable; regenerate and pack companion resources: " + key)
			return false
	if not Content.balance.has("civilian_appearance"):
		push_error("Missing original civilian appearance tables")
		return false
	if not CivilianBodyBuilder.available():
		push_error("Missing original civilian component scenes; regenerate and pack civilian parts")
		return false
	return true

func _spawn_camp(info: Dictionary) -> void:
	var camp: Dictionary = info.duplicate()
	camp.bunker = 0
	camp.bunker_remaining = 0.0
	camp.pool = []
	camp.freed = false
	var index := camps.size()
	camps.append(camp)
	camp.bunker = _spawn_camp_unit(index, "bunker", 0).entity_id
	for slot in range(Content.constants.THIRD.COMP[camp.side].size()):
		_spawn_camp_unit(index, Content.constants.THIRD.COMP[camp.side][slot], slot)

func _spawn_camp_unit(index: int, kind: String, slot: int) -> BattleUnit:
	var camp: Dictionary = camps[index]
	var point := {"x": camp.x, "z": camp.z} if kind == "bunker" else CampRules.home(camp, slot)
	var surface := world.source_height(point.x, point.z) if world != null else 0.0
	var altitude := float(Content.constants.GAME.HELI_ALT) if kind == "heli" else 0.0
	return spawn({"kind": kind, "side": camp.side, "position": Vector3(point.x, surface + altitude, point.z),
		"special": {"role": "third", "third": true, "camp_index": index, "slot": slot, "garrison": false,
			"retreat": false, "seek": false, "aggro_id": 0, "aggro_at": 0.0}})

func _camp_state(unit: BattleUnit) -> Dictionary:
	return {"kind": unit.kind, "side": unit.side, "slot": int(unit.special.slot), "x": float(unit.position.x), "z": float(unit.position.z),
		"hp": unit.hp, "max_hp": unit.max_hp, "garrison": unit.special.garrison, "retreat": unit.special.retreat,
		"seek": unit.special.seek, "aggro_at": unit.special.aggro_at,
		"stun": unit.has_status("stun_until", clock), "slow": unit.has_status("slow_until", clock),
		"slow_factor": float(unit.status.get("slow_factor", 0.6)), "confuse": unit.has_status("confuse_until", clock)}

func _set_scalar_point(unit: BattleUnit, point: Dictionary) -> void:
	var height := world.source_height(point.x, point.z) if world != null else 0.0
	if not is_finite(height):
		push_error("Scalar actor has no original terrain anchor")
		return
	unit.position = Vector3(point.x, height + (float(Content.constants.GAME.HELI_ALT) if unit.kind == "heli" else 0.0), point.z)

func _ungarrison(unit: BattleUnit) -> void:
	unit.special.garrison = false
	_set_scalar_point(unit, CampRules.home(camps[int(unit.special.camp_index)], int(unit.special.slot)))
	unit.refresh_collision()

func _camp_behavior(unit: BattleUnit, delta: float) -> void:
	if not authoritative:
		return
	var camp: Dictionary = camps[int(unit.special.camp_index)]
	var count := 0
	for member: BattleUnit in units.values():
		if member.special.get("third", false) and member.special.camp_index == unit.special.camp_index and member.special.get("garrison", false):
			count += 1
	var plan := CampRules.behavior(_camp_state(unit), camp, count, delta)
	var changed: bool = unit.special.garrison != plan.garrison
	unit.hp = plan.hp
	for key: String in ["garrison", "retreat", "seek"]:
		unit.special[key] = plan[key]
	_set_scalar_point(unit, plan)
	if changed:
		unit.refresh_collision()
	unit.visible = unit.presentation_visible and not unit.special.garrison

func _camp_aggro_target(unit: BattleUnit) -> BattleUnit:
	var target: BattleUnit = units.get(int(unit.special.aggro_id))
	if target != null and CampRules.aggro_valid(_camp_state(unit), {"hp": target.hp, "dead": not target.alive(), "side": target.side, "stealth": target.has_status("stealth_until", clock)}, clock):
		return target
	unit.special.aggro_id = 0
	return null

func _move_camp_unit(unit: BattleUnit, profile: Dictionary, delta: float) -> void:
	var camp: Dictionary = camps[int(unit.special.camp_index)]
	var target: BattleUnit
	if not unit.special.retreat and not unit.special.seek and not unit.special.garrison and not unit.has_status("stun_until", clock):
		target = _camp_aggro_target(unit)
		if target == null:
			target = _npc_acquire(unit, {"range": profile.get("sight", profile.range), "wid": profile.get("wid", "")})
	var goal := {"x": target.position.x, "z": target.position.z} if target != null else {}
	_set_scalar_point(unit, CampRules.move(_camp_state(unit), camp, profile, goal, delta, _terrain_blocked, hazard_blockers))

func _tick_camps(delta: float) -> void:
	if not authoritative:
		return
	for index in range(camps.size()):
		var camp: Dictionary = camps[index]
		if not camp.bunker:
			camp.bunker_remaining = float(camp.bunker_remaining) - delta
			if camp.bunker_remaining <= 0:
				camp.bunker = _spawn_camp_unit(index, "bunker", 0).entity_id
			continue
		for slot in range(camp.pool.size() - 1, -1, -1):
			var pending: Dictionary = camp.pool[slot]
			pending.remaining = float(pending.remaining) - delta
			if pending.remaining <= 0:
				camp.pool.remove_at(slot)
				_spawn_camp_unit(index, pending.kind, int(pending.slot))

func _on_third_death(unit: BattleUnit, attacker: BattleUnit) -> void:
	var index := int(unit.special.camp_index)
	var camp: Dictionary = camps[index]
	if unit.kind == "bunker":
		camp.bunker = 0
		camp.bunker_remaining = Content.constants.THIRD.BUNKER_RESPAWN_S
		for member: BattleUnit in units.values():
			if member.special.get("third", false) and int(member.special.camp_index) == index and member.special.get("garrison", false):
				_ungarrison(member)
	else:
		camp.pool.append({"kind": unit.kind, "slot": unit.special.slot, "remaining": Content.constants.THIRD.UNIT_RESPAWN_S})
	if camp.freed:
		return
	for member: BattleUnit in units.values():
		if member.special.get("third", false) and int(member.special.camp_index) == index:
			return
	camp.freed = true
	_free_camp_civilians(camp, attacker)

func _civilian_placement() -> Dictionary:
	var bases := {}
	for side: String in ["SWARM", "STEEL"]:
		bases[side] = [world.bases[side].x, world.bases[side].z]
	return {"bounds": authority_bounds, "lanes": world.lane_points, "bases": bases, "towers": [], "blockers": hazard_blockers}

func _spawn_civilian(side: String, spy: bool, profession: int, point: Dictionary) -> BattleUnit:
	var surface := world.source_height(point.x, point.z) if world != null else 0.0
	return spawn({"kind": "civilian", "side": "", "position": Vector3(point.x, surface, point.z),
		"special": {"role": "civilian", "neutral": true, "civil_side": side, "spy": spy, "profession": profession,
			"home": Vector2(point.x, point.z), "waypoint": null, "pause": rng.next() * float(Content.constants.CIVILIAN.WANDER_PAUSE[1]),
			"follow_peer": 0, "follow_time": 0.0, "flee": false, "flee_ttl": 0.0, "flee_point": Vector2.ZERO, "no_respawn": false}})

func _seed_civilians() -> void:
	if not authoritative:
		return
	var cfg: Dictionary = Content.constants.CIVILIAN
	var placement := _civilian_placement()
	var count: int = int(cfg.PER_SIDE_BASE) + int(cfg.PER_SIDE_PER_LANE) * placement.lanes.size()
	var spies := int(floorf(count * float(cfg.SPY_RATE) + 0.5))
	for side: String in ["SWARM", "STEEL"]:
		for index in range(count):
			var point := CivilianRules.point(rng, placement, _terrain_blocked)
			if not point.is_empty():
				_spawn_civilian(side, index < spies, int(floorf(rng.next() * Content.constants.CIVILIANS.size())), point)

func _free_camp_civilians(camp: Dictionary, attacker: BattleUnit) -> void:
	if not authoritative:
		return
	var owner: BattleUnit = attacker if attacker != null and attacker.is_hero() and pilots.has(attacker.peer_id) and attacker.alive() else null
	if owner == null:
		var nearest := INF
		for unit: BattleUnit in pilots.values():
			var distance := _planar_distance(unit.position, Vector3(camp.x, 0, camp.z))
			if unit.alive() and distance < nearest:
				nearest = distance
				owner = unit
	var count := int(Content.constants.THIRD.CLEAR_CIVS)
	for index in range(count):
		var angle := float(index) / count * TAU
		var point := {"x": float(camp.x) + cos(angle) * float(Content.constants.THIRD.FORM_R), "z": float(camp.z) - sin(angle) * float(Content.constants.THIRD.FORM_R)}
		var side := "SWARM" if rng.next() < 0.5 else "STEEL"
		var civilian := _spawn_civilian(side, false, int(floorf(rng.next() * Content.constants.CIVILIANS.size())), point)
		civilian.special.no_respawn = true
		civilian.special.home = Vector2(camp.x, camp.z)
		if owner != null:
			civilian.special.follow_peer = owner.peer_id
	if owner != null:
		events.append({"type": "civfree", "actor": owner.entity_id, "peer": owner.peer_id, "side": owner.side, "position": Vector3(camp.x, 0, camp.z), "count": count})

func _move_civilian(unit: BattleUnit, goal: Vector2, movement_speed: float, delta: float, away: bool = false) -> void:
	var point := CivilianRules.move({"x": unit.position.x, "z": unit.position.z}, goal, movement_speed, delta, authority_bounds, _terrain_blocked, away)
	if not point.is_empty():
		_set_scalar_point(unit, point)
		unit.yaw = point.yaw
		unit.rotation.y = unit.yaw

func _tick_civilians(delta: float) -> void:
	if not authoritative:
		return
	var cfg: Dictionary = Content.constants.CIVILIAN
	var placement := _civilian_placement()
	var remaining: Array[Dictionary] = []
	for pending: Dictionary in civilian_respawns:
		if clock < float(pending.at):
			remaining.append(pending)
			continue
		var point := CivilianRules.point(rng, placement, _terrain_blocked)
		if point.is_empty():
			remaining.append(pending)
		else:
			_spawn_civilian(pending.side, pending.spy, int(floorf(rng.next() * Content.constants.CIVILIANS.size())), point)
	civilian_respawns = remaining
	for unit: BattleUnit in units.values():
		if unit.special.get("role") != "civilian":
			continue
		var state: Dictionary = unit.special
		var movement_speed := CivilianRules.speed(state.spy)
		if state.flee:
			state.flee_ttl = float(state.flee_ttl) - delta
			if state.flee_ttl <= 0:
				_remove_field_unit(unit.entity_id)
			else:
				_move_civilian(unit, state.flee_point, movement_speed * float(cfg.FLEE_SPEED_F), delta, true)
			continue
		if int(state.follow_peer) != 0:
			var owner: BattleUnit = pilots.get(int(state.follow_peer))
			if owner == null or not owner.alive() or _planar_distance(unit.position, owner.position) > float(cfg.FOLLOW_LINK_M):
				state.follow_peer = 0
				state.follow_time = 0.0
			else:
				if _planar_distance(unit.position, owner.position) > float(cfg.FOLLOW_R):
					_move_civilian(unit, Vector2(owner.position.x, owner.position.z), movement_speed, delta)
				if state.civil_side == owner.side:
					state.follow_time = float(state.follow_time) + delta
					if state.follow_time >= float(cfg.FOLLOW_REWARD_S):
						state.follow_time -= float(cfg.FOLLOW_REWARD_S)
						var event := {"type": "civaid", "actor": owner.entity_id, "peer": owner.peer_id, "civilian": unit.entity_id, "profession": state.profession, "side": owner.side, "position": unit.position}
						event.merge(_grant_reward(owner, Content.constants.CIVILIANS[int(state.profession)].reward, cfg.FOLLOW_MUL))
						events.append(event)
				continue
		if state.pause > 0:
			state.pause = float(state.pause) - delta
			continue
		if state.waypoint == null or Vector2(unit.position.x, unit.position.z).distance_to(state.waypoint) < 2:
			var point := CivilianRules.wander(rng, placement, state.home, _terrain_blocked)
			state.waypoint = Vector2(point.x, point.z)
			state.pause = float(cfg.WANDER_PAUSE[0]) + rng.next() * (float(cfg.WANDER_PAUSE[1]) - float(cfg.WANDER_PAUSE[0]))
			continue
		_move_civilian(unit, state.waypoint, movement_speed, delta)

func _civilian_interact(unit: BattleUnit, id: int, action_name: String) -> void:
	var target: BattleUnit = units.get(id)
	if not authoritative or over or not unit.alive() or target == null or not target.alive() or target.special.get("role") != "civilian":
		return
	if _planar_distance(unit.position, target.position) > float(Content.constants.CIVILIAN.INTERACT_R) * 1.25:
		return
	var state: Dictionary = target.special
	state.follow_time = 0.0
	if action_name == "away":
		state.follow_peer = 0
		state.flee = true
		state.flee_ttl = Content.constants.CIVILIAN.FLEE_TTL_S
		state.flee_point = Vector2(unit.position.x, unit.position.z)
	else:
		state.flee = false
		state.follow_peer = unit.peer_id
	events.append({"type": "civact", "actor": unit.entity_id, "peer": unit.peer_id, "action": "away" if action_name == "away" else "follow", "position": target.position, "civil_side": state.civil_side})

func nearest_civilian(unit: BattleUnit) -> BattleUnit:
	if not unit.alive():
		return null
	var target: BattleUnit
	var best := float(Content.constants.CIVILIAN.INTERACT_R)
	for civilian: BattleUnit in units.values():
		if civilian.special.get("role") != "civilian" or not civilian.visible:
			continue
		var distance := _planar_distance(unit.position, civilian.position)
		if distance < best:
			best = distance
			target = civilian
	return target

func _kill_civilian(unit: BattleUnit, attacker: BattleUnit) -> void:
	var state: Dictionary = unit.special.duplicate(true)
	var point := unit.position
	_remove_field_unit(unit.entity_id, true)
	if attacker != null and attacker.is_hero():
		var amount := CivilianRules.kill_reward(attacker.side == state.civil_side, state.spy)
		attacker.money = maxf(0, attacker.money + amount)
		events.append({"type": "civkill", "actor": attacker.entity_id, "peer": attacker.peer_id, "side": attacker.side, "position": point, "value": amount, "spy": state.spy, "civil_side": state.civil_side})
	if not state.no_respawn:
		civilian_respawns.append({"side": state.civil_side, "spy": state.spy, "at": clock + float(Content.constants.CIVILIAN.RESPAWN_S)})

func _setup_weather(map_data: Dictionary, environment: Dictionary) -> void:
	if not Content.balance.has("weather"):
		push_error("Missing source weather rules; regenerate migration data before running the battle")
		return
	var center: Dictionary = map_data.config.get("center", {})
	weather_start = {"season": environment.get("season", "summer"), "time": environment.get("time", "day"),
		"weather": environment.get("weather", "clear"), "latitude": center.get("lat", 25.0)}
	weather_seed = int(floorf(float(center.get("lat", 0)) * 10000 + 0.5)) * 31 + int(floorf(float(center.get("lng", 0)) * 10000 + 0.5))
	weather_schedule = WeatherRules.solar_schedule(weather_start.season, weather_start.latitude, 0, int(environment.get("lunarDay", 15)))
	weather_vector = WeatherRules.vector_at(weather_start.season, weather_start.time, weather_start.weather, 0, weather_seed, weather_start.latitude)
	weather_dynamics = WeatherRules.dynamics(weather_vector)
	weather_surface = WeatherRules.surface_step()
	weather_fog = weather_dynamics.fog
	world.sync_weather(weather_dynamics, weather_surface, WeatherRules.clock_hour(weather_start.time, 0, weather_schedule), weather_schedule, weather_start.season, weather_seed)

func _weather_air(unit: BattleUnit) -> bool:
	return unit.flying or (unit.is_hero() and _air_unit(unit)) or unit.kind == "heli" or CombatMath.target_class(unit.kind) == "air" or _missile_target_altitude(unit) > 0

func _update_fluid_state(unit: BattleUnit) -> void:
	if world == null or world.native_data == null or world.native_data.water_profile.is_empty():
		return
	var surface := _movement_surface(unit.position)
	var bare := world.source_height(unit.position.x, unit.position.z)
	if not is_finite(surface) or not is_finite(bare):
		return
	unit.fluid_environment = EnvironmentRules.environment(world.water_code(unit.position.x, unit.position.z), world.water_y,
		unit.position.y, unit.height, bool(weather_dynamics.get("isFrozen", false)), unit.flying, surface, bare)
	unit.wet = int(unit.fluid_environment.code)

func _movement_surface(point: Vector3) -> float:
	var surface := _weapon_surface(point)
	var tunnel := world.layers.tunnel_at(Vector2(point.x, point.z))
	if not tunnel.is_empty() and point.y < float(tunnel.ceil):
		return surface
	return EnvironmentRules.ice_surface(surface, point.y, world.water_plane(point.x, point.z), bool(weather_dynamics.get("isFrozen", false)))

func movement_slope_queries() -> Dictionary:
	return {"height": world.source_height, "surface": _slope_surface, "tunnel": _slope_tunnel, "deck": _slope_deck,
		"deck_margin": float(Content.balance.structure.deckMargin)}

func _slope_surface(x: float, z: float, y: float) -> float:
	return _movement_surface(Vector3(x, y, z))

func _slope_tunnel(x: float, z: float) -> Dictionary:
	return world.layers.tunnel_at(Vector2(x, z))

func _slope_deck(x: float, z: float, margin: float) -> Variant:
	return world.layers.deck_height(Vector2(x, z), margin)

func _ice_ceiling(point: Vector3) -> Variant:
	return EnvironmentRules.ice_ceiling(null, point.y, world.water_plane(point.x, point.z), bool(weather_dynamics.get("isFrozen", false)))

func weather_attack_rate(unit: BattleUnit) -> float:
	if weather_dynamics.is_empty():
		return 1.0
	return WeatherRules.air_rate(weather_dynamics) if _weather_air(unit) else WeatherRules.ground_rate(weather_surface)

func weather_movement(_unit: BattleUnit, direction: Vector3, airborne: bool, ground_mode: bool = false) -> float:
	if weather_dynamics.is_empty():
		return 1.0
	var factor := WeatherRules.ground_speed(weather_surface) if ground_mode or not airborne else 1.0
	if airborne:
		factor *= WeatherRules.wind_speed(direction.x, direction.z, weather_dynamics.windDir, weather_dynamics.wind)
	return factor

func _weather_accuracy_penalty() -> float:
	if weather_start.is_empty():
		return 0.0
	return WeatherRules.accuracy_penalty(float(weather_dynamics.get("effectiveFog", 0)), WeatherRules.clock_hour(weather_start.time, clock, weather_schedule), weather_schedule)

func _companion_weather_speed(unit: BattleUnit) -> float:
	return 1.0 if weather_dynamics.is_empty() or _weather_air(unit) else WeatherRules.ground_speed(weather_surface)

func _wave_weather_factor(unit: BattleUnit, controls: Dictionary) -> float:
	if weather_dynamics.is_empty():
		return 1.0
	var airborne := unit.kind == "heli" or CombatMath.target_class(unit.kind) == "air"
	if not airborne:
		return WeatherRules.ground_speed(weather_surface)
	var cumulative: Array = world.lane_distances[unit.lane]
	var points: Array = world.lane_points[unit.lane]
	var progress := unit.npc_progress if unit.side == "SWARM" else float(cumulative[-1]) - unit.npc_progress
	var index := 1
	while index < cumulative.size() - 1 and float(cumulative[index]) < progress:
		index += 1
	var sign_value := (1.0 if unit.side == "SWARM" else -1.0) * (-1.0 if controls.confuse else 1.0)
	return WeatherRules.wind_speed((float(points[index][0]) - float(points[index - 1][0])) * sign_value,
		(float(points[index][1]) - float(points[index - 1][1])) * sign_value, weather_dynamics.windDir, weather_dynamics.wind)

func _lightning_states(unit: BattleUnit, now: float) -> Array:
	var states: Array = []
	for key: String in ["emp_until", "blind_until", "stun_until", "slow_until", "confuse_until", "sup_until", "mark_until", "unbalanced_until",
		"stealth_until", "inv_until", "phase_until", "reflect_until", "rooted_until", "shield_expand_until", "shield_def_boost_until",
		"shield_bash_until", "no_reload_until", "no_light_reload_until", "no_heavy_reload_until", "clones_until", "def_jump_until"]:
		var until: float = unit.status.get(key, 0)
		if until > now:
			states.append([key, until])
	if float(unit.bleed.get("until", 0)) > now:
		states.append(["bleed", unit.bleed.until])
	for buff: Dictionary in unit.buffs:
		if float(buff.until) > now:
			states.append(buff.duplicate(true))
	return states

func _tick_weather(delta: float) -> void:
	if weather_start.is_empty():
		return
	weather_elapsed += delta
	weather_vector = WeatherRules.vector_at(weather_start.season, weather_start.time, weather_start.weather, weather_elapsed, weather_seed, weather_start.latitude)
	weather_dynamics = WeatherRules.dynamics(weather_vector, weather_dynamics, delta)
	weather_fog = weather_dynamics.fog
	weather_surface = WeatherRules.surface_step(weather_surface, weather_dynamics, delta)
	_tick_weather_effects(delta)
	if world != null:
		world.sync_weather(weather_dynamics, weather_surface, WeatherRules.clock_hour(weather_start.time, weather_elapsed, weather_schedule), weather_schedule, weather_start.season, weather_seed)

func _tick_weather_effects(delta: float) -> void:
	for unit: BattleUnit in units.values():
		var scorch: Dictionary = unit.status.get("lightning_scorch", {})
		if scorch.is_empty():
			continue
		var states := _lightning_states(unit, clock)
		if not unit.alive() or unit.hp >= unit.max_hp or unit.hp > float(scorch.hp) or states.any(func(state): return not scorch.states.has(state)):
			unit.status.erase("lightning_scorch")
		else:
			scorch.hp = unit.hp
	var snow: float = weather_dynamics.get("effectiveSnow", 0)
	var snow_cover := WeatherRules.surface_cover(float(weather_surface.get("snow", 0)))
	var step := int(floorf(clock))
	if (snow > 0 or snow_cover > 0) and weather_last_freeze_step != step:
		weather_last_freeze_step = step
		var random := SourceRng.new(weather_seed ^ (step * 0x85ebca6b))
		for unit: BattleUnit in units.values():
			if not unit.alive() or unit.special.get("invulnerable", false) or unit.special.get("role") == "slab":
				continue
			# Source `lastFreezeAt || -COOLDOWN` treats a zero timestamp as absent.
			var last: float = unit.status.get("last_weather_freeze", -Content.constants.WEATHER_FREEZE.COOLDOWN_S)
			if last == 0:
				last = -Content.constants.WEATHER_FREEZE.COOLDOWN_S
			if clock - last < float(Content.constants.WEATHER_FREEZE.COOLDOWN_S):
				continue
			var probability := (snow if _weather_air(unit) else snow_cover) * 0.05
			if probability <= 0 or random.next() >= probability:
				continue
			unit.status.freeze_until = clock + Content.constants.WEATHER_FREEZE.DUR_S
			unit.status.last_weather_freeze = clock
			events.append({"type": "freeze", "actor": unit.entity_id, "position": unit.position})
	var thunder: float = weather_dynamics.get("effectiveThunder", 0)
	if thunder <= 0:
		lightning_timer = 0.0
		return
	lightning_timer -= delta
	if lightning_timer > 0:
		return
	var cfg: Dictionary = Content.constants.WEATHER_DEBUFFS.LIGHTNING
	lightning_timer = maxf(cfg.INTERVAL_MIN, (1 - thunder) * (float(cfg.INTERVAL_MAX) - float(cfg.INTERVAL_MIN)) + float(cfg.INTERVAL_MIN))
	var random := SourceRng.new(weather_seed ^ (int(floorf(clock * 10)) * 0x9e3779b9))
	if random.next() >= float(cfg.PROB_MIN) + thunder * (float(cfg.PROB_MAX) - float(cfg.PROB_MIN)):
		return
	var candidates := units.values().filter(func(unit): return unit.alive() and not unit.special.get("invulnerable", false))
	var strikes: Array = []
	var count := 3 if thunder > 0.80 else 2 if thunder > 0.45 else 1
	for index in range(mini(count, candidates.size())):
		var target: BattleUnit = candidates.pop_at(int(floorf(random.next() * candidates.size())))
		var position := target.position + Vector3.UP * target.height
		damage(null, target, {"pen": cfg.PEN}, cfg.BASE_DMG, false, {"weather_weapon": false}, false)
		if units.has(target.entity_id):
			target.status.lightning_scorch = {"hp": target.hp, "states": _lightning_states(target, clock)}
		strikes.append({"id": target.entity_id, "position": position, "kind": target.kind})
		_lightning_shockwave(target.position, target.entity_id)
	if not strikes.is_empty():
		events.append({"type": "lightning_strike", "actor": 0, "points": strikes})
	_strike_weather_surface(SourceRng.new(weather_seed ^ int(floorf(clock * 10)) ^ 0x57ea7))

func _strike_weather_surface(random: SourceRng) -> void:
	if world == null or world.native_data == null or world.authority_height_grid.is_empty() or authority_bounds.is_empty():
		return
	var plan := EnvironmentRules.surface_strike(random, authority_bounds, world.authority_height, world.wet_at,
		func(x, z): return world.layers.inferred_level(Vector2(x, z)), world.weather_obstacles, weather_dynamics, fire_fields.size())
	if plan.is_empty():
		return
	var point := Vector3(plan.x, plan.y, plan.z)
	_mark_weather_scorch(point, plan.radius)
	events.append({"type": "lightning_strike", "actor": 0, "points": [{"id": 0, "position": point, "absolute": true}]})
	_lightning_shockwave(point)
	if plan.fire:
		var fire_point := Vector3(point.x, world.source_height(point.x, point.z), point.z)
		_spawn_fire("fire", fire_point, float(plan.radius) / float(Content.constants.HAZARDS.fire.r),
			24.0 / (float(Content.constants.DAYCLOCK.GAME_H) / float(Content.constants.DAYCLOCK.REAL_S)), true)

func _mark_weather_scorch(point: Vector3, radius: float) -> void:
	if not point.is_finite():
		return
	for scar: Dictionary in weather_scars:
		if scar.position.distance_to(point) < radius * 0.5:
			return
	weather_scars.append({"position": point, "radius": radius})

func _spawn_fire(kind: String, point: Vector3, scale_factor: float, lifetime: Variant = null, lightning_fire: bool = false) -> void:
	if kind not in ["fire", "forestfire", "grassfire", "factoryfire"] or not point.is_finite():
		return
	fire_fields.append({"id": next_id, "kind": kind, "position": point, "scale": scale_factor,
		"ttl": lifetime, "lightning": lightning_fire})
	next_id += 1

func _terrain_blocked(x: float, z: float) -> bool:
	if world != null and world.wet_at(x, z) > 0:
		return true
	for fire: Dictionary in fire_fields:
		var radius := float(Content.constants.HAZARDS[fire.kind].r) * float(fire.scale)
		if Vector2(x - fire.position.x, z - fire.position.z).length() < radius + 2:
			return true
	for unit: BattleUnit in units.values():
		if unit.kind == "flood" and unit.special.get("role") == "hazard":
			var radius := float(Content.constants.HAZARDS.flood.r) * float(unit.special.scale)
			if _planar_distance(Vector3(x, 0, z), unit.position) < radius + 2:
				return true
	return false

func _tick_fires(delta: float) -> void:
	for index in range(fire_fields.size() - 1, -1, -1):
		var fire: Dictionary = fire_fields[index]
		if fire.ttl == null:
			continue
		fire.ttl = float(fire.ttl) - delta
		if fire.lightning and EnvironmentRules.lightning_fire_wet(weather_dynamics):
			fire.ttl = 0.0
		if fire.ttl <= 0:
			events.append({"type": "fire_expired", "actor": 0, "hazard": fire.id, "position": fire.position})
			fire_fields.remove_at(index)
	var factor := EnvironmentRules.fire_multiplier(weather_dynamics)
	if factor > 0:
		for fire: Dictionary in fire_fields:
			var definition: Dictionary = Content.constants.HAZARDS[fire.kind]
			for unit: BattleUnit in pilots.values():
				var altitude := _missile_target_altitude(unit)
				if not unit.alive() or altitude > float(definition.maxY) or (unit.kind in Content.constants.AIR.KINDS and altitude > float(Content.constants.AIR.OFF_GROUND)):
					continue
				if _planar_distance(unit.position, fire.position) > float(definition.r) * float(fire.scale):
					continue
				_fire_burn(unit, float(definition.dot) * factor * delta)
				if float(unit.status.get("burn_report", 0)) + 2 < clock:
					unit.status.burn_report = clock
					events.append({"type": "burn", "actor": unit.entity_id, "position": fire.position, "factor": floorf(factor * 100 + 0.5) / 100})
	if world != null:
		world.sync_fires(fire_fields, clock, weather_dynamics)

func _spawn_loot(point: Vector3, treasure_class: float = 0.0) -> void:
	var plan := SceneRules.loot_plan(rng, point.x, point.z, treasure_class)
	var surface := world.source_height(plan.x, plan.z) if world != null else 0.0
	if not is_finite(surface):
		return
	plan.position = Vector3(plan.x, surface, plan.z)
	plan.erase("x")
	plan.erase("z")
	plan.id = next_id
	next_id += 1
	loots.append(plan)

func _tick_loots(delta: float) -> void:
	for index in range(loots.size() - 1, -1, -1):
		var loot: Dictionary = loots[index]
		loot.ttl = float(loot.ttl) - delta
		if loot.ttl <= 0:
			loots.remove_at(index)
			continue
		for unit: BattleUnit in pilots.values():
			if not unit.alive() or _missile_target_altitude(unit) > float(Content.constants.LOOT.MAX_Y):
				continue
			if _planar_distance(unit.position, loot.position) > float(Content.constants.LOOT.PICK_R):
				continue
			if loot.get("ammo", false):
				for slot: String in ["light", "heavy"]:
					unit.ammo[slot] = weapon_definition(unit.character, slot, unit.combat_level(slot)).mag
				unit.reload_at.clear()
			elif loot.has("affix"):
				var key: String = loot.affix
				var definition: Dictionary = Content.constants.AFFIXES[key]
				unit.buffs = unit.buffs.filter(func(buff): return buff.get("affix", "") != key)
				var modifiers := {}
				for property: String in ["reload", "dmgTaken", "killHeal", "bounty"]:
					if definition.has(property):
						modifiers[property] = definition[property]
				unit.buffs.append({"until": clock + definition.dur, "mul": modifiers, "affix": key})
			else:
				unit.money += float(loot.value)
			events.append({"type": "loot", "actor": unit.entity_id, "peer": unit.peer_id, "position": loot.position, "ammo": loot.get("ammo", false),
				"affix": loot.get("affix", ""), "value": loot.get("value", 0)})
			loots.remove_at(index)
			break
	if world != null:
		world.sync_loots(loots, clock)

func _flood_effect(unit: BattleUnit) -> Dictionary:
	var floods: Array = []
	for zone: BattleUnit in units.values():
		if zone.kind == "flood":
			var definition: Dictionary = Content.constants.HAZARDS.flood
			floods.append({"x": zone.position.x, "z": zone.position.z, "radius": float(definition.r) * float(zone.special.scale), "slow": definition.slow})
	return SceneRules.flood_effect(floods, Vector2(unit.position.x, unit.position.z), unit.flying, unit.fluid_environment.get("air", false))

func _terrain_jump_velocity(unit: BattleUnit) -> float:
	var flood := _flood_effect(unit)
	return float(flood.jump) if flood.active else EnvironmentRules.jump_velocity(unit.fluid_environment, bool(weather_dynamics.get("isFrozen", false)), unit.flying)

func _airdrop_point() -> Dictionary:
	var bases := {}
	for side: String in ["SWARM", "STEEL"]:
		bases[side] = [world.bases[side].x, world.bases[side].z]
	return SceneRules.airdrop_point(rng, {"bounds": authority_bounds, "lanes": world.lane_points, "bases": bases, "towers": [], "blockers": hazard_blockers}, _terrain_blocked)

func _spawn_airdrop_wave() -> void:
	if not authoritative or over:
		return
	var cfg: Dictionary = Content.constants.AIRDROP
	var players := pilots.size()
	var room := int(cfg.MAX_LIVE) - airdrops.size()
	if players <= 0 or room <= 0:
		return
	var count := mini(room, maxi(1, ceili(players * float(cfg.PER_PLAYER))))
	var dropped := 0
	for index in range(count):
		var point := _airdrop_point()
		if point.is_empty():
			continue
		var size := SceneRules.airdrop_size(rng)
		airdrops.append({"id": next_id, "x": point.x, "z": point.z, "size": size.key, "multiplier": size.mul,
			"ttl": cfg.TTL_S, "land_at": clock + float(cfg.LAND_S)})
		next_id += 1
		dropped += 1
	if dropped > 0:
		events.append({"type": "airfall", "actor": 0, "count": dropped})

func _grant_reward(unit: BattleUnit, reward: String, multiplier: float) -> Dictionary:
	if not authoritative:
		return {}
	var cfg: Dictionary = Content.constants.AIRDROP
	var result := {"reward": reward}
	if reward == "medkit":
		var health := floorf(unit.max_hp * float(cfg.MEDKIT_HP) * multiplier + 0.5)
		var shield_amount := floorf(unit.max_shield * float(cfg.MEDKIT_SP) * multiplier + 0.5)
		result.hp = floorf(_heal_body(unit, health, "item") + 0.5)
		unit.shield = minf(unit.max_shield, unit.shield + shield_amount)
		result.shield = shield_amount
	elif reward == "battery":
		var power_amount := floorf(unit.max_power * float(cfg.BATTERY_MP) * multiplier + 0.5)
		unit.power += power_amount
		var reduction := float(cfg.BATTERY_CD) * multiplier
		for slot: String in ["def", "atk"]:
			unit.cooldowns[slot] = maxf(0, float(unit.cooldowns.get(slot, 0)) - reduction)
			if unit.ability_charges.has(slot) and unit.ability_charges[slot].has("recharge_at"):
				unit.ability_charges[slot].recharge_at = unit.ability_charges[slot].recharge_at.map(func(deadline): return maxf(clock, float(deadline) - reduction))
		result.power = power_amount
		result.cooldown = floorf(reduction * 10 + 0.5) / 10
	else:
		var amount := floorf(float(cfg.MONEY) * multiplier + 0.5)
		unit.money += amount
		result.value = amount
	return result

func _open_airdrop(unit: BattleUnit, state: Dictionary) -> void:
	if not authoritative or over or not unit.alive():
		return
	var rewards: Array = Content.constants.AIRDROP.REWARDS
	var reward: String = rewards[int(floorf(rng.next() * rewards.size()))]
	var event := {"type": "airdrop", "actor": unit.entity_id, "peer": unit.peer_id, "side": unit.side, "position": Vector3(state.x, 0, state.z), "size": state.size}
	var received := _grant_reward(unit, reward, state.multiplier)
	event.merge(received)
	events.append(event)

func _tick_airdrops(delta: float) -> void:
	if not authoritative or over:
		return
	var cfg: Dictionary = Content.constants.AIRDROP
	for index in range(airdrops.size() - 1, -1, -1):
		var state: Dictionary = airdrops[index]
		state.ttl = float(state.ttl) - delta
		if state.ttl <= 0:
			airdrops.remove_at(index)
			continue
		if clock < float(state.land_at):
			continue
		var point := Vector3(state.x, 0, state.z)
		for unit: BattleUnit in pilots.values():
			if not unit.alive() or _missile_target_altitude(unit) > float(cfg.MAX_Y) or _planar_distance(unit.position, point) > float(cfg.PICK_R):
				continue
			_open_airdrop(unit, state)
			airdrops.remove_at(index)
			break
	if world != null:
		world.sync_airdrops(_airdrop_snapshot(), clock)

func _airdrop_snapshot() -> Array:
	var states: Array = []
	for state: Dictionary in airdrops:
		var x := floorf(float(state.x) * 10 + 0.5) / 10
		var z := -floorf(-float(state.z) * 10 + 0.5) / 10
		states.append({"id": state.id, "x": x, "z": z, "size": state.size, "landing": clock < float(state.land_at)})
	return states

func _tick_mines() -> void:
	var cfg: Dictionary = Content.constants.GAME.MINES
	for unit: BattleUnit in pilots.values():
		var grounded := unit.kind == "robot" and not _air_unit(unit) or unit.kind == "morph" and _missile_target_altitude(unit) <= float(Content.constants.MORPH.GROUND_Y)
		if not unit.alive() or not grounded or unit.has_status("third_cooldown_until", clock):
			continue
		for index in range(mines.size() - 1, -1, -1):
			var mine: Dictionary = mines[index]
			var point := Vector3(mine.x, 0, mine.z)
			if _planar_distance(unit.position, point) > float(cfg.TRIGGER_R):
				continue
			mines.remove_at(index)
			unit.status.third_cooldown_until = clock + float(Content.constants.GAME.THREAT_CD_S)
			_publish_blast_event({"type": "mine_blast", "actor": unit.entity_id, "peer": unit.peer_id, "mine": mine.id, "position": point, "radius": cfg.R})
			for target: BattleUnit in units.values():
				if not target.alive() or target.is_hero() and _missile_target_altitude(target) > float(cfg.R):
					continue
				var factor := CombatMath.blast_falloff(cfg.R, _planar_distance(target.position, point))
				if factor > 0:
					damage(null, target, {"pen": cfg.PEN}, float(cfg.DMG) * factor, true, {"weather_weapon": false}, false)
			break
	if world != null:
		world.sync_mines(mines)

func _tick_ambush(delta: float) -> void:
	var cfg: Dictionary = Content.constants.GAME.AA_AMBUSH
	var site_cfg: Dictionary = Content.constants.FIELD.AA_SITE
	var count := 0
	for missile: Dictionary in missiles:
		if missile.get("ambush", false):
			count += 1
	for unit: BattleUnit in pilots.values():
		if count >= int(Content.constants.GAME.THREAT_MISSILES_MAX):
			return
		if not unit.alive() or unit.kind != "drone" and not (unit.kind == "morph" and _missile_target_altitude(unit) >= float(Content.constants.GAME.AA_MIN_ALT)):
			continue
		if unit.has_status("third_cooldown_until", clock) or unit.has_status("stealth_until", clock):
			continue
		if SceneRules.lane_distance(world.lane_points, unit.position.x, unit.position.z) <= float(Content.constants.GAME.AMBUSH_M):
			continue
		if rng.next() > float(cfg.CHANCE_PER_S) * delta:
			continue
		var best: BattleUnit
		var best_distance := INF
		for site: BattleUnit in units.values():
			if site.kind != "aasite" or not site.alive():
				continue
			var distance := _planar_distance(unit.position, site.position)
			if distance <= float(site_cfg.range) and distance < best_distance:
				best = site
				best_distance = distance
		if best == null:
			continue
		unit.status.third_cooldown_until = clock + float(Content.constants.GAME.THREAT_CD_S)
		var origin := Vector3(best.position.x, 2, best.position.z)
		var side := "SWARM" if unit.side == "STEEL" else "STEEL"
		_launch_missile({"actor": best.entity_id, "side": side, "target": unit.entity_id, "ambush": true,
			"position": origin, "origin": origin, "speed": cfg.SPEED, "dmg": cfg.DMG, "pen": cfg.PEN, "r": cfg.R,
			"hp": cfg.HP, "max_hp": cfg.HP, "ttl": 14.0, "range": site_cfg.range})
		events.append({"type": "sam", "actor": best.entity_id, "target": unit.entity_id, "target_peer": unit.peer_id, "position": best.position, "side": side, "ambush": true})
		count += 1

func _tick_relays(delta: float) -> void:
	var cfg: Dictionary = Content.constants.FIELD.RELAY
	for index in range(relay_states.size() - 1, -1, -1):
		var relay: Dictionary = relay_states[index]
		var side := ""
		var contested := false
		for unit: BattleUnit in pilots.values():
			if not unit.alive() or _planar_distance(unit.position, relay.position) > float(cfg.R):
				continue
			if not side.is_empty() and unit.side != side:
				contested = true
				break
			side = unit.side
		if side.is_empty() or contested:
			relay.charge = maxf(0, float(relay.charge) - delta * 2)
			_sync_relay_state(relay)
			continue
		if relay.side != side:
			relay.charge = 0.0
		relay.side = side
		relay.charge = float(relay.charge) + delta
		_sync_relay_state(relay)
		if relay.charge < float(cfg.CHANNEL_S):
			continue
		vision_until[side] = clock + float(cfg.VISION_S)
		events.append({"type": "relay", "actor": relay.id, "side": side, "position": relay.position})
		_remove_field_unit(int(relay.id), false)
		relay_states.remove_at(index)

func _sync_relay_state(state: Dictionary) -> void:
	var unit: BattleUnit = units.get(int(state.id))
	if unit != null:
		unit.special.relay_charge = state.charge
		unit.special.relay_side = state.side

func _collapse_scene(unit: BattleUnit) -> void:
	unit.hp = 0
	unit.special.collapsed = true
	unit.visible = unit.presentation_visible
	unit.refresh_collision()
	unit.apply_collapse()
	var radius := float(Content.constants.HAZARDS[unit.kind].r) * float(unit.special.scale) * float(Content.constants.SCENE_STRUCT.RUBBLE_F)
	for obstacle: Dictionary in hazard_blockers:
		if float(obstacle.x) == float(unit.position.x) and float(obstacle.z) == float(unit.position.z):
			obstacle.radius = radius
			break
	events.append({"type": "collapse", "actor": unit.entity_id, "kind": unit.kind, "position": unit.position, "electric": unit.special.get("electric", false)})
	if fire_fields.size() < 40:
		var duration := SceneRules.vehicle_fire_seconds(unit.special.get("electric", false)) if unit.kind in ["car", "ship"] else SceneRules.fire_seconds(unit.max_hp)
		_spawn_fire("fire", unit.position, maxf(0.3, radius / float(Content.constants.HAZARDS.fire.r)), duration)

func _drop_scene_loot(unit: BattleUnit) -> void:
	var probability: float = Content.constants.HAZARDS.get(unit.kind, {}).get("salvage", 0)
	if probability > 0 and rng.next() < probability:
		_spawn_loot(unit.position, minf(1, unit.max_hp / float(Content.constants.LOOT.TC.HP_REF)))

func _lightning_shockwave(center: Vector3, direct_id: int = 0) -> void:
	var cfg: Dictionary = Content.constants.WEATHER_DEBUFFS.LIGHTNING
	for unit: BattleUnit in units.values():
		if not unit.alive() or unit.entity_id == direct_id or unit.special.get("invulnerable", false):
			continue
		var offset := Vector2(unit.position.x - center.x, unit.position.z - center.z)
		var distance := offset.length()
		if distance > float(cfg.SHOCK_R):
			continue
		var fraction := 1 - distance / float(cfg.SHOCK_R)
		damage(null, unit, {}, float(cfg.SHOCK_DMG) * fraction, false, {}, false)
		var impulse := offset / maxf(0.1, distance) * float(cfg.SHOCK_IMP) * fraction
		if unit.is_hero() and not unit.is_bot:
			var human_impulse := float(cfg.SHOCK_IMP) * fraction
			if human_impulse == 0:
				human_impulse = 14.0
			var direction := offset / distance if distance > 0.05 else Vector2.RIGHT
			if unit.flying:
				unit.velocity += Vector3(direction.x, 0, direction.y) * human_impulse
			else:
				unit.impulse_velocity += direction * human_impulse
				unit.velocity.y += 2.5
			events.append({"type": "shockwave", "actor": unit.entity_id, "position": center, "impulse": impulse.length()})
		else:
			_place_solid(unit, impulse * 0.35)

func spawn(info: Dictionary, replica: bool = false) -> BattleUnit:
	var unit := BattleUnit.new()
	var data: Dictionary = info.duplicate()
	if info.has("stage"):
		data.special = info.get("special", {}).duplicate(true)
		data.special.siege_stage = int(info.stage)
	data.id = next_id if not info.has("id") else int(info.id)
	next_id = maxi(next_id, int(data.id) + 1)
	unit.name = "Unit_%d" % data.id
	add_child(unit)
	unit.configure(data, replica)
	if authoritative and not replica and balance_profile != null and unit.is_pilot():
		var hero: Dictionary = Content.heroes[unit.character]
		var stats: Dictionary = Content.constants.UNITS[unit.kind]
		var boss_factor: float = Content.constants.BOSS.HP_MUL if unit.special.get("boss", false) else 1.0
		unit.max_hp = floorf(float(stats.hp) * float(hero.mods.get("hp", 1)) * boss_factor * balance_profile.preferences.curve("hp", 0) + .5)
		unit.max_shield = floorf(float(stats.get("shield", 0)) * float(hero.mods.get("sp", 1)) * balance_profile.preferences.curve("sp", 0) + .5)
		unit.armor = float(hero.armor) * balance_profile.preferences.curve("ar", 0)
		unit.hp = unit.max_hp
		unit.shield = unit.max_shield
	units[unit.entity_id] = unit
	if unit.is_pilot():
		unit.yaw = 0.0 if unit.special.get("boss", false) else atan2(unit.position.x, unit.position.z) if unit.side == Content.constants.SUPER_SIDE else world.spawn_heading(unit.side, unit.spawn_slot)
		if not unit.player_view.rules.is_empty():
			unit.player_view.body_yaw = unit.yaw
		unit.rotation.y = unit.yaw
		if authoritative:
			unit.ensure_weapon_pose()
			if not unit.is_bot:
				unit.ensure_authority_body()
	if authoritative and unit.speed > 0 and not unit.is_hero() and unit.special.is_empty():
		unit.path_follower = PathFollow3D.new()
		unit.path_follower.loop = false
		unit.path_follower.rotation_mode = PathFollow3D.ROTATION_NONE
		world.paths[unit.lane].add_child(unit.path_follower)
		unit.path_follower.progress_ratio = 0.0 if unit.side == "SWARM" else 1.0
	unit_spawned.emit(unit)
	return unit

func submit_input(peer: int, command: Dictionary) -> void:
	if not authoritative or over or not pilots.has(peer):
		return
	var motion = command.get("move")
	var heading = command.get("yaw")
	var elevation = command.get("pitch")
	var vertical = command.get("vertical", 0.0)
	if not motion is Vector2 or not motion.is_finite() or not heading is float or not elevation is float:
		return
	if not is_finite(heading) or not is_finite(elevation):
		return
	if not (vertical is float or vertical is int) or not is_finite(float(vertical)):
		return
	var unit: BattleUnit = pilots[peer]
	var aiming: bool = command.get("aim", unit.input_state.get("aim", false)) == true
	var requested_mode: Variant = command.get("view_mode", unit.view_mode)
	var view_mode: String = requested_mode if requested_mode is String and requested_mode in ["fpv", "tps"] else unit.view_mode
	if aiming:
		view_mode = "fpv"
	if view_mode == "tps" and not unit.ensure_authority_body():
		message.emit(peer, "view_unavailable")
		return
	if unit.input_state.get("aim", false) and not aiming:
		unit.aim_off_at = clock
	unit.input_state = {"move": motion.limit_length(), "yaw": wrapf(heading, -PI, PI),
		"pitch": clampf(elevation, -1.45, 1.45), "vertical": clampf(float(vertical), -1, 1),
		"jump": command.get("jump", false) == true, "fire": command.get("fire", false) == true and unit.alive(),
		"jump_held": command.get("jump_held", false) == true,
		"level_move": command.get("level_move", false) is bool and command.get("level_move", false),
		"sprint": command.get("sprint", false) == true, "aim": aiming,
		"view_mode": view_mode,
		"view_restore": "tps" if aiming and command.get("view_restore") == "tps" else "",
		"slot": "heavy" if command.get("slot", "heavy" if aiming else "light") == "heavy" else "light"}
	unit.input_state["received"] = clock

func action(peer: int, type: String, argument: String = "") -> void:
	if not authoritative or over or not pilots.has(peer):
		return
	var unit: BattleUnit = pilots[peer]
	if type == "buy":
		buy(unit, argument)
		return
	if type == "buy_creep":
		var lane := argument.strip_edges()
		if lane.is_valid_int():
			buy_creep(unit, int(lane))
		return
	if type == "aim":
		var parts := argument.split(":")
		if parts.size() != 2 or parts[0] not in ["on", "off"] or not parts[1].is_valid_int():
			return
		var request := int(parts[1])
		if request <= unit.aim_request:
			return
		unit.aim_request = request
		if parts[0] == "on" and unit.has_status("blind_until", clock):
			return
		_set_human_aim(unit, parts[0] == "on" and unit.alive())
		return
	if not unit.alive():
		return
	if type in ["civ_follow", "civ_away"]:
		if argument.is_valid_int():
			_civilian_interact(unit, int(argument), "away" if type == "civ_away" else "follow")
		return
	match type:
		"reload":
			reload_weapon(unit, argument if argument in ["light", "heavy"] else "light")
		"cast":
			cast(unit, argument)
		"cast_stance":
			cast(unit, InputRules.hold_slot(unit.defending))
		"defend":
			if not unit.has_status("freeze_until", clock) and argument in ["on", "off", "toggle"]:
				var next := not unit.defending if argument == "toggle" else argument == "on"
				if not next or unit.shield > 0:
					unit.defending = next

func _set_human_aim(unit: BattleUnit, aiming: bool) -> void:
	if unit.input_state.get("aim", false) and not aiming:
		unit.aim_off_at = clock
	unit.input_state.aim = aiming
	unit.input_state.slot = "heavy" if aiming else "light"
	if not unit.player_view.rules.is_empty():
		unit.player_view.aiming = aiming
	if aiming:
		if not unit.player_view.rules.is_empty():
			if unit.view_mode == "tps":
				unit.player_view.body_yaw = unit.yaw
			unit.player_view.select_mode("fpv", unit.yaw)
		unit.view_mode = "fpv"
	elif unit.input_state.get("view_restore") == "tps":
		unit.view_mode = "tps"
		unit.input_state.view_mode = "tps"
		if not unit.player_view.rules.is_empty():
			unit.player_view.select_mode("tps", unit.yaw)
	if not aiming:
		unit.input_state.view_restore = ""

func request_iframe(unit: BattleUnit) -> bool:
	if not authoritative or over or not unit.alive() or unit.has_status("iframe_cooldown_until", clock):
		return false
	unit.status.iframe_cooldown_until = clock + (Content.constants.IFRAME.DRONE_CD if unit.kind == "drone" else Content.constants.IFRAME.CD)
	unit.status.inv_until = clock + Content.constants.IFRAME.DUR
	events.append({"type": "iframe", "actor": unit.entity_id, "side": unit.side, "duration": Content.constants.IFRAME.DUR})
	return true

func _physics_process(delta: float) -> void:
	if not authoritative:
		for unit in units.values():
			unit.interpolate(delta)
		return
	if over:
		return
	# Player controls and native kinetic hit reports run on the physics clock,
	# as source client reports do outside the room's combat tick.
	_tick_player_controls(delta)
	authority_accumulator += delta
	var tick_delta: float = float(Content.constants.GAME.TICK_MS) / 1000
	while authority_accumulator + 0.000000001 >= tick_delta and not over:
		authority_accumulator = maxf(0, authority_accumulator - tick_delta)
		_tick_authority(tick_delta)
		if not setup_error.is_empty():
			return
	_tick_projectiles(delta)
	_present_authority_actors(delta)

func _tick_authority(delta: float) -> void:
	if not authoritative or over:
		return
	# The original room updates brains against the preceding battle time/state.
	for unit: BattleUnit in pilots.values():
		if unit.is_bot:
			if not bot_brains.has(unit.entity_id):
				_create_bot_brain(unit)
				if not setup_error.is_empty():
					return
			if bot_brains.has(unit.entity_id):
				bot_brains[unit.entity_id].update(delta)
	simulation_tick += 1
	if over:
		return
	clock += delta
	_tick_weather(delta)
	if clock >= next_wave:
		next_wave = clock + Content.constants.GAME.WAVE_S
		spawn_wave()
	if clock >= next_airdrop:
		next_airdrop = clock + float(Content.constants.AIRDROP.INTERVAL_S)
		_spawn_airdrop_wave()
	# Anchors use the previous engagement state, before recovery and new targets.
	wave_anchors = _wave_anchors()
	for unit: BattleUnit in pilots.values():
		if unit.alive():
			_regenerate(unit, delta)
		elif clock >= unit.respawn_at and simulation_tick > unit.death_tick + 1:
			respawn(unit)
	_tick_actor_status(delta)
	_tick_casts(delta)
	_tick_carriers(delta)
	_tick_environment(delta)
	_tick_persistent_abilities(delta)
	_tick_npcs(delta)
	_tick_missiles(delta)
	_record_shot_history()
	npc_index_active = false
	npc_index.clear()
	npc_structures.clear()
	_prune_dead_creeps()

func _tick_environment(delta: float) -> void:
	_tick_civilians(delta)
	_tick_mines()
	_tick_ambush(delta)
	_tick_relays(delta)
	_tick_fires(delta)
	_tick_loots(delta)
	_tick_airdrops(delta)
	_tick_camps(delta)

func _tick_npcs(delta: float) -> void:
	npc_structures.clear()
	for structure: BattleUnit in units.values():
		if structure.alive() and structure.kind in ["tower", "base"]:
			npc_structures.append({"kind": structure.kind, "x": float(structure.position.x), "z": float(structure.position.z)})
	_begin_npc_index()
	for unit: BattleUnit in units.values():
		if unit.alive() and not unit.is_hero() and (unit.special.is_empty() or unit.special.get("third", false)):
			_tick_npc(unit, delta)

func _record_shot_history() -> void:
	for unit: BattleUnit in pilots.values():
		if unit.alive():
			_record_actor_history(unit)

func _record_actor_history(unit: BattleUnit) -> void:
	ShotHistory.record(unit.position_trail, clock, unit.position.x, unit.position.z, balance_profile.shot_trail_seconds() if balance_profile != null else NAN)

func _tick_player_controls(delta: float) -> void:
	for unit: BattleUnit in units.values():
		if not unit.alive():
			fire_controls.erase(unit.entity_id)
			continue
		if unit.is_pilot():
			var was_aiming: bool = unit.input_state.get("aim", false)
			if not unit.is_bot and clock - float(unit.input_state.get("received", clock)) > 0.5:
				unit.input_state = {"aim": was_aiming, "slot": "heavy" if was_aiming else "light",
					"view_mode": unit.view_mode, "view_restore": unit.input_state.get("view_restore", "")}
			if was_aiming and not unit.input_state.get("aim", false):
				unit.aim_off_at = clock
			if not unit.is_bot:
				_tick_recoil_echoes(unit)
				unit.simulate_movement(delta)
				_tick_view_fov(unit, delta)
				unit.recoil.advance(delta, _recoil_next)
				unit.sync_view_camera()
				if not unit.input_state.get("fire", false):
					unit.recoil.release_fire()
					_sync_body_charge(unit)
			if unit.input_state.get("aim", false) and unit.input_state.get("slot", "light") == "heavy":
				var weapon := weapon_definition(unit.character, "heavy", unit.combat_level("heavy"))
				if weapon.trajectory == "lob":
					fire_controls[unit.entity_id] = lob_control(unit, weapon)
				else:
					fire_controls.erase(unit.entity_id)
			else:
				fire_controls.erase(unit.entity_id)
			if not unit.is_bot:
				_tick_lock(unit)
			if not unit.is_bot and unit.input_state.get("fire", false):
				fire(unit, unit.input_state.get("slot", "light"))

func _present_authority_actors(delta: float) -> void:
	for unit: BattleUnit in units.values():
		if unit.is_pilot():
			_tick_weapon_pose(unit, delta)
			_tick_authority_body(unit, delta)
		unit.visible = (unit.alive() or unit.special.get("collapsed", false)) and unit.presentation_visible and not unit.special.get("garrison", false)
		if unit.special.get("role") != "carrier":
			unit.position.y = minf(unit.position.y, world.ceiling)
		unit.buffs = unit.buffs.filter(func(buff): return buff.until > clock)
		if unit.body_presentation != null:
			unit.presented_altitude = _missile_target_altitude(unit) if unit.is_hero() or unit.flying else 0.0

func spawn_wave() -> void:
	wave += 1
	for lane in range(world.paths.size()):
		for side in ["SWARM", "STEEL"]:
			_spawn_lane_wave(lane, side, wave, Content.constants.GAME.WAVE_SPAWN_OFF_M)
	events.append({"type": "wave", "actor": 0, "wave": wave})

func _prefill_lanes(map_data: Dictionary) -> void:
	if not map_data.has("wave_prefill"):
		push_error("Missing source prefill plan; regenerate migration data before running the battle")
		return
	for row: Dictionary in map_data.wave_prefill:
		_spawn_lane_wave(int(row.lane), row.side, int(row.wave), float(row.lead))

func _npc_surface(point: Vector2) -> float:
	var level := world.layers.inferred_level(point)
	if level == 2:
		var tunnel := world.layers.tunnel_at(point)
		if not tunnel.is_empty():
			return float(tunnel.floor)
	if level == 1:
		var deck: Variant = world.layers.deck_height(point, Content.balance.structure.deckMargin)
		if deck != null:
			return float(deck)
	return world.ground_height(point.x, point.y)

func _spawn_lane_wave(lane: int, side: String, wave_id: int, lead: float) -> void:
	if not Content.balance.has("wave_rules"):
		push_error("Missing source wave rules; regenerate migration data before running the battle")
		return
	var plan := WaveRules.spawn_plan(world.lane_points[lane], world.lane_distances[lane], side, lead, rng)
	var multiplier := NpcRules.creep_multiplier(float(creep_upgrades[side][lane]))
	for row: Dictionary in plan:
		var surface := _npc_surface(Vector2(row.x, row.z))
		if not is_finite(surface):
			push_error("Wave actor has no verified standing surface")
			continue
		var altitude: float = Content.constants.GAME.HELI_ALT if row.kind == "heli" else 0.0
		var unit := spawn({"side": side, "kind": row.kind, "lane": lane, "position": Vector3(row.x, surface + altitude, row.z), "creep_multiplier": multiplier})
		unit.npc_progress = row.progress
		unit.npc_has_wave = true
		unit.npc_wave = wave_id
		if unit.path_follower != null:
			unit.path_follower.progress_ratio = clampf(row.progress / float(world.lane_distances[lane][-1]), 0, 1) if side == "SWARM" else clampf(1 - row.progress / float(world.lane_distances[lane][-1]), 0, 1)

func _wave_anchors() -> Dictionary:
	var anchors := {}
	for unit: BattleUnit in units.values():
		if not unit.alive() or unit.is_hero() or unit.special.get("neutral", false) or not unit.has_lane or not unit.npc_has_wave or unit.npc_engaged:
			continue
		var key := "%s|%d|%d" % [unit.side, unit.lane, unit.npc_wave]
		anchors[key] = minf(float(anchors.get(key, INF)), unit.npc_progress)
	return anchors

func _advance_npc(unit: BattleUnit, delta: float) -> void:
	if not unit.has_lane or unit.lane >= world.lane_points.size():
		return
	var structures: Array = npc_structures.duplicate()
	var allies: Array = []
	for other: BattleUnit in units.values():
		if other.alive() and other != unit and other.side == unit.side and other.has_lane and other.lane == unit.lane and not other.is_hero() and not other.special.get("neutral", false):
			allies.append({"x": float(other.position.x), "z": float(other.position.z)})
	var state := {"x": float(unit.position.x), "z": float(unit.position.z), "progress": unit.npc_progress, "side": unit.side}
	var key := "%s|%d|%d" % [unit.side, unit.lane, unit.npc_wave]
	var controls := {"stun": unit.has_status("stun_until", clock), "slow": unit.has_status("slow_until", clock),
		"slow_factor": unit.status.get("slow_factor", 0.6), "confuse": unit.has_status("confuse_until", clock)}
	WaveRules.step(state, world.lane_points[unit.lane], world.lane_distances[unit.lane], unit.speed, delta, controls,
		float(wave_anchors.get(key, NAN)) if unit.npc_has_wave else NAN, structures, hazard_blockers, allies, _wave_weather_factor(unit, controls))
	unit.npc_progress = state.progress
	var surface := _npc_surface(Vector2(state.x, state.z))
	if not is_finite(surface):
		return
	var altitude: float = Content.constants.GAME.HELI_ALT if unit.kind == "heli" else 0.0
	var desired := Vector3(state.x, surface + altitude, state.z)
	var motion := desired - unit.position
	if Vector2(motion.x, motion.z).length_squared() > 0.0001:
		unit.yaw = atan2(-motion.x, -motion.z)
		unit.rotation.y = unit.yaw
	unit.move_and_collide(motion)

func _tick_npc(unit: BattleUnit, delta: float) -> void:
	var def: Dictionary = Content.constants.UNITS[unit.kind]
	unit.npc_cooldown = maxf(0, unit.npc_cooldown - delta)
	if unit.kind == "base":
		_tick_base_guns(unit, def.guns, delta)
		return
	if unit.special.get("third", false):
		_camp_behavior(unit, delta)
	var profile: Dictionary = def
	if unit.special.get("garrison", false):
		profile = def.duplicate()
		profile.range = float(def.range) * float(Content.constants.THIRD.GAR_RANGE_F)
	var target := _npc_acquire_cached(unit, profile)
	unit.npc_engaged = target != null
	if target != null and not unit.special.get("retreat", false):
		var direction := target.eye() - unit.eye()
		unit.yaw = atan2(-direction.x, -direction.z)
		unit.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
		if unit.npc_cooldown == 0 and not unit.has_status("emp_until", clock):
			unit.npc_cooldown = 1.0 / (maxf(0.01, def.get("rate", 1)) * weather_attack_rate(unit))
			unit.fire_at.npc = clock + unit.npc_cooldown
			var weapon_def: Dictionary = Content.constants.WEAPONS.get(def.get("wid", ""), Content.constants.STRUCT_W.get(unit.kind, {}))
			if weapon_def.get("r", 0) > 0:
				var point := Vector3(target.position.x, _missile_target_altitude(target) if target.is_hero() or target.kind == "heli" else 0, target.position.z)
				blast(unit, weapon_def, point, false, true, _unit_level(target), def.dmg)
				_publish_blast_event({"type": "boom", "actor": unit.entity_id, "position": _missile_world_position(point), "radius": weapon_def.r, "side": unit.side})
			elif not _roll_miss(unit, target, weapon_def):
				damage(unit, target, weapon_def, def.dmg * (1.0 if target.is_hero() else unit.creep_multiplier), false, {}, false)
			var shot := {"type": "shot", "actor": unit.entity_id, "kind": unit.kind, "start": unit.eye(), "end": _npc_shot_point(target), "side": unit.side}
			if unit.body_presentation != null:
				_emit_body_event(shot)
			else:
				events.append(shot)
		return
	if unit.special.get("third", false) and unit.speed > 0:
		_move_camp_unit(unit, def, delta)
		return
	if unit.speed <= 0 or not unit.has_lane:
		return
	_advance_npc(unit, delta)

func _npc_spec(unit: BattleUnit) -> Dictionary:
	return {"kind": unit.kind, "side": unit.side, "hero": unit.is_hero(), "hp": unit.hp, "dead": not unit.alive(),
		"neutral": unit.special.get("neutral", false), "garrison": unit.special.get("garrison", false),
		"third": unit.special.get("third", false), "siege_locked": siege_locked(unit),
		"stealth": unit.has_status("stealth_until", clock), "blind": unit.has_status("blind_until", clock),
		"altitude": _missile_target_altitude(unit), "sight_height": _relative_sight_height(unit), "hologram": unit.special.get("role") == "hologram"}

func _npc_blocked(observer: BattleUnit, target: BattleUnit, profile: Dictionary, weapon: Dictionary) -> bool:
	var observer_spec := _npc_spec(observer)
	var target_spec := _npc_spec(target)
	if target.kind in ["drone", "heli", "morph"]:
		var ceiling := minf(float(profile.range) * 0.9, Content.constants.GAME.GUN_CEIL_M)
		if absf(float(target_spec.altitude) - ceiling) <= MissileMotion.NATIVE_HEIGHT_TOLERANCE:
			target_spec.altitude = ceiling
	var range_factor := CombatMath.altitude_range(weapon, _height_difference(observer, target))
	if observer.is_hero():
		range_factor *= StatusRules.multiplier(observer.buffs, "range", clock)
	return NpcRules.blocked(observer_spec, target_spec, profile, weapon, _planar_distance(observer.position, target.position), range_factor, weather_fog)

func _begin_npc_index() -> void:
	npc_index_active = false
	npc_index.clear()
	var rules: Dictionary = Content.balance.get("npc", {})
	if not rules.has("cell"):
		return
	var sequence := 0
	for unit: BattleUnit in units.values():
		if unit.alive() and not unit.special.get("neutral", false):
			npc_index.append({"unit": unit, "x": int(floorf(unit.position.x / float(rules.cell))),
				"z": int(floorf(-unit.position.z / float(rules.cell))), "sequence": sequence})
		sequence += 1
	npc_index.sort_custom(func(first, second):
		if first.x != second.x:
			return first.x < second.x
		if first.z != second.z:
			return first.z < second.z
		return first.sequence < second.sequence)
	npc_index_active = true

func _npc_candidates(observer: BattleUnit, profile: Dictionary) -> Array:
	if not npc_index_active:
		return units.values()
	var rules: Dictionary = Content.balance.npc
	var radius: float = float(profile.range) * rules.candidate_range
	var low_x := int(floorf((observer.position.x - radius) / float(rules.cell)))
	var high_x := int(floorf((observer.position.x + radius) / float(rules.cell)))
	var low_z := int(floorf((-observer.position.z - radius) / float(rules.cell)))
	var high_z := int(floorf((-observer.position.z + radius) / float(rules.cell)))
	var candidates: Array = []
	for record: Dictionary in npc_index:
		if record.x >= low_x and record.x <= high_x and record.z >= low_z and record.z <= high_z:
			candidates.append(record.unit)
	return candidates

func _npc_acquire(observer: BattleUnit, profile: Dictionary) -> BattleUnit:
	var best: BattleUnit
	var best_score := INF
	var weapon: Dictionary = Content.constants.WEAPONS.get(profile.get("wid", ""), {})
	for target: BattleUnit in _npc_candidates(observer, profile):
		if _npc_blocked(observer, target, profile, weapon):
			continue
		var score := NpcRules.score(_planar_distance(observer.position, target.position), _npc_spec(target), weapon)
		if score >= best_score or not visible_to(observer, target):
			continue
		best = target
		best_score = score
	return best

func _npc_acquire_cached(observer: BattleUnit, profile: Dictionary) -> BattleUnit:
	# Preserve the source's targeting cadence while native physics can validate a held actor every frame.
	var rules: Dictionary = Content.balance.get("npc", {})
	if not rules.has("rescan"):
		return _npc_acquire(observer, profile)
	var period := maxi(1, int(rules.rescan))
	if observer.npc_cache_phase < 0:
		npc_phase_sequence = (npc_phase_sequence + 1) % period
		observer.npc_cache_phase = npc_phase_sequence
	var tick := int(floorf(clock / (float(Content.constants.GAME.TICK_MS) / 1000)))
	var held: BattleUnit = units.get(observer.npc_cached_target)
	if held != null and (observer.npc_cached_tick == tick or (tick + observer.npc_cache_phase) % period != 0):
		var weapon: Dictionary = Content.constants.WEAPONS.get(profile.get("wid", ""), {})
		if not _npc_blocked(observer, held, profile, weapon) and visible_to(observer, held):
			return held
	var target := _npc_acquire(observer, profile)
	observer.npc_cached_target = target.entity_id if target != null else 0
	observer.npc_cached_tick = tick
	return target

func acquire_target(unit: BattleUnit, reach: float, fov: bool = false) -> BattleUnit:
	var nearest: BattleUnit
	var best := INF
	for candidate: BattleUnit in units.values():
		if not candidate.alive() or candidate.side == unit.side:
			continue
		var distance := unit.eye().distance_to(candidate.eye()) - candidate.radius
		if distance > reach or distance >= best:
			continue
		if fov:
			var delta := candidate.eye() - unit.eye()
			var half_vertical := deg_to_rad(Content.constants.UNITS[unit.kind].get("fov", 68)) / 2
			var half_horizontal := atan(tan(half_vertical) * Content.constants.BOT_VIEW.ASPECT)
			var yaw_error := wrapf(atan2(-delta.x, -delta.z) - unit.yaw, -PI, PI)
			var pitch_error := atan2(delta.y, Vector2(delta.x, delta.z).length()) - unit.pitch
			if absf(yaw_error) > half_horizontal or absf(pitch_error) > half_vertical:
				continue
		if not visible_to(unit, candidate):
			continue
		nearest = candidate
		best = distance
	return nearest

func visible_to(unit: BattleUnit, target: BattleUnit) -> bool:
	if not cubic_cages.is_empty() and _skill_barriers_blocked(_relative_origin(unit), _relative_target(target)):
		return false
	var query := PhysicsRayQueryParameters3D.create(unit.sight_origin(), target.sight_target(), 1)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func visible_to_side(target: BattleUnit, side: String) -> bool:
	if target.side == side or target.special.get("neutral", false) or target.kind in ["base", "tower"]:
		return true
	if float(vision_until.get(side, 0)) > clock:
		return true
	var protection := AbilityFieldRules.protecting_fog(fogs, Vector2(target.position.x, target.position.z), target.side, clock)
	for observer: BattleUnit in units.values():
		if observer.side != side or not observer.alive() or observer.has_status("blind_until", clock) or not Content.constants.UNITS.get(observer.kind, {}).has("sight"):
			continue
		if target.has_status("stealth_until", clock):
			continue
		var point := Vector2(observer.position.x, observer.position.z)
		if not protection.is_empty() and not AbilityFieldRules.covers(protection, point, clock):
			continue
		var offset := Vector2(target.position.x - observer.position.x, target.position.z - observer.position.z)
		if offset.length() <= observer.sight_radius() * NpcRules.fog_sight(weather_fog) * AbilityFieldRules.observer_factor(fogs, point, side, clock) and visible_to(observer, target):
			return true
	return false

func apply_presentation_view(state: Dictionary) -> void:
	if not authoritative:
		return
	var shown := {}
	for actor in state.units:
		shown[int(actor.id)] = true
		var unit: BattleUnit = units.get(int(actor.id))
		if unit != null:
			present_victim_snapshot(unit, actor)
		if unit != null and unit.body_presentation != null:
			unit.body_presentation.capture_snapshot(actor, float(state.clock))
			_prime_body_view(unit)
	for unit: BattleUnit in units.values():
		if unit.presentation_visible and not shown.has(unit.entity_id):
			unit.mobile_damage.release(true)
			unit.clear_damage_fx()
		unit.presentation_visible = shown.has(unit.entity_id)
		unit.visible = (unit.alive() or unit.special.get("collapsed", false)) and unit.presentation_visible and not unit.special.get("garrison", false)
	for id: int in victim_reports.keys():
		if not shown.has(id):
			victim_reports.erase(id)
	view_snapshot_ready.emit(state)
	_present_retired_bodies(state.get("events", []))
	pending_missile_view = state.get("missiles", []).duplicate(true)
	missile_view_pending = true

func present_victim_snapshot(unit: BattleUnit, state: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	_sync_vital_bar(unit, state)
	var current := {"hp": float(state.hp), "shield": float(state.shield), "defending": bool(state.get("defending", false)),
		"dead": bool(state.get("dead", float(state.hp) <= 0)), "view_reset": int(state.get("view_reset", 0))}
	var previous: Dictionary = victim_reports.get(unit.entity_id, {})
	var reaction := VictimHitState.reaction(previous, current, unit.is_hero())
	victim_reports[unit.entity_id] = current
	# Original hero stage changes precede their shield/armor contact branch.
	if unit.is_hero():
		unit.present_scene_damage(state, world.combat_effects, previous.is_empty())
	if unit.is_pilot() and unit.peer_id == Session.player_id():
		var owned_current := current
		if owned_defense is bool:
			owned_current = current.duplicate()
			owned_current.defending = owned_defense
		var self_reaction := VictimHitState.self_reaction(previous, owned_current)
		if not self_reaction.is_empty():
			if self_reaction.shielded:
				if unit.first_person_shield != null:
					unit.first_person_shield.hit(float(self_reaction.flash))
				if unit.body != null:
					unit.body.flash_shield(float(self_reaction.flash))
			else:
				self_hurt.emit()
	var effects: CombatEffects = world.combat_effects
	if not reaction.is_empty() and unit.model != null:
		var dimensions: Dictionary = unit.body.profile.dimensions if unit.body != null else unit.geometry_override
		if dimensions.is_empty():
			push_error("Victim feedback requires captured model dimensions")
			return
		var camera := get_viewport().get_camera_3d()
		effects = world.ensure_combat_effects()
		effects.victim(unit.model.global_position, float(dimensions.height), unit.kind,
			bool(reaction.shielded), camera.global_position if camera != null else null)
		if reaction.shielded and unit.body != null:
			unit.body.flash_shield(float(reaction.flash))
	if not unit.is_hero():
		unit.present_scene_damage(state, effects, previous.is_empty())
	unit.present_damage_fx(state, effects)

func _sync_vital_bar(unit: BattleUnit, state: Dictionary) -> void:
	if unit.model == null:
		return
	var dimensions := unit.visual_dimensions()
	if dimensions.is_empty():
		return
	if not is_instance_valid(unit.vital_bar) or unit.vital_bar.get_parent() != unit.model:
		unit.vital_bar = VitalBar.new()
		unit.model.add_child(unit.vital_bar)
	var properties: Dictionary = state.get("special", {})
	var collider_height := 0.0
	if properties.get("role") == "hazard":
		collider_height = float(CameraPose.entity_collider(unit.kind, float(properties.get("scale", 1)), false).colH)
	unit.vital_bar.sync({"self": unit.is_pilot() and unit.peer_id == Session.player_id(),
		"hp": state.hp, "maximum": state.max_hp, "shield": state.shield, "max_shield": state.max_shield,
		"side": state.side, "viewer": Session.chosen_side, "kind": unit.kind,
		"static": unit.kind in ["tower", "base", "bunker"], "neutral": properties.get("neutral", false),
		"civilian": properties.get("role") == "civilian", "collapsed": properties.get("collapsed", false),
		"segment": properties.get("boss_segment") if properties.get("boss", false) else null,
		"top": dimensions.get("top", dimensions.height), "collider_height": collider_height})

func step_damage_fx(delta: float, now: float) -> void:
	if Session.dedicated:
		return
	for unit: BattleUnit in units.values():
		if unit.damage_fx == null or unit.model == null or not unit.model.is_visible_in_tree():
			continue
		if not weather_dynamics.has("windAmp") or not weather_dynamics.has("windDir"):
			push_error("Persistent damage FX require resolved source wind dynamics")
			return
		unit.damage_fx.advance(delta, now, weather_dynamics)
	for view: MissilePresentation in missile_presentations.values():
		if view.damage_fx.node != null and view.is_visible_in_tree():
			if not weather_dynamics.has("windAmp") or not weather_dynamics.has("windDir"):
				push_error("Missile damage FX require resolved source wind dynamics")
				return
			view.damage_fx.node.advance(delta, now, weather_dynamics)

func sync_missile_presentations(states: Array, reports: Array) -> void:
	if Session.dedicated or world == null:
		return
	if states.is_empty() and missile_presentations.is_empty():
		return
	var seen := {}
	var effects := world.ensure_combat_effects()
	for state: Dictionary in states:
		var id := int(state.id)
		seen[id] = true
		var relative: Vector3 = state.position
		var ground := _npc_presentation_ground(relative)
		if not is_finite(ground):
			push_error("Missile presentation requires verified terrain height")
			continue
		var point := Vector3(relative.x, ground + relative.y, relative.z)
		if not missile_presentations.has(id):
			var fresh := MissilePresentation.new()
			add_child(fresh)
			if not fresh.configure(id, point):
				fresh.free()
				continue
			missile_presentations[id] = fresh
		var view: MissilePresentation = missile_presentations[id]
		view.observe(state, point, effects)
	for id: int in missile_presentations.keys():
		if seen.has(id):
			continue
		# Reflection has no source missileId; only matching blast/intercept reports fracture it.
		var burst := reports.any(func(event): return event.type in ["missile_blast", "missile_intercept"] and int(event.get("missile", -1)) == id)
		var view: MissilePresentation = missile_presentations[id]
		view.release(effects, burst)
		view.queue_free()
		missile_presentations.erase(id)

func missile_view_collision(start: Vector3, end: Vector3) -> Dictionary:
	if not start.is_finite() or not end.is_finite():
		return {}
	var hit := {}
	for view: MissilePresentation in missile_presentations.values():
		hit = MissileViewRay.nearer(start, hit, view.ray.intersect(view, start, end))
	return hit

func step_missile_presentations(delta: float) -> void:
	if Session.dedicated or world == null or missile_presentations.is_empty():
		return
	var effects := world.ensure_combat_effects()
	for view: MissilePresentation in missile_presentations.values():
		view.advance(delta, effects)

func _prime_body_view(unit: BattleUnit) -> void:
	var presentation := unit.body_presentation
	if world == null or presentation == null or presentation.view_motion.configured or presentation.report.is_empty():
		return
	var target: Vector3 = presentation.report.position
	var ground := world.source_height(target.x, target.z)
	if not is_finite(ground):
		return
	var point := Vector3(target.x, ground, target.z)
	presentation.view_motion.place(point)
	unit.body.top_level = true
	unit.body.global_transform = Transform3D(Basis.IDENTITY.scaled_local(unit.model_base_scale * unit.body_scale), point)

func present_bodies(delta: float, now: float, frame: int, camera: Camera3D, local_view: PlayerViewState = null, owned: Dictionary = {}) -> void:
	if camera == null:
		return
	var local_peer := Session.player_id()
	var low_power := Controls.low_power()
	for unit: BattleUnit in units.values():
		if not unit.presentation_visible:
			continue
		if unit.body_presentation == null:
			if is_instance_valid(unit.vital_bar) and BodyPresentation.update_due(frame, str(unit.entity_id),
					BodyPresentation.update_stride(Vector2(unit.position.x - camera.global_position.x, unit.position.z - camera.global_position.z).length_squared(), low_power)):
				unit.vital_bar.pose(camera.global_position)
			continue
		var presentation := unit.body_presentation
		var is_self := unit.is_pilot() and unit.peer_id == local_peer
		var first_person := unit.view_mode != "tps"
		var heading := float(unit.rotation.y) + PI
		var position := unit.global_position
		var view_plan: Dictionary = {}
		var altitude := unit.presented_altitude if is_self else float(presentation.report.get("altitude", NAN))
		if not is_finite(altitude):
			unit.body.spin(delta)
			continue
		var flies: bool = unit.flying if is_self else unit.kind in Content.balance.bodyRules.presentation.flyKinds
		if is_self and local_view != null and not local_view.rules.is_empty():
			unit.body.top_level = false
			unit.body.position = unit.model_base_position * unit.body_scale
			first_person = local_view.mode != "tps"
			heading = local_view.body_yaw + PI
			if first_person:
				heading = unit.body_presentation.previous_yaw if unit.body_presentation.sampled else unit.body.poses.axis(unit.body.source_root, "y")
			unit.body.rotation.y = heading - float(unit.rotation.y)
			unit.body.visible = not first_person and unit.alive()
		elif not is_self:
			if world == null or presentation.report.is_empty():
				continue
			var motion := presentation.view_motion
			var target: Vector3 = presentation.report.position
			if not motion.configured:
				var ground := world.source_height(target.x, target.z)
				if not is_finite(ground):
					continue
				motion.place(Vector3(target.x, ground, target.z))
			var remote_state := {"id": str(unit.entity_id), "kind": unit.kind, "side": unit.side, "hero": unit.is_hero(),
				"flies": flies, "heroY": altitude, "target": target, "static": unit.body.profile["static"],
				"padY": target.y if unit.body.profile["static"] else null, "reported_yaw": presentation.report.yaw,
				"aim": presentation.entity.get("_aimAt"), "carrier": unit.special.get("role") == "carrier", "waterY": world.water_y}
			view_plan = motion.advance(delta, now, frame, camera.global_position, remote_state, presentation.pending_snap,
				{"ground": world.source_height, "surface": world.visual_surface, "flight": world.visual_flight_surface,
					"lane": world.lane_surface.at, "deck": world.visual_deck}, _body_facing_target.bind(unit), presentation.carrier_motion, low_power)
			if view_plan.is_empty():
				continue
			heading = motion.yaw
			position = motion.position
			unit.body.top_level = true
			unit.body.global_transform = Transform3D(Basis.from_euler(Vector3(motion.pitch, heading, 0), EULER_ORDER_YXZ)
				.scaled_local(unit.model_base_scale * unit.body_scale), position)
		var expanded: bool = unit.has_status("shield_expand_until", clock) if is_self else presentation.report.expanded
		var defending: bool = unit.defending if is_self else presentation.report.defending
		if is_self:
			expanded = bool(owned.get("expanded", expanded))
			defending = bool(owned.get("defending", defending))
		var shield := unit.shield if is_self else float(presentation.report.shield)
		var dead: bool = not unit.alive() if is_self else presentation.report.dead
		var state := {"hero": unit.is_hero(), "heroY": altitude, "flies": flies, "dead": dead,
			"isSelf": is_self, "sp": shield, "df": (2 if expanded else 1) if defending else 0,
			"visualDefense": defending and shield > 0, "visualShieldExpand": expanded}
		presentation.frame(delta, now, frame, position, heading,
			camera.global_position, state, first_person, low_power, _pose_body_mounts.bind(unit), view_plan)
		unit.body.spin(delta)

func present_geometry_lod(camera: Camera3D, frame: int, aim_blend: float, local_peer: int) -> void:
	if camera == null or not Content.balance.has("geometryLod"):
		return
	var rules: Dictionary = Content.balance.geometryLod
	for unit: BattleUnit in units.values():
		if unit.is_pilot() and unit.peer_id == local_peer or not unit.alive() or unit.special.get("garrison", false):
			continue
		var root := unit.model
		if not is_instance_valid(root) or not root.visible or not unit.presentation_visible:
			continue
		var state: GeometryLodState = root.get_meta("source_geometry_lod") if root.has_meta("source_geometry_lod") else null
		if state == null:
			state = GeometryLodState.new()
			root.set_meta("source_geometry_lod", state)
		var height := float(unit.visual_dimensions().get("height", 0))
		if height == 0:
			height = float(rules.defaultHeight)
		var point := root.global_position
		var dx := float(point.x) - float(camera.global_position.x)
		var dy := float(point.y) + height * .5 - float(camera.global_position.y)
		var dz := float(point.z) - float(camera.global_position.z)
		var result := state.observe(frame, str(unit.entity_id), dx * dx + dy * dy + dz * dz, aim_blend, rules)
		if not result.is_empty():
			GeometryLodState.apply(root, result.trim, result.outline)

func _body_facing_target(now: float, origin: Vector3, unit: BattleUnit) -> Variant:
	return _body_nearest(unit, now, origin, float(Content.constants.UNITS.get(unit.kind, {}).get("range", 0)), true)

func _body_nearest(unit: BattleUnit, now: float, origin: Vector3, reach: float, structures: bool) -> Variant:
	var entity := unit.body_presentation.entity
	var id := int(entity.get("_aimTarget", 0))
	if float(entity.get("_aimNext", 0)) == 0 or now >= float(entity._aimNext):
		var candidates: Array = []
		for candidate: BattleUnit in units.values():
			if not candidate.presentation_visible:
				continue
			candidates.append({"id": candidate.entity_id, "position": candidate.model.global_position if candidate.model != null else candidate.global_position,
				"side": candidate.side, "neutral": candidate.special.get("neutral", false), "dead": not candidate.alive(),
				"static": candidate.kind in ["base", "tower", "bunker"] or candidate.special.get("role") in ["slab", "hazard"],
				"visible": candidate.model != null and candidate.model.visible and not candidate.special.get("garrison", false),
				"self": candidate.is_pilot() and candidate.peer_id == Session.player_id()})
		id = BodyMountAim.nearest(entity, origin, unit.side, now, reach, candidates, structures)
	var target: BattleUnit = units.get(id)
	if target == null or not target.presentation_visible:
		return null
	return target.global_position if target.is_pilot() and target.peer_id == Session.player_id() else target.model.global_position if target.model != null else target.global_position

func _pose_body_mounts(delta: float, now: float, unit: BattleUnit) -> void:
	if is_instance_valid(unit.vital_bar):
		var camera := get_viewport().get_camera_3d()
		if camera != null:
			unit.vital_bar.pose(camera.global_position)
	if unit.model != null and not Session.dedicated:
		if not is_instance_valid(unit.head_marks) or unit.head_marks.get_parent() != unit.model:
			unit.head_marks = HeadMarks.new()
			unit.model.add_child(unit.head_marks)
		unit.head_marks.advance(unit, Session.chosen_side, delta, now)
	if unit.body.mounts.get("turret") == null and unit.body.mounts.get("gunTilt") == null and unit.body.mounts.get("guns") == null:
		return
	var entity := unit.body_presentation.entity
	var aim: Variant = entity.get("_aimAt")
	var nearest: Variant = null
	if unit.body.mounts.get("turret") != null and not (aim is Dictionary and now < float(aim.until)):
		var tower := unit.kind == "tower"
		nearest = _body_nearest(unit, now, unit.body.global_position,
			float(Content.constants.UNITS.get(unit.kind, {}).get("range", 0)) * (1.0 if tower else float(Content.balance.bodyRules.presentation.vehicleRange)), not tower)
	if unit.kind == "base" and world != null:
		var foe := "SWARM" if unit.side == "STEEL" else "STEEL"
		if world.bases.has(foe):
			var target: Vector3 = world.bases[foe]
			unit.body.poses.set_axis(unit.body.mounts.guns, "y", atan2(target.x - unit.position.x, target.z - unit.position.z))
	BodyMountAim.step(unit.body, entity, delta, now, unit.body.global_position,
		unit.body_presentation.view_motion.yaw if unit.body_presentation.view_motion.configured else float(unit.rotation.y) + float(unit.body.rotation.y), nearest)

func _npc_presentation_ground(point: Vector3) -> float:
	if world == null:
		return NAN
	var ground := world.source_height(point.x, point.z)
	if not is_finite(ground):
		ground = world.ground_height(point.x, point.z)
	return ground

func _npc_shot_point(target: BattleUnit, quantize: bool = true) -> Vector3:
	var raised := not quantize or target.is_hero() or target.kind in ["decoy", "heli"]
	var height := _missile_target_altitude(target) if target.is_hero() or target.flying or target.kind == "decoy" else 0.0
	return BodyMountAim.shot_point(target.global_position, _npc_presentation_ground(target.position), height, raised, quantize)

func _emit_body_event(event: Dictionary) -> void:
	body_event_serial += 1
	event.body_serial = body_event_serial
	var unit: BattleUnit = units.get(int(event.actor))
	if unit != null and event.type in ["cast_start", "cast"]:
		event.character = unit.character
		event.side = unit.side
	if (event.get("hero_report", false) or event.get("plasma_report", false)) and unit != null:
		event.shooter_peer = unit.peer_id
	if event.type == "plasma" and unit != null:
		event.audio_height = _missile_target_altitude(unit)
	if event.type == "shot" and unit != null:
		event.muzzle_ground = _npc_presentation_ground(unit.position)
		event.garrison = bool(unit.special.get("garrison", false))
		if unit.kind == "heli":
			event.muzzle_y = floorf(_missile_target_altitude(unit) + .5)
	events.append(event)
	if event.type == "projectile_terminal":
		present_projectile_terminal(event)
	if event.type == "local_blast":
		present_blast(event)
	if event.get("hero_report", false):
		present_shot(event)
	if event.get("plasma_report", false):
		present_plasma(event)
	if unit != null:
		var accepted := unit.present_body_event(event, presentation_time())
		if accepted and event.type == "weapon_fire" and unit.is_pilot():
			_fire_squad_clones(unit, event.slot, int(event.get("serial", -1)), presentation_time())
		if accepted and event.type == "shot" and not Session.dedicated:
			present_shot(event)
		if unit.authority_body != null:
			unit.authority_body.accept(event, presentation_time(), unit.global_position)
	body_event.emit(event)

func presentation_time() -> float:
	return BodyPresentation.time_now() + (0.0 if is_nan(body_clock_offset) else body_clock_offset)

func receive_body_events(received: Array, now: float) -> void:
	for event: Dictionary in received:
		if not event.has("body_serial"):
			continue
		if event.type == "local_blast":
			present_blast(event)
			continue
		if event.type == "projectile_terminal":
			present_projectile_terminal(event)
			continue
		if event.get("hero_report", false):
			present_shot(event)
			continue
		if event.get("plasma_report", false):
			present_plasma(event)
			continue
		var unit: BattleUnit = units.get(int(event.actor))
		if unit != null:
			var accepted := unit.present_body_event(event, now)
			if accepted and event.type == "weapon_fire" and unit.is_pilot():
				_fire_squad_clones(unit, event.slot, int(event.get("serial", -1)), now)
			if accepted and event.type == "shot" and not Session.dedicated:
				present_shot(event)

func _sync_body_charge(unit: BattleUnit) -> void:
	var charging := unit.recoil.rail_at != 0 or unit.recoil.steady_at != 0
	if unit.body_charge_on == charging:
		return
	unit.body_charge_on = charging
	_emit_body_event({"type": "heavy_charge", "actor": unit.entity_id, "on": charging})

func _create_bot_brain(unit: BattleUnit) -> void:
	if not Content.balance.has("bot") or bot_tower_sites.size() != world.lane_points.size():
		_setup_failed("Missing original bot policy/tower-site data; regenerate source content")
		return
	var brain := BotBrain.new()
	unit.bot_dodge_speed = Vector2(unit.velocity.x, unit.velocity.z).length()
	brain.configure(self, unit, bot_difficulty)
	bot_brains[unit.entity_id] = brain

func _bot_aim(unit: BattleUnit, aiming: bool) -> void:
	if not authoritative or over or not unit.alive() or aiming and unit.has_status("blind_until", clock):
		return
	if unit.input_state.get("aim", false) and not aiming:
		unit.aim_off_at = clock
	unit.input_state.aim = aiming

func _bot_defend(unit: BattleUnit, defending: bool) -> void:
	if authoritative and not over and unit.alive():
		unit.defending = defending and unit.shield > 0 and unit.cast_state.is_empty()

func _bot_move(unit: BattleUnit, destination: Vector2, delta: float) -> float:
	if not authoritative or over or not unit.alive() or not destination.is_finite() or not is_finite(delta) or delta <= 0:
		return 0.0
	var old := unit.position
	var requested := Vector2(destination.x - old.x, destination.y - old.z).length()
	var altitude := _missile_target_altitude(unit)
	var surface := _npc_surface(destination)
	if not is_finite(surface) or not is_finite(altitude):
		return 0.0
	var desired := Vector3(destination.x, surface + maxf(0.1, altitude), destination.y)
	unit.move_and_collide(desired - old)
	_update_fluid_state(unit)
	return _planar_distance(unit.position, old) / requested if requested > 0.0001 else 1.0

func _bot_altitude(unit: BattleUnit, altitude: float) -> void:
	if not authoritative or over or not unit.alive() or not is_finite(altitude):
		return
	var surface := _npc_surface(Vector2(unit.position.x, unit.position.z))
	if not is_finite(surface):
		return
	var was_flying := unit.flying
	unit.flying = unit.kind == "drone" or unit.kind == "morph" and altitude > float(Content.constants.FLY_Y)
	if was_flying != unit.flying:
		unit.refresh_collision()
	unit.move_and_collide(Vector3.UP * (minf(world.ceiling, surface + maxf(0.1, altitude)) - unit.position.y))
	unit.sync_view_camera()
	_update_fluid_state(unit)

func _bot_clear_shot(unit: BattleUnit, target: BattleUnit) -> bool:
	var ground := world.ground_height(unit.position.x, unit.position.z)
	if not is_finite(ground):
		return false
	return _visible_from(Vector3(unit.position.x, ground + _missile_target_altitude(unit) + Content.constants.LOS.EYE_M, unit.position.z), target)

func _refill_if_done(unit: BattleUnit, slot: String, definition: Dictionary) -> void:
	if authoritative and unit.reload_at.has(slot) and float(unit.reload_at[slot]) > 0 and clock >= float(unit.reload_at[slot]):
		unit.ammo[slot] = definition.mag
		unit.reload_at.erase(slot)

func reload_weapon(unit: BattleUnit, slot: String) -> void:
	if not authoritative or over or not unit.alive() or not unit.is_pilot() or slot not in ["light", "heavy"]:
		return
	var def := weapon_definition(unit.character, slot, unit.combat_level(slot))
	_refill_if_done(unit, slot, def)
	if float(unit.reload_at.get(slot, 0)) > clock or unit.ammo.get(slot, def.mag) >= def.mag:
		return
	unit.ammo[slot] = 0
	unit.reload_at[slot] = clock + _reload_duration(unit, def)

func _reload_duration(unit: BattleUnit, definition: Dictionary) -> float:
	var boss_factor: float = Content.constants.BOSS.ENRAGE_RELOAD_F if unit.special.get("boss", false) and int(unit.special.get("boss_segment", 0)) >= 3 else 1.0
	return definition.reload * StatusRules.multiplier(unit.buffs, "reload", clock) * float(weather_dynamics.get("snowCdMul", 1)) * boss_factor

func _weapon_rate(unit: BattleUnit, definition: Dictionary) -> float:
	var boss_factor: float = Content.constants.BOSS.ENRAGE_RATE_F if unit.special.get("boss", false) and int(unit.special.get("boss_segment", 0)) >= 3 else 1.0
	return definition.rate * weather_attack_rate(unit) * (0.5 if unit.defending and unit.shield > 0 else 1.0) * boss_factor

func _tick_weapon_pose(unit: BattleUnit, delta: float) -> void:
	if not authoritative or unit.weapon_pose == null:
		return
	var slot: String = unit.input_state.get("slot", "light")
	if slot not in ["light", "heavy"]:
		return
	var def := weapon_definition(unit.character, slot, unit.combat_level(slot))
	var control: Dictionary = fire_controls.get(unit.entity_id, {})
	var elevation := CockpitPose.barrel_elevation(control.velocity, control.direction) if not control.is_empty() and slot == "heavy" and unit.input_state.get("aim", false) else 0.0
	unit.weapon_pose.advance(delta, clock, slot, unit.flying, def, unit.reload_at.get(slot, NAN), elevation, unit.alive())

func _tick_view_fov(unit: BattleUnit, delta: float) -> void:
	var stats: Dictionary = Content.constants.UNITS[unit.kind]
	var base: float = stats.get("fovAir", stats.get("fov", 68)) if unit.flying else stats.get("fov", 68)
	unit.authority_fov = ScopeState.fov_step(unit.authority_fov, float(stats.get("zoomFov", base)) if unit.input_state.get("aim", false) else base, delta)

func _tick_authority_body(unit: BattleUnit, delta: float) -> void:
	if unit.authority_body == null:
		return
	unit.presented_altitude = _missile_target_altitude(unit)
	if not is_finite(unit.presented_altitude):
		return
	var expanded := unit.has_status("shield_expand_until", clock)
	unit.authority_body.advance(delta, presentation_time(), unit.global_position, unit.facing_yaw(), unit.body_scale,
		{"hero": true, "heroY": unit.presented_altitude, "flies": unit.flying, "dead": not unit.alive(),
			"sp": unit.shield, "visualDefense": unit.defending and unit.shield > 0, "visualShieldExpand": expanded}, unit.view_mode != "tps")

func _shot_view_mode(unit: BattleUnit, slot: String) -> String:
	if slot == "heavy" and unit.input_state.get("aim", false) and float(unit.ammo.get(slot, INF)) <= 1 and unit.input_state.get("view_restore") == "tps":
		return "tps"
	return unit.view_mode

func _launch_pose(unit: BattleUnit, slot: String, reach: float, direction: Variant = null, remember: bool = false, mode: String = "") -> Dictionary:
	unit.ensure_weapon_pose()
	if (unit.view_mode if mode.is_empty() else mode) == "tps":
		if unit.authority_body == null or unit.authority_body.body.source_root == null:
			return {"origin": Vector3(NAN, NAN, NAN), "direction": direction}
		return unit.authority_body.muzzle(slot, unit.global_position, unit.view_eye_height(), unit.facing_yaw(), unit.view_origin(), reach, direction)
	return {"origin": unit.weapon_pose.muzzle(unit.aim_transform(), slot, unit.flying, true, remember), "direction": direction}

func fire(unit: BattleUnit, slot: String) -> void:
	if not authoritative or over or not unit.alive() or not unit.is_pilot() or slot not in ["light", "heavy"]:
		return
	var def := weapon_definition(unit.character, slot, unit.combat_level(slot))
	var serial := unit.fire_serial
	_fire_once(unit, slot, def)
	if unit.fire_serial != serial and not unit.is_bot and unit.alive():
		_apply_recoil(unit, def, slot, unit.last_launch_direction)
		if slot == "heavy" and unit.input_state.get("aim", false) and float(unit.ammo.get("heavy", 0)) <= 0:
			_set_human_aim(unit, false)

func _fire_once(unit: BattleUnit, slot: String, def: Dictionary) -> void:
	if not _weapon_ready(unit, slot, def):
		return
	if not unit.is_bot:
		var ready := unit.recoil.gate(def, slot, clock, InputRules.moving(unit.input_state))
		_sync_body_charge(unit)
		if not ready:
			return
	unit.ensure_weapon_pose()
	var emission_mode := _shot_view_mode(unit, slot)
	var start: Vector3 = _launch_pose(unit, slot, def.range, null, false, emission_mode).origin
	if not start.is_finite():
		message.emit(unit.peer_id, "view_unavailable")
		return
	var launch_surface := NAN
	var shooter_frame := {}
	if def.trajectory in ["guide", "fnf", "lob", "flat"]:
		launch_surface = _weapon_surface(start)
		var reference := _height_reference(unit)
		if not is_finite(launch_surface) or not is_finite(reference):
			message.emit(unit.peer_id, "unavailable_surface")
			return
		shooter_frame = _shooter_frame(unit, reference)
	var control := {}
	if def.trajectory == "lob":
		control = fire_controls.get(unit.entity_id, {})
		# Source launches this frame's preview solution, solved from the current muzzle, from the next emission port.
		var preview_origin := _advisory_origin(unit, "heavy")
		if control.is_empty() or control.clock != clock or control.camera != unit.aim_transform() or control.pose_clock != unit.weapon_pose.clock or control.direction != unit.aim_direction() or control.level != unit.combat_level("heavy") or control.origin != preview_origin:
			control = lob_control(unit, def, preview_origin)
			fire_controls[unit.entity_id] = control
		if control.is_empty():
			message.emit(unit.peer_id, "unavailable_surface")
			return
	var reach: float = def.range
	if def.trajectory != "lob":
		reach = _launch_range(unit, def, _aim_target(unit, TargetingMath.maximum_range(def)))
		if not is_finite(reach):
			message.emit(unit.peer_id, "unavailable_surface")
			return
	var firing_direction: Vector3 = _launch_pose(unit, slot, reach, unit.aim_direction(), false, emission_mode).direction
	unit.last_launch_direction = firing_direction
	_spend_weapon_fire(unit, slot, def, 0, start, emission_mode)
	if def.trajectory == "flat":
		var state := ProjectileMotion.ballistic(start, firing_direction * def.projectile.speed, reach)
		state.actor = unit.entity_id
		state.side = unit.side
		state.definition = def.duplicate(true)
		state.origin_surface = launch_surface
		state.shooter_frame = shooter_frame
		state.slot = slot
		state.visual_speed = float(def.projectile.speed)
		_register_projectile(state)
		return
	if def.trajectory == "lob":
		var state := ProjectileMotion.ballistic(start, control.velocity, control.range)
		state.actor = unit.entity_id
		state.side = unit.side
		state.definition = def.duplicate(true)
		state.shooter_frame = shooter_frame
		state.visual_speed = float(def.projectile.antiAirSpeed if control.aa else def.projectile.speed)
		_register_projectile(state, RemoteShotState.relay(start, firing_direction, control))
		return
	if def.trajectory in ["guide", "fnf"]:
		var aim := _projectile_aim(unit, reach)
		_launch_guided(unit, def, start, aim.point, aim.hit, launch_surface, reach, shooter_frame, firing_direction)
		return
	var precise := _projectile_aim(unit, reach, def.area == "line")
	var end: Vector3 = precise.point
	var confirmed_contact := false
	match def.area:
		"blast":
			blast(unit, def, end)
		"fan":
			_fire_fan(unit, def, start, firing_direction)
		"line":
			var reference := _height_reference(unit)
			if is_finite(reference):
				_fire_line(unit, def, start, end, reference, _shooter_frame(unit, reference))
		_:
			if int(precise.missile) != 0 and start.distance_to(end) <= def.range * Content.constants.RANGE_TOL:
				confirmed_contact = true
				_damage_missile(unit, def, int(precise.missile))
			var target: BattleUnit = precise.target if precise.target != null else _aim_target(unit, reach) if int(precise.missile) == 0 else null
			if target != null:
				var surface := _height_reference(unit)
				var target_surface := _projectile_surface(target.position)
				if not is_finite(surface) or not is_finite(target_surface):
					return
				var target_height: float = target.position.y - target_surface if target.is_hero() else 0.0
				var offset := Vector3(target.position.x - unit.position.x, target_height - (unit.position.y - surface), target.position.z - unit.position.z)
				var budget: float = def.range * _settlement_range_factor(unit, def, start, surface, target, target_surface, _shooter_frame(unit, surface)) * Content.constants.RANGE_TOL
				var launch_budget: float = _launch_range(unit, def, target) * Content.constants.RANGE_TOL
				if visible_to_side(target, unit.side) and visible_to(unit, target) and CombatMath.direct_in_range(budget, offset, target.radius) and CombatMath.direct_in_range(launch_budget, target.position - start, target.radius):
					confirmed_contact = true
					if not _roll_miss(unit, target, def):
						var amount: float = def.dmg * CombatMath.damage_falloff(def, offset.length())
						amount = _roll_critical(unit, target, def, amount)
						damage(unit, target, def, amount)
	_emit_body_event({"type": "shot", "hero_report": true, "actor": unit.entity_id, "start": start, "end": end, "side": unit.side,
		"slot": slot, "weapon_type": def.type, "area": def.area, "level": unit.combat_level(slot),
		"direction": firing_direction, "range": reach, "hit": confirmed_contact, "shot_serial": unit.fire_serial})

func _apply_recoil(unit: BattleUnit, definition: Dictionary, slot: String, direction: Vector3, echo: bool = false) -> void:
	var back := unit.recoil.accepted(definition, slot, clock, unit.flying, _recoil_next, echo)
	if back == 0:
		return
	if unit.flying:
		unit.velocity -= direction * back
	else:
		unit.impulse_velocity -= Vector2(direction.x, direction.z) * back
		unit.velocity.y -= direction.y * back

func _recoil_next() -> float:
	return recoil_random.randf()

func _tick_recoil_echoes(unit: BattleUnit) -> void:
	for echo: Dictionary in unit.recoil.echoes.take_due(clock):
		var definition: Dictionary = echo.payload.definition
		var direction := unit.aim_direction()
		if unit.view_mode == "tps":
			var reach := _launch_range(unit, definition, _aim_target(unit, TargetingMath.maximum_range(definition)))
			if not is_finite(reach):
				continue
			direction = _launch_pose(unit, echo.payload.slot, reach, direction).direction
		_emit_body_event({"type": "body_echo", "actor": unit.entity_id, "slot": echo.payload.slot})
		_apply_recoil(unit, definition, echo.payload.slot, direction, true)

func _weapon_ready(unit: BattleUnit, slot: String, definition: Dictionary, source_cadence: bool = false, lenient: bool = false, reload_back: float = 0.0) -> bool:
	if not authoritative or over or not unit.alive() or not unit.is_pilot() or unit.has_status("emp_until", clock) or unit.has_status("blind_until", clock):
		return false
	if source_cadence:
		_refill_if_done(unit, slot, definition)
	if unit.has_status("phase_until", clock) or unit.has_status("cast_lock_until", clock) or not unit.cast_state.is_empty() or not source_cadence and unit.has_status("freeze_until", clock):
		return false
	if slot == "heavy" and unit.has_status("clones_until", clock):
		return false
	if not source_cadence:
		_refill_if_done(unit, slot, definition)
	if float(unit.reload_at.get(slot, 0)) > clock:
		return false
	if source_cadence:
		var rate := _weapon_rate(unit, definition)
		if clock - float(unit.last_fired_at.get(slot, 0)) < 1 / (rate * (1.5 if lenient else 1.0)):
			return false
	elif clock < float(unit.fire_at.get(slot, 0)):
		return false
	if not unit.ammo.has(slot):
		unit.ammo[slot] = definition.mag
	if float(unit.ammo[slot]) <= 0:
		if unit.has_status("no_reload_until", clock) or unit.has_status("no_%s_reload_until" % slot, clock):
			unit.ammo[slot] = definition.mag
		else:
			if source_cadence:
				unit.reload_at[slot] = clock - reload_back + _reload_duration(unit, definition)
			else:
				reload_weapon(unit, slot)
			return false
	if unit.power < float(definition.heavyMp):
		return false
	return source_cadence and not lenient or not definition.get("needAim", false) or unit.input_state.get("aim", false)

func _spend_weapon_fire(unit: BattleUnit, slot: String, definition: Dictionary, reload_back: float = 0.0, origin: Vector3 = Vector3(NAN, NAN, NAN), emission_mode: String = "") -> void:
	unit.ammo[slot] -= 1
	unit.power -= definition.heavyMp
	unit.fire_at[slot] = clock + 1.0 / _weapon_rate(unit, definition)
	unit.last_fired_at[slot] = clock
	if unit.ammo[slot] <= 0 and not unit.has_status("no_reload_until", clock) and not unit.has_status("no_%s_reload_until" % slot, clock):
		unit.reload_at[slot] = clock - reload_back + _reload_duration(unit, definition)
	if unit.has_status("alpha_arm_until", clock) and unit.has_status("stealth_until", clock):
		_add_modifier(unit, "dmg", float(unit.status.get("alpha_multiplier", 1)), Content.constants.SELF_ATK.ALPHA_S)
		unit.status.alpha_arm_until = 0
	unit.status.stealth_until = 0
	unit.play_action(slot)
	unit.fire_serial += 1
	unit.ensure_weapon_pose()
	var port := origin
	if not origin.is_finite():
		port = _launch_pose(unit, slot, definition.range, null, true).origin
	elif emission_mode != "tps":
		unit.weapon_pose.muzzle(unit.aim_transform(), slot, unit.flying)
	unit.weapon_pose.fire(unit.fire_serial, slot, clock, definition)
	_emit_body_event({"type": "weapon_fire", "actor": unit.entity_id, "slot": slot, "side": unit.side,
		"public_pose": not unit.is_bot,
		"serial": unit.fire_serial, "clock": clock, "muzzle": port, "empty_heavy": slot == "heavy" and unit.ammo[slot] <= 0, "aim_request": unit.aim_request,
		"level": unit.combat_level(slot)})

func _bot_fire(unit: BattleUnit, target: BattleUnit, slot: String, mode: String = "direct") -> bool:
	if not authoritative or over or not unit.alive() or not unit.is_pilot() or target == null or target.side == unit.side or slot not in ["light", "heavy"] or mode not in ["direct", "burst", "fan"]:
		return false
	var definition := weapon_definition(unit.character, slot, unit.combat_level(slot))
	var altitude := _missile_target_altitude(unit)
	var target_altitude := _missile_target_altitude(target) if target.is_hero() else 0.0
	var offset := Vector3(target.position.x - unit.position.x, target_altitude - altitude, target.position.z - unit.position.z)
	var reach: float = definition.range * CombatMath.altitude_range(definition, _height_difference(unit, target)) * StatusRules.multiplier(unit.buffs, "range", clock)
	var origin := unit.position + Vector3.UP * float(Content.constants.LOS.EYE_M)
	var endpoint := target.sight_target()
	var back := 0.0
	var burst_origin := Vector2(unit.position.x, unit.position.z)
	if mode == "burst":
		var cap: float = definition.projectile.fuel if definition.trajectory == "fnf" else definition.projectile.flightCap
		var previous := ShotHistory.origin(unit.position_trail, clock, Vector2(unit.position.x, unit.position.z), Vector2(target.position.x, target.position.z), definition, cap)
		var maximum: float = TargetingMath.maximum_range(definition) * Content.constants.RANGE_TOL
		var distance: float = previous.point.distance_to(Vector2(target.position.x, target.position.z))
		var height := _missile_target_altitude(target) if target.is_hero() or target.kind == "heli" else 0.0
		if distance > maximum or definition.trajectory == "lob" and distance > CombatMath.max_horizontal(maximum, height - altitude):
			return false
		back = previous.back
		burst_origin = previous.point
	elif mode == "direct" and offset.length() > reach and not (offset.y < 0 and CombatMath.in_range(reach, offset, target.radius)):
		return false
	if mode != "fan" and not _bot_clear_shot(unit, target) or not _weapon_ready(unit, slot, definition, true, mode != "direct", back):
		return false
	_spend_weapon_fire(unit, slot, definition, back)
	if mode == "direct":
		unit.bot_shot_count += 1
	if mode == "burst" or mode == "direct" and (slot == "heavy" or unit.bot_shot_count % 3 == 0):
		_emit_body_event({"type": "shot", "hero_report": true, "bot_report": true, "actor": unit.entity_id,
			"start": origin, "end": endpoint, "side": unit.side, "slot": slot,
			"weapon_type": definition.type, "area": definition.area, "shot_serial": unit.fire_serial})
	if mode == "burst":
		var height := _missile_target_altitude(target) if target.is_hero() or target.kind == "heli" else 0.0
		var impact := Vector3(target.position.x, clampf(height, 0, 400), target.position.z)
		var friendly := LobFireControl.friendly_impact(definition, Vector3(burst_origin.x, altitude, burst_origin.y), impact)
		_publish_blast_event({"type": "boom", "actor": unit.entity_id, "position": _missile_world_position(impact), "radius": definition.r, "side": unit.side})
		blast(unit, definition, impact, friendly, true, 0)
	elif mode == "fan":
		var direction := Vector3(target.position.x - unit.position.x, _relative_target(target).y - altitude - Content.constants.LOS.EYE_M, target.position.z - unit.position.z).normalized()
		_fire_fan(unit, definition, origin, direction)
		_emit_body_event({"type": "plasma", "plasma_report": true, "actor": unit.entity_id, "position": unit.position, "direction": direction,
			"start": origin, "radius": definition.range, "arc": definition.arc if definition.arc else 15,
			"level": unit.combat_level(slot), "slot": slot, "side": unit.side})
	else:
		if not _roll_miss(unit, target, definition):
			var amount := _roll_critical(unit, target, definition, float(definition.dmg) * CombatMath.damage_falloff(definition, offset.length()))
			_apply_hit_emp(definition, target)
			_apply_hit_elements(unit, definition, target)
			damage(unit, target, definition, amount * _weapon_multiplier(unit, target, definition), false, {"origin": unit.position}, false)
			if definition.area == "line":
				var direction := Vector3(target.position.x - unit.position.x, _relative_target(target).y - altitude - Content.constants.LOS.EYE_M, target.position.z - unit.position.z).normalized()
				_fire_line(unit, definition, origin, origin + direction * reach, _height_reference(unit), {}, {"skip": target.entity_id, "critical": false, "intercept": false, "maximum": reach})
	return true

func lob_control(unit: BattleUnit, def: Dictionary, launch_origin: Vector3 = Vector3(NAN, NAN, NAN)) -> Dictionary:
	var origin := launch_origin if launch_origin.is_finite() else _advisory_origin(unit, "heavy")
	var direction := unit.aim_direction()
	var maximum := TargetingMath.maximum_range(def)
	var crosshair := _projectile_aim(unit, maximum)
	var aim: Vector3 = crosshair.point
	var target: BattleUnit = crosshair.target
	var anti_air := target != null and CombatMath.target_class(target.kind) == "air"
	if anti_air:
		aim = target.aim_point()
		if not aim.is_finite():
			return {}
	var reach := _launch_range(unit, def, target)
	if not is_finite(reach):
		return {}
	var control := LobFireControl.prepare(def, origin, aim, reach, anti_air, world.ground_height, _arc_collision)
	if control.is_empty():
		return {}
	control.clock = clock
	control.origin = origin
	control.camera = unit.aim_transform()
	control.pose_clock = unit.weapon_pose.clock
	control.direction = direction
	control.level = unit.combat_level("heavy")
	control.target = target.entity_id if target != null else 0
	return control

func _launch_range(unit: BattleUnit, def: Dictionary, target: BattleUnit) -> float:
	if target == null:
		return def.range
	var surface := _height_reference(unit)
	var target_surface := world.ground_height(target.position.x, target.position.z)
	if not target.is_hero() and (not is_finite(surface) or not is_finite(target_surface)):
		return NAN
	return TargetingMath.launch_range(def, unit.position, unit.view_origin(), surface,
		{"hero": target.is_hero(), "position": target.position, "kind": target.kind,
		"altitude": target.position.y - target_surface})

func _aim_target(unit: BattleUnit, reach: float) -> BattleUnit:
	var control: Dictionary = fire_controls.get(unit.entity_id, {})
	if not control.is_empty() and unit.input_state.get("aim", false) and unit.input_state.get("slot", "light") == "heavy":
		var controlled: BattleUnit = units.get(int(control.get("target", 0)))
		var eligible := controlled != null and controlled.alive() and controlled.side != unit.side and visible_to_side(controlled, unit.side)
		return units.get(TargetingMath.aim_choice(unit.position, reach, {}, 0,
			{"on": true, "ok": control.ok and eligible, "target": int(control.get("target", 0))}))
	var precise := _projectile_aim(unit, reach)
	var exact := {} if precise.target == null else {"id": precise.target.entity_id, "point": precise.point}
	var exact_id := TargetingMath.aim_choice(unit.position, reach, exact, 0)
	if exact_id != 0:
		return units.get(exact_id)
	var candidates: Array = []
	var camera := unit.view_origin()
	for target: BattleUnit in units.values():
		if not target.is_hero() or not target.alive() or target.side == unit.side or not visible_to_side(target, unit.side):
			continue
		var point := target.aim_point()
		if not point.is_finite():
			continue
		var obstruction := world.obstruction_hit(camera, point)
		candidates.append({"id": target.entity_id, "hero": true, "point": point,
			"obstruction": INF if obstruction.is_empty() else camera.distance_to(obstruction.position)})
	return units.get(TargetingMath.cone_acquire(unit.position, camera, unit.aim_direction(), reach, candidates, unit.aim_anchor))

func _tick_lock(unit: BattleUnit) -> void:
	if not authoritative or over or not unit.alive():
		return
	if unit.has_status("blind_until", clock):
		return
	if clock - unit.lock_check_at < Content.balance.targeting.lockInterval:
		return
	unit.lock_check_at = clock
	if clock - unit.lock_at > Content.constants.LOCK.TTL:
		unit.aim_anchor = 0
	var slot := "heavy" if unit.input_state.get("aim", false) else "light"
	var def := weapon_definition(unit.character, slot, unit.combat_level(slot))
	var target := _aim_target(unit, TargetingMath.maximum_range(def))
	var primary := {}
	if target != null:
		var multiplier: float = Content.constants.FAN_RANGE_CENTER_F if def.area == "fan" else 1.0
		primary = {"id": target.entity_id, "distance": unit.position.distance_to(target.position) - target.radius,
			"reach": _launch_range(unit, def, target) * multiplier}
	var flights: Array = []
	var heavy := weapon_definition(unit.character, "heavy", unit.combat_level("heavy"))
	if heavy.trajectory == "fnf":
		for projectile: Dictionary in projectiles:
			if projectile.actor != unit.entity_id or int(projectile.get("target", 0)) == 0:
				continue
			var pursued: BattleUnit = units.get(int(projectile.target))
			if pursued == null or not pursued.alive() or pursued.side == unit.side or not visible_to_side(pursued, unit.side):
				continue
			flights.append({"id": pursued.entity_id, "distance": unit.position.distance_to(pursued.position) - pursued.radius,
				"reach": _launch_range(unit, heavy, pursued)})
	var candidate := TargetingMath.lock_candidate(primary, flights, unit.lock_keep_index)
	unit.lock_keep_index = candidate.index
	if candidate.id == 0:
		unit.aim_anchor = 0
		return
	_confirm_lock(unit, int(candidate.id))

func _confirm_lock(unit: BattleUnit, target_id: int) -> void:
	if not authoritative or over:
		return
	if unit.has_status("blind_until", clock):
		return
	var target: BattleUnit = units.get(target_id)
	if target == null or not unit.alive() or not target.alive() or target.side == unit.side or not visible_to_side(target, unit.side) or not visible_to(unit, target):
		return
	if target.special.get("neutral", false) or target.special.get("garrison", false):
		return
	if unit.side == Content.constants.SUPER_SIDE and target.side in ["GUER", "MILI"] or target.side == Content.constants.SUPER_SIDE and unit.side in ["GUER", "MILI"]:
		return
	var slot := "heavy" if unit.input_state.get("aim", false) else "light"
	if slot == "light" and unit.lock_target == target_id and clock - unit.lock_at <= Content.constants.LOCK.TTL:
		var heavy := weapon_definition(unit.character, "heavy", unit.combat_level("heavy"))
		if clock - unit.aim_off_at <= heavy.projectile.flightCap:
			slot = "heavy"
	var def := weapon_definition(unit.character, slot, unit.combat_level(slot))
	var surface := _projectile_surface(unit.position)
	var target_surface := _projectile_surface(target.position)
	if not is_finite(surface) or not is_finite(target_surface):
		return
	var delta := target.position - unit.position
	if not target.is_hero() and target.kind != "heli":
		delta.y = - (unit.position.y - surface)
	var multiplier: float = Content.constants.FAN_RANGE_CENTER_F if def.area == "fan" else 1.0
	var reach: float = def.range * _settlement_range_factor(unit, def, unit.view_origin(), surface, target, target_surface, _shooter_frame(unit, surface)) * Content.constants.RANGE_TOL * multiplier
	if maxf(0, delta.length() - target.radius) > reach:
		return
	unit.lock_target = target_id
	unit.aim_anchor = target_id
	unit.lock_at = clock
	events.append({"type": "lock", "actor": unit.entity_id, "peer": unit.peer_id,
		"side": unit.side, "target": target_id, "target_peer": target.peer_id if target.is_hero() else 0})

func _hit_unit(hit: Dictionary) -> BattleUnit:
	if hit.is_empty() or not hit.has("collider"):
		return null
	if hit.collider is BattleUnit:
		return hit.collider
	return hit.collider.get_parent() as BattleUnit

func _projectile_aim(unit: BattleUnit, reach: float, pierce: bool = false) -> Dictionary:
	return _projectile_ray(unit, unit.view_origin(), unit.aim_direction(), reach, pierce)

func presentation_aim(unit: BattleUnit, camera: Camera3D, reach: float, third_person: bool) -> Dictionary:
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z.normalized()
	var camera_distance := origin.distance_to(unit.global_position) if third_person else 0.0
	var far := reach + camera_distance
	var geometry := _projectile_ray(unit, origin, direction, far, true, 1)
	var targets := _projectile_ray(unit, origin, direction, far, false, 2 | 512)
	var stop := origin.distance_to(geometry.point) if not geometry.hit.is_empty() else INF
	# Source TPS ignores a terrain stop behind the player, retaining target hits.
	if stop < camera_distance * float(Content.balance.controls.casting.rearStopFactor):
		stop = INF
	if not targets.hit.is_empty() and origin.distance_to(targets.point) <= stop:
		return targets
	if is_finite(stop):
		return geometry
	return {"point": origin + direction * far, "hit": {}, "target": null, "missile": 0}

func _projectile_ray(unit: BattleUnit, origin: Vector3, direction: Vector3, reach: float, pierce: bool = false, mask: int = -1) -> Dictionary:
	var end := origin + direction * reach
	var excluded: Array[RID] = []
	for candidate: BattleUnit in units.values():
		if candidate.side == unit.side or not candidate.alive() or not visible_to_side(candidate, unit.side):
			excluded.append(candidate.hit_area.get_rid())
	var collision_mask := mask
	if collision_mask < 0:
		collision_mask = 1 if pierce else 1 | 2 | 512
	var query := PhysicsRayQueryParameters3D.create(origin, end, collision_mask, excluded)
	query.collide_with_areas = true
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: BattleUnit
	if not hit.is_empty():
		target = _hit_unit(hit)
	return {"point": hit.position if not hit.is_empty() else end, "hit": hit, "target": target,
		"missile": int(hit.collider.get_meta("missile", 0)) if not hit.is_empty() else 0}

func _arc_collision(start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _launch_guided(unit: BattleUnit, def: Dictionary, start: Vector3, aim: Vector3, hit: Dictionary, surface: float, reach: float, shooter_frame: Dictionary, direction: Vector3 = Vector3(NAN, NAN, NAN)) -> void:
	var target_id := 0
	var launch_def := def.duplicate(true)
	if def.trajectory == "fnf":
		var target := _aim_target(unit, reach)
		if target != null:
			target_id = target.entity_id
	if not hit.is_empty():
		var target := _hit_unit(hit)
		if target != null and target.alive() and target.side != unit.side and visible_to_side(target, unit.side):
			if def.trajectory == "guide" and def.type == "launcher" and CombatMath.target_class(target.kind) == "air":
				launch_def.projectile.speed = launch_def.projectile.antiAirSpeed
	var state := ProjectileMotion.launch(launch_def, start, direction if direction.is_finite() else unit.aim_direction(), surface,
		projectile_rng.next(), projectile_rng.next(), aim, target_id)
	state.actor = unit.entity_id
	state.side = unit.side
	state.range = reach
	# Upgrading or switching weapons cannot retune a warhead already in flight.
	state.definition = launch_def
	state.shooter_frame = shooter_frame
	_register_projectile(state)

func _register_projectile(state: Dictionary, relay: Dictionary = {}) -> void:
	var unit: BattleUnit = units[state.actor]
	state.visual_id = "%d/%d" % [unit.entity_id, unit.fire_serial]
	projectiles.append(state)
	var definition: Dictionary = state.definition
	var report := RemoteShotState.relay(state.origin, unit.last_launch_direction) if relay.is_empty() else relay
	var event := {"type": "shot", "hero_report": true, "remote_only": true, "actor": unit.entity_id,
		"start": state.origin, "end": report.target, "slot": definition.slot, "area": definition.area,
		"weapon_type": definition.type, "side": unit.side, "shot_serial": unit.fire_serial}
	if report.speed != null:
		event.mv = report.speed
	_emit_body_event(event)

func projectile_view(viewer: BattleUnit) -> Array:
	var states: Array = []
	if viewer == null:
		return states
	for state: Dictionary in projectiles:
		if state.actor != viewer.entity_id or not state.has("visual_id"):
			continue
		var definition: Dictionary = state.definition
		states.append({"id": state.visual_id, "key": "%s-%s-%s" % [definition.ch, definition.slot, state.side.to_lower()],
			"position": state.position, "velocity": state.velocity, "age": state.age,
			"speed": float(state.get("visual_speed", definition.projectile.speed))})
	return states

func present_echo(definition: Dictionary, origin: Vector3, unit: BattleUnit) -> void:
	if world == null or over or not unit.alive():
		return
	_fire_squad_clones(unit, definition.slot, -1, presentation_time())
	var reach := _launch_range(unit, definition, _aim_target(unit, TargetingMath.maximum_range(definition)))
	if not is_finite(reach):
		return
	var presentation := world.ensure_projectile_visuals()
	var direction := unit.aim_direction()
	if unit.render_view_mode == "tps" and unit.camera != null:
		direction = unit.camera.global_basis * Vector3.FORWARD
	if definition.type in ["beam", "rail"]:
		var ray: Dictionary = _projectile_ray(unit, unit.camera.global_position, direction, reach, definition.area == "line") if unit.render_view_mode == "tps" and unit.camera != null else _projectile_aim(unit, reach, definition.area == "line")
		var point: Vector3 = ray.point
		presentation.tracer(origin, point, _fpv_tracer_color(definition.type, unit.side))
		return
	if unit.render_view_mode == "tps" and unit.camera != null:
		direction = SourceQuaternion.vector_normalized(unit.camera.global_position + direction * reach - origin)
	var target := origin + direction * reach
	var ground := world.ground_height(target.x, target.z) if definition.type == "launcher" else NAN
	var surface := _weapon_surface(origin) if definition.trajectory in ["guide", "fnf"] else NAN
	if (definition.type == "launcher" and not is_finite(ground)) or (definition.trajectory in ["guide", "fnf"] and not is_finite(surface)):
		return
	var state := VisualShellMotion.launch(definition, origin, target, ground, surface, definition.projectile.speed)
	presentation.spawn_shell(state, "%s-%s-%s" % [definition.ch, definition.slot, unit.side.to_lower()])

func _projectile_surface(point: Vector3) -> float:
	if world == null:
		return 0.0
	var bottom: float = world.native_data.min_height - 100 if world.native_data != null else -100
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.01, Vector3(point.x, bottom, point.z), 8 | 16 | 32 | 64 | 1024)
	# The synthetic test world uses only the ordinary static collision layer.
	if world.native_data == null:
		query.collision_mask = 1
	var hit := SupportRay.intersect(get_world_3d().direct_space_state, query)
	return hit.position.y if not hit.is_empty() else NAN

func _weapon_surface(point: Vector3) -> float:
	var ground := world.ground_height(point.x, point.z)
	if not is_finite(ground):
		return NAN
	var surface := world.layers.projectile_surface(point, ground)
	var probe := Vector3(point.x, maxf(point.y, surface) + Content.balance.structure.deckStep, point.z)
	if not is_finite(_projectile_surface(probe)):
		return NAN
	var physical := _projectile_surface(point)
	if is_finite(physical) and physical > surface and point.y >= physical - Content.balance.structure.deckStep:
		surface = physical
	return surface

func _tick_projectiles(delta: float) -> void:
	if not authoritative or over:
		return
	var visibility: Dictionary = {}
	for index in range(projectiles.size() - 1, -1, -1):
		if over:
			return
		var state: Dictionary = projectiles[index]
		var def: Dictionary = state.definition
		if not visibility.has(state.side):
			var shown := {}
			for candidate: BattleUnit in units.values():
				if visible_to_side(candidate, state.side):
					shown[candidate.entity_id] = true
			visibility[state.side] = shown
		var target: BattleUnit = units.get(state.target)
		var target_data := {}
		if target != null and target.alive() and visibility[state.side].has(target.entity_id):
			target_data = {"position": target.global_position, "radius": target.radius}
		var previous := ProjectileMotion.advance(state, def, delta, target_data)
		var segment: Vector3 = state.position - previous
		var hit := {}
		if segment.length() > 0.01:
			var excluded: Array[RID] = []
			# Source client collision candidates contain only currently observed enemies.
			for unit: BattleUnit in units.values():
				if unit.side == state.side or not unit.alive() or not visibility[state.side].has(unit.entity_id):
					excluded.append(unit.hit_area.get_rid())
			var mask := 1 if def.area == "line" else 1 | 2 | 512
			var query := PhysicsRayQueryParameters3D.create(previous, state.position + segment.normalized() * 0.3, mask, excluded)
			query.collide_with_areas = true
			query.hit_back_faces = true
			hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			hit = ProjectileMotion.proximity(state, def, previous, target_data)
		var endpoint: Vector3 = hit.position if not hit.is_empty() else state.position
		var terminal := ProjectileMotion.finish(state, def, not hit.is_empty())
		events.append({"type": "shot", "actor": state.actor, "start": previous, "end": endpoint,
			"side": state.side, "slot": state.get("slot", "heavy"), "terminal": terminal, "physical": true})
		if not terminal:
			continue
		projectiles.remove_at(index)
		if def.trajectory == "flat" and def.area == "line":
			_emit_body_event({"type": "projectile_terminal", "actor": state.actor, "slot": def.slot, "side": state.side,
				"level": float(def.get("lvl", 1)), "start": state.origin, "end": endpoint,
				"visual_id": state.get("visual_id", ""), "clock": clock})
		var attacker: BattleUnit = units.get(state.actor)
		if attacker == null or not attacker.alive():
			continue
		if def.trajectory == "flat":
			if def.area == "line":
				_fire_line(attacker, def, state.origin, endpoint, state.origin_surface, state.shooter_frame)
			elif not hit.is_empty() and hit.collider.has_meta("missile"):
				if state.origin.distance_to(endpoint) <= def.range * Content.constants.RANGE_TOL:
					var fired_position: Vector3 = state.shooter_frame.position
					fired_position.y = state.shooter_frame.altitude
					_damage_missile(attacker, def, int(hit.collider.get_meta("missile")), fired_position)
			elif not hit.is_empty() and _hit_unit(hit) != null:
				var victim: BattleUnit = _hit_unit(hit)
				var surface := _height_reference(victim) if victim.is_hero() else world.ground_height(victim.position.x, victim.position.z)
				if not is_finite(surface):
					continue
				var target_height: float = victim.position.y - surface if victim.is_hero() else 0.0
				var fired_position: Vector3 = state.shooter_frame.position
				var offset := Vector3(victim.position.x - fired_position.x, target_height - state.shooter_frame.altitude, victim.position.z - fired_position.z)
				var reach: float = def.range * _settlement_range_factor(attacker, def, state.origin, state.origin_surface, victim, surface, state.shooter_frame) * Content.constants.RANGE_TOL
				var launch_budget: float = _launch_range_from_frame(def, state.shooter_frame, victim, surface) * Content.constants.RANGE_TOL
				if visible_to_side(victim, state.side) and _visible_from(state.origin, victim) and CombatMath.direct_in_range(reach, offset, victim.radius) and CombatMath.direct_in_range(launch_budget, victim.position - state.origin, victim.radius):
					if not _roll_miss(attacker, victim, def):
						var amount: float = def.dmg * CombatMath.damage_falloff(def, offset.length())
						amount = _roll_critical(attacker, victim, def, amount)
						damage(attacker, victim, def, amount, false, {"origin": state.origin})
			continue
		if state.dud or hit.is_empty():
			continue
		var level := world.layers.impact_level(endpoint)
		var tunnel := world.layers.tunnel_at(Vector2(endpoint.x, endpoint.z))
		var surface: float = tunnel.floor if level == 2 else world.ground_height(endpoint.x, endpoint.z)
		if not is_finite(surface):
			push_error("Projectile impact has no verified standing surface")
			continue
		var height := maxf(endpoint.y, surface + 1)
		_publish_local_blast(attacker, BlastFeedback.local_point(endpoint, world.ground_height(endpoint.x, endpoint.z), tunnel), BlastFeedback.local_radius(def.get("r")))
		# Source burst reports quantize height above the standing surface to decimetres.
		endpoint.y = surface + roundf((height - surface) * 10) / 10
		var friendly := LobFireControl.friendly_impact(def, state.shooter_frame.position if state.has("shooter_frame") else state.origin, endpoint)
		var report_point := _missile_world_position(Vector3(endpoint.x, endpoint.y - surface, endpoint.z))
		_publish_blast_event({"type": "boom", "actor": attacker.entity_id, "position": report_point, "radius": float(def.get("r", 0)), "side": attacker.side})
		blast(attacker, def, Vector3(endpoint.x, maxf(0, endpoint.y - surface), endpoint.z), friendly, true, level)

func blast(unit: BattleUnit, def: Dictionary, impact: Vector3, friendly: bool = false, relative_heights: bool = false, impact_level: int = -1, npc_damage: float = NAN) -> void:
	# Coverage deliberately ignores LOS; each victim consumes the original blast bands.
	for target: BattleUnit in units.values():
		if not target.alive() or (target.side == unit.side and not friendly):
			continue
		if impact_level >= 0 and not world.layers.slabs.is_empty() and world.layers.separated(impact_level, Vector2(impact.x, impact.z), Vector2(target.position.x, target.position.z), _unit_level(target)):
			continue
		var position := target.position
		if relative_heights:
			position.y = _body_altitude(target)
			if not position.is_finite():
				continue
		var flat := Vector2(impact.x - position.x, impact.z - position.z)
		var horizontal := maxf(0, flat.length() - target.radius)
		var vertical := maxf(0, maxf(position.y - impact.y, impact.y - position.y - target.height))
		var distance := Vector2(horizontal, vertical).length()
		var factor := CombatMath.blast_falloff(def.get("r", 0), distance)
		if factor > 0:
			var same := target.side == unit.side
			var probability := 0.0 if same else _dodge_probability(target, unit)
			if not same and _roll_miss(unit, target, def):
				continue
			var compensation := 1.0 / (1 - clampf(probability, 0, Content.constants.EVASION.P_MAX))
			var amount: float = (npc_damage if is_finite(npc_damage) else float(def.get("dmg", 0))) * factor * compensation
			if is_finite(npc_damage) and not target.is_hero():
				amount *= unit.creep_multiplier
			var context := {"blast": impact, "radius": def.get("r", 0)}
			if is_finite(npc_damage):
				_apply_hit_elements(null if same else unit, def, target)
				damage(null if same else unit, target, def, amount, friendly, context, false)
			elif same:
				_apply_hit_elements(null, def, target)
				damage(null, target, def, amount * _weapon_multiplier(unit, target, def), friendly, context, false)
			else:
				_apply_hit_elements(unit, def, target)
				damage(unit, target, def, amount * _weapon_multiplier(unit, target, def), friendly, context, false)

func _fire_fan(unit: BattleUnit, def: Dictionary, origin: Vector3 = Vector3(INF, INF, INF), direction: Vector3 = Vector3(INF, INF, INF)) -> void:
	if not origin.is_finite():
		origin = _advisory_origin(unit)
	if not direction.is_finite():
		direction = unit.aim_direction()
	var reference := _height_reference(unit)
	if not is_finite(reference):
		return
	var frame := _shooter_frame(unit, reference)
	var candidates: Array = []
	for target: BattleUnit in units.values():
		if target.side == unit.side or not target.alive():
			continue
		if not visible_to_side(target, unit.side) or not _visible_from(origin, target):
			continue
		var surface := _height_reference(target) if target.is_hero() else world.ground_height(target.position.x, target.position.z)
		if not is_finite(surface):
			continue
		var range_factor := _settlement_range_factor(unit, def, origin, reference, target, surface, frame)
		var position := target.global_position
		position.y = _body_altitude(target)
		candidates.append({"id": target.entity_id, "kind": target.kind, "position": position,
			"radius": target.radius, "height": target.height, "range_factor": range_factor})
	var relative_origin := Vector3(origin.x, origin.y - reference, origin.z)
	for hit in CombatMath.fan_hits(def, relative_origin, direction, candidates):
		var target: BattleUnit = units[hit.id]
		_apply_hit_elements(unit, def, target)
		damage(unit, target, def, hit.amount * _weapon_multiplier(unit, target, def), false, {"origin": origin}, false)

func _visible_from(origin: Vector3, target: BattleUnit) -> bool:
	if not cubic_cages.is_empty():
		var surface := _weapon_surface(origin)
		if not is_finite(surface) or _skill_barriers_blocked(Vector3(origin.x, origin.y - surface, origin.z), _relative_target(target)):
			return false
	var query := PhysicsRayQueryParameters3D.create(origin, target.sight_target(), 1)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _shooter_frame(unit: BattleUnit, surface: float) -> Dictionary:
	return {"position": unit.global_position, "altitude": unit.global_position.y - surface,
		"eye_y": unit.global_position.y + unit.view_eye_height(), "sight_y": unit.global_position.y - surface + Content.constants.LOS.EYE_M, "surface": surface}

func camera_origin(unit: BattleUnit) -> Vector3:
	return camera_origin_at(unit, unit.yaw)

func camera_origin_at(unit: BattleUnit, yaw: float) -> Vector3:
	if unit.view_mode == "tps":
		# Ring framing uses only the vertical projection coefficient.
		var projection := Projection.create_perspective(unit.authority_fov, 1.0, float(Content.balance.cameraRules.near), 3500)
		return third_person_camera(unit, yaw, unit.pitch, projection, unit.ring_height(), unit.movement_roll).origin
	return first_person_camera_origin_at(unit, yaw)

func first_person_camera_origin_at(unit: BattleUnit, yaw: float) -> Vector3:
	var position := unit.global_position
	var scale_factor := SuperRules.body_scale(float(unit.upgrades.get("super", 0)))
	var colliders := _camera_colliders()
	var signature: Array = [position, yaw, unit.flying, unit.character, unit.charge, scale_factor, colliders]
	var frame := Engine.get_physics_frames()
	if unit.camera_cache_frame == frame and unit.camera_cache_signature == signature:
		return unit.camera_cache_origin
	var camera := CameraPose.anchor(unit.character, position, yaw, unit.flying, unit.charge, scale_factor)
	if world == null:
		return camera
	var blockers: Array = world.active_columns if world.native_data != null else []
	var surface := _weapon_surface(position)
	camera = CameraPose.clip(position, camera, unit.view_eye_height(), blockers, colliders, _unit_level(unit) == 1, surface,
		func(start: Vector3, end: Vector3): return world.obstruction_hit(start, end, false), _weapon_surface)
	unit.camera_cache_frame = frame
	unit.camera_cache_signature = signature
	unit.camera_cache_origin = camera
	return camera

func _camera_colliders() -> Array:
	var result: Array = []
	if not Content.balance.has("playerView"):
		return result
	for entity: BattleUnit in units.values():
		if entity.special.get("role") != "hazard":
			continue
		var collider := CameraPose.entity_collider(entity.kind, float(entity.special.get("scale", 1)), entity.special.get("collapsed", false))
		if float(collider.colR) == 0:
			continue
		collider.position = entity.global_position
		result.append(collider)
	return result

func third_person_camera(unit: BattleUnit, yaw: float, pitch: float, projection: Projection, ring_y: float = NAN, roll: float = 0.0) -> Transform3D:
	var position := unit.global_position
	var height := CameraPose.body_height(unit.character, unit.flying, SuperRules.body_scale(float(unit.upgrades.get("super", 0))))
	var camera := CameraPose.third_person_anchor(position, height, yaw, pitch, _weapon_surface)
	if world != null:
		var blockers: Array = world.active_columns if world.native_data != null else []
		camera = CameraPose.clip(position, camera, height * float(Content.balance.playerView.pullHeight), blockers, _camera_colliders(),
			_unit_level(unit) == 1, _weapon_surface(position),
			func(start: Vector3, end: Vector3): return world.obstruction_hit(start, end, false), _weapon_surface)
	var frame := Transform3D(unit.recoil.third_person_basis(yaw, pitch, roll), camera)
	# Source framing follows clipping and intentionally has no second floor/clip pass.
	return CameraPose.frame_ring(frame, projection, Vector3(position.x, ring_y, position.z)) if is_finite(ring_y) else frame

func _launch_range_from_frame(def: Dictionary, frame: Dictionary, target: BattleUnit, target_surface: float) -> float:
	var position: Vector3 = frame.position
	var eye := Vector3(position.x, frame.eye_y, position.z)
	return TargetingMath.launch_range(def, position, eye, frame.surface,
		{"hero": target.is_hero(), "position": target.position, "kind": target.kind,
		"altitude": target.position.y - target_surface})

func _advisory_origin(unit: BattleUnit, slot: String = "") -> Vector3:
	unit.ensure_weapon_pose()
	if unit.view_mode == "tps":
		return _launch_pose(unit, slot if not slot.is_empty() else str(unit.input_state.get("slot", "light")), 0).origin
	return unit.weapon_pose.current_muzzle(unit.aim_transform())

func _settlement_range_factor(unit: BattleUnit, def: Dictionary, origin: Vector3, origin_surface: float, target: BattleUnit, target_surface: float, shooter_frame: Dictionary = {}) -> float:
	if unit.is_bot:
		return CombatMath.altitude_range(def, _height_difference(unit, target)) * StatusRules.multiplier(unit.buffs, "range", clock)
	var gap: float
	if target.is_pilot():
		gap = shooter_frame.get("eye_y", origin.y) - (target.global_position.y + target.view_eye_height())
	else:
		# Source compares two absolute hero eyes, otherwise two heights above their own surfaces.
		var shooter_sight: float = shooter_frame.get("sight_y", origin.y - origin_surface - unit.height * Content.constants.SELF_F.eye + Content.constants.LOS.EYE_M)
		var target_sight: float = Content.constants.LOS.TOWER_EYE_M if target.kind in ["base", "tower"] else target.position.y - target_surface + (Content.constants.LOS.EYE_M if target.is_hero() or target.kind in ["heli", "decoy", "kami", "hyper"] else Content.constants.LOS.TGT_M)
		gap = shooter_sight - target_sight
	var factor := CombatMath.altitude_range(def, gap)
	for buff in unit.buffs:
		if buff.until > clock:
			factor *= buff.get("mul", {}).get("range", 1.0)
	return factor

func _fire_line(unit: BattleUnit, def: Dictionary, origin: Vector3, endpoint: Vector3, origin_surface: float = NAN, shooter_frame: Dictionary = {}, options: Dictionary = {}) -> void:
	var candidates: Array = []
	var segment := endpoint - origin
	if segment.length() < 0.01:
		return
	var maximum: float = options.get("maximum", def.range * (1 + Content.constants.ALTITUDE.RANGE * Content.constants.ALTITUDE.RANGE_HEAVY_MUL))
	var length := minf(segment.length(), maximum)
	var direction := segment.normalized()
	if not is_finite(origin_surface):
		origin_surface = _projectile_surface(origin)
	if not is_finite(origin_surface):
		return
	if not shooter_frame.is_empty():
		origin_surface = shooter_frame.surface
	for target: BattleUnit in units.values():
		if target.side == unit.side or not target.alive():
			continue
		if not visible_to_side(target, unit.side) or not _visible_from(origin, target):
			continue
		var surface := _height_reference(target) if target.is_hero() else world.ground_height(target.position.x, target.position.z)
		if not is_finite(surface):
			continue
		var relative_sample: float = Content.constants.LOS.TOWER_EYE_M if target.kind in ["tower", "base"] else Content.constants.LOS.TGT_M + (target.position.y - surface if target.is_hero() or target.kind == "heli" else 0.0)
		var relative_position := target.position
		relative_position.y = _body_altitude(target)
		candidates.append({"id": target.entity_id, "position": relative_position, "radius": target.radius,
			"height": target.height, "sample_y": relative_sample,
			"relative_y": relative_sample - (origin.y - origin_surface),
			"range_factor": _settlement_range_factor(unit, def, origin, origin_surface, target, surface, shooter_frame)})
	var relative_origin := Vector3(origin.x, origin.y - origin_surface, origin.z)
	for hit in CombatMath.line_hits(def, relative_origin, direction, length, candidates):
		if int(hit.id) == int(options.get("skip", 0)):
			continue
		var target: BattleUnit = units[hit.id]
		var amount: float = _roll_critical(unit, target, def, hit.amount) if options.get("critical", true) else float(hit.amount)
		damage(unit, target, def, amount, false, {"origin": origin, "direction": direction})
	if not options.get("intercept", true):
		return
	for missile: Dictionary in missiles.duplicate():
		if missile.side != unit.side and MissileMotion.line_contains(def, relative_origin, direction, length, missile.position):
			_damage_missile(unit, def, int(missile.id), relative_origin)

func _acquire_base_target(unit: BattleUnit, reach: float) -> BattleUnit:
	return _npc_acquire(unit, {"range": reach})

func _tick_base_guns(unit: BattleUnit, guns: Dictionary, delta: float) -> void:
	if not authoritative or over or not unit.alive():
		return
	if unit.gun_cooldowns.is_empty():
		unit.gun_cooldowns.resize(int(guns.n))
		unit.gun_cooldowns.fill(0.0)
	for index in range(unit.gun_cooldowns.size()):
		unit.gun_cooldowns[index] = maxf(0, unit.gun_cooldowns[index] - delta)
		if unit.gun_cooldowns[index] > 0:
			continue
		var target := _acquire_base_target(unit, guns.range)
		if target == null:
			continue
		var config: Dictionary = Content.constants.BASE_MISSILE
		var offset: float = Content.balance.missile.launchOffset * (1 if index == 0 else -1)
		var origin := Vector3(unit.position.x + offset, config.LAUNCH_Y, unit.position.z)
		if not is_finite(world.ground_height(origin.x, origin.z)):
			continue
		unit.gun_cooldowns[index] = 1.0 / (guns.rate * weather_attack_rate(unit))
		var definition: Dictionary = Content.constants.STRUCT_W.base
		_launch_missile({"actor": unit.entity_id, "side": unit.side, "target": target.entity_id,
			"position": origin, "origin": origin, "speed": config.SPEED, "dmg": guns.dmg,
			"pen": definition.pen, "r": definition.r, "hp": config.HP, "max_hp": config.HP,
			"ttl": guns.range / config.SPEED + config.TTL_PAD, "range": guns.range})
		var shot := {"type": "shot", "actor": unit.entity_id, "kind": unit.kind, "start": _missile_world_position(origin),
			"end": _npc_shot_point(target), "side": unit.side, "gun": index}
		if unit.body_presentation != null:
			_emit_body_event(shot)
		else:
			events.append(shot)

func _launch_missile(state: Dictionary) -> void:
	if not authoritative or over:
		return
	state.id = next_id
	next_id += 1
	missiles.append(state)
	_sync_missile_bodies()

func _missile_world_position(point: Vector3) -> Vector3:
	return Vector3(point.x, world.ground_height(point.x, point.z) + point.y, point.z)

func _missile_target_altitude(target: BattleUnit) -> float:
	if not target.is_hero() and target.kind != "heli" and target.special.get("role") not in ["summon", "hologram", "carrier"]:
		return 0.0
	if world == null:
		return target.position.y
	var surface := _height_reference(target) if target.is_hero() else world.ground_height(target.position.x, target.position.z)
	return target.position.y - surface

func _body_altitude(target: BattleUnit) -> float:
	# Source body/LOS target bands do not use the altitude of the newer non-hero summon kinds.
	return _missile_target_altitude(target) if target.is_hero() or target.kind in ["heli", "decoy", "kami", "hyper"] else 0.0

func _height_reference(unit: BattleUnit) -> float:
	if world == null:
		return 0.0
	var surface := _projectile_surface(unit.position)
	var ground := world.ground_height(unit.position.x, unit.position.z)
	if not is_finite(surface) or not is_finite(ground):
		return NAN
	return world.layers.player_reference(unit.position, surface, ground)

func _unit_level(unit: BattleUnit) -> int:
	if unit.kind in ["tower", "base"]:
		return 0
	var spec := {"kind": unit.kind, "hero": unit.is_hero(), "has_lane": unit.has_lane,
		"altitude": _missile_target_altitude(unit), "kami": unit.kind == "kami", "decoy": unit.kind == "decoy", "hyper": unit.kind == "hyper"}
	if unit.is_hero() and not unit.is_bot:
		var surface := _projectile_surface(unit.position)
		var ground := world.ground_height(unit.position.x, unit.position.z)
		spec.level = world.layers.player_level(unit.position, surface, ground)
	return world.layers.unit_level(spec, Vector2(unit.position.x, unit.position.z))

func _missile_obstruction(start: Vector3, end: Vector3) -> bool:
	var from := _missile_world_position(start)
	var to := _missile_world_position(end)
	return from.is_finite() and to.is_finite() and not world.obstruction_hit(from, to, false).is_empty()

func _tick_missiles(delta: float) -> void:
	if not authoritative or over:
		return
	for index in range(missiles.size() - 1, -1, -1):
		var state: Dictionary = missiles[index]
		var target: BattleUnit = units.get(int(state.target))
		# TTL expires before attraction, including attraction away from a dead original target.
		if target != null and not state.get("lost", false) and float(state.ttl) - delta > 0:
			var decoys: Array = []
			for id: int in hologram_decoys:
				var decoy: BattleUnit = units.get(id)
				if decoy == null:
					continue
				decoys.append({"id": id, "hp": decoy.hp, "dead": not decoy.alive(), "side": decoy.side,
					"position": Vector3(decoy.position.x, _missile_target_altitude(decoy), decoy.position.z)})
			var kamis: Array = []
			if target.is_hero() and target.kind == "drone":
				for id: int in target.carrier_ids:
					var carrier: BattleUnit = units.get(id)
					if carrier != null and carrier.kind == "kami":
						kamis.append({"id": id, "hp": carrier.hp,
							"position": Vector3(carrier.position.x, _missile_target_altitude(carrier), carrier.position.z)})
			state.target = MissileMotion.attracted_target(state, target.side, decoys, kamis)
			target = units.get(int(state.target))
		var target_data := {}
		if target != null and target.alive():
			var altitude := _missile_target_altitude(target)
			if is_finite(altitude):
				target_data.position = Vector3(target.position.x, altitude, target.position.z)
				target_data.phase = target.is_hero() and target.has_status("phase_until", clock)
				target_data.reflect = target.is_hero() and target.has_status("reflect_until", clock)
				target_data.yaw = target.facing_yaw()
				target_data.reflect_arc = target.status.get("reflect_arc", deg_to_rad(120.0))
		var outcome := MissileMotion.advance(state, delta, target_data, _missile_obstruction)
		if not outcome.get("remove", false):
			continue
		_remove_missile(int(state.id))
		if outcome.get("deflected", false):
			events.append({"type": "reflect_hit", "actor": target.entity_id, "missile": state.id,
				"position": _missile_world_position(outcome.reflection), "side": target.side, "deflected": true})
			_publish_blast_event({"type": "missile_deflect", "actor": target.entity_id, "missile": state.id,
				"position": _missile_world_position(outcome.flash), "radius": state.r, "side": target.side})
		if outcome.has("blast"):
			var point := _missile_world_position(outcome.blast)
			if not point.is_finite():
				continue
			var owner: BattleUnit = units.get(int(state.actor))
			var detached := owner == null
			if detached:
				owner = BattleUnit.new()
				owner.side = state.side
			var victim: BattleUnit = units.get(int(outcome.get("target", 0)))
			var level := _unit_level(victim) if victim != null else -1
			blast(owner, {"pen": state.pen, "r": state.r}, outcome.blast, false, true, level, state.dmg)
			if detached:
				owner.free()
			_publish_blast_event({"type": "missile_blast", "actor": state.actor, "missile": state.id,
				"position": point, "radius": state.r, "side": state.side})
	_sync_missile_bodies()

func _remove_missile(id: int) -> void:
	for index in range(missiles.size()):
		if int(missiles[index].id) == id:
			missiles.remove_at(index)
			break
	if missile_bodies.has(id):
		var body: MissileBody = missile_bodies[id]
		body.collision_layer = 0
		body.visible = false
		body.queue_free()
		missile_bodies.erase(id)

func _damage_missile(unit: BattleUnit, def: Dictionary, id: int, origin: Vector3 = Vector3(INF, INF, INF)) -> void:
	if not authoritative or over or not unit.alive():
		return
	if unit.has_status("blind_until", clock) or unit.has_status("emp_until", clock):
		return
	if def.get("needAim", false) and not unit.input_state.get("aim", false):
		return
	if not origin.is_finite():
		var altitude := _missile_target_altitude(unit)
		if not is_finite(altitude):
			return
		origin = Vector3(unit.position.x, altitude, unit.position.z)
	for state: Dictionary in missiles:
		if int(state.id) != id or state.side == unit.side:
			continue
		var distance := origin.distance_to(state.position)
		if distance > def.range * Content.constants.RANGE_TOL:
			return
		# Source missiles have no TARGET_CLASS entry, so vsMult is exactly one.
		var amount: float = def.dmg * CombatMath.damage_falloff(def, distance)
		for buff: Dictionary in unit.buffs:
			if buff.until > clock:
				amount *= buff.get("mul", {}).get("dmg", 1.0)
		if unit.special.get("boss", false) and int(unit.special.get("boss_segment", 0)) >= 3:
			amount *= float(Content.constants.BOSS.ENRAGE_DMG_F)
		state.hp -= amount
		if state.hp <= 0:
			var point := _missile_world_position(state.position)
			_remove_missile(id)
			unit.money += Content.constants.ECON.BOUNTY.missile
			_publish_blast_event({"type": "missile_intercept", "actor": unit.entity_id, "missile": id,
				"position": point, "radius": Content.balance.missile.interceptRadius, "side": unit.side})
		return

func _sync_missile_bodies() -> void:
	for state: Dictionary in missiles:
		var id := int(state.id)
		var point := _missile_world_position(state.position)
		var created := not missile_bodies.has(id)
		if not missile_bodies.has(id):
			var fresh := MissileBody.new()
			# Register collision at the launch pose, without a transient body at the world origin.
			fresh.position = point if point.is_finite() else Vector3.ZERO
			fresh.set_meta("missile", id)
			add_child(fresh)
			missile_bodies[id] = fresh
		var body: MissileBody = missile_bodies[id]
		body.visible = point.is_finite()
		body.collision_layer = 512 if point.is_finite() else 0
		if point.is_finite():
			body.place(point, point - body.position if not created and body.position.is_finite() else Vector3.ZERO)

func damage(attacker: BattleUnit, target: BattleUnit, def: Dictionary, amount: float, friendly: bool = false,
		context: Dictionary = {}, attack_modifiers: bool = true) -> void:
	var same := attacker != null and target.side == attacker.side
	if not authoritative or over or not target.alive() or (same and not friendly) or amount <= 0:
		return
	if target.special.get("invulnerable", false) or target.special.get("garrison", false):
		return
	if attacker != null and (attacker.side == Content.constants.SUPER_SIDE and target.side in ["GUER", "MILI"] or target.side == Content.constants.SUPER_SIDE and attacker.side in ["GUER", "MILI"]):
		return
	if siege_locked(target):
		return
	if attack_modifiers:
		if def.get("area") not in ["fan", "blast"] and not context.has("blast"):
			_apply_hit_emp(def, target)
		_apply_hit_elements(attacker, def, target)
		amount *= _weapon_multiplier(attacker, target, def)
	if context.get("weather_weapon", not def.is_empty()) and not reflecting:
		amount *= float(weather_dynamics.get("rainAtkMul", 1))
	amount *= _ally_bot_damage_factor(target, attacker)
	if target.special.get("boss", false) and int(target.special.get("boss_segment", 0)) >= 3 and (attacker == null or not attacker.is_hero()):
		amount *= float(Content.constants.BOSS.ENRAGE_NPC_DMG_F)
	if target.has_status("freeze_until", clock):
		amount *= 1 - Content.constants.WEATHER_FREEZE.DMG_REDUCTION
	if target.has_status("inv_until", clock) or target.has_status("phase_until", clock):
		return
	if target.has_status("reflect_until", clock) and attacker != null:
		var offset := Vector2(attacker.position.x - target.position.x, attacker.position.z - target.position.z)
		var forward := Vector2(-sin(target.facing_yaw()), -cos(target.facing_yaw()))
		if offset.length() > 0.01 and forward.dot(offset.normalized()) >= cos(float(target.status.get("reflect_arc", deg_to_rad(120))) / 2):
			var reflected: float = amount * float(target.status.get("reflect_ratio", 0.6))
			if not same and not reflecting:
				reflecting = true
				damage(target, attacker, def, reflected, false, {}, false)
				reflecting = false
			events.append({"type": "reflect_hit", "actor": target.entity_id, "attacker": attacker.entity_id, "amount": reflected})
			return
	if target.kind == "base" and attacker != null and not attacker.side.is_empty() and attacker.side != Content.constants.SUPER_SIDE:
		var supported := false
		for ally: BattleUnit in units.values():
			if ally.side == attacker.side and ally.alive() and not ally.is_hero() and not ally.special.get("neutral", false) and _planar_distance(ally.position, target.position) < float(Content.balance.siege.baseSupportRadius):
				supported = true
				break
		if not supported:
			amount *= float(Content.constants.GAME.BASE_ARMOR_NEED_CREEP)
	if target.is_hero():
		var wet := target.wet
		if not wet and target.special.get("role") == "clone":
			var owner: BattleUnit = units.get(int(target.special.owner_id))
			wet = owner.wet if owner != null else 0
		amount *= StatusRules.multiplier(target.buffs, "dmgTaken", clock) * StatusRules.fluid_factor(wet)
		var defense_factor := _shield_defense_factor(target, attacker, def, context)
		amount *= defense_factor
		_stamp_suppression(target, attacker)
		var blast_hit: bool = def.get("area") == "blast" or context.has("blast")
		var unbalance: float = Content.constants.SHIELD_DEFENSE.FLIGHT_UNBAL_BLAST_F if blast_hit else Content.constants.SHIELD_DEFENSE.FLIGHT_UNBAL_DIRECT_F
		_stamp_unbalance(target, unbalance if defense_factor < 1 else 1.0)
		target.damaged_at = clock
		_break_on_hit(target)
		_interrupt_cast(target)
	var credit := _damage_credit(attacker)
	if credit != null and not same:
		target.assists[credit.peer_id] = true
		credit.last_hit_target = target.entity_id
	var split := CombatMath.shield_split(def, amount, target.shield)
	var shield_loss := minf(target.shield, split.toSp)
	var durability := 1.0
	if not target.is_hero() and (attacker == null or not attacker.is_hero()):
		durability = NpcRules.creep_damage_taken(target.creep_multiplier, target.armor, def.get("pen", 0))
	var hp_damage: float = split.toHp * CombatMath.armor_multiplier(target.armor, def.get("pen", 0)) * durability
	if target.special.get("third", false) and target.kind != "bunker" and attacker != null and not attacker.side.is_empty() and attacker.side != target.side and not attacker.special.get("neutral", false):
		target.special.aggro_id = attacker.entity_id
		target.special.aggro_at = clock
	var floor_hp := maxf(float(context.get("floor_hp", 0)), _siege_hp_floor(target))
	# Source damage floors only prevent further loss; an already lower HP value
	# must never heal. Damage/credit/vamp budgets still use the original hit loss.
	var minimum_hp := minf(target.hp, floor_hp) if floor_hp > 0 else 0.0
	var remaining_hp := maxf(minimum_hp, target.hp - hp_damage)
	var hp_loss := minf(target.hp, hp_damage)
	target.shield = maxf(0, target.shield - split.toSp)
	target.hp = remaining_hp
	target.damaged_at = clock
	if target.shield <= 0:
		target.defending = false
	var dealt := shield_loss + hp_loss
	_record_air_sink(target, dealt)
	_record_blood_hurt(target, attacker, dealt)
	if attacker != null and not same and dealt > 0:
		attacker.damage_out += dealt
		_record_bot_hurt(target, attacker, dealt)
		if attacker.is_hero() and attacker.alive():
			_heal_body(attacker, dealt * StatusRules.maximum(attacker.buffs, "vamp", clock))
		events.append({"type": "hurt", "actor": target.entity_id, "attacker": attacker.entity_id,
			"origin": attacker.position, "amount": dealt, "side": target.side})
	if floor_hp > 0 or target.is_hero() and split.toHp <= 0:
		return
	if target.hp <= 0:
		_kill_unit(target, attacker)
		if target.hp > 0:
			return # Source clone death swaps cancel the segment sync for this hit.
	_boss_sync(target)

func _record_blood_hurt(target: BattleUnit, attacker: BattleUnit, amount: float) -> void:
	if not amount > 0 or attacker == null or not target.is_pilot() or pilots.get(target.peer_id) != target:
		return
	var elevation: Variant = attacker.position.y + attacker.view_eye_height() if attacker.is_pilot() and not attacker.is_bot else null
	hurt_bearings.record(target.entity_id, attacker.entity_id, attacker.position, amount, elevation)

func flush_blood_hurt() -> void:
	var order: Array = pilots.values().map(func(unit): return unit.entity_id)
	for event: Dictionary in hurt_bearings.flush(order):
		var target: BattleUnit = units.get(int(event.actor))
		if target == null:
			continue
		blood_event_serial += 1
		event.type = "screen_hurt"
		event.peer = target.peer_id
		event.blood_serial = blood_event_serial
		events.append(event)

func _record_bot_hurt(target: BattleUnit, attacker: BattleUnit, amount: float) -> void:
	var lead: BattleUnit = pilots.get(target.peer_id, target)
	if not lead.is_bot or amount <= 0:
		return
	var altitude := attacker.position.y + attacker.view_eye_height() if attacker.is_pilot() and not attacker.is_bot else _missile_target_altitude(attacker)
	lead.bot_alert = {"point": Vector2(attacker.position.x, attacker.position.z), "altitude": altitude, "at": clock}
	var tactics: Dictionary = Content.constants.BOT_TACTIC
	for stale_key in lead.threat.keys():
		if clock - float(lead.threat[stale_key].at) > float(tactics.THREAT_S):
			lead.threat.erase(stale_key)
	var key := BotRules.threat_key(attacker)
	var previous: Dictionary = lead.threat.get(key, {})
	lead.threat[key] = {"value": (float(previous.value) * BotRules.threat_decay(clock - float(previous.at), tactics) if not previous.is_empty() else 0.0) + amount,
		"at": clock, "kind": previous.get("kind", attacker.kind)}

func _kill_unit(target: BattleUnit, attacker: BattleUnit) -> void:
	if not authoritative:
		return
	target.upgrade_survivor = false
	var same := attacker != null and target.side == attacker.side
	if target.special.get("role") == "civilian":
		_kill_civilian(target, attacker)
		return
	if target.special.get("role") == "slab":
		_remove_field_unit(target.entity_id, true)
		return
	if target.special.get("role") == "clone":
		var owner: BattleUnit = units.get(int(target.special.owner_id))
		if owner != null:
			owner.clone_ids.erase(target.entity_id)
		_remove_field_unit(target.entity_id, true)
		return
	if target.is_pilot() and _clone_death_swap(target):
		return
	if target.is_pilot():
		target.death_tick = simulation_tick
	_report_death(target)
	if target.is_pilot():
		target.climb.release()
		target.recoil.clear_active()
		if target.weapon_pose != null:
			target.weapon_pose.bursts.pending.clear()
		if target.cockpit != null:
			target.cockpit.bursts.pending.clear()
		_set_human_aim(target, false)
	target.visible = false
	target.collision_layer = 0
	target.collision_mask = 0
	target.hit_area.collision_layer = 0
	var bounty := bounty_for_kind(target.kind)
	if attacker != null and attacker.is_hero() and not same:
		if attacker.is_pilot():
			attacker.money += bounty * StatusRules.multiplier(attacker.buffs, "bounty", clock)
		if not target.special.get("neutral", false):
			attacker.score = minf(Content.constants.BATTLE_SCORE.MAX, attacker.score + Content.constants.BATTLE_SCORE.KILL * (Content.constants.BATTLE_SCORE.HARD_F if target.is_hero() or target.kind == "tower" else 1))
	for peer in target.assists:
		var contributor: BattleUnit = pilots.get(peer)
		if contributor == null or contributor.side == target.side or (attacker != null and attacker.is_hero() and contributor.peer_id == attacker.peer_id):
			continue
		var height := _missile_target_altitude(target) - _missile_target_altitude(contributor)
		var radius: float = Content.constants.ECON.ASSIST.R_M
		var reach := maxf(radius, CombatMath.max_horizontal(radius, height))
		if Vector2(contributor.position.x - target.position.x, contributor.position.z - target.position.z).length() > reach:
			continue
		if not target.special.get("neutral", false):
			contributor.score = minf(Content.constants.BATTLE_SCORE.MAX, contributor.score + Content.constants.BATTLE_SCORE.ASSIST * (Content.constants.BATTLE_SCORE.HARD_F if target.is_hero() or target.kind == "tower" else 1))
		var earned: float = bounty * Content.constants.ECON.ASSIST.F * StatusRules.multiplier(contributor.buffs, "bounty", clock)
		contributor.money += earned
		if bounty > 0:
			if match_stats.has(contributor.side):
				match_stats[contributor.side].assists += 1
			events.append({"type": "assist", "actor": contributor.entity_id, "target": target.entity_id, "amount": roundf(earned)})
	target.assists.clear()
	if attacker != null and attacker.is_hero() and attacker.alive() and not same and not target.special.get("neutral", false):
		_heal_body(attacker, attacker.max_hp * StatusRules.maximum(attacker.buffs, "killHeal", clock))
	target.cast_state.clear()
	target.defending = false
	if target.is_hero():
		if match_stats.has(target.side):
			match_stats[target.side].deaths += 1
		if attacker != null and not same and match_stats.has(attacker.side):
			match_stats[attacker.side].kills += 1
	elif not target.special.get("neutral", false) and target.special.get("role") != "carrier" and attacker != null and attacker.is_hero() and not same and match_stats.has(attacker.side):
		var weight := float(Content.constants.UNITS.get(target.kind, {}).get("bounty", 1))
		match_stats[attacker.side].creepKills += weight if weight != 0 else 1
	if target.special.get("third", false):
		_remove_field_unit(target.entity_id)
		_on_third_death(target, attacker)
		return
	if target.special.get("role") == "hazard":
		if SceneRules.physical(target.kind) and Content.constants.HAZARDS[target.kind].get("block", false):
			_collapse_scene(target)
		else:
			hazard_blockers = hazard_blockers.filter(func(obstacle): return float(obstacle.x) != float(target.position.x) or float(obstacle.z) != float(target.position.z))
			_remove_field_unit(target.entity_id)
		_drop_scene_loot(target)
		return
	if target.special.get("role") == "carrier":
		_carrier_shot_down(target)
		return
	if target.special.get("boss", false):
		if target.special.get("boss_down", false):
			return
		target.special.boss_down = true
		target.respawn_at = INF
		target.input_state.aim = false
		_siege_fell(target)
		_boss_fell(target)
		events.append({"type": "boss_down", "actor": target.entity_id, "peer": target.peer_id, "side": target.side,
			"character": target.character, "stage": target.special.get("siege_stage", -1)})
		return
	if target.kind in ["tower", "base"]:
		_siege_fell(target)
	if target.kind == "base":
		over = true
		winner = "STEEL" if target.side == "SWARM" else "SWARM"
		result.emit(winner)
	elif target.is_pilot():
		target.deaths += 1
		target.respawn_at = clock + respawn_delay(target.kind, target.deaths)
		var penalty: float = floorf(target.money) if target.side == Content.constants.SUPER_SIDE else (target.respawn_at - clock) * Content.constants.ECON.DEATH_PENALTY_PER_S
		if target.side == Content.constants.SUPER_SIDE:
			target.money = 0
			_set_super_level(target, floorf(float(target.upgrades.get("super", 0)) * float(Content.balance["super"].deathFactor)))
		else:
			target.money = maxf(0, target.money - penalty)
		events.append({"type": "penalty", "actor": target.entity_id, "amount": roundf(penalty)})

func _fire_burn(unit: BattleUnit, amount: float) -> void:
	if not authoritative or over or unit.hp <= 0 or not unit.alive() or unit.special.get("invulnerable", false) or unit.special.get("garrison", false):
		return
	if unit.is_hero() and unit.has_status("inv_until", clock):
		return
	if unit.max_hp + unit.max_shield <= 0:
		return
	var state := EnvironmentRules.burn_split(unit.hp, unit.shield, unit.max_hp, unit.max_shield, amount, StatusRules.multiplier(unit.buffs, "dmgTaken", clock))
	unit.damaged_at = clock
	unit.hp = state.hp
	unit.shield = state.shield
	if unit.hp <= 0:
		var killer: BattleUnit = pilots.get(int(unit.bleed.get("peer", 0)), units.get(int(unit.bleed.get("actor", 0))))
		_kill_unit(unit, killer)
	_boss_sync(unit)

func _shield_defense_factor(target: BattleUnit, attacker: BattleUnit, definition: Dictionary, context: Dictionary) -> float:
	if not target.defending or target.shield <= 0:
		return 1.0
	var forward := Vector2(-sin(target.facing_yaw()), -cos(target.facing_yaw()))
	var center := Vector2(target.position.x, target.position.z)
	var attack_slot := ""
	for slot: String in ["heavy", "light"]:
		var weapon := weapon_definition(target.character, slot, target.combat_level(slot))
		var fired: float = target.last_fired_at.get(slot, -INF)
		if fired != 0 and clock - fired < 1.0 / (weapon.rate * 0.5):
			attack_slot = slot
			break
	var boosted := target.has_status("shield_def_boost_until", clock)
	var arc: float = Content.constants.SHIELD_DEFENSE.EXPAND_ARC if target.has_status("shield_expand_until", clock) else Content.constants.SHIELD_DEFENSE.FRONT_ARC
	if context.has("blast") or definition.get("area") == "blast":
		var point: Vector3 = context.get("blast", attacker.position if attacker != null else Vector3(INF, INF, INF))
		var shield_center := center + forward * target.radius
		var fallback_radius: float = definition.get("radius", 8.0)
		var radius: float = context.get("radius", fallback_radius if fallback_radius else 8.0)
		if point.is_finite() and Vector2(point.x, point.z).distance_to(shield_center) <= radius + target.radius:
			return StatusRules.shield_kind_factor(target.kind, true, boosted, attack_slot)
		return 1.0
	var origin: Vector3 = context.get("origin", attacker.position if attacker != null else Vector3(INF, INF, INF))
	if not origin.is_finite():
		if context.has("direction"):
			var direction: Vector3 = context.direction
			if forward.dot(Vector2(direction.x, direction.z)) <= -cos(arc / 2):
				return StatusRules.shield_kind_factor(target.kind, false, boosted, attack_slot)
		return 1.0
	var offset := Vector2(origin.x, origin.z) - center
	if offset.length() > 0.01 and forward.dot(offset.normalized()) >= cos(arc / 2):
		return StatusRules.shield_kind_factor(target.kind, false, boosted, attack_slot)
	return 1.0

func flight_balance_state(unit: BattleUnit) -> Dictionary:
	return {"flying": unit.flying, "dead": not unit.alive(), "drone": unit.kind == "drone",
		"altitude": _missile_target_altitude(unit), "wind": float(weather_dynamics.get("wind", 0)),
		"sink": unit.air_sink, "sink_speed": unit.air_sink_speed, "lock_until": unit.lift_lock_until,
		"unbalance_left": maxf(0, float(unit.status.get("unbalanced_until", 0)) - clock),
		"defending": unit.defending, "shield": unit.shield}

# The source client derives _unbalanced() from its snapshot-rounded unbalLeft.
func _owner_control_status(viewer: BattleUnit) -> Dictionary:
	var result := ActorSnapshot.control_status(viewer, clock)
	var balance := flight_balance_state(viewer)
	balance.unbalance_left = result.unbalLeft
	result.unbalanced = MovementRules.flight_unbalanced(balance, clock)
	return result

func _record_air_sink(target: BattleUnit, amount: float) -> void:
	if not target.is_hero() or not target.flying or amount <= 0:
		return
	if target.kind == "drone" and _missile_target_altitude(target) < WeatherRules.unbalance_threshold(float(weather_dynamics.get("wind", 0))):
		return
	if target.is_bot:
		var distance := MovementRules.sink_distance(amount, float(weather_dynamics.get("wind", 0)))
		target.move_and_collide(Vector3.DOWN * minf(_missile_target_altitude(target), distance))
	else:
		var state := MovementRules.sink_hit(flight_balance_state(target), amount, clock)
		target.air_sink = state.sink
		target.air_sink_speed = state.speed
		target.lift_lock_until = state.lock_until

func _weapon_multiplier(attacker: BattleUnit, target: BattleUnit, definition: Dictionary) -> float:
	var factor := CombatMath.vs_multiplier(definition, target.kind)
	if attacker == null:
		return factor
	if factor > 1 and CombatMath.target_class(target.kind) == "air" and _air_unit(attacker):
		factor = 1.0
	var boss_factor: float = Content.constants.BOSS.ENRAGE_DMG_F if attacker.special.get("boss", false) and int(attacker.special.get("boss_segment", 0)) >= 3 else 1.0
	return factor * StatusRules.multiplier(attacker.buffs, "dmg", clock) * boss_factor

func _air_unit(unit: BattleUnit) -> bool:
	if unit.kind not in Content.constants.AIR.KINDS:
		return false
	var jump: float = Content.constants.UNITS[unit.kind].get("jump", 0)
	return _missile_target_altitude(unit) > jump * jump / (2 * Content.constants.AIR.GRAV)

func _stamp_unbalance(target: BattleUnit, factor: float) -> void:
	if not target.is_hero():
		return
	var altitude := _missile_target_altitude(target)
	if target.kind == "drone" and altitude < WeatherRules.unbalance_threshold(float(weather_dynamics.get("wind", 0))):
		return
	var flying: bool = target.kind == "drone" or (target.kind == "morph" and altitude > Content.constants.MORPH.GROUND_Y) or altitude >= Content.constants.GAME.AA_MIN_ALT
	if not flying and not _air_unit(target):
		return
	target.status.unbalanced_until = maxf(float(target.status.get("unbalanced_until", 0)), clock + Content.constants.FLIGHT.UNBAL_S * maxf(0.1, factor))

func _height_difference(first: BattleUnit, second: BattleUnit) -> float:
	if first == null or second == null:
		return 0.0
	if (first.is_bot or second.is_bot) and first.is_hero() and second.is_hero():
		var a := _relative_sight_height(first) if first.is_bot else first.position.y + first.view_eye_height()
		var b := _relative_sight_height(second) if second.is_bot else second.position.y + second.view_eye_height()
		return a - b
	if first.is_pilot() and second.is_pilot():
		return first.position.y + first.view_eye_height() - second.position.y - second.view_eye_height()
	return _relative_sight_height(first) - _relative_sight_height(second)

func _relative_sight_height(unit: BattleUnit) -> float:
	if unit.kind in ["tower", "base"]:
		return Content.constants.LOS.TOWER_EYE_M
	var altitude := _missile_target_altitude(unit)
	return altitude + (Content.constants.LOS.EYE_M if unit.is_hero() or unit.kind in ["heli", "decoy", "kami", "hyper"] else Content.constants.LOS.TGT_M)

func _suppression(unit: BattleUnit) -> float:
	return float(unit.status.get("sup_factor", 0)) if unit != null and unit.has_status("sup_until", clock) else 0.0

func _stamp_suppression(target: BattleUnit, attacker: BattleUnit) -> void:
	var strength := StatusRules.suppression_strength(_height_difference(target, attacker)) if attacker != null else 0.0
	if strength <= 0:
		return
	target.status.sup_factor = maxf(_suppression(target), strength)
	target.status.sup_until = clock + Content.constants.HIGH_SUP.DUR_S

func _dodge_probability(target: BattleUnit, attacker: BattleUnit) -> float:
	if target == null or not target.is_hero():
		return 0.0
	if StatusRules.maximum(target.buffs, "dodge", clock) > 0:
		return 1.0
	var flying: bool = target.kind == "drone" or _missile_target_altitude(target) >= Content.constants.GAME.AA_MIN_ALT
	var mobility := hero_speed(target.character, flying)
	var movement_speed := target.bot_dodge_speed if target.is_bot else Vector2(target.velocity.x, target.velocity.z).length()
	if mobility <= StatusRules.evasion_min_speed() or movement_speed < Content.constants.EVASION.MOVING_SPD:
		return 0.0
	var probability: float = Content.constants.EVASION.GROUND + (Content.constants.EVASION.AIR_BONUS if flying else 0.0) + StatusRules.maximum(target.buffs, "evade", clock)
	var difference := _height_difference(target, attacker)
	if difference > 0:
		probability += Content.constants.ALTITUDE.DODGE * CombatMath.altitude_strength(difference)
	return minf(probability, Content.constants.EVASION.P_MAX) * (1 - Content.constants.HIGH_SUP.DODGE * _suppression(target))

func _roll_miss(attacker: BattleUnit, target: BattleUnit, definition: Dictionary) -> bool:
	if definition.is_empty() or definition.get("area") in ["fan", "line"]:
		return false
	var probability := StatusRules.miss_probability(_dodge_probability(target, attacker), _suppression(attacker),
		attacker != null and attacker.has_status("unbalanced_until", clock), _weather_accuracy_penalty())
	if probability <= 0 or rng.next() >= probability:
		return false
	events.append({"type": "dodge", "actor": target.entity_id, "attacker": attacker.entity_id if attacker != null else 0,
		"position": target.position, "side": target.side})
	return true

func _roll_critical(attacker: BattleUnit, target: BattleUnit, definition: Dictionary, amount: float, prepared: bool = false) -> float:
	if attacker == null:
		return amount
	var forced: bool = attacker.status.get("phase_critical", false)
	if forced:
		attacker.status.phase_critical = false
	elif not definition.get("crit", 0):
		return amount
	var factors := StatusRules.critical_factors(_height_difference(attacker, target))
	var rate: float = definition.get("crit", 0) * factors.rate
	if attacker.has_status("unbalanced_until", clock):
		rate *= Content.constants.FLIGHT.UNBAL_CRIT_MUL
	if not forced and rng.next() >= rate:
		return amount
	var multiplier: float = definition.get("critX", 0)
	if multiplier == 0:
		multiplier = Content.constants.VITALS.CRIT_X
	amount *= 1 + (multiplier - 1) * factors.damage
	events.append({"type": "crit", "actor": attacker.entity_id, "target": target.entity_id,
		"position": target.position, "audio_height": _missile_target_altitude(target) if target.is_hero() else 0.0,
		"amount": floorf(amount * (1.0 if prepared else _weapon_multiplier(attacker, target, definition)) + 0.5)})
	return amount

func _apply_hit_emp(definition: Dictionary, target: BattleUnit) -> void:
	if not definition.get("emp", 0) or not target.is_hero() or StatusRules.maximum(target.buffs, "ccImm", clock) > 0:
		return
	target.status.emp_until = maxf(float(target.status.get("emp_until", 0)), clock + float(definition.emp))

func _apply_hit_elements(attacker: BattleUnit, definition: Dictionary, target: BattleUnit) -> void:
	var element: String = definition.get("elem") if definition.get("elem") is String else ""
	if element.is_empty() or element == "physical" or not target.alive() or target.kind in ["tower", "base", "bunker"]:
		return
	if target.is_hero() and (target.has_status("inv_until", clock) or StatusRules.maximum(target.buffs, "ccImm", clock) > 0):
		return
	var heavy: bool = definition.get("id") == "heavy"
	var fast: bool = definition.get("rate", 0) > 5
	var effect := ""
	if element in ["shock", "impact", "shockwave"]:
		var probability: float = 0.35 if heavy else 0.12 if fast else 0.22
		if element != "shock":
			probability = 0.60 if heavy else 0.28 if fast else 0.45
		if definition.get("elemProb") != null:
			probability = float(definition.elemProb)
		if rng.next() >= probability:
			return
		if element == "shock":
			var duration: float = definition.get("empDur", 1.2)
			target.status.emp_until = maxf(float(target.status.get("emp_until", 0)), clock + (duration if duration else 1.2))
			effect = "emp_hit"
		else:
			target.status.stagger_stacks = mini(3, int(target.status.get("stagger_stacks", 0)) + 1)
			target.status.stun_until = minf(clock + 1.2, maxf(clock, float(target.status.get("stun_until", 0))) + 0.25)
			effect = "stagger"
	else:
		var buildup: Dictionary = target.status.get("element_buildup", {})
		var last_hit: Dictionary = target.status.get("element_last_hit", {})
		var increment: float = definition.get("elemBuildup", 0)
		if increment == 0:
			increment = 40 if heavy else 12 if fast else 25
		buildup[element] = float(buildup.get(element, 0)) + increment
		last_hit[element] = clock
		target.status.element_buildup = buildup
		target.status.element_last_hit = last_hit
		if float(buildup[element]) < (50 if element in ["poison", "sonic"] else 100):
			return
		buildup[element] = 0.0
		var peer := attacker.peer_id if attacker != null else 0
		var actor := attacker.entity_id if attacker != null else 0
		match element:
			"poison":
				target.status.poison_stacks = mini(5, int(target.status.get("poison_stacks", 0)) + 1)
				var base_damage: float = definition.get("dmg", 0)
				var dps := maxf(6, floorf((base_damage if base_damage else 50) * 0.15 + 0.5))
				target.bleed = {"dps": dps * target.status.poison_stacks, "until": clock + 3.0, "pen": 10, "peer": peer, "actor": actor}
				target.status.slow_until = maxf(float(target.status.get("slow_until", 0)), clock + 2.0)
				target.status.slow_factor = maxf(0.5, 1 - 0.08 * int(target.status.poison_stacks))
				effect = "poison_hit"
			"sonic":
				target.status.sonic_stacks = mini(4, int(target.status.get("sonic_stacks", 0)) + 1)
				target.status.confuse_until = minf(clock + 3.5, maxf(clock, float(target.status.get("confuse_until", 0))) + 0.8)
				effect = "confuse_hit"
			"fire":
				var base_damage: float = definition.get("dmg", 0)
				var penetration: float = definition.get("pen", 0)
				target.bleed = {"dps": maxf(15, floorf((base_damage if base_damage else 60) * 0.35 + 0.5)), "until": clock + 3.0,
					"pen": penetration if penetration else 8, "peer": peer, "actor": actor}
				effect = "burn"
			"frost":
				target.status.slow_until = maxf(float(target.status.get("slow_until", 0)), clock + 2.5)
				target.status.slow_factor = 0.45
				effect = "freeze"
	if not effect.is_empty():
		events.append({"type": effect, "actor": target.entity_id, "position": target.position, "element": element,
			"side": target.side, "stacks": target.status.get("poison_stacks", 0) if element == "poison" else target.status.get("sonic_stacks", 0) if element == "sonic" else target.status.get("stagger_stacks", 0)})

func _heal_body(unit: BattleUnit, amount: float, source: String = "def") -> float:
	if not authoritative or not unit.alive() or amount <= 0:
		return 0.0
	var factor := 1.0
	var cap := unit.max_hp
	if unit.special.get("boss", false):
		if source != "def":
			return 0.0
		factor = float(Content.constants.BOSS.HEAL_DEF_F)
		cap *= StatusRules.boss_hp_cap(float(unit.special.get("boss_segment", 0)))
	if factor <= 0:
		return 0.0
	var amplification := StatusRules.multiplier(unit.buffs, "healAmp", clock) if unit.is_hero() else 1.0
	var before := unit.hp
	unit.hp = minf(cap, unit.hp + amount * factor * amplification)
	if unit.hp > before:
		unit.status.erase("lightning_scorch")
	return maxf(0, unit.hp - before)

func _break_on_hit(unit: BattleUnit) -> void:
	var broken := unit.buffs.any(func(buff): return buff.get("break_on_hit", false))
	unit.buffs = unit.buffs.filter(func(buff): return not buff.get("break_on_hit", false))
	if broken:
		unit.status.no_reload_until = 0

func respawn(unit: BattleUnit) -> void:
	if not authoritative or unit.special.get("boss", false):
		return
	unit.slope_blocked = false
	unit.climb.release()
	unit.movement_roll = 0.0
	var position := _super_spawn_position(unit.peer_id, unit.kind == "drone") if unit.side == Content.constants.SUPER_SIDE else world.spawn_position(unit.side, unit.spawn_slot, unit.kind == "drone")
	if not position.is_finite():
		unit.respawn_at = INF
		message.emit(unit.peer_id, "unavailable_surface")
		push_error("Respawn has no verified standing surface")
		return
	unit.position_trail.clear()
	unit.recoil.clear_active()
	unit.upgrade_survivor = false
	unit.hp = unit.max_hp
	unit.snap_body_presentation()
	unit.shield = unit.max_shield
	unit.power = unit.max_power
	unit.flying = unit.kind == "drone"
	unit.position = position
	# The third faction has no lane heading and keeps its previous facing.
	if unit.side != Content.constants.SUPER_SIDE:
		unit.yaw = world.spawn_heading(unit.side, unit.spawn_slot)
	if not unit.is_bot and not unit.player_view.rules.is_empty():
		unit.pitch = float(Content.balance.playerView.spawnPitch)
		unit.view_reset += 1
	if not unit.player_view.rules.is_empty():
		unit.player_view.body_yaw = unit.yaw
	unit.rotation.y = unit.yaw
	unit.velocity = Vector3.ZERO
	unit.impulse_velocity = Vector2.ZERO
	unit.charge = 0
	unit.low_gravity = false
	unit.lift = Content.constants.FLIGHT.LIFT_MAX
	unit.air_sink = 0
	unit.air_sink_speed = 0
	unit.lift_lock_until = 0
	unit.damaged_at = -99
	unit.wet = 0
	unit.fluid_environment.clear()
	unit.respawn_at = 0
	unit.collision_mask = 1 | 4
	unit.refresh_collision()
	unit.visible = unit.presentation_visible
	# Source clears ability modifiers but retains timed loot affixes.
	unit.buffs = unit.buffs.filter(func(buff): return not str(buff.get("affix", "")).is_empty())
	unit.status.erase("lightning_scorch")
	unit.status.last_weather_freeze = -Content.constants.WEATHER_FREEZE.COOLDOWN_S
	for key: String in ["stun_until", "slow_until", "confuse_until", "blind_until", "inv_until", "emp_until", "stealth_until", "mark_until", "unbalanced_until", "cast_lock_until", "freeze_until", "sup_until", "sup_factor", "element_buildup", "element_last_hit", "poison_stacks", "sonic_stacks", "stagger_stacks"]:
		unit.status.erase(key)
	unit.cast_state.clear()
	unit.bleed.clear()
	unit.cast_preview.clear()
	unit.heal_aura.clear()
	unit.assists.clear()
	unit.defending = false
	unit.aim_anchor = 0
	unit.lock_target = 0
	unit.lock_at = -100.0
	unit.aim_off_at = -100.0
	unit.reload_at.clear()
	unit.fire_at.clear()
	for slot in ["light", "heavy"]:
		unit.ammo[slot] = weapon_definition(unit.character, slot, unit.combat_level(slot)).mag
	events.append({"type": "respawn", "actor": unit.entity_id, "side": unit.side, "peer": unit.peer_id})

func _regenerate(unit: BattleUnit, delta: float) -> void:
	var charge: float
	if balance_profile != null:
		var level := minf(float(Content.constants.ECON.UPGRADES.ch.max), SuperRules.defense_level(float(unit.upgrades.get("super", 0)))) if unit.side == Content.constants.SUPER_SIDE else float(unit.upgrades.ch)
		charge = balance_profile.charge(level)
	else:
		charge = Content.balance["super"].charge[SuperRules.level(float(unit.upgrades.get("super", 0)))] if unit.side == Content.constants.SUPER_SIDE else Content.balance.charge[int(unit.upgrades.ch)]
	var fluid := StatusRules.fluid_factor(unit.wet)
	var regen := StatusRules.multiplier(unit.buffs, "regen", clock)
	if unit.power < unit.max_power:
		unit.power = minf(unit.max_power, unit.power + Content.constants.UNITS[unit.kind].mpRegen * charge * fluid * delta)
	var out_of_combat: bool = clock - unit.damaged_at > Content.constants.VITALS.OOC_S
	if out_of_combat or unit.has_status("sp_regen_hit_until", clock):
		unit.shield = minf(unit.max_shield, unit.shield + unit.max_shield * Content.constants.VITALS.SP_REGEN_PS * charge * regen * fluid * delta)
	if out_of_combat:
		_heal_body(unit, unit.max_hp * Content.constants.VITALS.HP_REGEN_PS * charge * regen * fluid * delta, "ooc")
	var bases: Array = [world.bases.SWARM, world.bases.STEEL] if unit.side == Content.constants.SUPER_SIDE else [world.bases[unit.side]]
	var near_base := bases.any(func(base): return Vector2(unit.position.x - base.x, unit.position.z - base.z).length() < Content.constants.GAME.HERO_HEAL_RADIUS)
	if regen > 1 or near_base:
		_heal_body(unit, Content.constants.UNITS[unit.kind].regen * regen * delta, "def" if regen > 1 else "base")
	if unit.wet == 3 and unit.alive():
		_fire_burn(unit, float(Content.constants.TERRAIN_FX.FROZEN_DOT) * delta)
		if float(unit.status.get("fluid_freeze_report", 0)) + 2 < clock:
			unit.status.fluid_freeze_report = clock
			events.append({"type": "fluid_freeze", "actor": unit.entity_id, "position": unit.position})

func buy(unit: BattleUnit, item: String) -> bool:
	if not authoritative or over:
		return false
	if unit.side == Content.constants.SUPER_SIDE:
		if item != "super" or not unit.is_pilot() or int(unit.upgrades.get("super", 0)) >= int(Content.constants.SUPER_UPG.MAX) or unit.money < float(Content.constants.SUPER_UPG.PRICE):
			return false
		unit.money -= float(Content.constants.SUPER_UPG.PRICE)
		_set_super_level(unit, int(unit.upgrades.get("super", 0)) + 1)
		return true
	var definitions: Dictionary = Content.constants.ECON.UPGRADES
	if not definitions.has(item) or not unit.is_pilot() or unit.special.get("boss", false) or unit.side == Content.constants.SUPER_SIDE:
		return false
	var level: int = int(unit.upgrades[item])
	if level >= int(definitions[item].max):
		return false
	var step: Dictionary = Content.constants.ECON.UPG_STEPS[level]
	if unit.money < step.price or unit.score < step.score:
		return false
	unit.money -= step.price
	unit.upgrades[item] += 1
	_apply_upgrade(unit, item)
	events.append({"type": "buy", "actor": unit.entity_id, "peer": unit.peer_id, "item": item, "level": int(unit.upgrades[item])})
	return true

func _set_super_level(unit: BattleUnit, value: float) -> void:
	if not authoritative or unit.side != Content.constants.SUPER_SIDE:
		return
	var level := SuperRules.level(value)
	var previous := int(unit.upgrades.get("super", 0))
	unit.upgrades["super"] = level
	for slot: String in ["light", "heavy"]:
		unit.ammo.erase(slot)
		unit.reload_at.erase(slot)
	var hero: Dictionary = Content.heroes[unit.character]
	var stats: Dictionary = Content.constants.UNITS[unit.kind]
	var defense := SuperRules.defense_level(level)
	var curves: Dictionary = Content.balance["super"].curves
	var hp_curve := balance_profile.preferences.curve("hp", defense) if balance_profile != null else float(curves.hp[level])
	var sp_curve := balance_profile.preferences.curve("sp", defense) if balance_profile != null else float(curves.sp[level])
	var ar_curve := balance_profile.preferences.curve("ar", defense) if balance_profile != null else float(curves.ar[level])
	var maximum := floorf(float(stats.hp) * float(hero.mods.get("hp", 1)) * (1 + float(Content.constants.ECON.UPGRADES.hp.step) * defense) * hp_curve + 0.5)
	var shields := floorf(float(stats.shield) * float(hero.mods.get("sp", 1)) * (1 + float(Content.constants.ECON.UPGRADES.sp.step) * defense) * sp_curve + 0.5)
	if unit.alive():
		unit.hp = minf(maximum, unit.hp + maxf(0, maximum - unit.max_hp))
		unit.shield = minf(shields, unit.shield + maxf(0, shields - unit.max_shield))
	unit.max_hp = maximum
	unit.max_shield = shields
	unit.armor = (float(hero.armor) + float(Content.constants.ECON.UPGRADES.ar.step) * defense) * ar_curve
	unit.refresh_body_scale()
	if level != previous:
		events.append({"type": "buy", "actor": unit.entity_id, "peer": unit.peer_id, "item": "super", "level": level})

func _apply_upgrade(unit: BattleUnit, item: String) -> void:
	var definitions: Dictionary = Content.constants.ECON.UPGRADES
	var hero: Dictionary = Content.heroes[unit.character]
	var stats: Dictionary = Content.constants.UNITS[unit.kind]
	var curve: float = balance_profile.preferences.curve(item, unit.upgrades[item]) if balance_profile != null else Content.balance.upgrade_curves[item][int(unit.upgrades[item])]
	match item:
		"hp":
			var boss_factor: float = Content.constants.BOSS.HP_MUL if unit.special.get("boss", false) or unit.side == defending_side else 1.0
			var maximum := floorf(stats.hp * hero.mods.get("hp", 1) * boss_factor * (1 + definitions.hp.step * unit.upgrades.hp) * curve + 0.5)
			if unit.alive():
				unit.hp += maximum - unit.max_hp
				unit.upgrade_survivor = unit.hp <= 0
			unit.max_hp = maximum
		"sp":
			var maximum := floorf(stats.shield * hero.mods.get("sp", 1) * (1 + definitions.sp.step * unit.upgrades.sp) * curve + 0.5)
			if unit.alive():
				unit.shield += maximum - unit.max_shield
			unit.max_shield = maximum
		"ar":
			unit.armor = (hero.armor + definitions.ar.step * unit.upgrades.ar) * curve
		"lw", "hw":
			var slot := "light" if item == "lw" else "heavy"
			unit.ammo.erase(slot)
			unit.reload_at.erase(slot)

func upgrades_maxed(unit: BattleUnit) -> bool:
	for key: String in Content.constants.ECON.UPGRADES:
		if int(unit.upgrades.get(key, 0)) < int(Content.constants.ECON.UPGRADES[key].max):
			return false
	return true

func buy_creep(unit: BattleUnit, lane: int) -> bool:
	if not authoritative or over or not unit.is_pilot() or unit.special.get("boss", false) or not upgrades_maxed(unit):
		return false
	var levels: Array = creep_upgrades.get(unit.side, [])
	if lane < 0 or lane >= levels.size():
		return false
	var definition: Dictionary = Content.constants.CREEP_UPG
	if int(levels[lane]) >= int(definition.MAX) or unit.money < float(definition.PRICE):
		return false
	unit.money -= definition.PRICE
	levels[lane] = int(levels[lane]) + 1
	events.append({"type": "creep_upgrade", "actor": unit.entity_id, "side": unit.side, "lane": lane, "level": levels[lane]})
	return true

func cast_player_at(peer: int, slot: String, source_point: Vector2) -> bool:
	if not authoritative or over or slot not in ["def", "atk"] or not source_point.is_finite():
		return false
	var unit: BattleUnit = pilots.get(peer)
	if unit == null or unit.is_bot or not unit.alive():
		return false
	return cast(unit, slot, Vector3(source_point.x, 0, -source_point.y))

func cast(unit: BattleUnit, slot: String, requested_point: Vector3 = Vector3(INF, INF, INF)) -> bool:
	if not authoritative or over or not unit.alive() or not unit.is_pilot() or slot not in ["def", "atk"]:
		return false
	if not unit.is_bot and unit.has_status("freeze_until", clock):
		return false
	var level := unit.combat_level(slot)
	var def := ability_definition(unit.character, slot, level)
	if not unit.is_bot and float(def.range) > 0 and def.fx in ["strike", "emp"] and unit.lock_target == 0:
		return false
	if not _ability_supported(def, unit.character):
		message.emit(unit.peer_id, "unsupported")
		return false
	var point: Vector3 = unit.position if unit.is_bot or requested_point.is_finite() else _ability_point(unit, def)
	if unit.is_bot or requested_point.is_finite():
		point = unit.position
		if def.range and requested_point.is_finite():
			var clamped := AbilityTarget.clamp_point(Vector2(unit.position.x, unit.position.z), def.range, Vector2(requested_point.x, requested_point.z))
			point = Vector3(clamped.x, 0, clamped.y)
			point.y = world.ground_height(point.x, point.z)
	if not point.is_finite() or not _companion_surfaces_available(unit, def, point):
		message.emit(unit.peer_id, "unavailable_surface")
		return false
	var carrier_origin := _ability_origin(unit, slot) if slot == "atk" and def.carrier else Vector3.ZERO
	if slot == "atk" and def.carrier and (world == null or not carrier_origin.is_finite()
			or not is_finite(world.ground_height(carrier_origin.x, carrier_origin.z))):
		message.emit(unit.peer_id, "unavailable_surface")
		return false
	if def.fx == "cube":
		for index in range(6):
			var angle := index * PI / 3
			if world == null or not is_finite(world.ground_height(unit.position.x + cos(angle) * 5.5, unit.position.z - sin(angle) * 5.5)):
				message.emit(unit.peer_id, "unavailable_surface")
				return false
	if _ready_charges(unit, slot, def) <= 0 or unit.has_status("emp_until", clock) or unit.has_status("cast_lock_until", clock) or not unit.cast_state.is_empty():
		return false
	var cost := floorf(float(def.mp) + 0.5)
	if unit.power < cost:
		return false
	unit.power -= cost
	var boss_cooldown: float = Content.constants.BOSS.ENRAGE_CD_F if unit.special.get("boss", false) and int(unit.special.get("boss_segment", 0)) >= 3 else 1.0
	var deadline: float = clock + def.cd * float(weather_dynamics.get("snowCdMul", 1)) * boss_cooldown
	if int(def.charges) > 1:
		var charge: Dictionary = unit.ability_charges.get(slot, {"max": int(def.charges), "recharge_at": []})
		charge.max = int(def.charges)
		charge.recharge_at.append(deadline)
		unit.ability_charges[slot] = charge
		unit.cooldowns[slot] = 0 if charge.recharge_at.size() < charge.max else charge.recharge_at.min()
	else:
		unit.cooldowns[slot] = deadline
	if def.fx not in ["stealth", "vision", "rally", "recon"]:
		unit.status.stealth_until = 0
	var cast_duration: float = def.castTime
	if slot == "atk" and cast_duration == 0:
		cast_duration = Content.constants.ATK_CAST_S
	unit.cast_preview = {"definition": def.duplicate(true), "point": point, "until": clock + cast_duration}
	if slot == "def":
		unit.cast_state = {"slot": slot, "start": clock, "duration": def.castTime, "point": point,
			"definition": def.duplicate(true), "level": level}
		_emit_body_event({"type": "cast_start", "actor": unit.entity_id, "slot": slot, "level": level, "fx": def.fx, "duration": def.castTime, "point": point})
		return true
	unit.defending = false
	unit.status.cast_lock_until = clock + (def.castTime if def.castTime else Content.constants.ATK_CAST_S)
	if def.carrier:
		_launch_carriers(unit, def, point, carrier_origin)
	else:
		point = unit.position if def.target == "self" or (def.add is Dictionary and def.add.get("fx") == "clone") else point
		_cast_effect(unit, def, point)
	var event := {"type": "cast", "actor": unit.entity_id, "slot": slot, "fx": def.fx, "point": point,
		"radius": def.r, "duration": def.dur, "fraction": 1.0, "level": level,
		"carrier": def.carrier, "cast_duration": cast_duration}
	if def.carrier:
		event.origin = carrier_origin
	_emit_body_event(event)
	return true

func _ability_point(unit: BattleUnit, definition: Dictionary) -> Vector3:
	if not definition.range:
		return unit.position
	var timing: Dictionary = Content.balance.controls.casting
	var hit := _projectile_aim(unit, maxf(float(definition.range) * float(timing.aimRangeMultiplier), float(timing.aimMinimumRange)))
	var point: Vector3 = hit.point
	point.x = floorf(point.x * 10 + 0.5) / 10
	point.z = -floorf(-point.z * 10 + 0.5) / 10
	var offset := Vector2(point.x - unit.position.x, point.z - unit.position.z)
	if offset.length() > float(definition.range):
		offset = offset.normalized() * float(definition.range)
		point.x = unit.position.x + offset.x
		point.z = unit.position.z + offset.y
	point.y = world.ground_height(point.x, point.z)
	return point

func _ability_origin(unit: BattleUnit, slot: String) -> Vector3:
	if slot != "atk":
		return unit.position
	var origin := unit.position
	var distance := INF
	for structure: BattleUnit in units.values():
		if not structure.alive() or structure.side != unit.side or structure.kind not in ["tower", "base"]:
			continue
		var candidate := _planar_distance(unit.position, structure.position)
		if candidate < distance:
			origin = structure.position
			distance = candidate
	return origin

func _carrier_resources_available(character: String) -> bool:
	if not Content.balance.get("carrier", {}).has("shotDown") or not Content.balance.carrier.has("completion"):
		return false
	for kind: String in ["kami", "decoy", "hyper"]:
		if not Content.balance.carrier.shotDown.has(kind) or not Content.balance.carrier.completion.has(kind):
			return false
	for side: String in ["steel", "swarm", "super"]:
		for model: String in [character + "_kami", "decoy", "hyper"]:
			var key := side + "_" + model
			if not Content.balance.get("companions", {}).has(key) or not BodyRig.available(key):
				return false
	return true

func _launch_carriers(owner: BattleUnit, definition: Dictionary, point: Vector3, origin: Vector3) -> void:
	var surface := world.ground_height(origin.x, origin.z)
	if not is_finite(surface):
		message.emit(owner.peer_id, "unavailable_surface")
		return
	var start := {"x": float(origin.x), "y": float(origin.y - surface), "z": -float(origin.z)}
	var destination := CarrierRules.destination(start, point.x, -point.z, owner.facing_yaw())
	var parts := CarrierRules.parts(owner.kind, definition.fx)
	var total: float = definition.count if definition.fx in ["strike", "summon"] else 0.0
	if owner.character == "s01" or owner.kind == "drone" and owner.character not in ["t09", "m07"]:
		var rule: Dictionary = Content.constants.SQUAD.KAMI
		var count: float = float(definition.count if definition.count else rule.N) if owner.character == "s01" else float(parts)
		var speed: float = Content.constants.UNITS.drone.speed * rule.SPEED_MUL
		for index in range(ceili(count)):
			var side := CarrierRules.side(index)
			var state := {"kind": "kami", "x": start.x - sin(destination.yaw) * rule.FWD + cos(destination.yaw) * rule.SIDE * side,
				"z": start.z + cos(destination.yaw) * rule.FWD + sin(destination.yaw) * rule.SIDE * side, "y": start.y,
				"yaw": destination.yaw + rule.SPREAD * side, "tx": destination.x, "tz": destination.z,
				"fraction": 1.0 / count, "count": CarrierRules.integer_part(total, parts, index) if total else -1,
				"die_at": clock + destination.distance / speed + rule.TTL_S, "target": 0}
			_spawn_carrier(owner, definition, state)
	elif owner.character == "m06" or owner.kind == "morph" and owner.character != "m07":
		var rule: Dictionary = Content.constants.DECOY
		var count: float = float(definition.count if definition.count else 5) if owner.character == "m06" else float(parts)
		var drops: Array = []
		for index in range(floori(count)):
			drops.append({"fraction": 1.0 / count, "count": CarrierRules.integer_part(total, parts, index) if total else -1})
		_spawn_carrier(owner, definition, {"kind": "decoy", "x": start.x, "z": start.z, "y": start.y + rule.ALT,
			"yaw": destination.yaw, "tx": destination.x, "tz": destination.z, "drops": drops, "next_bomb": 0.0,
			"die_at": clock + destination.distance / rule.SPEED + count * rule.BOMB_GAP + rule.TTL_S, "target": 0})
	else:
		var count := 1.0
		if owner.character in ["t09", "m07"]:
			count = float(definition.count if definition.count else 8 if owner.character == "t09" else 6)
		for index in range(ceili(count)):
			var tx: float = destination.x
			var tz: float = destination.z
			if owner.character == "t09":
				var angle := float(index) / count * TAU + (rng.next() - 0.5) * 0.5
				var radius: float = 0.0 if index == 0 else (0.2 + 0.8 * rng.next()) * (definition.scatter if definition.scatter else 50.0)
				tx += cos(angle) * radius
				tz += sin(angle) * radius
			elif owner.character == "m07":
				var radius: float = (definition.scatter if definition.scatter else 35.0) * (0.2 + float(index) / count * 1.2)
				var angle := rng.next() * TAU
				tx += CarrierLaunchTrig.cosine(angle) * radius
				tz += CarrierLaunchTrig.sine(angle) * radius
			var dx: float = tx - start.x
			var dz: float = tz - start.z
			var distance := maxf(1, CarrierRules.hypot2(dx, dz))
			_spawn_carrier(owner, definition, {"kind": "hyper", "x": start.x, "z": start.z, "y": start.y,
				"x0": start.x, "z0": start.z, "y0": start.y, "yaw": atan2(-dx, dz), "tx": tx, "tz": tz,
				"ux": dx / distance, "uz": dz / distance, "distance": distance, "travel": 0.0,
				"phase": "climb", "spin": 0.0, "dive": {}, "chase": false, "target": 0,
				"fraction": 1.0 / count, "count": CarrierRules.integer_part(total, parts, index) if total else -1,
				"launch_at": clock + index * 0.22 if owner.character == "m07" else 0.0})

func _spawn_carrier(owner: BattleUnit, definition: Dictionary, state: Dictionary) -> BattleUnit:
	var position := _missile_world_position(Vector3(state.x, state.y, -state.z))
	if not position.is_finite():
		message.emit(owner.peer_id, "unavailable_surface")
		return null
	var model_key := "%s_%s_kami" % [owner.side.to_lower(), owner.character] if state.kind == "kami" else "%s_%s" % [owner.side.to_lower(), state.kind]
	var unit := spawn({"kind": state.kind, "side": owner.side, "position": position, "yaw": state.yaw,
		"special": {"role": "carrier", "owner_id": owner.entity_id, "owner_peer": owner.peer_id, "model_key": model_key, "hp": Content.balance.carrier.hp[state.kind]}})
	unit.collision_layer = 0
	unit.collision_mask = 0
	state.owner_id = owner.entity_id
	state.definition = definition.duplicate(true)
	carrier_states[unit.entity_id] = state
	owner.carrier_ids.append(unit.entity_id)
	events.append({"type": "carrier_spawn", "actor": unit.entity_id, "owner": owner.entity_id, "kind": state.kind,
		"side": owner.side, "position": position, "slot": definition.id})
	return unit

func _tick_carriers(delta: float) -> void:
	if not authoritative:
		return
	# Original producers run bomber, kamikaze and hypersonic rosters in separate passes.
	# Squads retain their single body when the hero representative leaves the roster.
	for kind: String in ["decoy", "kami", "hyper"]:
		var owners := pilots.values() if kind == "hyper" else units.values().filter(func(unit): return unit.is_pilot())
		for owner: BattleUnit in owners:
			for index in range(owner.carrier_ids.size() - 1, -1, -1):
				var id: int = owner.carrier_ids[index]
				var unit: BattleUnit = units.get(id)
				if unit == null or not carrier_states.has(id):
					owner.carrier_ids.remove_at(index)
					carrier_states.erase(id)
					continue
				var state: Dictionary = carrier_states[id]
				if state.kind != kind:
					continue
				if not unit.alive():
					_remove_carrier(id)
					continue
				var target: BattleUnit = units.get(int(state.target))
				var target_data := {}
				if target != null and target.alive():
					target_data = {"x": float(target.position.x), "z": -float(target.position.z), "height": _relative_target(target).y}
				var outcome := CarrierRules.advance(state, delta, clock, target_data)
				var position := _missile_world_position(Vector3(state.x, state.y, -state.z))
				if not position.is_finite():
					message.emit(owner.peer_id, "unavailable_surface")
					_remove_carrier(id)
					continue
				unit.position = position
				unit.yaw = state.yaw
				unit.rotation.y = unit.yaw
				unit.special.phase = state.get("phase", "flight")
				if state.kind == "decoy":
					unit.special.lost = bool(state.get("lost", false))
				_finish_carrier_step(unit, outcome)

func _finish_carrier_step(unit: BattleUnit, outcome: Dictionary) -> void:
	# Original completion reports precede delivery effects, including lethal ones.
	if outcome.remove:
		for report: Dictionary in Content.balance.carrier.completion[unit.kind]:
			_publish_blast_event({"type": "boom", "actor": int(unit.special.owner_id), "position": unit.position,
				"radius": float(report.radius), "side": unit.side, "sam": report.sam, "kami": report.kami, "hyper": report.hyper})
	for arrival: Dictionary in outcome.arrivals:
		_carrier_arrive(unit, Vector3(arrival.x, 0, -arrival.z), arrival.fraction, int(arrival.count))
	if outcome.remove:
		_remove_carrier(unit.entity_id)

func _carrier_arrive(unit: BattleUnit, point: Vector3, fraction: float, count_override: int = -1) -> void:
	var state: Dictionary = carrier_states.get(unit.entity_id, {})
	var owner: BattleUnit = pilots.get(int(unit.special.owner_peer))
	if state.is_empty() or owner == null or not owner.is_pilot():
		return
	point.y = world.ground_height(point.x, point.z)
	if not point.is_finite():
		message.emit(owner.peer_id, "unavailable_surface")
		return
	_cast_effect(owner, state.definition, point, fraction, true, count_override)
	events.append({"type": "ability_arrive", "actor": owner.entity_id, "carrier": unit.entity_id, "position": point,
		"fraction": fraction, "count": count_override, "fx": state.definition.fx, "side": owner.side})

func _carrier_shot_down(unit: BattleUnit) -> void:
	for report: Dictionary in Content.balance.carrier.shotDown[unit.kind]:
		_publish_blast_event({"type": "boom", "actor": int(unit.special.owner_id), "position": unit.position, "radius": float(report.radius),
			"side": unit.side, "intercept": true, "sam": report.sam, "kami": report.kami})
	_remove_carrier(unit.entity_id)

func _remove_carrier(id: int) -> void:
	var state: Dictionary = carrier_states.get(id, {})
	var owner: BattleUnit = units.get(int(state.get("owner_id", 0)))
	if owner != null:
		owner.carrier_ids.erase(id)
	carrier_states.erase(id)
	_remove_field_unit(id)

func _ability_supported(definition: Dictionary, character: String) -> bool:
	if definition.support or definition.fx not in ["buff", "heal", "emp", "vision", "stealth", "rally", "recon", "intercept", "reflect", "phaseshift", "shield_bash", "strike", "fog", "cube", "summon", "decoy_beacon"]:
		return false
	if definition.carrier and not _carrier_resources_available(character):
		return false
	if definition.fx == "summon" and definition.unit not in SUMMON_KINDS:
		return false
	if definition.fx in ["summon", "decoy_beacon"]:
		var kind: String = definition.unit if definition.fx == "summon" else "decoy_beacon"
		for side: String in ["steel", "swarm", "super"]:
			if not Content.balance.get("companions", {}).has(side + "_" + kind) or not BodyRig.available(BodyRig.entity_key(side, kind)):
				return false
	var added: Variant = definition.get("add")
	return not added is Dictionary or added.fx in ["haste", "leap", "dodge", "vamp", "mark", "evade", "overdrive", "alpha", "stun", "slow", "confuse", "bleed", "pull", "siege", "clone"]

func _ready_charges(unit: BattleUnit, slot: String, definition: Dictionary) -> int:
	var maximum := maxi(1, int(definition.charges))
	var allocated := unit.ability_charges.has(slot)
	var state: Dictionary = unit.ability_charges.get(slot, {})
	var summary := AbilityChargeState.inspect(maximum, unit.cooldowns.get(slot, 0), state, clock, allocated)
	if maximum > 1 and allocated:
		state.max = maximum
		state.recharge_at = summary.deadlines
		unit.cooldowns[slot] = summary.cooldown
	return int(summary.ready)

func _add_modifier(unit: BattleUnit, key: String, value: float, duration: float, break_on_hit: bool = false) -> void:
	unit.buffs.append({"until": clock + duration, "mul": {key: value}, "break_on_hit": break_on_hit})

func _ability_allies(unit: BattleUnit, center: Vector3, radius: float, global_team: bool = false) -> Array:
	return pilots.values().filter(func(ally): return ally.side == unit.side and (global_team or (ally.alive() and Vector2(ally.position.x - center.x, ally.position.z - center.z).length() <= radius)))

func _cast_effect(unit: BattleUnit, definition: Dictionary, center: Vector3, fraction: float = 1.0, once: bool = true, count_override: int = -1) -> void:
	if not authoritative or over:
		return
	var boost := {"dmgMul": 0.0, "heal": 0.0, "alphaX": 1.0}
	if definition.id == "atk":
		boost = StatusRules.self_attack_boost(unit.character, unit.combat_level("atk"), unit.combat_level("light"), unit.combat_level("heavy"), weapon_definition(unit.character, "heavy", unit.combat_level("heavy")))
	var allies: Array = _ability_allies(unit, center, definition.r) if definition.target == "team" else [unit]
	var modifiers: Dictionary = definition.mul if definition.mul is Dictionary else {}
	var added: Dictionary = definition.add if definition.add is Dictionary else {}
	match definition.fx:
		"buff":
			for ally: BattleUnit in allies:
				for key: String in modifiers:
					var value: float = modifiers[key] + (boost.dmgMul if key == "dmg" else 0)
					_add_modifier(ally, key, 1 + (value - 1) * fraction, definition.dur, definition.brk)
				match added.get("fx", ""):
					"haste", "leap":
						var key := "speed" if added.fx == "haste" else "jump"
						var value := float(added.get("f", 1.25 if added.fx == "haste" else 2))
						_add_modifier(ally, key, 1 + (value - 1) * fraction, definition.dur)
					"dodge": _add_modifier(ally, "dodge", 1, definition.dur)
					"vamp": _add_modifier(ally, "vamp", float(added.get("f", 0.12)) * fraction, definition.dur)
					"evade", "overdrive":
						_add_modifier(ally, "evade", float(added.get("evade", 0)) * fraction, definition.dur, definition.brk)
						if added.fx == "overdrive" and once:
							_refill_all(ally)
							ally.status.no_reload_until = clock + definition.dur
					"mark":
						if once:
							ally.status.mark_until = clock + float(added.get("dur", definition.dur))
					"clone":
						if once:
							ally.status.clones_until = clock + definition.dur
							ally.status.no_light_reload_until = clock + definition.dur
							_spawn_clones(ally, float(added.get("count", 2)) if added.get("count", 2) else 2)
					"siege":
						if once:
							_refill_all(ally)
							ally.status.no_heavy_reload_until = clock + definition.dur
							ally.status.rooted_until = clock + definition.dur + float(added.get("recoverS", 1.5))
							ally.status.root_position = ally.position
							events.append({"type": "siege_mode", "actor": ally.entity_id, "side": ally.side, "until": clock + definition.dur})
		"heal":
			var amount: float = definition.heal + boost.heal
			for ally: BattleUnit in allies:
				if amount > 0:
					_heal_body(ally, amount * fraction)
					if definition.sp and not definition.aura:
						ally.shield = minf(ally.max_shield, ally.shield + ally.max_shield * fraction)
			if definition.target == "team" and definition.r > 0:
				events.append({"type": "heal_aoe", "actor": unit.entity_id, "peer": unit.peer_id,
					"side": unit.side, "position": center, "radius": definition.r})
			for ally: BattleUnit in allies:
				if definition.cleanse and once:
					_cleanse(ally)
				var duration: float = definition.dur * fraction
				if duration > 0:
					if definition.ccImm or (definition.cleanse and not definition.aura and definition.id == "def"):
						_add_modifier(ally, "ccImm", 1, duration)
					if definition.healAmp > 0:
						_add_modifier(ally, "healAmp", 1 + definition.healAmp * fraction, duration)
					if definition.regen > 0:
						_add_modifier(ally, "regen", 1 + (definition.regen - 1) * fraction, duration)
			if definition.aura and once:
				var duration: float = (definition.dur if definition.dur else 6) * fraction
				unit.heal_aura = {"until": clock + duration, "radius": definition.r if definition.r else 28,
					"hps": (definition.hot if definition.hot else 35) * fraction,
					"sp_hps": (definition.spRestore / duration if definition.spRestore and duration > 0 else 15 if definition.sp else 0) * fraction,
					"side": unit.side, "cleanse": definition.cleanse}
				events.append({"type": "heal_aura_start", "actor": unit.entity_id, "peer": unit.peer_id, "side": unit.side,
					"position": unit.position, "radius": unit.heal_aura.radius, "duration": duration})
		"emp":
			for target: BattleUnit in units.values():
				if target.side == unit.side or not target.alive() or target.kind in ["tower", "base", "bunker"] or Vector2(target.position.x - center.x, target.position.z - center.z).length() > definition.r:
					continue
				if target.is_hero() and StatusRules.maximum(target.buffs, "ccImm", clock) > 0:
					continue
				target.status.emp_until = maxf(float(target.status.get("emp_until", 0)), clock + definition.dur * fraction)
				if definition.dmg * fraction > 0:
					damage(unit, target, definition, definition.dmg * fraction, false, {"origin": center}, false)
			if not added.is_empty():
				_apply_cc(unit, added, center, definition.r)
			if definition.vision:
				vision_until[unit.side] = maxf(float(vision_until.get(unit.side, 0)), clock + definition.vision * fraction)
		"vision", "intercept":
			if definition.fx == "intercept":
				var radius: float = definition.r * sqrt(maxf(0.01, fraction))
				for index in range(missiles.size() - 1, -1, -1):
					var missile: Dictionary = missiles[index]
					if missile.side == unit.side or Vector2(missile.position.x - unit.position.x, missile.position.z - unit.position.z).length() > radius:
						continue
					_remove_missile(int(missile.id))
					_publish_blast_event({"type": "missile_intercept", "actor": unit.entity_id, "missile": missile.id,
						"position": _missile_world_position(missile.position), "radius": 8.0, "side": unit.side})
			if definition.fx == "vision" or definition.vision:
				vision_until[unit.side] = maxf(float(vision_until.get(unit.side, 0)), clock + definition.vision * fraction)
		"stealth":
			if once:
				unit.status.stealth_until = clock + definition.dur * fraction
				if added.get("fx") == "alpha":
					unit.status.alpha_multiplier = boost.alphaX
					unit.status.alpha_arm_until = clock + definition.dur
		"reflect":
			unit.status.reflect_until = clock + (definition.dur if definition.dur else 3.0) * fraction
			unit.status.reflect_arc = deg_to_rad(float(definition.get("arc", 120)))
			unit.status.reflect_ratio = definition.get("ratio", 0.6)
		"phaseshift":
			var phase_duration: float = (definition.dur if definition.dur else 1.8) * fraction
			unit.status.phase_until = clock + phase_duration
			unit.status.phase_damage = (definition.dmg if definition.dmg else 50) * fraction
			events.append({"type": "phase_start", "actor": unit.entity_id, "peer": unit.peer_id, "side": unit.side, "duration": phase_duration})
		"fog": _spawn_fog(unit, definition, center)
		"cube": _spawn_cubic_slabs(unit, definition, center, fraction)
		"summon": _spawn_autonomous_summons(unit, definition, center, fraction, count_override)
		"decoy_beacon": _spawn_holograms(unit, definition, fraction)
		"rally", "recon":
			for ally: BattleUnit in _ability_allies(unit, center, 0, true):
				if definition.revive > 0 and once and not ally.alive() and ally.respawn_at > clock:
					_revive_body(ally, definition.revive)
				if not ally.alive():
					continue
				for key: String in modifiers:
					_add_modifier(ally, key, 1 + (float(modifiers[key]) - 1) * fraction, definition.dur)
				if definition.regen > 0:
					_add_modifier(ally, "regen", 1 + (definition.regen - 1) * fraction, definition.dur)
				if added.get("fx") == "evade":
					_add_modifier(ally, "evade", float(added.get("evade", 0)) * fraction, definition.dur)
				if definition.cleanse:
					if once:
						_cleanse(ally)
					_add_modifier(ally, "ccImm", 1, definition.dur)
			if definition.vision and once:
				vision_until[unit.side] = maxf(float(vision_until.get(unit.side, 0)), clock + definition.vision)
		"strike":
			for index in range(count_override if count_override >= 0 else maxi(0, ceili(float(definition.count)))):
				var angle := rng.next() * TAU
				var radius: float = 0.0 if index == 0 else rng.next() * (definition.scatter if definition.scatter else definition.r * 2)
				var point := center + Vector3(cos(angle) * radius, 0, -sin(angle) * radius)
				point.y = 0
				_publish_blast_event({"type": "boom", "actor": unit.entity_id, "position": _missile_world_position(point),
					"radius": definition.r, "side": unit.side})
				var attack := {"dmg": definition.dmg * fraction, "r": definition.r, "vs": definition.vs, "pen": definition.pen,
					"vsSp": definition.vsSp, "vsHp": definition.vsHp, "spPierce": definition.spPierce,
					"elem": definition.elem, "elemBuildup": definition.elemBuildup}
				blast(unit, attack, point, false, true, 0)
				if not added.is_empty():
					_apply_cc(unit, added, point, definition.r)
	if definition.fx == "buff" and definition.vision and once:
		vision_until[unit.side] = maxf(float(vision_until.get(unit.side, 0)), clock + definition.vision * fraction)
	for ally: BattleUnit in allies:
		if definition.spRestore and once and not definition.aura and ally.alive():
			ally.shield = minf(ally.max_shield, ally.shield + definition.spRestore * fraction)
		var duration: float = (definition.dur if definition.dur else 8) * fraction
		if definition.spRegenHit:
			ally.status.sp_regen_hit_until = maxf(float(ally.status.get("sp_regen_hit_until", 0)), clock + duration)
		if definition.shieldDefBoost:
			ally.status.shield_def_boost_until = maxf(float(ally.status.get("shield_def_boost_until", 0)), clock + duration)
	var duration: float = (definition.dur if definition.dur else 8) * fraction
	for flag: String in ["shieldExpand", "shieldBash", "defJump"]:
		if definition[flag]:
			var key: String = {"shieldExpand": "shield_expand_until", "shieldBash": "shield_bash_until", "defJump": "def_jump_until"}[flag]
			unit.status[key] = maxf(float(unit.status.get(key, 0)), clock + duration)

func _refill_all(unit: BattleUnit) -> void:
	unit.reload_at.clear()
	for slot: String in ["light", "heavy"]:
		unit.ammo[slot] = weapon_definition(unit.character, slot, unit.combat_level(slot)).mag

func _cleanse(unit: BattleUnit) -> void:
	for key: String in ["stun_until", "slow_until", "confuse_until", "emp_until"]:
		unit.status[key] = 0
	unit.bleed.clear()
	for key: String in ["element_buildup", "element_last_hit"]:
		unit.status.erase(key)
	for key: String in ["poison_stacks", "sonic_stacks", "stagger_stacks"]:
		unit.status[key] = 0
	events.append({"type": "cleanse", "actor": unit.entity_id, "side": unit.side})

func _revive_body(unit: BattleUnit, fraction: float) -> void:
	if not authoritative or unit.special.get("boss", false):
		return
	unit.slope_blocked = false
	unit.climb.release()
	unit.movement_roll = 0.0
	unit.position_trail.clear()
	unit.hp = maxf(1, floorf(unit.max_hp * fraction + 0.5))
	unit.snap_body_presentation()
	unit.shield = unit.max_shield * fraction
	unit.respawn_at = 0
	unit.damaged_at = clock
	unit.status.inv_until = clock + Content.constants.SELF_ATK.REVIVE_INV_S
	for key: String in ["stun_until", "slow_until", "confuse_until", "blind_until", "sup_until", "sup_factor"]:
		unit.status[key] = 0
	unit.bleed.clear()
	unit.assists.clear()
	unit.status.erase("element_buildup")
	unit.status.erase("element_last_hit")
	unit.collision_mask = 1 | 4
	unit.refresh_collision()
	unit.visible = unit.presentation_visible
	events.append({"type": "revive", "actor": unit.entity_id, "side": unit.side})

func _interrupt_cast(unit: BattleUnit) -> void:
	if unit.special.get("role") == "clone":
		unit = units.get(int(unit.special.owner_id))
		if unit == null:
			return
	if unit.cast_state.is_empty():
		return
	var state := unit.cast_state.duplicate(true)
	unit.cast_state.clear()
	unit.cast_preview.clear()
	unit.status.cast_lock_until = 0
	var ratio: float = clampf(clock - state.start, 0, state.duration) / state.duration if state.duration > 0 else 1.0
	var fraction := ratio * ratio
	_cast_effect(unit, state.definition, state.point, fraction)
	_emit_body_event({"type": "cast", "actor": unit.entity_id, "slot": "def", "fx": state.definition.fx,
		"fraction": fraction, "interrupted": true, "point": state.point, "level": state.level,
		"radius": state.definition.r, "duration": state.definition.dur})

func _apply_cc(unit: BattleUnit, added: Dictionary, center: Vector3, radius: float) -> void:
	for target: BattleUnit in units.values():
		if target.side == unit.side or not target.alive() or target.kind in ["tower", "base", "bunker"]:
			continue
		if target.is_hero() and (target.has_status("inv_until", clock) or StatusRules.maximum(target.buffs, "ccImm", clock) > 0):
			continue
		if Vector2(target.position.x - center.x, target.position.z - center.z).length() > radius * 1.5:
			continue
		match added.fx:
			"stun", "slow", "confuse":
				var key: String = {"stun": "stun_until", "slow": "slow_until", "confuse": "confuse_until"}[added.fx]
				var default_duration: float = {"stun": 1.0, "slow": 2.5, "confuse": 2.0}[added.fx]
				target.status[key] = maxf(float(target.status.get(key, 0)), clock + float(added.get("dur", default_duration)))
				if added.fx == "slow":
					target.status.slow_factor = added.get("f", 0.6)
			"bleed":
				target.bleed = {"dps": added.get("dps", 15), "until": clock + float(added.get("dur", 4)), "pen": added.get("pen", 10), "peer": unit.peer_id}
			"pull":
				var offset := Vector2(center.x - target.position.x, center.z - target.position.z)
				var distance := offset.length()
				var impulse: float = added.get("imp", 18)
				if impulse == 0:
					impulse = 18
				if target.is_hero() and not target.is_bot:
					if distance > 1:
						var push := offset / distance * minf(impulse, distance * 2)
						if target.flying:
							target.velocity.x += push.x
							target.velocity.z += push.y
						else:
							target.impulse_velocity += push
							target.velocity.y += 3
				else:
					var denominator := distance if distance else 1.0
					_place_solid(target, offset / denominator * minf(impulse * 0.5, denominator))

func _place_solid(unit: BattleUnit, offset: Vector2) -> void:
	if not unit.alive() or not offset.is_finite():
		return
	unit.move_and_collide(Vector3(offset.x, 0, offset.y))

func _tick_element_buildup(unit: BattleUnit, delta: float) -> void:
	var buildup: Dictionary = unit.status.get("element_buildup", {})
	var last_hit: Dictionary = unit.status.get("element_last_hit", {})
	for element: String in buildup.keys():
		if clock - float(last_hit.get(element, 0)) > 2.5:
			buildup[element] = maxf(0, float(buildup[element]) - 20 * delta)
			if float(buildup[element]) <= 0:
				buildup.erase(element)
	if unit.bleed.is_empty() or float(unit.bleed.until) <= clock:
		unit.status.poison_stacks = 0
	if not unit.has_status("confuse_until", clock):
		unit.status.sonic_stacks = 0
	if not unit.has_status("stun_until", clock):
		unit.status.stagger_stacks = 0

func _tick_shield_bash(unit: BattleUnit, delta: float) -> void:
	if not unit.is_hero() or not unit.defending or unit.shield <= 0 or not unit.has_status("shield_bash_until", clock):
		return
	var forward := Vector2(-sin(unit.facing_yaw()), -cos(unit.facing_yaw()))
	for target: BattleUnit in units.values():
		if not target.alive() or target.side == unit.side:
			continue
		var offset := Vector2(target.position.x - unit.position.x, target.position.z - unit.position.z)
		var distance := offset.length()
		var denominator := distance if distance else 1.0
		if distance > 4.0 + (target.effect_radius if target.effect_radius else 1.0) or forward.dot(offset / denominator) < 0.5:
			continue
		_place_solid(target, offset / denominator * 12 * delta)
		damage(unit, target, {"pen": 10}, 35 * delta, false, {"weather_weapon": false}, false)
		if float(target.status.get("bash_at", 0)) + 1.0 < clock:
			target.status.bash_at = clock
			events.append({"type": "shield_bash", "actor": unit.entity_id, "target": target.entity_id, "position": target.position})

func _damage_credit(attacker: BattleUnit) -> BattleUnit:
	if attacker == null:
		return null
	return attacker if attacker.is_hero() else units.get(int(attacker.special.get("owner_id", 0)))

func _auto_target(companion: BattleUnit, owner: BattleUnit) -> BattleUnit:
	var sight: float = companion.special.get("sight", 200)
	if not sight:
		sight = 200
	if owner != null and owner.last_hit_target:
		var focus: BattleUnit = units.get(owner.last_hit_target)
		if focus != null and focus.alive() and focus.side != companion.side and _planar_distance(companion.position, focus.position) <= sight * 1.5:
			return focus
	var best: BattleUnit
	var best_score := INF
	for candidate: BattleUnit in units.values():
		if not candidate.alive() or candidate.side == companion.side or candidate.side.is_empty() or candidate.special.get("neutral", false):
			continue
		var distance := _planar_distance(companion.position, candidate.position)
		if distance > sight:
			continue
		var score := distance + (0.0 if candidate.is_hero() else 50.0 if candidate.kind in ["tower", "base"] else 100.0)
		if score < best_score:
			best = candidate
			best_score = score
	return best

func _planar_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()

func _companion_position(center: Vector3, offset: Vector2, altitude: float) -> Vector3:
	if world == null:
		return Vector3(NAN, NAN, NAN)
	var point := Vector3(center.x + offset.x, 0, center.z + offset.y)
	point.y = world.ground_height(point.x, point.z) + altitude
	return point

func _summon_plan(_unit: BattleUnit, definition: Dictionary, center: Vector3, fraction: float, random: SourceRng, count_override: int = -1) -> Array:
	var profile: Dictionary = Content.constants.UNITS[definition.unit]
	var count := count_override if count_override >= 0 else maxi(1, int(floorf(float(definition.count if definition.count else 2) * fraction + 0.5)))
	# The original non-heli drone value is undefined; eye/shot/movement readers
	# consume it with y || 0. Preserve that conversion without inventing a constant.
	var altitude: float = (Content.constants.GAME.HELI_ALT if "heli" in definition.unit else Content.constants.GAME.get("DRONE_ALT", 0.0)) if profile.get("fly", false) else 0.0
	var plan: Array = []
	for index in range(count):
		var angle := float(index) / count * TAU + (random.next() - 0.5) * 0.5
		var direction := Vector2(cos(angle), -sin(angle))
		plan.append({"position": _companion_position(center, direction * (6 + index * 4), altitude), "offset": direction * 12})
	return plan

func _companion_surfaces_available(unit: BattleUnit, definition: Dictionary, center: Vector3 = Vector3(NAN, NAN, NAN)) -> bool:
	if not center.is_finite():
		center = unit.position
	if definition.fx == "summon":
		for entry: Dictionary in _summon_plan(unit, definition, center, 1, SourceRng.new(rng.state)):
			if not entry.position.is_finite():
				return false
	elif definition.fx == "decoy_beacon":
		for index in range(ceili(float(definition.count if definition.count else 2))):
			var offset := Vector2(cos(unit.facing_yaw()), -sin(unit.facing_yaw())) * (-3 if index == 0 else 3)
			if not _companion_position(unit.position, offset, 2).is_finite():
				return false
	elif definition.add is Dictionary and definition.add.get("fx") == "clone":
		for index in range(ceili(float(definition.add.get("count", 2))) if definition.add.get("count", 2) else 2):
			var angle := unit.facing_yaw() + (2.1 if index == 0 else -2.1)
			if not _companion_position(unit.position, Vector2(cos(angle), -sin(angle)) * 4, _missile_target_altitude(unit)).is_finite():
				return false
	return true

func _spawn_clones(owner: BattleUnit, count: float = 2) -> void:
	_despawn_clones(owner)
	owner.clones_initialized = true
	var altitude := _missile_target_altitude(owner)
	for index in range(ceili(count)):
		var angle := owner.facing_yaw() + (2.1 if index == 0 else -2.1)
		var direction := Vector2(cos(angle), -sin(angle))
		var point := _companion_position(owner.position, direction * 4, altitude)
		if not point.is_finite():
			message.emit(owner.peer_id, "unavailable_surface")
			continue
		var clone := spawn({"character": owner.character, "kind": owner.kind, "side": owner.side,
			"peer": owner.peer_id, "position": point, "yaw": owner.facing_yaw(), "effect_radius": owner.effect_radius if owner.effect_radius else 1.8,
			"special": {"role": "clone", "owner_id": owner.entity_id, "offset": direction * 12,
				"hp": owner.hp, "max_hp": owner.max_hp, "shield": owner.shield, "max_shield": owner.max_shield, "armor": owner.armor, "speed": 0.0, "cd": 0.0}})
		clone.flying = owner.flying
		clone.refresh_collision()
		owner.clone_ids.append(clone.entity_id)
	events.append({"type": "clone_spawn", "actor": owner.entity_id, "side": owner.side, "count": count})

func _despawn_clones(owner: BattleUnit) -> void:
	if not owner.clones_initialized:
		return
	for id: int in owner.clone_ids:
		_remove_field_unit(id)
	owner.clone_ids.clear()
	# The source spawn helper clears these flags on every subsequent cast, including an empty previous roster.
	owner.status.erase("clones_until")
	owner.status.erase("no_light_reload_until")

func _clone_death_swap(owner: BattleUnit) -> bool:
	var best: BattleUnit
	for id: int in owner.clone_ids:
		var clone: BattleUnit = units.get(id)
		if clone != null and clone.alive() and (best == null or clone.hp > best.hp):
			best = clone
	if best == null:
		return false
	owner.hp = best.hp
	owner.shield = best.shield
	# Lethal swaps bypass horizontal collision; expiry swaps use the source placement seam.
	owner.position.x = best.position.x
	owner.position.z = best.position.z
	owner.clone_ids.erase(best.entity_id)
	_remove_field_unit(best.entity_id)
	events.append({"type": "clone_death_swap", "actor": owner.entity_id, "side": owner.side, "position": owner.position})
	return true

func _tick_clones(delta: float) -> void:
	for owner: BattleUnit in pilots.values():
		if owner.clone_ids.is_empty():
			continue
		if not owner.alive():
			_despawn_clones(owner)
			continue
		if clock >= float(owner.status.get("clones_until", 0)):
			var best := owner
			for id: int in owner.clone_ids:
				var clone: BattleUnit = units.get(id)
				if clone != null and clone.alive() and clone.hp > best.hp:
					best = clone
			if best != owner:
				owner.hp = best.hp
				owner.shield = best.shield
				_place_solid(owner, Vector2(best.position.x - owner.position.x, best.position.z - owner.position.z))
				events.append({"type": "clone_time_swap", "actor": owner.entity_id, "side": owner.side, "position": owner.position})
			_despawn_clones(owner)
			continue
		var weapon := weapon_definition(owner.character, "light", owner.combat_level("light"))
		var sight: float = Content.constants.UNITS[owner.kind].get("sight", weapon.range if weapon.range else 200)
		for id: int in owner.clone_ids.duplicate():
			var clone: BattleUnit = units.get(id)
			if clone == null or not clone.alive():
				continue
			clone.special.cd = maxf(0, float(clone.special.cd) - delta)
			clone.special.sight = sight
			if clone.flying != owner.flying:
				clone.flying = owner.flying
				clone.refresh_collision()
			var ground := world.ground_height(clone.position.x, clone.position.z)
			if is_finite(ground):
				clone.position.y = ground + _missile_target_altitude(owner)
			var target := _auto_target(clone, owner)
			if target != null:
				var distance := _planar_distance(clone.position, target.position)
				if distance <= weapon.range:
					_face_companion(clone, target.position)
					if clone.special.cd == 0:
						clone.special.cd = 1.0 / ((float(weapon.rate) if weapon.rate else 3.0) * weather_attack_rate(clone))
						var amount: float = weapon.dmg * _weapon_multiplier(owner, target, weapon) * CombatMath.damage_falloff(weapon, distance)
						amount = _roll_critical(clone, target, weapon, amount, true)
						damage(clone, target, weapon, amount, false, {"origin": clone.position}, false)
						_companion_shot(clone, target, weapon)
				else:
					_move_companion(clone, target.position, minf(21 * _companion_weather_speed(clone) * delta, distance - float(weapon.range) * 0.85))
					_face_companion(clone, target.position)
				continue
			var point := owner.position + Vector3(clone.special.offset.x, 0, clone.special.offset.y)
			var distance := _planar_distance(clone.position, point)
			if distance > 6:
				_move_companion(clone, point, minf(21 * _companion_weather_speed(clone) * delta, distance - 4))
			clone.yaw = owner.facing_yaw()
			clone.rotation.y = clone.yaw

func _spawn_autonomous_summons(owner: BattleUnit, definition: Dictionary, center: Vector3, fraction: float = 1.0, count_override: int = -1) -> void:
	var profile: Dictionary = Content.constants.UNITS[definition.unit]
	var scale_factor := 1.0 + (owner.combat_level(definition.id) - 1.0 if definition.id in ["def", "atk"] else 0.0) * 0.35
	if owner.side == Content.constants.SUPER_SIDE:
		scale_factor *= NpcRules.creep_multiplier(float(owner.upgrades.get("super", 0)))
	for entry: Dictionary in _summon_plan(owner, definition, center, fraction, rng, count_override):
		if not entry.position.is_finite():
			message.emit(owner.peer_id, "unavailable_surface")
			continue
		var health := floorf(float(profile.hp) * scale_factor + 0.5)
		var summon := spawn({"kind": definition.unit, "side": owner.side, "position": entry.position,
			"special": {"role": "summon", "owner_id": owner.entity_id, "offset": entry.offset, "hp": health, "max_hp": health,
				"dmg": floorf(float(profile.dmg) * scale_factor + 0.5), "armor": profile.get("armor", 0), "speed": profile.get("speed", 15),
				"range": profile.get("range", 150), "rate": profile.get("rate", 0.8), "sight": profile.get("sight", 200), "wid": profile.get("wid", ""), "cd": 0.0}})
		autonomous_summons.append(summon.entity_id)
		events.append({"type": "summon_spawn", "actor": summon.entity_id, "kind": summon.kind, "side": summon.side, "position": summon.position})

func _tick_summons(delta: float) -> void:
	for index in range(autonomous_summons.size() - 1, -1, -1):
		var summon: BattleUnit = units.get(autonomous_summons[index])
		if summon == null or not summon.alive():
			_remove_field_unit(autonomous_summons[index])
			autonomous_summons.remove_at(index)
			continue
		var owner: BattleUnit = units.get(int(summon.special.owner_id))
		var target := _auto_target(summon, owner)
		summon.special.cd = maxf(0, float(summon.special.cd) - delta)
		if target != null:
			var distance := _planar_distance(summon.position, target.position)
			if distance <= float(summon.special.range):
				if summon.special.cd == 0:
					summon.special.cd = 1.0 / ((float(summon.special.rate) if summon.special.rate else 0.8) * weather_attack_rate(summon))
					var weapon: Dictionary = Content.constants.WEAPONS.get(summon.special.wid, {"dmg": summon.special.dmg, "pen": 0})
					damage(summon, target, weapon, float(summon.special.dmg) * CombatMath.damage_falloff(weapon, distance), false, {}, false)
					_companion_shot(summon, target, weapon)
			else:
				_move_companion(summon, target.position, minf(summon.speed * _companion_weather_speed(summon) * delta, distance - float(summon.special.range) * 0.85))
		elif owner != null and owner.alive():
			var point := owner.position + Vector3(summon.special.offset.x, 0, summon.special.offset.y)
			var distance := _planar_distance(summon.position, point)
			if distance > 6:
				_move_companion(summon, point, minf(summon.speed * _companion_weather_speed(summon) * delta, distance - 4))

func _spawn_holograms(owner: BattleUnit, definition: Dictionary, fraction: float = 1.0) -> void:
	var weapon := weapon_definition(owner.character, "light", owner.combat_level("light"))
	var duration: float = (definition.dur if definition.dur else 6.0) * fraction
	for index in range(ceili(float(definition.count if definition.count else 2))):
		var offset := Vector2(cos(owner.facing_yaw()), -sin(owner.facing_yaw())) * (-3 if index == 0 else 3)
		var point := _companion_position(owner.position, offset, 2)
		if not point.is_finite():
			message.emit(owner.peer_id, "unavailable_surface")
			continue
		var decoy := spawn({"kind": "decoy_beacon", "side": owner.side, "position": point, "yaw": owner.facing_yaw(), "effect_radius": 1.5,
			"special": {"role": "hologram", "owner_id": owner.entity_id, "offset": offset * 3, "cd": 0.0,
				"range": weapon.range if weapon.range else 200, "sight": weapon.range if weapon.range else 200, "rate": weapon.rate if weapon.rate else 3,
				"until": clock + duration, "blind_radius": definition.get("blindR", 14) if definition.get("blindR", 14) else 14,
				"blind_duration": definition.get("blindDur", 1.5) if definition.get("blindDur", 1.5) else 1.5}})
		hologram_decoys.append(decoy.entity_id)
		events.append({"type": "decoy_beacon_spawn", "actor": decoy.entity_id, "owner": owner.entity_id, "side": owner.side, "position": point, "duration": duration})

func _tick_holograms(delta: float) -> void:
	for index in range(hologram_decoys.size() - 1, -1, -1):
		var decoy: BattleUnit = units.get(hologram_decoys[index])
		if decoy == null:
			hologram_decoys.remove_at(index)
			continue
		var owner: BattleUnit = units.get(int(decoy.special.owner_id))
		if not decoy.alive() or clock >= float(decoy.special.until):
			if owner != null:
				_apply_cc(owner, {"fx": "confuse", "dur": decoy.special.blind_duration}, decoy.position, float(decoy.special.blind_radius))
			events.append({"type": "flashbang_detonate", "actor": decoy.entity_id, "position": decoy.position, "radius": decoy.special.blind_radius, "duration": decoy.special.blind_duration})
			_remove_field_unit(decoy.entity_id)
			hologram_decoys.remove_at(index)
			continue
		decoy.special.cd = maxf(0, float(decoy.special.cd) - delta)
		var target := _auto_target(decoy, owner)
		if target != null and owner != null and owner.alive():
			var weapon := weapon_definition(owner.character, "light", owner.combat_level("light"))
			var distance := _planar_distance(decoy.position, target.position)
			if distance <= float(decoy.special.range):
				_face_companion(decoy, target.position)
				if decoy.special.cd == 0:
					decoy.special.cd = 1.0 / (float(decoy.special.rate) * weather_attack_rate(decoy))
					var amount: float = weapon.dmg * _weapon_multiplier(owner, target, weapon) * CombatMath.damage_falloff(weapon, distance) * 0.3
					damage(decoy, target, weapon, amount, false, {"origin": decoy.position}, false)
					_companion_shot(decoy, target, weapon)
			else:
				_move_companion(decoy, target.position, minf(decoy.speed * delta, distance - float(decoy.special.range) * 0.85), false)
				_face_companion(decoy, target.position)
			continue
		if owner != null and owner.alive():
			var point := owner.position + Vector3(decoy.special.offset.x, 0, decoy.special.offset.y)
			var distance := _planar_distance(decoy.position, point)
			if distance > 4:
				_move_companion(decoy, point, minf(decoy.speed * delta, distance), false)
				_face_companion(decoy, point)
		else:
			var forward := Vector3(-sin(decoy.yaw), 0, -cos(decoy.yaw))
			_move_companion(decoy, decoy.position + forward, decoy.speed * delta, false)

func _move_companion(unit: BattleUnit, point: Vector3, distance: float, solid: bool = true) -> void:
	var offset := Vector2(point.x - unit.position.x, point.z - unit.position.z)
	if distance <= 0 or offset.is_zero_approx():
		return
	var displacement := offset.normalized() * distance
	var previous := unit.position
	var altitude := _missile_target_altitude(unit)
	if solid:
		_place_solid(unit, displacement)
	else:
		unit.position += Vector3(displacement.x, 0, displacement.y)
	var ground := world.ground_height(unit.position.x, unit.position.z)
	if not is_finite(ground):
		unit.position = previous
		return
	unit.position.y = ground + altitude
	if unit.special.get("role") == "summon":
		_face_companion(unit, point)

func _face_companion(unit: BattleUnit, point: Vector3) -> void:
	unit.yaw = atan2(-(point.x - unit.position.x), -(point.z - unit.position.z))
	unit.rotation.y = unit.yaw

func _companion_shot(unit: BattleUnit, target: BattleUnit, weapon: Dictionary) -> void:
	var shot := {"type": "shot", "actor": unit.entity_id, "kind": unit.kind, "start": unit.position, "end": _npc_shot_point(target, false), "side": unit.side,
		"weapon_type": weapon.get("type", ""), "companion": true}
	if unit.special.has("wid"):
		shot.wid = unit.special.wid
	if unit.body_presentation != null:
		_emit_body_event(shot)
	else:
		events.append(shot)

func _spawn_fog(unit: BattleUnit, definition: Dictionary, center: Vector3) -> void:
	var duration: float = definition.dur if definition.dur else 8.0
	var radius: float = definition.r if definition.r else 35.0
	fogs.append({"id": next_field_id, "center": Vector2(center.x, center.z), "radius": radius,
		"duration": duration, "start": clock, "until": clock + duration, "side": unit.side,
		"owner": unit.entity_id, "add": definition.add.duplicate(true) if definition.add is Dictionary else {}})
	next_field_id += 1
	events.append({"type": "fog_spawn", "actor": unit.entity_id, "position": center, "radius": radius, "duration": duration, "side": unit.side})

func _spawn_cubic_slabs(unit: BattleUnit, definition: Dictionary, center: Vector3, fraction: float) -> void:
	var duration: float = definition.dur if definition.dur else 5.0
	var hp := floorf((float(definition.hp) if definition.hp else 350.0) * fraction + 0.5)
	var members: Array = []
	for index in range(6):
		var angle := index * PI / 3
		var point := center + Vector3(cos(angle) * 5.5, 0, -sin(angle) * 5.5)
		point.y = world.ground_height(point.x, point.z)
		var slab := spawn({"kind": "slab", "side": unit.side, "position": point, "effect_radius": 1.75,
			"yaw": -angle, "special": {"role": "slab", "hp": hp, "angle": angle, "height": 6.0, "until": clock + duration}})
		members.append(slab.entity_id)
	cubic_cages.append({"center": Vector2(center.x, center.z), "radius": 5.5, "until": clock + duration,
		"duration": duration, "dps": (float(definition.dmg) if definition.dmg else 50.0) * fraction,
		"owner": unit.entity_id, "members": members})
	events.append({"type": "cube_spawn", "actor": unit.entity_id, "position": center, "radius": 5.5, "duration": duration, "side": unit.side})

func _publish_blast_event(event: Dictionary) -> void:
	if not authoritative:
		return
	if event.type in ["boom", "missile_blast", "missile_intercept", "missile_deflect"]:
		var point: Vector3 = event.position
		event.audio_height = point.y - world.ground_height(point.x, point.z)
	blast_event_serial += 1
	event.blast_serial = blast_event_serial
	events.append(event)
	pending_blast_feedback.append(event.duplicate(true))

func _blast_requests(event: Dictionary) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	if world == null:
		return requests
	if event.type == "die" and not DeathPresentation.has_effects(event.kind):
		return requests
	var ground := _npc_presentation_ground(event.position)
	if not is_finite(ground):
		push_error("Blast feedback requires a verified source terrain height")
		return requests
	if event.type == "die":
		for command: Dictionary in DeathPresentation.commands(event.kind, event.get("side", ""), event.position, ground):
			if command.type == "blast":
				requests.append({"point": command.point, "radius": float(command.radius)})
	else:
		requests.append({"point": BlastFeedback.point(event, ground), "radius": float(event.radius)})
	return requests

func _settle_blast_feedback(point: Vector3, radius: float, serial: int, only_peer: int = 0) -> Array[BattleUnit]:
	var changed: Array[BattleUnit] = []
	if not authoritative or not point.is_finite() or not is_finite(radius):
		return changed
	for pilot: BattleUnit in pilots.values():
		if pilot.peer_id <= 0 or pilot.is_bot or not pilot.is_pilot():
			continue
		if only_peer != 0 and pilot.peer_id != only_peer:
			continue
		if pilot.camera == null or not pilot.alive() or pilot.side.is_empty():
			continue
		var eye := camera_origin(pilot)
		if not eye.is_finite():
			push_error("Blast feedback requires a finite authority camera")
			continue
		var response := BlastFeedback.reaction(point, radius, pilot.position, eye, pilot.height, pilot.yaw, pilot.flying, pilot.recoil.trauma)
		var impulse: Vector3 = response.velocity
		if pilot.flying:
			pilot.velocity += impulse
		else:
			# Source ground vel.y is discarded; vy receives its separate lift account.
			pilot.impulse_velocity += Vector2(impulse.x, impulse.z)
			pilot.velocity += Vector3(impulse.x, float(response.lift), impulse.z)
		if float(response.trauma) != pilot.recoil.trauma:
			changed.append(pilot)
		pilot.recoil.trauma = float(response.trauma)
		pilot.blast_applied_serial = maxi(pilot.blast_applied_serial, serial)
	return changed

func flush_blast_feedback() -> void:
	if not authoritative:
		return
	var queued := pending_blast_feedback
	pending_blast_feedback = []
	var changed: Dictionary = {}
	for event: Dictionary in queued:
		for request: Dictionary in _blast_requests(event):
			for pilot: BattleUnit in _settle_blast_feedback(request.point, float(request.radius), int(event.blast_serial)):
				changed[pilot.entity_id] = pilot
	# One fresh private shake sample after the whole published event batch.
	for pilot: BattleUnit in changed.values():
		pilot.recoil.advance(0, _recoil_next)

func _publish_local_blast(unit: BattleUnit, point: Vector3, radius: float) -> void:
	if not authoritative or not unit.is_pilot() or unit.is_bot or unit.peer_id <= 0 or unit.camera == null or pilots.get(unit.peer_id) != unit:
		return
	blast_event_serial += 1
	for pilot: BattleUnit in _settle_blast_feedback(point, radius, blast_event_serial, unit.peer_id):
		pilot.recoil.advance(0, _recoil_next)
	_emit_body_event({"type": "local_blast", "actor": unit.entity_id, "only_peer": unit.peer_id, "position": point,
		"radius": radius, "side": unit.side, "blast_serial": blast_event_serial,
		"feedback_recoil": unit.recoil.snapshot(), "clock": clock})

func apply_owner_recoil(state: Dictionary) -> bool:
	if authoritative:
		return false
	var pilot: BattleUnit = pilots.get(Session.player_id())
	if pilot == null:
		return false
	var serial := int(state.get("blast_serial", 0))
	if serial < pilot.blast_received_serial:
		return false
	pilot.blast_received_serial = serial
	pilot.recoil.apply_snapshot(state.get("recoil", {}))
	return true

func _report_death(unit: BattleUnit) -> void:
	death_event_serial += 1
	_publish_blast_event({"type": "die", "actor": unit.entity_id, "kind": unit.kind, "position": unit.position,
		"side": unit.side, "peer": unit.peer_id, "notice_peer": unit.special.get("owner_peer", unit.peer_id), "death_serial": death_event_serial})

func _retain_removed_body(unit: BattleUnit) -> void:
	if Session.dedicated or world == null or not victim_reports.has(unit.entity_id) or not RetiredBody.eligible(unit):
		return
	unit_view_removed.emit(unit.model)
	if footprint_glows != null and footprint_glows.active.has(unit.entity_id):
		footprint_glows._drop(unit.entity_id)
	if skill_glows != null and skill_glows.active.has(unit.entity_id):
		skill_glows._drop(unit.entity_id)
	if lock_glow != null and lock_glow.target_id == unit.entity_id:
		lock_glow.clear()
	retired_bodies[unit.entity_id] = RetiredBody.capture(unit, self)

func _present_retired_bodies(received: Array) -> void:
	var dead := {}
	for event: Dictionary in received:
		if event.get("type") in ["die", "moon_boom"]:
			dead[int(event.get("actor", 0))] = true
	var pending := retired_bodies
	retired_bodies = {}
	for id: int in pending:
		var view: RetiredBody = pending[id]
		if dead.has(id):
			if view.begin(world.ensure_combat_effects()):
				dissolve_ghosts.append(view)
		else:
			view.dispose()

func step_dissolve_ghosts(delta: float) -> void:
	if not is_finite(delta) or delta < 0:
		return
	for index in range(dissolve_ghosts.size() - 1, -1, -1):
		if not dissolve_ghosts[index].advance(delta):
			dissolve_ghosts.remove_at(index)

func _remove_field_unit(id: int, report: bool = false) -> void:
	var unit: BattleUnit = units.get(id)
	if unit == null:
		return
	if report:
		_report_death(unit)
	_retain_removed_body(unit)
	unit.hp = 0
	unit.visible = false
	unit.collision_layer = 0
	unit.hit_area.collision_layer = 0
	units.erase(id)
	unit.queue_free()

func _tick_cubic_slabs(delta: float) -> void:
	for index in range(cubic_cages.size() - 1, -1, -1):
		var cage: Dictionary = cubic_cages[index]
		var remaining: Array = cage.members.filter(func(id): return units.has(id) and units[id].alive())
		if clock >= float(cage.until) or remaining.is_empty():
			for id in cage.members:
				_remove_field_unit(int(id))
			cubic_cages.remove_at(index)
			continue
		var owner: BattleUnit = units.get(int(cage.owner))
		if owner == null:
			continue
		var center: Vector2 = cage.center
		for target: BattleUnit in units.values():
			if target.side == owner.side or not target.alive() or center.distance_to(Vector2(target.position.x, target.position.z)) > float(cage.radius):
				continue
			damage(owner, target, {"pen": 12}, float(cage.dps) * delta, false, {"weather_weapon": false}, false)

func _tick_fogs(delta: float) -> void:
	for index in range(fogs.size() - 1, -1, -1):
		var fog: Dictionary = fogs[index]
		if clock >= float(fog.until):
			fogs.remove_at(index)
			continue
		var owner: BattleUnit = units.get(int(fog.owner))
		var added: Dictionary = fog.add
		if owner == null or added.get("fx") != "bleed":
			continue
		var center: Vector2 = fog.center
		for target: BattleUnit in units.values():
			if target.side == fog.side or not target.alive():
				continue
			var radius: float = float(fog.radius) + (target.effect_radius if target.effect_radius else 1.0)
			if center.distance_to(Vector2(target.position.x, target.position.z)) > radius:
				continue
			var dps: float = added.get("dps", 12)
			var pen: float = added.get("pen", 8)
			damage(owner, target, {"pen": pen if pen else 8}, (dps if dps else 12) * delta, false, {"weather_weapon": false}, false)
			_apply_hit_elements(owner, {"elem": "poison", "elemBuildup": 20 * delta}, target)

func _slab_records() -> Array:
	var records: Array = []
	for cage: Dictionary in cubic_cages:
		for id in cage.members:
			var slab: BattleUnit = units.get(int(id))
			if slab == null or not slab.alive():
				continue
			records.append({"center": Vector2(slab.position.x, slab.position.z), "angle": slab.special.angle,
				"hp": slab.hp, "height": slab.special.height})
	return records

func _relative_origin(unit: BattleUnit) -> Vector3:
	return Vector3(unit.position.x, _missile_target_altitude(unit) + (Content.constants.LOS.TOWER_EYE_M if unit.kind == "tower" else Content.constants.LOS.EYE_M), unit.position.z)

func _relative_target(unit: BattleUnit) -> Vector3:
	var height: float = Content.constants.LOS.TOWER_EYE_M if unit.kind in ["tower", "base"] else Content.constants.LOS.TGT_M
	return Vector3(unit.position.x, _body_altitude(unit) + height, unit.position.z)

func _skill_barriers_blocked(start: Vector3, end: Vector3) -> bool:
	return is_finite(AbilityFieldRules.slab_hit(start, end, _slab_records()))

func _fog_snapshot() -> Array:
	var states: Array = []
	for fog: Dictionary in fogs:
		states.append({"id": fog.id, "center": fog.center, "radius": fog.radius, "start": fog.start,
			"until": fog.until, "duration": fog.duration, "side": fog.side})
	return states

func _tick_heal_auras(delta: float) -> void:
	if not authoritative:
		return
	for unit: BattleUnit in pilots.values():
		if not unit.heal_aura.is_empty():
			if not unit.alive() or float(unit.heal_aura.until) <= clock:
				events.append({"type": "heal_aura_end", "actor": unit.entity_id, "peer": unit.peer_id, "side": unit.side})
				unit.heal_aura.clear()
				continue
			var aura := unit.heal_aura
			# Source visits hero representatives and the entity roster separately.
			for ally: BattleUnit in pilots.values() + units.values():
				if ally.side != aura.side or ally.side.is_empty() or ally.special.get("neutral", false) or ally.hp <= 0 or not ally.alive() \
						or Vector2(ally.position.x - unit.position.x, ally.position.z - unit.position.z).length() > float(aura.radius) + ally.effect_radius:
					continue
				if float(aura.hps) > 0:
					_heal_body(ally, float(aura.hps) * delta, "aura")
				if float(aura.sp_hps) > 0 and ally.shield < ally.max_shield:
					ally.shield = minf(ally.max_shield, ally.shield + float(aura.sp_hps) * delta)
				if aura.cleanse and ally.is_hero():
					_cleanse(ally)

func _tick_ability_states(delta: float) -> void:
	# Aggregate ability seam retained for isolated source-component consumers.
	_tick_actor_status(delta)
	_tick_casts(delta)
	_tick_carriers(delta)
	_tick_persistent_abilities(delta)

func _tick_actor_status(delta: float) -> void:
	for unit: BattleUnit in units.values():
		unit.buffs = unit.buffs.filter(func(buff): return float(buff.until) > clock)
		if not unit.alive():
			unit.cast_state.clear()
			unit.cast_preview.clear()
			unit.bleed.clear()
			unit.status.erase("phase_until")
	for unit: BattleUnit in pilots.values():
		if unit.alive():
			_tick_shield_bash(unit, delta)
	for unit: BattleUnit in units.values():
		if not unit.bleed.is_empty():
			if float(unit.bleed.until) <= clock:
				unit.bleed.clear()
			else:
				var attacker: BattleUnit = pilots.get(int(unit.bleed.get("peer", 0)), units.get(int(unit.bleed.get("actor", 0))))
				damage(attacker, unit, {"pen": unit.bleed.pen}, float(unit.bleed.dps) * delta, false, {"weather_weapon": false}, false)

func _tick_casts(_delta: float) -> void:
	for unit: BattleUnit in pilots.values():
		if unit.alive() and not unit.cast_state.is_empty() and clock >= float(unit.cast_state.start) + float(unit.cast_state.duration):
			var state := unit.cast_state.duplicate(true)
			unit.cast_state.clear()
			_cast_effect(unit, state.definition, state.point)
			events.append({"type": "cast", "actor": unit.entity_id, "character": unit.character, "side": unit.side,
				"slot": "def", "fx": state.definition.fx, "fraction": 1.0, "point": state.point, "level": state.level,
				"radius": state.definition.r, "duration": state.definition.dur})

func _tick_persistent_abilities(delta: float) -> void:
	_tick_heal_auras(delta)
	_tick_clones(delta)
	_tick_cubic_slabs(delta)
	_tick_fogs(delta)
	_tick_summons(delta)
	_tick_phase_shift(delta)
	_tick_holograms(delta)
	_tick_element_states(delta)

func _tick_phase_shift(_delta: float) -> void:
	for unit: BattleUnit in pilots.values():
		if not unit.alive():
			unit.status.erase("phase_until")
			continue
		if unit.status.has("phase_until") and float(unit.status.phase_until) != 0 and clock >= float(unit.status.phase_until):
			unit.status.erase("phase_until")
			unit.status.phase_critical = true
			var amount: float = unit.status.get("phase_damage", 50)
			blast(unit, {"dmg": amount if amount else 50, "r": 6, "pen": 10}, Vector3(unit.position.x, 0, unit.position.z), false, true, 0)
			_apply_cc(unit, {"fx": "pull", "imp": -20}, unit.position, 6)
			events.append({"type": "phase_exit", "actor": unit.entity_id, "side": unit.side, "position": unit.position, "radius": 6.0})

func _tick_element_states(delta: float) -> void:
	for unit: BattleUnit in units.values():
		_tick_element_buildup(unit, delta)

func _prune_dead_creeps() -> void:
	for id in units.keys():
		var unit: BattleUnit = units[id]
		if unit.alive() or unit.is_hero() or not unit.special.is_empty() or unit.kind in ["base", "tower"]:
			continue
		if unit.path_follower != null:
			unit.path_follower.queue_free()
		_retain_removed_body(unit)
		unit.queue_free()
		units.erase(id)

func snapshot(peer: int = 0, recipient_side: Variant = null) -> Dictionary:
	# One immutable identity per queued notice, shared by every viewer publication.
	for event: Dictionary in events:
		if not event.has("notice_serial"):
			notice_event_serial += 1
			event.notice_serial = notice_event_serial
	var visible_units: Array = []
	var viewer: BattleUnit = pilots.get(peer)
	# Room allegiance selects vision; the existing pilot still owns its resources.
	var side := ""
	if recipient_side != null:
		side = str(recipient_side)
	elif viewer != null:
		side = viewer.side
	for unit: BattleUnit in units.values():
		if not side.is_empty() and not visible_to_side(unit, side):
			continue
		var state := ActorSnapshot.project(unit, viewer, clock)
		if unit.body_presentation != null:
			unit.presented_altitude = _missile_target_altitude(unit) if unit.is_hero() or unit.flying else 0.0
			# Original custom summon/hologram serialization omits y. Their private
			# flight/eye height is independent of the renderer's published lift.
			if not unit.is_hero() and unit.special.get("role") in ["summon", "hologram"] and unit.kind not in ["heli", "decoy", "kami", "hyper"]:
				unit.presented_altitude = 0.0
			state.hero_y = unit.presented_altitude
		visible_units.append(state)
	var visible_ids := {}
	for unit in visible_units:
		visible_ids[unit.id] = true
	var visible_events: Array = events.filter(func(event): return not event.has("only_peer") or int(event.only_peer) == peer)
	if not side.is_empty():
		visible_events = []
		for event: Dictionary in events:
			if event.has("only_peer"):
				if int(event.only_peer) == peer:
					visible_events.append(event)
			elif event.type in ["lightning_strike", "cast", "cast_start", "phase_start", "phase_exit",
					"decoy_beacon_spawn", "flashbang_detonate", "cube_spawn", "fog_spawn", "heal_aoe"]:
				# Source snapshotFor shares weather, cast and field reports even
				# when the referenced body is hidden or no longer in the snapshot.
				visible_events.append(event)
			elif event.type == "die" or str(event.type) in BlastFeedback.REPORT_TYPES:
				# Source death/explosion broadcasts survive entity removal and fog filtering.
				visible_events.append(event)
			elif event.type == "lock" and int(event.get("target_peer", 0)) == peer:
				visible_events.append(event)
			elif event.type in ["wave", "airfall", "airdrop", "relay", "siege", "siege_talk", "boss_segment", "boss_down"] or event.has("missile") or visible_ids.has(event.actor):
				visible_events.append(event)
	visible_events = visible_events.map(func(event):
		var owner: BattleUnit = units.get(int(event.get("actor", 0)))
		return ActorSnapshot.event(event, viewer != null and owner == viewer))
	return {"clock": clock, "body_time": presentation_time(), "vision_side": side, "wave": wave, "over": over, "winner": winner, "stats": match_stats.duplicate(true),
		"weather": {"vector": weather_vector.duplicate(true), "dynamics": weather_dynamics.duplicate(true), "surface": weather_surface.duplicate(true),
			"seed": weather_seed, "schedule": weather_schedule.duplicate(true), "season": weather_start.get("season", "summer"), "hour": WeatherRules.clock_hour(weather_start.get("time", "day"), weather_elapsed, weather_schedule)},
		"creep_upgrades": creep_upgrades.duplicate(true), "siege": {"enabled": siege, "defender": defending_side, "open": siege_open.duplicate()},
		"fires": fire_fields.duplicate(true), "weather_scars": weather_scars.duplicate(true),
		"loots": loots.duplicate(true),
		"mines": mines.duplicate(true),
		"airdrops": _airdrop_snapshot(),
		"fogs": _fog_snapshot(),
		"units": visible_units, "events": visible_events.duplicate(), "fire_control": _control_snapshot(viewer),
		"lock": _lock_snapshot(viewer), "reachability": _reachability_snapshot(viewer),
		"footprint": _footprint_snapshot(viewer), "skill_footprint": _skill_footprint_snapshot(viewer),
		"missiles": _missile_snapshot(), "weapon_pose": _weapon_pose_snapshot(viewer),
		"projectile_view": projectile_view(viewer),
		"view_velocity": viewer.velocity if viewer != null else Vector3.ZERO,
		"control_status": _owner_control_status(viewer) if viewer != null else {},
		"status_icons": ActorSnapshot.status_icon_details(viewer, clock) if viewer != null else {},
		"movement_feedback": {"slope_blocked": viewer.slope_blocked if viewer != null and viewer.alive() and not over else false},
		"blast_serial": viewer.blast_applied_serial if viewer != null else 0,
		"recoil": viewer.recoil.snapshot() if viewer != null else {},
		"aim_control": {"on": viewer.input_state.get("aim", false), "request": viewer.aim_request} if viewer != null else {}}

func _weapon_pose_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or viewer.weapon_pose == null or not viewer.alive() or over:
		return {}
	var pose := viewer.weapon_pose
	if not is_finite(pose.clock):
		return {}
	return {"clock": pose.clock, "serial": pose.accepted_serial, "visual_serial": pose.weapons.last_serial, "slot": pose.slot, "form": pose.form,
		"gun": pose.gun, "kick": pose.kick, "view_mode": viewer.view_mode,
		"muzzle": _launch_pose(viewer, pose.slot, 0).origin if viewer.view_mode == "tps" else pose.current_muzzle(viewer.aim_transform())}

func _footprint_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or world == null or over or not viewer.alive() or not viewer.is_hero():
		return {}
	var slot: String = viewer.input_state.get("slot", "light")
	if slot not in ["light", "heavy"]:
		return {}
	var definition := weapon_definition(viewer.character, slot, viewer.combat_level(slot))
	if definition.get("needAim", false) and not viewer.input_state.get("aim", false):
		return {}
	var origin := _advisory_origin(viewer)
	var maximum := TargetingMath.maximum_range(definition)
	var ray: Dictionary
	if definition.area == "line":
		ray = _projectile_aim(viewer, maximum, true)
	else:
		ray = _projectile_aim(viewer, maximum)
	var targets: Array = []
	for target: BattleUnit in units.values():
		if target.side == viewer.side or not target.alive() or not visible_to_side(target, viewer.side):
			continue
		var dimensions := target.visual_dimensions()
		if dimensions.is_empty():
			continue
		var reach := _launch_range(viewer, definition, target)
		if not is_finite(reach):
			continue
		targets.append({"id": target.entity_id, "kind": target.kind, "position": target.position,
			"radius": target.radius, "height": dimensions.height, "top": dimensions.top, "reach": reach,
			"self": target == viewer, "ally": target.side == viewer.side, "foe": target.side != viewer.side,
			"visible": target.alive() and visible_to_side(target, viewer.side), "dead": not target.alive()})
	var control := {}
	if definition.trajectory == "lob":
		var cached: Dictionary = fire_controls.get(viewer.entity_id, {})
		if cached.is_empty():
			return {}
		if cached.clock != clock or cached.camera != viewer.aim_transform() or cached.direction != viewer.aim_direction() or float(cached.level) != viewer.combat_level("heavy"):
			return {}
		control = {"on": true, "ok": cached.ok, "close": cached.close, "has_impact": cached.arc.has_impact,
			"impact": cached.arc.impact, "aim": cached.aim}
	var footprint := ShotFootprintMath.evaluate(definition, origin, viewer.aim_direction(), targets,
		{"point": ray.point, "target": ray.target.entity_id if ray.target != null else 0}, control, _arc_collision)
	return {} if footprint.is_empty() else {"hits": footprint.hits, "warn": footprint.warn, "slot": slot, "side": viewer.side}

func apply_footprint(footprint: Dictionary, lock_state: Dictionary = {}) -> void:
	if footprint_glows == null:
		footprint_glows = FootprintGlows.new()
		add_child(footprint_glows)
	footprint_glows.apply(units, footprint, int(lock_state.get("anchor", 0)))

func _skill_footprint_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or over or not viewer.alive() or viewer.cast_preview.is_empty() or clock >= float(viewer.cast_preview.until):
		return {}
	var targets: Array = []
	for target: BattleUnit in units.values():
		targets.append({"id": target.entity_id, "side": target.side, "position": target.position, "radius": target.radius,
			"visible": visible_to_side(target, viewer.side), "dead": not target.alive(),
			"garrison": target.special.get("garrison", false), "neutral": target.special.get("neutral", false)})
	var hits := ShotFootprintMath.skill_victims(viewer.cast_preview.definition, viewer.cast_preview.point, targets, viewer.side)
	return {"hits": hits, "side": viewer.side, "warn": false}

func apply_skill_footprint(footprint: Dictionary) -> void:
	if skill_glows == null:
		skill_glows = FootprintGlows.new()
		skill_glows.skill_layer = true
		add_child(skill_glows)
	skill_glows.apply(units, footprint, 0)

func apply_lock_glow(lock_state: Dictionary) -> bool:
	if lock_glow == null:
		lock_glow = LockGlowPresentation.new()
		add_child(lock_glow)
	return lock_glow.apply(units, lock_state)

func _reachability_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or world == null or over or not viewer.alive() or not viewer.is_hero():
		return {}
	var slot: String = viewer.input_state.get("slot", "light")
	if slot not in ["light", "heavy"]:
		return {}
	var level := viewer.combat_level(slot)
	var definition := weapon_definition(viewer.character, slot, level)
	# Source fan/line footprints have no single-target entrance gate.
	if definition.area in ["fan", "line"]:
		return {}
	var maximum := TargetingMath.maximum_range(definition)
	# Flat rounds and frozen laser points do not steer toward cone candidates.
	var target: BattleUnit
	if definition.trajectory in ["flat", "guide"]:
		target = _projectile_aim(viewer, maximum).target
	else:
		target = _aim_target(viewer, maximum)
	if target == null or not target.alive() or target.side == viewer.side or not visible_to_side(target, viewer.side):
		return {}
	var reach := _launch_range(viewer, definition, target)
	if not is_finite(reach):
		return {}
	var dimensions := target.visual_dimensions()
	if dimensions.is_empty():
		return {}
	var advice := ReachabilityMath.evaluate(definition, _advisory_origin(viewer),
		{"position": target.position, "kind": target.kind, "height": dimensions.height, "top": dimensions.top,
			"radius": target.radius}, reach, _arc_collision)
	return {"target": target.entity_id, "slot": slot, "ok": advice.ok, "warn": advice.warn}

func _missile_snapshot() -> Array:
	var states: Array = []
	for state: Dictionary in missiles:
		states.append({"id": state.id, "position": MissileMotion.snapshot_position(state), "hp": ceilf(state.hp), "max_hp": state.max_hp})
	return states

func _lock_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or over or not viewer.alive() or clock - viewer.lock_at > Content.constants.LOCK.TTL:
		return {}
	var target: BattleUnit = units.get(viewer.lock_target)
	if target == null or not target.alive() or target.side == viewer.side or not visible_to_side(target, viewer.side):
		return {}
	return {"target": target.entity_id, "confirmed_at": viewer.lock_at, "anchor": viewer.aim_anchor}

func _control_snapshot(viewer: BattleUnit) -> Dictionary:
	if viewer == null or over or not viewer.alive() or not viewer.input_state.get("aim", false) or viewer.input_state.get("slot", "light") != "heavy":
		return {}
	var control: Dictionary = fire_controls.get(viewer.entity_id, {})
	if control.is_empty():
		return {}
	return {"points": control.arc.points, "origin": control.origin, "impact": control.arc.impact, "has_impact": control.arc.has_impact,
		"ok": control.ok, "aa": control.aa, "high": control.high, "close": control.close, "side": viewer.side,
		"elevation": CockpitPose.barrel_elevation(control.velocity, control.direction)}

# Returns false for a snapshot that must not reach any presentation consumer.
func apply_snapshot(data: Dictionary) -> bool:
	var serial := int(data.get("_serial", snapshot_serial + 1))
	if authoritative or data.clock < clock or serial <= snapshot_serial:
		return false
	snapshot_serial = serial
	clock = data.clock
	if is_nan(body_clock_offset) and data.get("body_time") is float and is_finite(float(data.body_time)):
		# Align once per room; snapshot jitter cannot rewind the local animation clock.
		body_clock_offset = float(data.body_time) - BodyPresentation.time_now()
	match_stats = data.get("stats", match_stats).duplicate(true)
	var stages: Dictionary = data.get("siege", {})
	if not stages.is_empty():
		siege = bool(stages.enabled)
		defending_side = String(stages.defender)
		siege_open = stages.open.duplicate()
	loots.clear()
	for loot: Dictionary in data.get("loots", []):
		loots.append(loot.duplicate(true))
	mines.clear()
	for mine: Dictionary in data.get("mines", []):
		mines.append(mine.duplicate())
	fire_fields.clear()
	for fire: Dictionary in data.get("fires", []):
		fire_fields.append(fire.duplicate(true))
	weather_scars.clear()
	for scar: Dictionary in data.get("weather_scars", []):
		weather_scars.append(scar.duplicate(true))
	var weather: Dictionary = data.get("weather", {})
	if not weather.is_empty():
		weather_vector = weather.vector.duplicate(true)
		weather_dynamics = weather.dynamics.duplicate(true)
		weather_surface = weather.surface.duplicate(true)
		weather_fog = weather_dynamics.fog
		weather_schedule = weather.schedule.duplicate(true)
		weather_seed = int(weather.seed)
		world.sync_weather(weather_dynamics, weather_surface, float(weather.hour), weather_schedule, weather.season, weather_seed)
	world.sync_fires(fire_fields, clock, weather_dynamics)
	world.sync_loots(loots, clock)
	world.sync_mines(mines)
	world.sync_airdrops(data.get("airdrops", []), clock)
	creep_upgrades = data.get("creep_upgrades", creep_upgrades).duplicate(true)
	fog_view = data.get("fogs", []).duplicate(true)
	var received_missiles: Array[Dictionary] = []
	for state: Dictionary in data.get("missiles", []):
		received_missiles.append(state)
	var received_ids: Array = received_missiles.map(func(state): return int(state.id))
	for id: int in missile_bodies.keys():
		if not received_ids.has(id):
			_remove_missile(id)
	missiles = received_missiles
	_sync_missile_bodies()
	wave = int(data.wave)
	var seen := {}
	for state in data.units:
		var id: int = int(state.id)
		seen[id] = true
		var fresh := not units.has(id)
		var unit: BattleUnit = spawn(state, true) if fresh else units[id]
		present_victim_snapshot(unit, state)
		unit.apply_snapshot(state, fresh)
		if unit.body_presentation != null:
			unit.body_presentation.capture_snapshot(state, float(data.clock))
			_prime_body_view(unit)
		if fresh and unit.kind == "bunker":
			world.clear_camp_columns([{"x": state.position.x, "z": state.position.z}])
		if unit.is_pilot():
			pilots[unit.peer_id] = unit
	for id in units.keys():
		if seen.has(id):
			continue
		var removed: BattleUnit = units[id]
		if removed.is_pilot():
			pilots.erase(removed.peer_id)
		_retain_removed_body(removed)
		victim_reports.erase(id)
		removed.queue_free()
		units.erase(id)
	view_snapshot_ready.emit(data)
	_present_retired_bodies(data.get("events", []))
	pending_missile_view = data.get("missiles", []).duplicate(true)
	missile_view_pending = true
	receive_body_events(data.events, presentation_time())
	present_world_events(data.events)
	if data.over and not over:
		over = true
		winner = data.winner
		result.emit(winner)
	return true

func present_world_events(received: Array) -> void:
	if Session.dedicated or world == null:
		return
	for event: Dictionary in received:
		if event.type == "die":
			present_death(event)
		if event.type == "screen_hurt":
			screen_hurt.emit(event)
		if event.type == "lightning_strike":
			world.present_lightning(event.points)
		if event.type == "shot":
			present_shot(event)
		if event.type == "projectile_terminal":
			present_projectile_terminal(event)
		if event.type == "plasma":
			present_plasma(event)
		if str(event.type) in BlastFeedback.REPORT_TYPES or event.type == "local_blast":
			present_blast(event)
	if missile_view_pending:
		var states := pending_missile_view
		pending_missile_view = []
		missile_view_pending = false
		sync_missile_presentations(states, received)

func present_blast(event: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	var local: bool = event.type == "local_blast"
	if local and int(event.only_peer) != Session.player_id():
		return
	var stream := "local" if local else "global"
	var serial := int(event.get("blast_serial", -1))
	if serial <= int(presented_blast_serials.get(stream, -1)):
		return
	presented_blast_serials[stream] = serial
	if local and not authoritative:
		var pilot: BattleUnit = pilots.get(Session.player_id())
		if pilot != null and serial > pilot.blast_received_serial:
			pilot.blast_received_serial = serial
			pilot.recoil.apply_snapshot(event.feedback_recoil)
	var ground := _npc_presentation_ground(event.position)
	if not is_finite(ground):
		push_error("Explosion presentation requires a verified source terrain height")
		return
	var point := BlastFeedback.point(event, ground)
	var effects := world.ensure_combat_effects()
	if local:
		effects.explosion(point, float(event.radius) * .8, 0xffaa33)
	else:
		effects.blast_burst(point, ground, float(event.radius), bool(event.get("kami", false)), BlastFeedback.sam(event))

func present_death(event: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	var serial := int(event.get("death_serial", -1))
	if serial <= presented_death_serial:
		return
	presented_death_serial = serial
	death_presented.emit(event)
	if not DeathPresentation.has_effects(event.kind):
		return
	var ground := _npc_presentation_ground(event.position)
	if not is_finite(ground):
		push_error("Death presentation requires a verified source terrain height")
		return
	world.ensure_combat_effects().death(event, ground)

func present_shot(event: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	var owner: BattleUnit = units.get(int(event.actor))
	var origin: Vector3 = event.start
	if event.get("physical", false):
		return
	if event.get("hero_report", false):
		owner = _hero_representative(int(event.actor), int(event.get("shooter_peer", 0)))
		var is_self := int(event.get("shooter_peer", owner.peer_id if owner != null else 0)) == Session.player_id()
		if is_self and (owner == null or not owner.is_pilot()):
			return
		if owner != null and not owner.is_hero():
			return
		var serial := int(event.body_serial)
		if serial <= int(hero_report_serials.get(int(event.actor), -1)):
			return
		hero_report_serials[int(event.actor)] = serial
		if owner == null:
			var plan := RemoteShotState.plan({}, event.slot, origin, event.end, bool(event.get("hit", false)), bool(event.get("bot_report", false)), world.clip_shot)
			world.ensure_combat_effects().shot(origin, plan.target, event.slot == "heavy", event.side, plan.impact)
			return
		if not is_self:
			_present_remote_shot(owner, event)
			return
		if event.get("remote_only", false):
			if event.slot == "heavy":
				world.ensure_combat_effects().muzzle(origin, true, event.side)
			return
	if owner != null and owner.body_presentation != null and event.has("body_serial") and not event.get("hero_report", false):
		var serial := int(event.body_serial)
		if serial <= owner.body_presentation.presented_shot:
			return
		owner.body_presentation.presented_shot = serial
		origin = owner.body_presentation.npc_origin(int(event.body_serial), origin)
		if not event.has("slot"):
			var report := NpcShotMotion.report_style(event, owner.kind)
			var kind: String = report.kind
			var style: Dictionary = report.style
			var velocity: Variant = null
			var flight := 0.0
			var gravity := 0.0
			if style.mode == "shell":
				var arc := NpcShotMotion.artillery(origin, event.end)
				velocity = arc.velocity
				flight = arc.flight
				gravity = float(Content.constants.BALLISTIC.G)
				NpcShotMotion.aim(owner.body, owner.body_presentation.entity, arc.angle, presentation_time())
			world.ensure_combat_effects().npc(origin, event.end, kind, report.wid, event.side, world.clip_shot, velocity, gravity, flight)
			return
	# Base launch visuals follow the authoritative missile stream.
	if event.get("kind") == "base" or owner != null and owner.kind == "base":
		return
	if owner != null and owner.is_pilot() and not event.get("physical", false) and event.get("area") in ["fan", "line"]:
		var definition := _hero_effect_definition(owner, event)
		origin = _hero_effect_origin(owner, event.slot, origin, int(event.get("shot_serial", -1)))
		var effects := world.ensure_combat_effects()
		if event.area == "fan":
			effects.fan_blast(origin, event.direction, definition, float(event.range), event.side,
				Content.heroes[owner.character].get("visual", {}).get("hue"), world.clip_shot)
		else:
			var target: Vector3 = event.end if owner.peer_id == Session.player_id() else world.clip_shot(origin, event.end).to
			_present_hero_lance(owner, definition, event.side, origin, target, true)
		return
	if owner != null and owner.is_pilot() and owner.peer_id == Session.player_id():
		if event.get("physical", false):
			return
		if event.get("slot") == "light" and event.get("area") == null and event.get("weapon_type") in ["beam", "rail"]:
			world.ensure_projectile_visuals().tracer(event.start, event.end, _fpv_tracer_color(event.weapon_type, event.side))
			var effects := world.ensure_combat_effects()
			effects.muzzle(event.start, false, event.side)
			if event.get("hit", false):
				effects.spark(event.end, 2.2, int(_fpv_tracer_color(event.weapon_type, event.side).to_rgba32() >> 8))
			return
	world.tracer(origin, event.end, event.side)

func present_plasma(event: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	var owner := _hero_representative(int(event.actor), int(event.get("shooter_peer", 0)))
	if owner != null and not owner.is_hero():
		return
	if int(event.get("shooter_peer", owner.peer_id if owner != null else 0)) == Session.player_id():
		return
	if event.has("body_serial"):
		var serial := int(event.body_serial)
		if serial <= int(hero_report_serials.get(int(event.actor), -1)):
			return
		hero_report_serials[int(event.actor)] = serial
	if owner != null:
		owner.remote_burst_driven = true
	var definition := _hero_effect_definition(owner, event) if owner != null else {}
	var origin: Vector3 = _hero_effect_origin(owner, event.slot, event.start) if owner != null else event.start
	var hue: Variant = Content.heroes[owner.character].get("visual", {}).get("hue") if owner != null else null
	world.ensure_combat_effects().remote_plasma(origin, SourceQuaternion.vector_normalized(event.direction), definition,
		float(event.radius), float(event.get("arc", 15)), event.slot, event.side,
		hue, bool(event.get("bar", false)), world.clip_shot)
	if owner != null:
		_remote_fire_pose(owner, event.slot, null, presentation_time(), false)

func present_projectile_terminal(event: Dictionary) -> void:
	if Session.dedicated or world == null:
		return
	var owner: BattleUnit = units.get(int(event.actor))
	if owner == null or not owner.is_pilot() or owner.peer_id != Session.player_id():
		return
	var serial := int(event.body_serial)
	if serial <= int(terminal_event_serials.get(owner.entity_id, -1)):
		return
	terminal_event_serials[owner.entity_id] = serial
	if not str(event.get("visual_id", "")).is_empty():
		world.ensure_projectile_visuals().retire_round(event.visual_id, float(event.clock))
	_present_hero_lance(owner, _hero_effect_definition(owner, event), event.side, event.start, event.end, false)

func _present_hero_lance(owner: BattleUnit, definition: Dictionary, side: String, origin: Vector3, target: Vector3, muzzle: bool) -> void:
	var effects := world.ensure_combat_effects()
	var hue: Variant = Content.heroes[owner.character].get("visual", {}).get("hue")
	effects.lance_visual(origin, target, definition, side, hue)
	if muzzle:
		effects.muzzle(origin, true, side)

func _hero_effect_definition(owner: BattleUnit, event: Dictionary) -> Dictionary:
	var slot: String = event.get("slot", "heavy")
	var is_self := owner.peer_id == Session.player_id()
	return client_weapon_definition(owner, slot) if is_self else client_weapons.other_weapon(owner.character, slot)

func _hero_effect_origin(owner: BattleUnit, slot: String, fallback: Vector3, serial: int = -1) -> Vector3:
	if owner.peer_id == Session.player_id():
		return fallback
	var candidates: Array = []
	for candidate: BattleUnit in _hero_group(owner):
		var point := candidate.body.next_muzzle(slot)
		if serial >= 0 and candidate.body_presentation != null:
			point = candidate.body_presentation.hero_origin(serial, point)
		candidates.append({"position": candidate.body.global_position, "muzzle": point if point.is_finite() else null})
	return RemoteShotState.muzzle(candidates, fallback)

func _hero_group(owner: BattleUnit) -> Array[BattleUnit]:
	var group: Array[BattleUnit] = []
	for candidate: BattleUnit in units.values():
		if candidate != owner and (owner.peer_id == 0 or candidate.peer_id != owner.peer_id or not candidate.is_hero()):
			continue
		if candidate.body == null or not candidate.presentation_visible or candidate.body_presentation == null or candidate.body_presentation.report.is_empty():
			continue
		group.append(candidate)
	return group

func _hero_representative(id: int, peer: int = 0) -> BattleUnit:
	var owner: BattleUnit = units.get(id)
	if owner != null and owner.presentation_visible and (owner.body_presentation == null or not owner.body_presentation.report.is_empty() or (owner.is_pilot() and owner.peer_id == Session.player_id())):
		return owner
	if peer == 0 and owner != null:
		peer = owner.peer_id
	if peer == 0:
		return null
	for candidate: BattleUnit in units.values():
		if candidate.special.get("role") == "clone" and candidate.peer_id == peer and candidate.presentation_visible:
			if candidate.body_presentation == null or not candidate.body_presentation.report.is_empty():
				return candidate
	return null

func _fire_squad_clones(owner: BattleUnit, slot: String, serial: int, now: float) -> void:
	if serial >= 0:
		hero_pose_serials[owner.entity_id] = maxi(int(hero_pose_serials.get(owner.entity_id, -1)), serial)
	for candidate: BattleUnit in _hero_group(owner):
		if candidate == owner:
			continue
		if serial >= 0:
			candidate.body_presentation.cache_hero_port(serial, slot, now)
		candidate.body_presentation.fire_local(slot, now)

func _remote_fire_pose(owner: BattleUnit, slot: String, target: Variant, now: float, prepared: bool) -> void:
	for candidate: BattleUnit in _hero_group(owner):
		if not prepared:
			candidate.body_presentation.fire_local(slot, now)
		if target is Vector3:
			candidate.body_presentation.entity._aimAt = {"x": target.x, "y": target.y, "z": target.z,
				"until": now + float(Content.balance.bodyRules.presentation.aimHold)}

func _present_remote_shot(owner: BattleUnit, event: Dictionary) -> void:
	var definition := client_weapons.other_weapon(owner.character, event.slot)
	var now := presentation_time()
	owner.remote_burst_driven = true
	var prepared: bool = not event.get("bot_report", false) and int(hero_pose_serials.get(int(event.actor), -1)) >= int(event.get("shot_serial", 0))
	var origin := _hero_effect_origin(owner, event.slot, event.start, int(event.get("shot_serial", -1)))
	if event.get("area") == "fan" and not event.get("remote_only", false):
		world.ensure_combat_effects().remote_plasma(origin, SourceQuaternion.vector_normalized(event.direction), definition,
			float(event.range), float(definition.get("arc", 15)), event.slot, event.side,
			Content.heroes[owner.character].get("visual", {}).get("hue"), bool(event.get("bar", false)), world.clip_shot)
		_remote_fire_pose(owner, event.slot, null, now, prepared)
		return
	var plan := RemoteShotState.plan(definition, event.slot, origin, event.end,
		bool(event.get("hit", false)), bool(event.get("bot_report", false)), world.clip_shot)
	match plan.kind:
		"lance":
			_present_hero_lance(owner, definition, event.side, origin, plan.target, true)
		"shell":
			var ground := _npc_presentation_ground(plan.target) if definition.type == "launcher" else NAN
			var surface := world.visual_surface(origin) if definition.trajectory in ["guide", "fnf"] else NAN
			if definition.type == "launcher" and not is_finite(ground) or definition.trajectory in ["guide", "fnf"] and not is_finite(surface):
				push_error("Remote projectile presentation requires verified terrain/standing surfaces")
				return
			var state := VisualShellMotion.launch(definition, origin, plan.target, ground, surface, float(event.get("mv", NAN)))
			world.ensure_projectile_visuals().spawn_shell(state, "%s-%s-%s" % [owner.character, event.slot, event.side.to_lower()])
			world.ensure_combat_effects().muzzle(origin, true, event.side)
			if definition.type == "launcher":
				for candidate: BattleUnit in _hero_group(owner):
					RemoteShotState.aim_heavy(candidate.body, SourceQuaternion.vector_normalized(state.velocity))
		"shot":
			world.ensure_combat_effects().shot(origin, plan.target, event.slot == "heavy", event.side, plan.impact)
			remote_bursts.schedule(definition, now, {"actor": int(event.actor), "slot": event.slot,
				"side": event.side, "aim": event.end, "definition": definition, "shooter_peer": owner.peer_id})
	_remote_fire_pose(owner, event.slot, event.end, now, prepared)

func step_remote_shots(now: float) -> void:
	if Session.dedicated or world == null:
		return
	for callback: Dictionary in remote_bursts.take_due(now):
		var payload: Dictionary = callback.payload
		var owner := _hero_representative(int(payload.actor), int(payload.get("shooter_peer", 0)))
		var origin: Vector3 = _hero_effect_origin(owner, payload.slot, payload.aim) if owner != null else payload.aim
		var plan := RemoteShotState.echo(payload.definition, origin, payload.aim, world.clip_shot)
		world.ensure_combat_effects().shot(origin, plan.target, payload.slot == "heavy", payload.side, plan.impact)
		if owner != null:
			_remote_fire_pose(owner, payload.slot, payload.aim, now, false)

func _fpv_tracer_color(type: String, side: String) -> Color:
	var style: Dictionary = Content.balance.projectileVisual
	var hex: int = style.beamColors[side] if type == "beam" else style.colors[side].col
	return Color.hex((hex << 8) | 0xff)
