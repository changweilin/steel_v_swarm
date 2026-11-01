extends Node

const MuzzleTests = preload("res://tests/muzzle_suite.gd")
const CameraTests = preload("res://tests/camera_suite.gd")
const BurstTests = preload("res://tests/burst_suite.gd")
const ProjectileVisualTests = preload("res://tests/projectile_visual_suite.gd")
const StatusTests = preload("res://tests/status_suite.gd")
const HealAuraTests = preload("res://tests/heal_aura_suite.gd")
const SimulationFrameTests = preload("res://tests/simulation_frame_suite.gd")
const DeathLifecycleTests = preload("res://tests/death_lifecycle_suite.gd")
const MovementTests = preload("res://tests/movement_suite.gd")
const TraversalTests = preload("res://tests/traversal_suite.gd")
const ClimbTests = preload("res://tests/climb_suite.gd")
const FieldTests = preload("res://tests/field_suite.gd")
const CompanionTests = preload("res://tests/companion_suite.gd")
const CarrierTests = preload("res://tests/carrier_suite.gd")
const CarrierControllerTests = preload("res://tests/carrier_controller_suite.gd")
const AbilityRouteTests = preload("res://tests/ability_route_suite.gd")
const NpcTests = preload("res://tests/npc_suite.gd")
const WaveTests = preload("res://tests/wave_suite.gd")
const WeatherTests = preload("res://tests/weather_suite.gd")
const EnvironmentTests = preload("res://tests/environment_suite.gd")
const TextureTests = preload("res://tests/texture_suite.gd")
const CelUniformTests = preload("res://tests/cel_uniform_suite.gd")
const TrainTests = preload("res://tests/train_suite.gd")
const SceneryMotionTests = preload("res://tests/scenery_motion_suite.gd")
const WildlifeTests = preload("res://tests/wildlife_suite.gd")
const WildlifeDensityTests = preload("res://tests/wildlife_density_suite.gd")
const PetalTests = preload("res://tests/petal_suite.gd")
const AquaticTests = preload("res://tests/aquatic_suite.gd")
const MarineTests = preload("res://tests/marine_suite.gd")
const VisualTests = preload("res://tests/visual_suite.gd")
const OutlineTests = preload("res://tests/outline_suite.gd")
const GeometryLodTests = preload("res://tests/geometry_lod_suite.gd")
const SceneryTests = preload("res://tests/scenery_suite.gd")
const SceneTests = preload("res://tests/scene_suite.gd")
const SupplyTests = preload("res://tests/supply_suite.gd")
const ThirdTests = preload("res://tests/third_suite.gd")
const MatchTests = preload("res://tests/match_suite.gd")
const CombatFeedTests = preload("res://tests/combat_feed_suite.gd")
const MissileDefenseTests = preload("res://tests/missile_defense_suite.gd")
const AimingPresentationTests = preload("res://tests/aiming_presentation_suite.gd")
const BotTests = preload("res://tests/bot_suite.gd")
const BossTests = preload("res://tests/boss_suite.gd")
const CampaignTests = preload("res://tests/campaign_suite.gd")
const SuperTests = preload("res://tests/super_suite.gd")
const ControlsTests = preload("res://tests/controls_suite.gd")
const MobileTests = preload("res://tests/mobile_suite.gd")
const ViewTests = preload("res://tests/view_suite.gd")
const PlayerViewTests = preload("res://tests/player_view_suite.gd")
const BodyTests = preload("res://tests/body_suite.gd")
const RoomTests = preload("res://tests/room_suite.gd")
const RoomLoadingTests = preload("res://tests/room_loading_suite.gd")
const RoomWorldResourceTests = preload("res://tests/room_world_resources_suite.gd")
const RoomWorldPrebuildTests = preload("res://tests/room_world_prebuild_suite.gd")
const RoomRosterTests = preload("res://tests/room_roster_suite.gd")
const RoomMemberTests = preload("res://tests/room_member_suite.gd")
const SpectatorTests = preload("res://tests/spectator_suite.gd")
const SnapshotTests = preload("res://tests/snapshot_suite.gd")
const SnapshotEventTests = preload("res://tests/snapshot_events_suite.gd")
const CastEventTests = preload("res://tests/cast_events_suite.gd")
const FieldEventTests = preload("res://tests/field_events_suite.gd")
const RoomAdmissionTests = preload("res://tests/room_admission_suite.gd")
const RoomRematchTests = preload("res://tests/room_rematch_suite.gd")
const RoomRecoveryTests = preload("res://tests/room_recovery_suite.gd")
const RoomMetadataTests = preload("res://tests/room_metadata_suite.gd")
const DeploymentTests = preload("res://tests/deployment_suite.gd")
const BalancePreferenceTests = preload("res://tests/balance_preference_suite.gd")
const AudioTests = preload("res://tests/audio_suite.gd")
const QuickRestartTests = preload("res://tests/quick_restart_suite.gd")
const FatalTests = preload("res://tests/fatal_suite.gd")
const PipTests = preload("res://tests/pip_suite.gd")
const HeadMarkTests = preload("res://tests/head_mark_suite.gd")
const VitalBarTests = preload("res://tests/vital_bar_suite.gd")
const MinimapTests = preload("res://tests/minimap_suite.gd")
const MinimapVisionTests = preload("res://tests/minimap_vision_suite.gd")
const MinimapMaskTests = preload("res://tests/minimap_mask_suite.gd")

class VisibilityUnit extends BattleUnit:
	# The original planar-vision oracle has dimensions and sight bands, but no
	# renderer or terrain. Model construction belongs to its separate fixtures.
	func _build_model() -> void:
		pass

var failures := 0
var failure_report: FileAccess
var failure_scope := "core"
var scope_failures := {}
const FAILURE_REPORT = "user://source-fixture-failures.jsonl"
const CONSOLE_FAILURES_PER_SCOPE = 12
var assertions := 0
var maximum_fan_error := 0.0
var maximum_projectile_error := 0.0
var maximum_lob_error := 0.0
var maximum_line_error := 0.0
var maximum_kinetic_error := 0.0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		var count := int(scope_failures.get(failure_scope, 0)) + 1
		scope_failures[failure_scope] = count
		if failure_report != null:
			failure_report.store_line(JSON.stringify({"scope": failure_scope, "assertion": assertions, "description": description}))
		if count <= CONSOLE_FAILURES_PER_SCOPE:
			push_error(description)
		elif count == CONSOLE_FAILURES_PER_SCOPE + 1:
			print("SOURCE_FAILURE_LOG_CONTINUES ", failure_scope, " report=", ProjectSettings.globalize_path(FAILURE_REPORT))

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.000001, description + " actual=" + str(actual) + " expected=" + str(expected))

func _ground_point(simulation: BattleSimulation, x: float, y: float, z: float) -> Vector3:
	# Source captures stub flat ground at y=0; rebase their heights onto the authored terrain.
	return Vector3(x, simulation.world.ground_height(x, z) + y, z)

func _missile_point(simulation: BattleSimulation, point: Vector3) -> Vector3:
	# Authority missiles keep the source frame: height above the local ground.
	return Vector3(point.x, point.y - simulation.world.ground_height(point.x, point.z), point.z)

func _require_prepared_match(simulation: BattleSimulation, label: String) -> bool:
	var ready := simulation.setup_complete and simulation.match_initialized
	_check(ready, label + ": authored match preparation required: " + simulation.setup_error)
	if not ready:
		simulation.free()
	return ready

func _run() -> void:
	failure_report = FileAccess.open(FAILURE_REPORT, FileAccess.WRITE)
	if failure_report == null:
		push_error("Cannot preserve the complete source-fixture failure report")
		get_tree().quit(1)
		return
	await get_tree().process_frame
	var selected: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-suite="):
			selected.append(argument.trim_prefix("--fixture-suite="))
	if not selected.is_empty():
		Content.read_json("res://data/fixtures.json", [])
		for path: String in selected:
			if not Content.fixture_registry.consumers.has(path) or not path.ends_with("_suite.gd"):
				_check(false, "Unknown registered source fixture suite: " + path)
				continue
			await _run_fixture_suite(load("res://" + path))
		_finish()
		return
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", Content.fixture_sections_for(get_script(), false))
	await _run_fixture_suite(RoomTests)
	await _run_fixture_suite(RoomMemberTests)
	await _run_fixture_suite(RoomAdmissionTests)
	await _run_fixture_suite(RoomRematchTests)
	await _run_fixture_suite(RoomRecoveryTests)
	await _run_fixture_suite(RoomMetadataTests)
	await _run_fixture_suite(DeploymentTests)
	await _run_fixture_suite(BalancePreferenceTests)
	await _run_fixture_suite(AudioTests)
	await _run_fixture_suite(QuickRestartTests)
	await _run_fixture_suite(FatalTests)
	await _run_fixture_suite(PipTests)
	await _run_fixture_suite(HeadMarkTests)
	await _run_fixture_suite(VitalBarTests)
	await _run_fixture_suite(MinimapTests)
	await _run_fixture_suite(MinimapVisionTests)
	await _run_fixture_suite(MinimapMaskTests)
	await _run_fixture_suite(SpectatorTests)
	await _run_fixture_suite(SnapshotTests)
	await _run_fixture_suite(SnapshotEventTests)
	await _run_fixture_suite(CastEventTests)
	await _run_fixture_suite(FieldEventTests)
	await _run_fixture_suite(RoomRosterTests)
	await _run_fixture_suite(RoomLoadingTests)
	await RoomWorldResourceTests.run(self)
	await RoomWorldPrebuildTests.run(self)
	for fixture in fixtures.volumes:
		var actor := BattleUnit.new()
		add_child(actor)
		actor.configure({"id":90001,"side":fixture.side,"kind":fixture.kind,"character":fixture.character,"position":Vector3.ZERO})
		var target: CylinderShape3D = actor.hit_area.get_child(0).shape
		_near(target.radius, fixture.radius, "Source target radius: " + fixture.kind)
		_near(target.height, fixture.height, "Source target height: " + fixture.kind)
		if not fixture.character.is_empty():
			_near(actor.camera.position.y, fixture.eye, "Source hero eye height")
			_near(actor.camera.position.z, -fixture.forward, "Source body-forward camera anchor")
			for mode in ["ground", "air"]:
				actor.flying = mode == "air"
				actor.refresh_collision()
				var movement: CylinderShape3D = actor.movement_shape.shape
				var spec: Dictionary = fixture[mode]
				_near(movement.radius, spec.r, "Source movement radius")
				_near(movement.height, spec.top - spec.bot, "Source movement vertical band")
				_near(actor.movement_shape.position.y, (spec.bot + spec.top) / 2, "Source movement band offset")
		actor.free()
	var rng := SourceRng.new(123456789)
	for value in fixtures.rng:
		_near(rng.next(), value, "Source RNG parity")
	for fixture in fixtures.shield:
		var split := CombatMath.shield_split(fixture.def, fixture.damage, fixture.shield)
		_near(split.toSp, fixture.result.toSp, "Shield budget parity")
		_near(split.toHp, fixture.result.toHp, "Shield overflow parity")
	for fixture in fixtures.envelope:
		var delta := Vector3(fixture.delta[0], fixture.delta[1], fixture.delta[2])
		_check(CombatMath.in_range(fixture.range, delta) == fixture.result, "Range envelope parity")
	for fixture in fixtures.falloff:
		for sample in fixture.samples:
			_near(CombatMath.damage_falloff(fixture.def, sample.distance), sample.result, "Weapon falloff parity")
	for fixture in fixtures.fan:
		var distance := CombatMath.fan_bin_distance(fixture.def, int(fixture.bin), fixture.distance, fixture.phi, fixture.radius)
		if fixture.result == null:
			_check(distance < 0, "Fan bin misses outside wedge")
		else:
			_near(distance, fixture.result, "Fan bin surface parity")
	for fixture in fixtures.zones:
		var zones := CombatMath.lance_zones(Vector2(fixture.offset[0], fixture.offset[1]), fixture.radius, fixture.beam)
		var expected: Array[int] = []
		for zone in fixture.result:
			expected.append(int(zone))
		_check(zones == expected, "Lance zone overlap parity actual=" + str(zones) + " expected=" + str(expected))
	for fixture in fixtures.fanHits:
		var targets: Array = fixture.targets.duplicate(true)
		for target in targets:
			target.position = Vector3(target.position[0], target.position[1], target.position[2])
		var origin := Vector3(fixture.origin[0], fixture.origin[1], fixture.origin[2])
		var direction := Vector3(fixture.direction[0], fixture.direction[1], fixture.direction[2])
		var definition := Content.weapon(fixture.character, fixture.slot, int(fixture.level))
		var hits := CombatMath.fan_hits(definition, origin, direction, targets)
		var label: String = fixture.character + ": " + fixture.name
		_check(hits.size() == fixture.hits.size(), "Source fan bin winners: " + label)
		for i in range(mini(hits.size(), fixture.hits.size())):
			_check(hits[i].id == fixture.hits[i].id, "Source fan target insertion order: " + label)
			var error: float = absf(hits[i].amount - fixture.hits[i].amount)
			maximum_fan_error = maxf(maximum_fan_error, error)
			_check(error < maxf(0.000001, absf(fixture.hits[i].amount) * 0.000001), "Source fan per-bin damage within native vector precision: " + label)
	for fixture in fixtures.altitudeRange:
		_near(CombatMath.altitude_range({"slot": "heavy" if fixture.heavy else "light"}, fixture.gap), fixture.result, "Source altitude range multiplier")
	_near(CombatMath.armor_multiplier(0, 100), 1.0, "Penetration does not create negative armor")
	_near(CombatMath.blast_falloff(10, 18), 0.0, "Blast edge excludes damage")
	_near(CombatMath.blast_falloff(10, 5), 1.0, "Blast core has full damage")
	_check(Content.heroes.size() == 32, "Complete character roster")
	for character in Content.heroes:
		_check(Content.heroes[character].weapons.light.size() == 4, "Four light weapon tiers")
		_check(Content.heroes[character].abilities.atk.size() == 4, "Four attack tiers")
	for map_data in Content.maps:
		for team_size in range(1, 6):
			var variant: Dictionary = map_data.variants[str(team_size)]
			_check(variant.lanes.size() == ceili(team_size / 2.0), "Active lane subset")
			_check(variant.structures.filter(func(info): return info.kind == "tower").size() == variant.lanes.size() * 4, "Source tower pairs")
	await _visibility_tests(fixtures.visibility)
	await _occlusion_tests(fixtures.occlusion)
	await _settlement_tests()
	await _combat_visibility_tests()
	_projectile_reference_tests(fixtures)
	await _blast_volume_tests(fixtures.blastVolumes)
	await _projectile_settlement_tests()
	await _lob_reference_tests(fixtures)
	await _lob_settlement_tests(fixtures.lobSafety)
	await _friendly_core_tests(fixtures.friendlyCoreOutcomes)
	_line_reference_tests(fixtures.lineHits)
	await _settlement_range_tests(fixtures.settlementRange)
	for fixture in fixtures.deadShooterReports:
		_check(fixture.settlements == 0, "Original impact report rejects a dead shooter: " + fixture.method)
	await _kinetic_reference_tests(fixtures.kineticFlight)
	await _kinetic_settlement_tests()
	_targeting_reference_tests(fixtures)
	await _targeting_settlement_tests()
	await _lock_confirmation_tests(fixtures.lockConfirmation)
	_missile_flight_tests(fixtures.missileFlight)
	await _missile_reference_tests(fixtures)
	await _base_target_tests(fixtures.baseTargets)
	await _missile_authority_tests(fixtures.baseLaunches)
	await _run_fixture_suite(StructureSuite)
	await ReachabilitySuite.run(self, fixtures.reachability)
	await ModelSuite.run(self, fixtures.modelCentres)
	await FootprintSuite.run(self, fixtures.shotFootprints)
	await _run_fixture_suite(CockpitSuite)
	await MuzzleTests.run(self, fixtures.muzzleLaunches)
	await _run_fixture_suite(CameraTests)
	await _run_fixture_suite(BurstTests)
	await _run_fixture_suite(ProjectileVisualTests)
	await _run_fixture_suite(StatusTests)
	await _run_fixture_suite(HealAuraTests)
	await _run_fixture_suite(SimulationFrameTests)
	await _run_fixture_suite(DeathLifecycleTests)
	await _run_fixture_suite(MissileDefenseTests)
	await _run_fixture_suite(AimingPresentationTests)
	await _run_fixture_suite(BotTests)
	await _run_fixture_suite(BossTests)
	await _run_fixture_suite(CampaignTests)
	await _run_fixture_suite(SuperTests)
	await _run_fixture_suite(ControlsTests)
	await _run_fixture_suite(MobileTests)
	await _run_fixture_suite(ViewTests)
	await _run_fixture_suite(PlayerViewTests)
	await _run_fixture_suite(BodyTests)
	await _run_fixture_suite(MovementTests)
	await _run_fixture_suite(TraversalTests)
	await _run_fixture_suite(ClimbTests)
	await _run_fixture_suite(FieldTests)
	await _run_fixture_suite(CompanionTests)
	await _run_fixture_suite(CarrierTests)
	await _run_fixture_suite(CarrierControllerTests)
	await _run_fixture_suite(AbilityRouteTests)
	await _run_fixture_suite(NpcTests)
	await _run_fixture_suite(WaveTests)
	await _run_fixture_suite(WeatherTests)
	await _run_fixture_suite(EnvironmentTests)
	await _run_fixture_suite(TextureTests)
	await _run_fixture_suite(CelUniformTests)
	await _run_fixture_suite(TrainTests)
	await _run_fixture_suite(SceneryMotionTests)
	await _run_fixture_suite(WildlifeTests)
	await _run_fixture_suite(WildlifeDensityTests)
	await _run_fixture_suite(PetalTests)
	await _run_fixture_suite(AquaticTests)
	await _run_fixture_suite(MarineTests)
	await _run_fixture_suite(VisualTests)
	await _run_fixture_suite(OutlineTests)
	await _run_fixture_suite(GeometryLodTests)
	await _run_fixture_suite(SceneryTests)
	await _run_fixture_suite(SceneTests)
	await _run_fixture_suite(SupplyTests)
	await _run_fixture_suite(ThirdTests)
	await _run_fixture_suite(MatchTests)
	await _run_fixture_suite(CombatFeedTests)
	if failures == 0:
		print("TEST_PASS assertions=", assertions)
		print("FAN_REFERENCE_PASS cases=", fixtures.fanHits.size(), " maximumDamageError=", maximum_fan_error)
		print("PROJECTILE_REFERENCE_PASS launches=", fixtures.projectileLaunches.size(), " flights=", fixtures.projectileFlight.size(), " maximumVectorError=", maximum_projectile_error)
		print("LOB_REFERENCE_PASS controls=", fixtures.lobControl.size(), " flights=", fixtures.lobFlight.size(), " maximumVectorError=", maximum_lob_error)
		print("LINE_REFERENCE_PASS cases=", fixtures.lineHits.size(), " maximumDamageError=", maximum_line_error)
		print("KINETIC_REFERENCE_PASS cases=", fixtures.kineticFlight.size(), " maximumVectorError=", maximum_kinetic_error)
		print("TARGETING_REFERENCE_PASS cone=", fixtures.targetingCone.size(), " launchRanges=", fixtures.launchRange.size(), " locks=", fixtures.lockCandidates.size(), " priorities=", fixtures.aimPriority.size(), " confirmations=", fixtures.lockConfirmation.size())
		print("MISSILE_REFERENCE_PASS flights=", fixtures.missileFlight.size(), " damage=", fixtures.missileDamage.size(), " lines=", fixtures.missileLines.size(), " rays=", fixtures.missileRays.size())
		print("STRUCTURE_REFERENCE_PASS separation=", fixtures.structureSeparation.size(), " levels=", fixtures.structureLevels.size(), " clientPoses=", fixtures.structureClient.size(), " worlds=", fixtures.structureWorlds.size(), " blasts=", fixtures.structureBlasts.size())
		print("REACHABILITY_REFERENCE_PASS cases=", fixtures.reachability.size())
		print("MODEL_CENTRE_REFERENCE_PASS cases=", fixtures.modelCentres.size())
		print("FOOTPRINT_REFERENCE_PASS cases=", fixtures.shotFootprints.size())
		print("COCKPIT_REFERENCE_PASS poses=", fixtures.cockpitPoses.size(), " ports=", fixtures.cockpitMuzzles.size())
	_finish()

func _finish() -> void:
	if failures > 0:
		print("TEST_FAIL count=", failures, " scopes=", JSON.stringify(scope_failures), " report=", ProjectSettings.globalize_path(FAILURE_REPORT))
	else:
		print("SOURCE_FIXTURE_PASS assertions=", assertions)
	failure_report.close()
	get_tree().quit(0 if failures == 0 else 1)

func _run_fixture_suite(suite: Variant) -> void:
	failure_scope = suite.resource_path
	var previous_assertions := assertions
	var previous_failures := failures
	var keys := Content.fixture_sections_for(suite)
	var encoded_bytes := 0
	for key: String in keys:
		encoded_bytes += int(Content.fixture_registry.sections[key].bytes)
	var budget := 256 * 1024 * 1024
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-budget-mib="):
			budget = maxi(1, argument.trim_prefix("--fixture-budget-mib=").to_int()) * 1024 * 1024
	if encoded_bytes > budget:
		_check(false, "Unverified source suite requires incremental case consumption: " + suite.resource_path + " bytes=" + str(encoded_bytes))
		failure_scope = "core"
		return
	# A mismatched call is only a script error, which would otherwise report assertions=0 as a pass.
	var arguments := 1 if suite in [RoomWorldResourceTests, RoomWorldPrebuildTests] else 2
	if _run_arguments(suite) != arguments:
		_check(false, "Selected source suite does not accept this runner's arguments: " + suite.resource_path)
		failure_scope = "core"
		return
	var data: Dictionary = Content.read_json("res://data/fixtures.json", keys)
	print("SOURCE_SUITE_BEGIN ", suite.resource_path)
	if suite in [RoomWorldResourceTests, RoomWorldPrebuildTests]:
		await suite.run(self)
	else:
		await suite.run(self, data)
	data.clear()
	await get_tree().process_frame
	print("SOURCE_SUITE_END ", suite.resource_path, " assertions=", assertions - previous_assertions, " failures=", failures - previous_failures)
	failure_scope = "core"

func _run_arguments(suite: GDScript) -> int:
	for method: Dictionary in suite.get_script_method_list():
		if method.name == "run":
			return method.args.size()
	return -1

func _missile_flight_tests(fixtures: Array) -> void:
	for fixture in fixtures:
		var state: Dictionary = fixture.steps[0].before.duplicate(true)
		state.position = _reference_vector(state.position)
		state.origin = _reference_vector(state.origin)
		for step: Dictionary in fixture.steps:
			var target: Dictionary = step.target.duplicate(true)
			if not target.is_empty():
				target.position = _reference_vector(target.position)
			var outcome := MissileMotion.advance(state, fixture.delta, target, func(_start, _end): return step.blocked)
			_check(state.position.distance_to(_reference_vector(step.after.position)) < 0.001, "Source server missile motion: " + fixture.name)
			_near(state.ttl, step.after.ttl, "Source missile TTL precedence")
			_check(state.get("lost", false) == step.after.lost, "Source permanent missile loss: " + fixture.name)
			_check(outcome.get("remove", false) == step.removed, "Source missile removal: " + fixture.name)
			_check(outcome.has("blast") == (step.blast != null), "Source missile harmless expiry / blast: " + fixture.name)
			if step.blast != null:
				_check(outcome.blast.distance_to(_reference_vector(step.blast)) < 0.001, "Source missile endpoint/fuse blast")

func _missile_reference_tests(fixtures: Dictionary) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 701, "side": "STEEL", "character": "t09", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_missile_reference_tests"):
		return
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[701]
	actor.position = _ground_point(sim, 0, 1, 0)
	for fixture: Dictionary in fixtures.missileDamage:
		actor.character = fixture.character
		actor.input_state = {"aim": fixture.get("aiming", true)}
		actor.buffs = [{"until": 1.0, "mul": {"dmg": fixture.buff}}] if fixture.has("buff") else []
		actor.money = 0
		sim.clock = 0
		var state := {"id": 9, "actor": 0, "side": "STEEL" if fixture.get("ally", false) else "SWARM",
			"position": Vector3(0, 1, -fixture.distance), "hp": fixture.hp, "max_hp": fixture.hp}
		sim.missiles.assign([state])
		sim._damage_missile(actor, Content.weapon(fixture.character, fixture.slot, int(fixture.level)), 9)
		_check(absf((fixture.hp - state.hp) - fixture.damage) < 0.001, "Original hitMissile damage/range: " + fixture.character + " " + fixture.name)
		_check(sim.missiles.is_empty() == fixture.removed, "Original missile removal: " + fixture.name)
		_near(actor.money, fixture.bounty, "Original missile bounty without score")
	actor.buffs.clear()
	actor.input_state = {"aim": true}
	for fixture: Dictionary in fixtures.missileSnapshots:
		var state := {"id": 9, "position": _reference_vector(fixture.point), "components": fixture.point, "hp": 69.2, "max_hp": 70}
		sim.missiles.assign([state])
		var packet: Dictionary = sim._missile_snapshot()[0]
		_check(packet.position == _reference_vector(fixture.result.position), "Original missile _frame north-positive half-tie quantization")
		_near(packet.hp, fixture.result.hp, "Original missile snapshot HP rounding")
	for fixture: Dictionary in fixtures.missileLines:
		var def := Content.weapon(fixture.character, fixture.slot, int(fixture.level))
		var point := _reference_vector(fixture.point)
		var origin := _reference_vector(fixture.origin)
		var direction := _reference_vector(fixture.direction)
		var hits := MissileMotion.line_contains(def, origin, direction, fixture.length, point)
		var amount: float = def.dmg * CombatMath.damage_falloff(def, origin.distance_to(point)) if hits else 0.0
		_check(absf(amount - fixture.damage) < 0.001, "Original heroLance missile cylinder/range: " + fixture.character)
	sim.missiles.clear()
	var body := MissileBody.new()
	add_child(body)
	body.position = Vector3(0, 100, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for fixture: Dictionary in fixtures.missileRays:
		var origin := _reference_vector(fixture.origin) + body.position
		var direction := _reference_vector(fixture.direction)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 10, 512)
		query.hit_back_faces = true
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		_check(hit.is_empty() == (fixture.point == null), "Source missile geometry native ray presence")
		if not hit.is_empty() and fixture.point != null:
			_check(hit.position.distance_to(_reference_vector(fixture.point) + body.position) < 0.001, "Source missile geometry native ray point")
	body.queue_free()
	sim.queue_free()
	await get_tree().process_frame

func _base_target_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_base_target_tests"):
		return
	sim.set_physics_process(false)
	var base: BattleUnit
	for unit: BattleUnit in sim.units.values():
		unit.side = "STEEL"
		if unit.kind == "base":
			base = unit
	base.position = _ground_point(sim, 0, 0, 0)
	for fixture: Dictionary in fixtures:
		var targets := {}
		for spec: Dictionary in fixture.targets:
			var character := ""
			if spec.hero:
				for id in Content.heroes:
					if Content.heroes[id].kind == spec.kind:
						character = id
						break
			targets[int(spec.id)] = sim.spawn({"kind": spec.kind, "character": character, "side": "SWARM", "position": _ground_point(sim, spec.x, spec.y, -spec.z)})
		await get_tree().physics_frame
		var found := sim._acquire_base_target(base, Content.constants.UNITS.base.guns.range)
		_check(found == targets.get(int(fixture.result)), "Original base planar acquisition, hero bias and air ceiling: " + str(fixture.targets))
		for unit: BattleUnit in targets.values():
			sim.units.erase(unit.entity_id)
			unit.queue_free()
	sim.queue_free()
	await get_tree().process_frame

func _missile_authority_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 801, "side": "STEEL", "character": "t08", "bot": false},
		{"peer": 802, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_missile_authority_tests"):
		return
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[801]
	var target: BattleUnit = sim.pilots[802]
	var base: BattleUnit
	for unit: BattleUnit in sim.units.values():
		if unit.kind == "base" and unit.side == "STEEL":
			base = unit
	base.position = _ground_point(sim, 0, 0, 0)
	for unit: BattleUnit in sim.units.values():
		if unit != target:
			unit.side = "STEEL"
	actor.position = _ground_point(sim, 300, 1, 0)
	target.position = _ground_point(sim, 0, 20, -100)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var health := target.hp
	for fixture: Dictionary in fixtures:
		for missile: Dictionary in sim.missiles.duplicate():
			sim._remove_missile(int(missile.id))
		target.side = "SWARM" if fixture.available else "STEEL"
		sim._tick_base_guns(base, Content.constants.UNITS.base.guns, fixture.delta)
		_check(sim.missiles.size() == fixture.missiles.size(), "Original base independent gun launch count")
		for index in range(base.gun_cooldowns.size()):
			_near(base.gun_cooldowns[index], fixture.cooldowns[index], "Original independent base cooldown")
		for index in range(mini(sim.missiles.size(), fixture.missiles.size())):
			var state: Dictionary = sim.missiles[index]
			var expected: Dictionary = fixture.missiles[index]
			_check(state.position == _reference_vector(expected.position), "Original left/right base launch offsets")
			for key in ["speed", "dmg", "r", "hp", "ttl", "range"]:
				_near(state[key], expected[key], "Original base missile " + key)
	_near(target.hp, health, "Base launches never deal immediate direct damage")
	for missile: Dictionary in sim.missiles.duplicate():
		sim._remove_missile(int(missile.id))
	actor.position = _ground_point(sim, 0, 20, 0)
	actor.yaw = 0
	actor.pitch = 0
	actor.input_state = {"aim": false, "slot": "light"}
	target.position = _ground_point(sim, 0, 20, -100)
	target.side = "SWARM"
	target.shield = 0
	var incoming := _missile_point(sim, actor.view_origin() + Vector3.FORWARD * 60)
	var missile := {"actor": base.entity_id, "side": "SWARM", "target": actor.entity_id,
		"position": incoming, "origin": incoming,
		"speed": Content.constants.BASE_MISSILE.SPEED, "dmg": Content.constants.UNITS.base.guns.dmg,
		"r": Content.constants.STRUCT_W.base.r, "pen": Content.constants.STRUCT_W.base.pen,
		"hp": 1.0, "max_hp": Content.constants.BASE_MISSILE.HP, "ttl": 5.0, "range": Content.constants.UNITS.base.guns.range}
	sim._launch_missile(missile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var money := actor.money
	var score := actor.score
	var magazine: float = actor.ammo.light
	var target_health := target.hp
	var aimed := sim._projectile_aim(actor, 120)
	_check(int(aimed.missile) == int(missile.id), "Native precise ray selects incoming missile before enemy")
	sim.fire(actor, "light")
	_check(sim.missiles.is_empty(), "Instant beam destroys a missile")
	_near(actor.ammo.light, magazine - 1, "Missile interception spends one launch magazine round")
	_near(actor.money, money + Content.constants.ECON.BOUNTY.missile, "Missile kill awards only source bounty")
	_near(actor.score, score, "Missile kill never awards battle score")
	_near(target.hp, target_health, "Intercepted missile never deals blast damage")
	_check(sim.events.any(func(event): return event.type == "missile_intercept"), "Harmless interception has its own event")
	actor.fire_at.clear()
	missile = missile.duplicate(true)
	missile.hp = 70.0
	missile.side = "STEEL"
	sim._launch_missile(missile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "light")
	_near(missile.hp, 70, "Friendly missile screens the ray but cannot take interception damage")
	_near(target.hp, target_health, "Friendly missile suppresses direct-beam cone fallback")
	var snapshot := sim.snapshot(801)
	_check(snapshot.missiles.size() == 1 and sim.snapshot(802).missiles.size() == 1, "Source missiles are shared globally across faction snapshots")
	sim.authoritative = false
	var before: Vector3 = missile.position
	sim._tick_missiles(0.1)
	_check(missile.position == before, "Clients cannot advance authority missiles")
	sim._damage_missile(actor, Content.weapon(actor.character, "light"), int(missile.id))
	_near(missile.hp, 70, "Clients cannot settle interception")
	sim.authoritative = true
	sim._remove_missile(int(missile.id))
	actor.character = "t04"
	actor.ammo.light = Content.weapon(actor.character, "light").mag
	actor.fire_at.clear()
	missile = missile.duplicate(true)
	missile.side = "SWARM"
	missile.hp = 1.0
	actor.ensure_weapon_pose()
	missile.position = _missile_point(sim, actor.weapon_pose.muzzle(actor.aim_transform(), "light", actor.flying, true, false) + Vector3(0, -0.03, -30))
	sim._launch_missile(missile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	money = actor.money
	sim.fire(actor, "light")
	_near(missile.hp, 1, "Kinetic interception waits for physical flight")
	for frame in range(120):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_check(sim.missiles.is_empty(), "Native kinetic sweep strikes an incoming missile")
	_near(actor.money, money + Content.constants.ECON.BOUNTY.missile, "Kinetic interception settles bounty once")
	sim._tick_projectiles(1.0 / 60)
	_near(actor.money, money + Content.constants.ECON.BOUNTY.missile, "Removed kinetic round cannot intercept twice")
	target.side = "STEEL"
	actor.input_state = {"aim": true, "slot": "heavy"}
	actor.ammo.heavy = Content.weapon(actor.character, "heavy").mag
	actor.fire_at.clear()
	missile = missile.duplicate(true)
	missile.hp = 1.0
	var tower := sim.spawn({"kind": "tower", "side": "SWARM", "position": _ground_point(sim, 0, 0, -15)})
	var tower_health := tower.hp
	sim._launch_missile(missile)
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	_check(not sim.missiles.is_empty(), "Penetration never terminates on a missile body")
	for frame in range(120):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_check(sim.missiles.is_empty(), "Terminal penetrating line settles incoming missiles")
	_check(tower.hp < tower_health, "Missile interception does not consume or inherit the line's unit penetration budget")
	base.side = "SWARM"
	base.hp = 0
	actor.shield = 0
	var platform := StaticBody3D.new()
	platform.collision_layer = 1 | 16
	var lift := sim.world.ground_height(10, 0)
	platform.position = Vector3(10, lift + 99.5, 0)
	var support := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 1, 8)
	support.shape = box
	platform.add_child(support)
	sim.world.add_child(platform)
	sim.world.layers.configure([[10.0, 3.0, 10.0, -3.0, 4.0, 1, 0]], [{"x1": 10.0, "z1": -3.0, "y1": lift + 100.0, "x2": 10.0, "z2": 3.0, "y2": lift + 100.0, "hw": 4.0}])
	var altitude := actor.position.y - sim.world.ground_height(actor.position.x, actor.position.z)
	target.position = Vector3(10, lift + 100 + altitude, 0)
	target.shield = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var actor_health := actor.hp
	target_health = target.hp
	missile = missile.duplicate(true)
	missile.hp = Content.constants.BASE_MISSILE.HP
	missile.position = Vector3(0, altitude, -8)
	sim._launch_missile(missile)
	sim._tick_missiles(0.05)
	_check(sim.missiles.is_empty() and actor.hp < actor_health and target.hp < target_health, "Base missile blast retains source relative body bands across standing surfaces after launcher death")
	_check(sim.events.any(func(event): return event.type == "missile_blast"), "Impact has a damaging blast event distinct from interception")
	sim.units.erase(base.entity_id)
	actor_health = actor.hp
	missile = missile.duplicate(true)
	sim._launch_missile(missile)
	sim._tick_missiles(0.05)
	_check(sim.missiles.is_empty() and actor.hp < actor_health, "Removed launcher retains the captured missile side for blast settlement")
	sim.queue_free()
	await get_tree().process_frame

func _targeting_reference_tests(fixtures: Dictionary) -> void:
	for fixture in fixtures.targetingCone:
		var candidates: Array = fixture.candidates.duplicate(true)
		for candidate in candidates:
			candidate.point = _reference_vector(candidate.point)
			candidate.obstruction = INF if candidate.obstruction == null else candidate.obstruction
		var result := TargetingMath.cone_acquire(_reference_vector(fixture.position), _reference_vector(fixture.eye),
			_reference_vector(fixture.forward), fixture.reach, candidates, int(fixture.keep))
		_check(result == int(fixture.result), "Source cone/anchor: " + fixture.name)
	for fixture in fixtures.launchRange:
		var def := Content.weapon(fixture.character, fixture.slot, int(fixture.level))
		var target: Dictionary = fixture.target.duplicate(true)
		if not target.is_empty():
			target.position = _reference_vector(target.position)
		var result := TargetingMath.launch_range(def, _reference_vector(fixture.position), _reference_vector(fixture.eye), fixture.surface, target)
		_check(absf(result - fixture.range) < 0.0001, "Source client launch height frames: " + fixture.character + " " + fixture.name)
		_near(TargetingMath.maximum_range(def), fixture.maximum, "Source acquisition maximum range")
	for fixture in fixtures.lockCandidates:
		var result := TargetingMath.lock_candidate(fixture.primary, fixture.flights, int(fixture.index))
		_check(result.id == int(fixture.result.id) and result.index == int(fixture.result.index), "Source primary/unique round-robin in-flight locks")
	for fixture in fixtures.aimPriority:
		var precise := {} if fixture.exact == null else {"id": 1, "point": Vector3(fixture.exact, 0, 0)}
		var lob := {} if fixture.lob == null else {"on": true, "ok": fixture.lob.ok, "target": 1}
		_check(TargetingMath.aim_choice(Vector3.ZERO, 100, precise, 2, lob) == int(fixture.result), "Source lob/exact/cone priority")

func _targeting_settlement_tests() -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 501, "side": "STEEL", "character": "t09", "bot": false},
		{"peer": 502, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_targeting_settlement_tests"):
		return
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[501]
	var target: BattleUnit = sim.pilots[502]
	actor.position = _ground_point(sim, 0, 1, 0)
	target.position = _ground_point(sim, 7, 1, -100)
	actor.yaw = 0
	actor.pitch = 0
	actor.input_state = {"aim": true, "slot": "heavy"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(sim._projectile_aim(actor, 150).target == null, "Off-axis hero misses the exact physical ray")
	_check(sim._aim_target(actor, 150) == target, "Native cone acquires visible off-axis hero")
	sim.clock = 1
	sim._tick_lock(actor)
	_check(actor.lock_target == target.entity_id and actor.aim_anchor == target.entity_id, "Authority confirms cone lock")
	_check(sim.snapshot(501).lock.target == target.entity_id and sim.snapshot(502).lock.is_empty() and sim.snapshot().lock.is_empty(), "Confirmed lock snapshot belongs only to its pilot")
	var old_time := actor.lock_at
	sim.clock += 0.1
	sim._tick_lock(actor)
	_near(actor.lock_at, old_time, "Lock heartbeat obeys source quarter-second budget")
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1 and sim.projectiles[0].target == target.entity_id, "FNF fresh launch acquisition shares cone solver")
	actor.yaw = PI
	actor.rotation.y = PI
	sim.clock += 1
	actor.fire_at.clear()
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 2 and sim.projectiles[1].target == 0, "Turning away never falls back to a stale confirmed FNF anchor")
	actor.input_state = {"aim": false, "slot": "light"}
	actor.aim_off_at = sim.clock
	sim._tick_lock(actor)
	_check(actor.lock_target == target.entity_id and actor.lock_at == sim.clock, "In-flight FNF continues the same heavy lock after aim release")
	sim.projectiles.clear()
	sim.clock += 0.3
	sim._tick_lock(actor)
	_check(actor.aim_anchor == 0, "Missing aim and in-flight candidates clear the acquisition anchor")
	sim.clock = actor.lock_at + Content.constants.LOCK.TTL + 0.01
	_check(sim.snapshot(501).lock.is_empty(), "Unrefreshed confirmed lock expires at source TTL")
	actor.rotation.y = 0
	actor.yaw = 0
	actor.input_state = {"aim": true, "slot": "heavy"}
	sim.fire_controls[actor.entity_id] = {"ok": false, "target": target.entity_id}
	_check(sim._aim_target(actor, 150) == null, "Failed lob fire control prohibits exact and cone fallback")
	sim.fire_controls.clear()
	var wall := StaticBody3D.new()
	wall.position = _ground_point(sim, 0, 5, -50)
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 10, 0.1)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	sim.world.add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(sim._aim_target(actor, 150) == null, "Native non-terrain obstruction rejects cone acquisition")
	var confirmed := actor.lock_at
	sim._confirm_lock(actor, target.entity_id)
	_near(actor.lock_at, confirmed, "Authority LOS independently rejects a blocked lock")
	wall.queue_free()
	await get_tree().physics_frame
	actor.position.y = sim.world.ground_height(actor.position.x, actor.position.z) + 80
	var direction := target.eye() - actor.eye()
	actor.yaw = atan2(-direction.x, -direction.z)
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	actor.fire_at.clear()
	actor.ammo.heavy = Content.weapon(actor.character, "heavy").mag
	actor.power = actor.max_power
	await get_tree().physics_frame
	var def := Content.weapon(actor.character, "heavy")
	var effective := sim._launch_range(actor, def, target)
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1 and effective > def.range, "Native FNF captures an acquired lower-hero launch envelope")
	_near(sim.projectiles[0].range, effective, "Physical warhead retains target-derived range")
	sim.projectiles.clear()
	actor.character = "t04"
	actor.ammo.light = Content.weapon(actor.character, "light").mag
	actor.fire_at.clear()
	sim.fire(actor, "light")
	_check(sim.projectiles.size() == 1, "Native flat gun launches with target-derived altitude envelope")
	_near(sim.projectiles[0].range, sim._launch_range(actor, Content.weapon(actor.character, "light"), target), "Flat round captures launch envelope")
	actor.position = _ground_point(sim, 0, 1, 0)
	actor.yaw = 0
	actor.pitch = 0
	actor.character = "s03"
	actor.height = Content.heroes.s03.height
	actor.ammo.light = Content.weapon(actor.character, "light").mag
	actor.fire_at.clear()
	target.shield = 0
	var before := target.hp
	sim.fire(actor, "light")
	_check(target.hp < before, "Instant direct beam shares source cone fallback after an exact-ray miss")
	_check(sim.projectiles.size() == 1, "Beam remains instant while an earlier flat round stays in flight")
	target.character = ""
	_check(sim._aim_target(actor, 150) == null, "NPCs cannot enter hero-only cone fallback")
	sim.queue_free()
	await get_tree().process_frame

func _lock_confirmation_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 601, "side": "STEEL", "character": "t09", "bot": false},
		{"peer": 602, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_lock_confirmation_tests"):
		return
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[601]
	var target: BattleUnit = sim.pilots[602]
	# Source compares absolute hero eyes on flat ground, so both heroes share one terrain offset.
	var floor_y := sim.world.ground_height(0, 0)
	# Source stubs team sight; keep native LOS but grant the shooter side shared vision.
	sim.vision_until["STEEL"] = INF
	for fixture in fixtures:
		actor.character = fixture.character
		actor.kind = Content.heroes[fixture.character].kind
		actor.height = Content.heroes[fixture.character].height
		actor.upgrades.lw = int(fixture.level) - 1
		actor.upgrades.hw = int(fixture.level) - 1
		actor.position = Vector3(0, floor_y + 1, 0)
		actor.hp = 0 if fixture.dead else actor.max_hp
		actor.status.blind_until = 11.0 if fixture.get("blind", false) else 0.0
		actor.input_state = {"aim": fixture.aiming}
		target.special.neutral = fixture.get("neutral", false)
		target.special.garrison = fixture.get("garrison", false)
		target.position = Vector3(0, floor_y + 1, -fixture.distance)
		sim.clock = 10
		actor.lock_target = target.entity_id if int(fixture.previous) == 2 else -1 if int(fixture.previous) == 3 else 0
		actor.lock_at = sim.clock - fixture.lockAge
		actor.aim_off_at = sim.clock - fixture.releaseAge
		actor.aim_anchor = 0
		await get_tree().physics_frame
		sim._confirm_lock(actor, target.entity_id)
		_check((actor.aim_anchor == target.entity_id) == fixture.accepted, "Original heroLock authority gate: " + fixture.character + " " + fixture.name)
	sim.queue_free()
	await get_tree().process_frame

func _lob_geometry(fixture: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	root.add_child(floor_body)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	var faces := PackedVector3Array()
	for point in [Vector2(-32000, -32000), Vector2(32000, 32000), Vector2(32000, -32000),
		Vector2(-32000, -32000), Vector2(-32000, 32000), Vector2(32000, 32000)]:
		faces.append(Vector3(point.x, fixture.ground.base + fixture.ground.x * point.x + fixture.ground.z * point.y, point.y))
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	for box in fixture.boxes:
		var body := StaticBody3D.new()
		root.add_child(body)
		var minimum := _reference_vector(box.min)
		var maximum := _reference_vector(box.max)
		body.position = (minimum + maximum) / 2
		var box_collider := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = maximum - minimum
		box_collider.shape = box_shape
		body.add_child(box_collider)
	return root

func _lob_collision(start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.hit_back_faces = true
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)

func _lob_vector(actual: Vector3, expected: Array, label: String) -> void:
	var error := actual.distance_to(_reference_vector(expected))
	maximum_lob_error = maxf(maximum_lob_error, error)
	_check(error < 0.01, "Source lob with native collision: " + label + " error=" + str(error))

func _lob_reference_tests(fixtures: Dictionary) -> void:
	var lower_charge := 0
	for fixture in fixtures.lobControl:
		var geometry := _lob_geometry(fixture)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ground := func(x: float, z: float) -> float: return fixture.ground.base + fixture.ground.x * x + fixture.ground.z * z
		var requested := _reference_vector(fixture.aim)
		var anti_air: bool = not fixture.target.is_empty() and CombatMath.target_class(fixture.target) == "air"
		if anti_air:
			requested.y += 1.5
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level))
		var control := LobFireControl.prepare(def, _reference_vector(fixture.origin), requested, fixture.range, anti_air, ground, _lob_collision)
		var label: String = fixture.character + ": " + fixture.name
		_check(not control.is_empty(), "Verified source lob control: " + label)
		if not control.is_empty():
			for key in ["ok", "aa", "high", "close", "clamped"]:
				_check(control[key] == fixture.expected[key], "Source lob " + key + ": " + label)
			lower_charge += 1 if control.high else 0
			_check(absf(control.speed - fixture.expected.speed) < 0.0001, "Source variable launch speed: " + label)
			_lob_vector(control.aim, fixture.expected.aim, label + " aim")
			_lob_vector(control.velocity, fixture.expected.velocity, label + " velocity")
			_check(control.arc.has_impact == fixture.expected.hasImpact, "Source arc termination: " + label)
			_check(control.arc.points.size() == fixture.expected.points.size(), "Source adaptive arc point budget: " + label)
			for index in range(mini(control.arc.points.size(), fixture.expected.points.size())):
				_lob_vector(control.arc.points[index], fixture.expected.points[index], label + " point " + str(index))
			if fixture.expected.hasImpact:
				_lob_vector(control.arc.impact, fixture.expected.impact, label + " impact")
		geometry.free()
	_check(lower_charge > 0, "Source reference exercises a reduced-charge branch")
	for fixture in fixtures.lobFlight:
		var geometry := _lob_geometry(fixture)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level))
		var state := ProjectileMotion.ballistic(_reference_vector(fixture.origin), _reference_vector(fixture.velocity), fixture.range)
		var hit := {}
		var frames := 0
		while frames < 4000:
			frames += 1
			var previous := ProjectileMotion.advance(state, def, 1.0 / 60)
			var direction: Vector3 = state.position - previous
			hit = _lob_collision(previous, state.position + direction.normalized() * 0.3)
			if ProjectileMotion.finish(state, def, not hit.is_empty()):
				break
		var label: String = fixture.character + ": " + fixture.name
		_check(frames == fixture.frames, "Source lob flight impact/fuel frame: " + label + " actual=" + str(frames) + " expected=" + str(fixture.frames))
		_check(state.dud == fixture.state.dud, "Source lob permanent disarming: " + label)
		_check((not hit.is_empty() and not state.dud) == (fixture.burst != null), "Source lob detonates only on an armed collision: " + label)
		_lob_vector(state.position, fixture.state.position, label + " flight endpoint")
		if fixture.burst != null and not hit.is_empty():
			_lob_vector(hit.position, [fixture.burst.x, fixture.ground.base + fixture.ground.x * fixture.burst.x - fixture.ground.z * fixture.burst.z, -fixture.burst.z], label + " collision")
		geometry.free()

func _lob_settlement_tests(fixtures: Array) -> void:
	for fixture in fixtures:
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level))
		var friendly := LobFireControl.friendly_impact(def, Vector3.ZERO, Vector3(fixture.distance, 80, 0))
		_check(friendly == fixture.friendly and friendly == fixture.self, "Source minimum safe range is planar and strictly bounded")
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 1, "side": "STEEL", "character": "t03", "bot": false},
		{"peer": 2, "side": "SWARM", "character": "s06", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_lob_settlement_tests"):
		return
	sim.set_physics_process(false)
	for actor: BattleUnit in sim.units.values():
		if not actor.is_hero():
			sim.units.erase(actor.entity_id)
			actor.free()
	var actor: BattleUnit = sim.pilots[1]
	var target: BattleUnit = sim.pilots[2]
	actor.position = _ground_point(sim, 0, 0.1, 0)
	target.position = _ground_point(sim, 0, 0.1, -80)
	target.shield = 0
	var direction := target.eye() - actor.eye()
	actor.yaw = atan2(-direction.x, -direction.z)
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	actor.input_state = {"aim": true, "slot": "heavy"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	var def := Content.weapon(actor.character, "heavy")
	var control := sim.lob_control(actor, def)
	_check(not control.aa and control.ok, "Crosshair on a ground robot selects the fixed-angle solution")
	_check(absf(control.velocity.y - Vector2(control.velocity.x, control.velocity.z).length()) < 0.00001, "Ground launch uses 45 degrees within native Vector3 rounding")
	sim.fire_controls[actor.entity_id] = control
	var health := target.hp
	var ammo: float = actor.ammo.heavy
	var power := actor.power
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1, "Lob launcher creates an authority projectile")
	_near(target.hp, health, "Lob cannot settle damage on firing")
	_near(actor.ammo.heavy, ammo - 1, "Lob consumes one round on launch")
	_near(actor.power, power - def.heavyMp, "Lob consumes power once")
	_check(sim.projectiles[0].velocity == control.velocity, "Preview and launch share the same solved velocity")
	var state := sim.snapshot(1)
	_check(state.fire_control.points == control.arc.points, "Snapshot retains the launch fire-control arc")
	_check(sim.snapshot(2).fire_control.is_empty(), "Other peers do not receive the shooter's fire-control preview")
	sim.world.aim_arc(state.fire_control)
	_check(sim.world.arc_preview.visible and sim.world.arc_mesh.get_surface_count() == 1, "Native arc preview consumes authority points")
	sim.world.aim_arc({})
	_check(not sim.world.arc_preview.visible, "Leaving lob aiming hides the preview")
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1, "Duplicate lob launch preserves the fire-rate budget")
	for frame in range(600):
		if sim.projectiles.is_empty():
			break
		sim.clock += 1.0 / 60
		sim._tick_projectiles(1.0 / 60)
	_check(sim.projectiles.is_empty() and target.hp < health, "Ground shell settles damage only after native flight and collision")
	actor.position = _ground_point(sim, 0, 0.1, 0)
	var close_distance: float = def.r * Content.constants.BALLISTIC.LOB_MIN_F * 0.5
	var floor_point := _ground_point(sim, 0, 0, -close_distance)
	direction = floor_point - actor.eye()
	actor.yaw = 0
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	actor.ammo.heavy = def.mag
	actor.power = actor.max_power
	actor.fire_at.clear()
	actor.reload_at.clear()
	actor.shield = 0
	actor.hp = actor.max_hp
	var ally := sim.spawn({"kind": "soldier", "side": actor.side, "position": _ground_point(sim, 0, 0.1, -close_distance)})
	ally.hp = 10000
	ally.armor = 0
	var own_health := actor.hp
	var ally_health := ally.hp
	var funds := actor.money
	var score := actor.score
	await get_tree().physics_frame
	await get_tree().physics_frame
	control = sim.lob_control(actor, def)
	_check(control.close, "Source fire control marks the minimum-range self-damage warning")
	sim.fire(actor, "heavy")
	for frame in range(180):
		if sim.projectiles.is_empty():
			break
		sim.clock += 1.0 / 60
		sim._tick_projectiles(1.0 / 60)
	_check(actor.hp < own_health and ally.hp < ally_health, "Close lob collision damages both shooter and allies")
	sim.damage(actor, ally, {}, 100000, true)
	_near(actor.money, funds, "Friendly lethal damage cannot award a bounty")
	_near(actor.score, score, "Friendly lethal damage cannot award score")
	# A flying target must be directly under the crosshair to enable the AA solver.
	var aircraft := sim.spawn({"kind": "heli", "side": "SWARM", "position": _ground_point(sim, 0, 25, -80)})
	direction = aircraft.position + Vector3.UP * aircraft.height / 2 - actor.eye()
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	await get_tree().physics_frame
	await get_tree().physics_frame
	control = sim.lob_control(actor, def)
	_check(control.aa and absf(control.speed - def.projectile.antiAirSpeed) < 0.001, "Crosshair aircraft enables source AA launch speed")
	actor.yaw = PI / 2
	control = sim.lob_control(actor, def)
	_check(not control.aa, "Aircraft away from the crosshair cannot pull the ground aim into AA mode")
	sim.queue_free()
	await get_tree().process_frame

func _reference_vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _line_reference_tests(fixtures: Array) -> void:
	for fixture in fixtures:
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level))
		var targets: Array = fixture.targets.duplicate(true)
		for target in targets:
			target.position = _reference_vector(target.position)
		var hits := CombatMath.line_hits(def, _reference_vector(fixture.origin), _reference_vector(fixture.direction), fixture.length, targets)
		var label: String = fixture.character + ": " + fixture.name
		_check(hits.size() == fixture.hits.size(), "Source line selection count: " + label)
		for index in range(mini(hits.size(), fixture.hits.size())):
			for key in ["id", "zone", "rank", "repeat"]:
				_check(hits[index][key] == fixture.hits[index][key], "Source line " + key + ": " + label)
			var error: float = absf(hits[index].amount - fixture.hits[index].amount)
			maximum_line_error = maxf(maximum_line_error, error)
			_check(error < maxf(0.000001, absf(fixture.hits[index].amount) * 0.000001), "Source line damage within native precision: " + label + " error=" + str(error))

func _settlement_range_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	sim.set_physics_process(false)
	var actor := BattleUnit.new()
	sim.add_child(actor)
	actor.configure({"id": 1, "kind": "robot", "character": "t04", "side": "STEEL", "position": Vector3.ZERO})
	for fixture in fixtures:
		actor.position.y = fixture.ground + fixture.height
		actor.buffs.clear()
		if fixture.has("modifier"):
			actor.buffs.append({"until": fixture.modifier.expiry, "mul": {"range": fixture.modifier.factor}})
		var target := BattleUnit.new()
		sim.add_child(target)
		var character := "s06" if fixture.kind == "robot" else ""
		var altitude := 26 if fixture.kind in ["robot", "heli"] else 0
		target.configure({"id": 2, "kind": fixture.kind, "character": character, "side": "SWARM",
			"position": Vector3(10, fixture.targetGround + altitude, 0)})
		var frame := sim._shooter_frame(actor, fixture.ground)
		var factor := sim._settlement_range_factor(actor, Content.weapon("t04", fixture.slot), actor.view_origin(), fixture.ground, target, fixture.targetGround, frame)
		_near(factor, fixture.factor, "Source impact range uses matching height frames and excludes expired buffs")
		var fired_eye := actor.view_origin()
		actor.position += Vector3(300, 250, -400)
		var captured := sim._settlement_range_factor(actor, Content.weapon("t04", fixture.slot), fired_eye + Vector3(5, -20, -10), fixture.ground, target, fixture.targetGround, frame)
		_near(captured, fixture.factor, "Source shooter height frame survives movement and a different muzzle origin")
		target.free()
	sim.queue_free()
	await get_tree().process_frame

func _kinetic_reference_tests(fixtures: Array) -> void:
	var range_rejections := 0
	for fixture in fixtures:
		var geometry := _lob_geometry(fixture)
		for body in fixture.bodies:
			var area := Area3D.new()
			area.collision_layer = 2
			area.collision_mask = 0
			area.monitoring = false
			area.set_meta("entity", int(body.id))
			geometry.add_child(area)
			area.position = _reference_vector(body.position)
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = _reference_vector(body.size)
			collider.shape = shape
			area.add_child(collider)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var def := Content.weapon(fixture.character, fixture.slot, int(fixture.level))
		var state := ProjectileMotion.ballistic(_reference_vector(fixture.origin), _reference_vector(fixture.velocity), def.range)
		var hit := {}
		var frames := 0
		while frames < 4000:
			frames += 1
			var previous := ProjectileMotion.advance(state, def, fixture.delta)
			var segment: Vector3 = state.position - previous
			var mask := 1 if def.area == "line" else 1 | 2
			var query := PhysicsRayQueryParameters3D.create(previous, state.position + segment.normalized() * 0.3, mask)
			query.hit_back_faces = true
			query.collide_with_areas = true
			hit = get_viewport().world_3d.direct_space_state.intersect_ray(query)
			if ProjectileMotion.finish(state, def, not hit.is_empty()):
				break
		var label: String = fixture.character + ": " + fixture.name
		_check(frames == fixture.frames, "Source kinetic collision/range termination frame: " + label)
		_check(not state.dud, "Kinetic range termination never creates a lingering dud")
		var error: float = state.position.distance_to(_reference_vector(fixture.state.position))
		maximum_kinetic_error = maxf(maximum_kinetic_error, error)
		_check(error < 0.001, "Source kinetic integrated position: " + label + " error=" + str(error))
		if def.area == "line":
			_check(fixture.report != null and fixture.report.t == "lance", "Source penetrating shell ignores intervening bodies")
			var endpoint: Vector3 = hit.position if not hit.is_empty() else state.position
			_check(endpoint.distance_to(_reference_vector(fixture.report.point)) < 0.001, "Source kinetic penetration endpoint: " + label)
		elif fixture.report != null:
			_check(not hit.is_empty() and hit.collider is Area3D and hit.collider.get_meta("entity") == int(fixture.report.id), "Source kinetic first body: " + label)
		if def.area != "line" and not hit.is_empty() and hit.collider is Area3D:
			var id: int = hit.collider.get_meta("entity")
			var body: Dictionary = fixture.bodies.filter(func(value): return int(value.id) == id)[0]
			var radius: float = Content.balance.unitVolumes.soldier.SWARM.radius
			var allowed := CombatMath.direct_in_range(def.range * Content.constants.RANGE_TOL, _reference_vector(body.position) - _reference_vector(fixture.origin), radius)
			_check(allowed == (fixture.report != null), "Source physical body outside damage range rejects its hit report: " + label)
			range_rejections += 1 if not allowed else 0
		geometry.free()
	_check(range_rejections > 0, "Source kinetic fixtures exercise physical collision without a valid damage report")

func _kinetic_settlement_tests() -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 1, "side": "STEEL", "character": "t04", "bot": false},
		{"peer": 2, "side": "SWARM", "character": "s06", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_kinetic_settlement_tests"):
		return
	sim.set_physics_process(false)
	for unit: BattleUnit in sim.units.values():
		if not unit.is_hero():
			sim.units.erase(unit.entity_id)
			unit.free()
	var actor: BattleUnit = sim.pilots[1]
	var front: BattleUnit = sim.pilots[2]
	actor.position = Vector3(0, 80, 0)
	actor.yaw = 0
	actor.pitch = 0
	actor.input_state = {"aim": true}
	front.position = Vector3(0, 80, -35)
	front.shield = 0
	var rear := sim.spawn({"kind": "robot", "character": "s07", "side": "SWARM", "position": Vector3(0, 80, -65)})
	rear.shield = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	var front_health := front.hp
	var rear_health := rear.hp
	var magazine: float = actor.ammo.light
	sim.fire(actor, "light")
	_check(sim.projectiles.size() == 1, "Slow kinetic light weapon launches a physical round")
	_near(front.hp, front_health, "Light kinetic damage waits for flight")
	_near(actor.ammo.light, magazine - 1, "Kinetic launch spends ammunition once")
	sim.fire(actor, "light")
	_check(sim.projectiles.size() == 1, "Duplicate kinetic launch respects fire rate")
	actor.position.x = 100
	actor.yaw = PI
	for frame in range(60):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_check(sim.projectiles.is_empty() and front.hp < front_health, "Kinetic round retains the firing origin and direction when shooter moves")
	_near(rear.hp, rear_health, "Ordinary kinetic round stops at the first enemy")
	actor.position = Vector3(0, 80, 0)
	actor.yaw = 0
	front_health = front.hp
	rear_health = rear.hp
	var power := actor.power
	magazine = actor.ammo.heavy
	var def := Content.weapon(actor.character, "heavy")
	sim.fire(actor, "heavy")
	_near(front.hp, front_health, "Penetrating kinetic launch does not damage the first body immediately")
	_near(actor.ammo.heavy, magazine - 1, "Penetrating kinetic launch spends one round")
	_near(actor.power, power - def.heavyMp, "Penetrating kinetic launch spends power once")
	sim._tick_projectiles(1.0 / 60)
	_near(front.hp, front_health, "Penetrating shell does not settle before its trajectory ends")
	for frame in range(60):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_check(sim.projectiles.is_empty() and front.hp < front_health and rear.hp < rear_health, "Kinetic line settles front and rear bodies together at termination")
	var settled := front.hp
	sim._tick_projectiles(1.0 / 60)
	_near(front.hp, settled, "A terminated kinetic line cannot settle twice")
	var wall := StaticBody3D.new()
	sim.add_child(wall)
	wall.position = Vector3(0, 80, -20)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 30, 1)
	collision.shape = shape
	wall.add_child(collision)
	actor.fire_at.clear()
	actor.ammo.heavy = def.mag
	actor.power = actor.max_power
	front_health = front.hp
	rear_health = rear.hp
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	for frame in range(60):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_near(front.hp, front_health, "Kinetic penetration terminates at a thin native wall")
	_near(rear.hp, rear_health, "Penetration cannot settle bodies behind its wall endpoint")
	var beam := sim.spawn({"kind": "robot", "character": "t05", "side": "STEEL", "position": Vector3(0, 80, 0)})
	beam.yaw = 0
	beam.pitch = 0
	beam.input_state = {"aim": true}
	sim.fire(beam, "heavy")
	_near(front.hp, front_health, "Instant line shares the native obstruction endpoint")
	wall.free()
	actor.fire_at.clear()
	actor.ammo.light = Content.weapon(actor.character, "light").mag
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "light")
	actor.hp = 0
	_check(sim.visible_to_side(front, actor.side), "Living ally preserves the dead shooter's target observation")
	for frame in range(60):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(1.0 / 60)
	_near(front.hp, front_health, "Dead shooter cannot settle an in-flight impact report")
	sim.authoritative = false
	magazine = actor.ammo.heavy
	sim.fire(actor, "heavy")
	_near(actor.ammo.heavy, magazine, "Clients cannot launch authority kinetic rounds")
	sim.queue_free()
	await get_tree().process_frame

func _friendly_core_tests(fixtures: Array) -> void:
	for fixture in fixtures:
		var sim := BattleSimulation.new()
		add_child(sim)
		sim.set_physics_process(false)
		var character: String = Content.heroes.keys().filter(func(id): return Content.heroes[id].side == fixture.side)[0]
		var actor := BattleUnit.new()
		sim.add_child(actor)
		actor.configure({"id": 1, "kind": Content.heroes[character].kind, "side": fixture.side,
			"character": character, "position": Vector3.ZERO})
		var core := sim.spawn({"id": 2, "kind": "base", "side": fixture.side, "position": Vector3.ZERO})
		var funds := actor.money
		var score := actor.score
		sim.damage(actor, core, {}, 1000000000, true)
		_check(sim.over == fixture.over and sim.winner == fixture.winner, "Source friendly core destruction awards victory to the opposing faction")
		_near(actor.money, funds, "Friendly core destruction cannot award a bounty")
		_near(actor.score, score, "Friendly core destruction cannot award score")
		sim.queue_free()
		await get_tree().process_frame

func _projectile_vector(actual: Vector3, expected: Array, label: String) -> void:
	var error := actual.distance_to(_reference_vector(expected))
	maximum_projectile_error = maxf(maximum_projectile_error, error)
	_check(error < 0.001, "Source projectile vector within native precision: " + label + " error=" + str(error))

func _projectile_reference_tests(fixtures: Dictionary) -> void:
	for fixture in fixtures.projectileLaunches:
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level)).duplicate(true)
		if fixture.antiAir:
			def.projectile.speed = def.projectile.antiAirSpeed
		var state := ProjectileMotion.launch(def, _reference_vector(fixture.origin), _reference_vector(fixture.direction), 0,
			fixture.rolls[0], fixture.rolls[1], Vector3.ZERO)
		_projectile_vector(state.velocity, fixture.velocity, "launch " + fixture.character)
		_near(state.launch_distance, fixture.distance, "Source height-dependent launch distance")
	for fixture in fixtures.projectileFlight:
		var def := Content.weapon(fixture.character, "heavy", int(fixture.level)).duplicate(true)
		if fixture.antiAir:
			def.projectile.speed = def.projectile.antiAirSpeed
		def.projectile.fuel = fixture.fuel
		var state: Dictionary = fixture.steps[0].before.duplicate(true)
		for key in ["position", "origin", "velocity", "guide_point", "home_point"]:
			state[key] = _reference_vector(state[key])
		for step in fixture.steps:
			var target: Dictionary = step.target.duplicate(true)
			if not target.is_empty():
				target.position = _reference_vector(target.position)
			var previous := ProjectileMotion.advance(state, def, fixture.delta, target)
			var hit: bool = step.physicalHit or not ProjectileMotion.proximity(state, def, previous, target).is_empty()
			var done := ProjectileMotion.finish(state, def, hit)
			var label: String = fixture.character + ": " + fixture.name
			for key in ["position", "velocity", "home_point"]:
				_projectile_vector(state[key], step.after[key], label + " " + key)
			for key in ["age", "home_radius"]:
				_near(state[key], step.after[key], "Source projectile " + key)
			for key in ["chase", "last_known", "dud"]:
				_check(state[key] == step.after[key], "Source projectile " + key + ": " + label)
			_check(done == step.done, "Source collision/range/fuel termination: " + label)
			_check((done and hit and not state.dud) == step.burst, "Source collision-first explosion: " + label)

func _blast_volume_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	sim.set_physics_process(false)
	var attacker := BattleUnit.new()
	sim.add_child(attacker)
	attacker.configure({"id": 1, "kind": "soldier", "side": "STEEL", "position": Vector3.ZERO})
	for fixture in fixtures:
		var target := BattleUnit.new()
		sim.add_child(target)
		target.configure({"id": 2, "kind": fixture.kind, "side": fixture.get("side", "SWARM"), "character": fixture.character, "position": Vector3.ZERO})
		target.hp = 10000
		target.shield = 0
		target.armor = 0
		sim.units = {2: target}
		# The source capture stubs `_damage` at entry; the attacking creep satisfies the
		# separate base-siege support rule so HP loss still equals that entry amount.
		if fixture.kind == "base":
			sim.units[1] = attacker
		sim.blast(attacker, {"dmg": 100, "r": fixture.radius, "vsSp": 1, "vsHp": 1}, _reference_vector(fixture.impact), fixture.get("friendly", false))
		_check(absf(10000 - target.hp - fixture.amount) < 0.0001, "Source blast measures horizontal surface and vertical body band: " + fixture.kind)
		target.free()
	sim.units.clear()
	sim.queue_free()
	await get_tree().process_frame

func _projectile_settlement_tests() -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [
		{"peer": 1, "side": "STEEL", "character": "t09", "bot": false},
		{"peer": 2, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_projectile_settlement_tests"):
		return
	sim.set_physics_process(false)
	var actor: BattleUnit = sim.pilots[1]
	var target: BattleUnit = sim.pilots[2]
	actor.position = _ground_point(sim, 0, 80, 0)
	target.position = _ground_point(sim, 0, 80, -100)
	target.shield = 0
	var direction := target.eye() - actor.eye()
	actor.yaw = atan2(-direction.x, -direction.z)
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	actor.input_state = {"aim": true}
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ammo: float = actor.ammo.heavy
	var power := actor.power
	var health := target.hp
	var def := Content.weapon(actor.character, "heavy")
	var combat_rng_state := sim.rng.state
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1 and sim.projectiles[0].target == target.entity_id, "Authority locks only the launch-time aimed enemy")
	_near(target.hp, health, "Missile does not settle damage on launch")
	_near(actor.ammo.heavy, ammo - 1, "Launch spends ammo once")
	_near(actor.power, power - def.heavyMp, "Launch spends power once")
	_check(sim.rng.state == combat_rng_state, "Launch spread preserves the settlement RNG stream")
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1, "Duplicate launch respects the fire-rate budget")
	for frame in range(16):
		sim._tick_projectiles(0.05)
	var observer := sim.spawn({"kind": "soldier", "side": actor.side, "position": _ground_point(sim, 0, 80, -200)})
	actor.input_state = {}
	actor.position.x = 300
	actor.upgrades.hw = 3
	_near(sim.projectiles[0].definition.dmg, def.dmg, "In-flight warhead retains its launch tier")
	target.position.z = -210
	await get_tree().physics_frame
	sim.authoritative = false
	var before: Vector3 = sim.projectiles[0].position
	sim._tick_projectiles(0.05)
	_check(sim.projectiles[0].position == before, "Client cannot advance authority warheads")
	sim.authoritative = true
	for frame in range(160):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(0.05)
	_check(sim.projectiles.is_empty() and target.hp < health, "Locked missile follows beyond launch range after shooter moves and leaves aim")
	var settled := target.hp
	sim._tick_projectiles(0.05)
	_near(target.hp, settled, "Removed warhead cannot duplicate damage")
	# Losing team sight must not give the authority missile omniscient target updates.
	actor.position = _ground_point(sim, 0, 80, 0)
	target.position = _ground_point(sim, 0, 80, -100)
	actor.yaw = 0
	actor.pitch = 0
	actor.input_state = {"aim": true}
	actor.ammo.heavy = Content.weapon(actor.character, "heavy", 4).mag
	actor.power = actor.max_power
	actor.fire_at.clear()
	actor.reload_at.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	for frame in range(16):
		sim._tick_projectiles(0.05)
	var last_known: Vector3 = sim.projectiles[0].home_point
	target.position.z = -600
	observer.hp = 0
	await get_tree().physics_frame
	sim._tick_projectiles(0.05)
	_check(sim.projectiles[0].home_point == last_known and sim.projectiles[0].last_known, "Hidden target is pursued only at its last observed point")
	sim.projectiles.clear()
	# A guided launcher freezes a point, independently of later aim or target movement.
	actor = sim.pilots[2]
	actor.position = _ground_point(sim, 0, 80, 0)
	actor.yaw = 0
	actor.pitch = 0
	actor.input_state = {"aim": true}
	sim.clock += 1
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	_check(sim.projectiles.size() == 1, "Laser-guided launcher creates a physical warhead")
	var frozen: Vector3 = sim.projectiles[0].guide_point
	actor.yaw = PI
	actor.position.x = 100
	sim._tick_projectiles(0.05)
	_check(sim.projectiles[0].guide_point == frozen and sim.projectiles[0].target == 0, "Laser target point is frozen at launch")
	sim.projectiles.clear()
	actor.position = _ground_point(sim, 0, 80, 0)
	target = sim.pilots[1]
	target.position = _ground_point(sim, 0, 80, -60)
	direction = target.eye() - actor.eye()
	actor.yaw = 0
	actor.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	actor.ammo.heavy = Content.weapon(actor.character, "heavy").mag
	actor.fire_at.clear()
	actor.reload_at.clear()
	actor.power = actor.max_power
	await get_tree().physics_frame
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	_near(sim.projectiles[0].definition.projectile.speed, Content.weapon(actor.character, "heavy").projectile.antiAirSpeed, "Laser-guided launchers share source crosshair AA speed selection")
	sim.projectiles.clear()
	actor.position = _ground_point(sim, 0, 80, 0)
	actor.yaw = 0
	actor.pitch = 0
	actor.ammo.heavy = Content.weapon(actor.character, "heavy").mag
	actor.fire_at.clear()
	actor.reload_at.clear()
	actor.power = actor.max_power
	target = sim.pilots[1]
	target.position = _ground_point(sim, 0, 80, -50)
	target.shield = 0
	var wall := StaticBody3D.new()
	sim.add_child(wall)
	wall.position = _ground_point(sim, 0, 80, -10)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 20, 1)
	collision.shape = shape
	wall.add_child(collision)
	await get_tree().physics_frame
	await get_tree().physics_frame
	health = target.hp
	sim.fire(actor, "heavy")
	for frame in range(10):
		if sim.projectiles.is_empty():
			break
		sim._tick_projectiles(0.05)
	_check(sim.projectiles.is_empty(), "Swept native collision catches a thin wall between flight frames")
	_near(target.hp, health, "Guided warhead cannot damage a distant enemy through its first obstruction")
	wall.free()
	actor.position.x = map_data.bounds.maxX + 100
	actor.ammo.heavy = Content.weapon(actor.character, "heavy").mag
	actor.fire_at.clear()
	ammo = actor.ammo.heavy
	power = actor.power
	await get_tree().physics_frame
	sim.fire(actor, "heavy")
	_check(sim.projectiles.is_empty(), "Unverified launch surface rejects the warhead")
	_near(actor.ammo.heavy, ammo, "Unverified launch surface rejects before spending ammo")
	_near(actor.power, power, "Unverified launch surface rejects before spending power")
	sim.queue_free()
	await get_tree().process_frame

func _visibility_tests(fixtures: Array) -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	sim.set_physics_process(false)
	for kind in ["robot", "drone", "soldier", "tower", "base"]:
		var character := ""
		if kind in ["robot", "drone"]:
			for id in Content.heroes:
				if Content.heroes[id].kind == kind:
					character = id
					break
		var observer := VisibilityUnit.new()
		sim.add_child(observer)
		observer.configure({"id": 1, "side": "STEEL", "kind": kind, "character": character, "position": Vector3.ZERO})
		var target := VisibilityUnit.new()
		sim.add_child(target)
		target.configure({"id": 2, "side": "SWARM", "kind": "heli", "position": Vector3.ZERO})
		sim.units = {1: observer, 2: target}
		sim.pilots = {1: observer}
		for fixture in fixtures:
			if fixture.kind != kind:
				continue
			observer.input_state = {"aim": fixture.aiming}
			target.position = Vector3(fixture.distance, fixture.height, 0)
			_near(observer.sight_radius(), fixture.radius, "Source aiming sight radius")
			_near(observer.sight_origin().y, fixture.eye, "Source LOS observer height")
			_near(target.sight_target().y, fixture.target, "Source LOS target height")
			var shown := sim.visible_to_side(target, observer.side)
			_check(shown == fixture.result, "Source planar team vision ignores target altitude")
			sim.events = [{"type": "shot", "actor": target.entity_id}]
			var state := sim.snapshot(1)
			_check(state.units.size() == (2 if shown else 1), "Snapshot uses shared team visibility")
			_check(state.events.size() == (1 if shown else 0), "Hidden enemy shots do not leak")
			sim.apply_presentation_view(state)
			_check(target.visible == shown, "Authority presentation matches filtered snapshot")
			_check(sim.units.size() == 2 and target.hp == target.max_hp, "Hidden authority actors retain simulation state")
		observer.free()
		target.free()
	sim.units.clear()
	sim.pilots.clear()
	sim.queue_free()
	await get_tree().process_frame

func _occlusion_tests(fixtures: Array) -> void:
	for fixture in fixtures:
		var body := StaticBody3D.new()
		add_child(body)
		var collision := CollisionShape3D.new()
		if fixture.has("box"):
			var spec: Dictionary = fixture.box
			var shape := BoxShape3D.new()
			shape.size = Vector3(spec.size[0], spec.size[1], spec.size[2])
			collision.shape = shape
			body.position = Vector3(spec.position[0], spec.position[1], spec.position[2])
			body.rotation.y = spec.rotation
		else:
			var faces := PackedVector3Array()
			for point in fixture.faces:
				faces.append(Vector3(point[0], point[1], point[2]))
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			shape.backface_collision = true
			collision.shape = shape
		body.add_child(collision)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var start := Vector3(fixture.start[0], fixture.start[1], fixture.start[2])
		var end := Vector3(fixture.end[0], fixture.end[1], fixture.end[2])
		var query := PhysicsRayQueryParameters3D.create(start, end, 1)
		query.hit_back_faces = true
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty() == fixture.result, "Source box/roof LOS including undersides and openings: " + str(fixture.start) + " -> " + str(fixture.end) + " expected=" + str(fixture.result))
		if not hit.is_empty() and fixture.fraction != null:
			_check(absf(start.distance_to(hit.position) / start.distance_to(end) - fixture.fraction) < 0.00001, "Native obstruction matches source ray intersection")
		body.free()

func _combat_visibility_tests() -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var map_data := Content.map_variant(0, 1)
	await sim.setup(map_data, [{"peer": 1, "side": "SWARM", "character": "s04", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_combat_visibility_tests"):
		return
	sim.set_physics_process(false)
	sim.next_wave = INF
	var player: BattleUnit = sim.pilots[1]
	for actor: BattleUnit in sim.units.values():
		if actor != player:
			sim.units.erase(actor.entity_id)
			actor.free()
	# A drone hero cannot settle below the authority hover floor on real terrain.
	player.position = _ground_point(sim, 0, Content.constants.FLIGHT.HOVER_M, 0)
	player.yaw = 0
	player.pitch = 0
	player.input_state = {"received": sim.clock}
	var near := sim.spawn({"kind": "tower", "side": "STEEL", "position": _ground_point(sim, 0, 0.1, -35)})
	var rear := sim.spawn({"kind": "tower", "side": "STEEL", "position": _ground_point(sim, 0, 0.1, -70)})
	await get_tree().physics_frame
	await get_tree().physics_frame
	var near_hp := near.hp
	var rear_hp := rear.hp
	sim.fire(player, "light")
	_check(near.hp < near_hp, "Authority fan damages nearest per-bin target")
	_near(rear.hp, rear_hp, "Front target screens the rear target even after building hit cap")
	var wall := StaticBody3D.new()
	sim.add_child(wall)
	wall.position = _ground_point(sim, 0, 20, -15)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 40, 4)
	collision.shape = shape
	wall.add_child(collision)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not sim.visible_to(player, near), "Native wall blocks source sight sample points")
	near_hp = near.hp
	sim.clock += 1
	sim.fire(player, "light")
	_near(near.hp, near_hp, "Authority fan cannot shoot through a wall")
	sim.blast(player, {"dmg": 10, "r": 5, "vsSp": 1, "vsHp": 1}, near.eye())
	_check(near.hp < near_hp, "Blast retains deliberate coverage through LOS blockers")
	wall.free()
	var enemy := sim.spawn({"kind": "soldier", "side": "STEEL", "position": _ground_point(sim, 0, 0.1, -40)})
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(sim.visible_to_side(enemy, player.side), "Enemy is visible inside shared team sight")
	var state := sim.snapshot(1)
	sim.apply_presentation_view(state)
	_check(enemy.visible, "Host presents a spotted enemy")
	enemy.position.z = -1000
	sim.apply_presentation_view(sim.snapshot(1))
	_check(not enemy.visible, "Host hides an enemy leaving team sight")
	sim._physics_process(0.01)
	_check(not enemy.visible and sim.units.has(enemy.entity_id), "Authority physics preserves hidden presentation and live actor")
	enemy.position = _ground_point(sim, 0, 0.1, -40)
	sim.apply_presentation_view(sim.snapshot(1))
	_check(enemy.visible, "Enemy entering sight reappears without respawning")
	player.hp = 0
	_check(not sim.visible_to_side(enemy, player.side), "Dead observers do not provide sight")
	player.hp = player.max_hp
	var ally := sim.spawn({"kind": "soldier", "side": player.side, "position": Vector3(0, 0.1, -950)})
	enemy.position.z = -1000
	_check(sim.visible_to_side(enemy, player.side), "Remote ally shares planar team vision")
	ally.hp = 0
	_check(not sim.visible_to_side(enemy, player.side), "Dead remote ally loses team vision")
	var magazine: float = player.ammo.light
	sim.authoritative = false
	sim.clock += 10
	sim.fire(player, "light")
	_near(player.ammo.light, magazine, "Client fire cannot spend ammo or settle damage")
	sim.authoritative = true
	sim.queue_free()
	await get_tree().process_frame

func _settlement_tests() -> void:
	var sim := BattleSimulation.new()
	add_child(sim)
	var fixture_map := Content.map_variant(0, 1)
	await sim.setup(fixture_map, [
		{"peer": 1, "side": "STEEL", "character": "t01", "bot": false},
		{"peer": 2, "side": "SWARM", "character": "s01", "bot": false}], {"time": "day", "weather": "clear"}, true)
	if not _require_prepared_match(sim, "_settlement_tests"):
		return
	sim.set_physics_process(false)
	var player: BattleUnit = sim.pilots[1]
	var enemy: BattleUnit = sim.pilots[2]
	await get_tree().physics_frame
	var starting_money := player.money
	_check(sim.buy(player, "lw"), "First tier purchase with source eligibility")
	_near(player.money, starting_money - Content.constants.ECON.UPG_STEPS[0].price, "Server charges exactly once")
	_check(not sim.buy(player, "lw"), "Score threshold rejects a second tier")
	_near(player.score, 0, "Purchase does not spend battle score")
	player.money = 10000
	player.score = 100
	player.position = _ground_point(sim, 0, 0.1, 0)
	_check(sim.buy(player, "hp"), "Source upgrade purchases remain available away from the base")
	_check(not sim.buy(player, "forged_item"), "Unknown upgrade rejected")
	sim.submit_input(1, {"move": Vector2(1000, -1000), "yaw": 0.0, "pitch": 100.0})
	_check(player.input_state.move.length() <= 1.000001, "Movement magnitude clamped")
	_check(player.input_state.pitch <= 1.45, "Pitch clamped")
	var before: Dictionary = player.input_state.duplicate()
	sim.submit_input(1, {"move": Vector2(NAN, 0), "yaw": 0.0, "pitch": 0.0})
	_check(player.input_state == before, "Nonfinite movement rejected")
	sim.submit_input(1, {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "vertical": []})
	_check(player.input_state == before, "Malformed vertical input rejected")
	var health := enemy.hp
	sim.authoritative = false
	sim.damage(player, enemy, {"vsSp": 1, "vsHp": 1}, 999999)
	_near(enemy.hp, health, "Client damage does not settle HP")
	sim.authoritative = true
	var own_health := player.hp
	sim.damage(player, player, {}, 999999)
	_near(player.hp, own_health, "Friendly shot rejected")
	player.ammo.light = 0
	sim.reload_weapon(player, "light")
	var reload_time: float = player.reload_at.light
	sim.reload_weapon(player, "light")
	_near(player.reload_at.light, reload_time, "Repeated reload cannot extend deadline")
	sim.clock = reload_time + 0.01
	player.input_state = {"yaw": 0.0, "pitch": 0.0}
	sim.fire(player, "light")
	var magazine: float = Content.weapon(player.character, "light", 2).mag
	_near(player.ammo.light, magazine - 1, "Reload refills lazily before firing")
	sim.fire(player, "light")
	_near(player.ammo.light, magazine - 1, "Fire rate rejects same-frame duplicate")
	player.position = _ground_point(sim, 0, 0.1, 0)
	enemy.position = _ground_point(sim, 0, 0.1, -10)
	var direction := enemy.eye() - player.eye()
	player.yaw = atan2(-direction.x, -direction.z)
	player.pitch = atan2(direction.y, Vector2(direction.x, direction.z).length())
	_check(player.aim_direction().dot(direction.normalized()) > 0.99999, "Native pitch convention targets the correct altitude")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shield_before := enemy.shield
	sim.clock += 1
	sim.fire(player, "light")
	_near(enemy.shield, shield_before, "Kinetic launch does not settle immediate damage")
	sim._tick_projectiles(1.0 / 60)
	_check(enemy.shield < shield_before, "Native kinetic sweep damages the aimed enemy")
	sim.damage(player, enemy, {"vsSp": 1, "vsHp": 1}, 999999)
	_check(not enemy.alive() and enemy.respawn_at > sim.clock, "Server schedules hero respawn")
	sim.respawn(enemy)
	_near(enemy.hp, enemy.max_hp, "Respawn restores HP")
	_near(enemy.shield, enemy.max_shield, "Respawn restores shields")
	var enemy_base: BattleUnit
	for unit: BattleUnit in sim.units.values():
		if unit.kind == "base" and unit.side == "SWARM":
			enemy_base = unit
	sim.damage(player, enemy_base, {}, 9999999)
	_check(sim.over and sim.winner == "STEEL", "Server settles battle outcome")
	var money_after := player.money
	sim.damage(player, enemy_base, {}, 9999999)
	_near(player.money, money_after, "Repeated lethal reports cannot duplicate bounty")
	sim.queue_free()
	await get_tree().process_frame
