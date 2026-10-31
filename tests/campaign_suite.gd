extends RefCounted

const StatusHelper = preload("res://tests/status_suite.gd")
const SessionScript = preload("res://scripts/session.gd")

static func run(h: Node, fixtures: Dictionary) -> void:
	for key: String in ["campaignProgress", "campaignDeployments", "campaignLineTiming", "campaignCamera", "campaignFocus", "campaignLeaders", "campaignSpawns"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original campaign oracle: " + key)
			return
	for input: Dictionary in fixtures.campaignProgress:
		var save := CampaignProgress.new()
		save.path = "res://tests/campaign-save-fixture.cfg"
		save.cleared[input.side] = input.initial.duplicate()
		var unlocked: Array = []
		var seen: Array = []
		for index in range(Content.campaign.chapters.size()):
			unlocked.append(save.unlocked(input.side, index))
			seen.append(save.has_seen(input.side, Content.campaign.chapters[index].id))
		StatusHelper.compare(h, unlocked, input.before.unlocked, "Original previous-chapter unlock per faction")
		StatusHelper.compare(h, seen, input.before.seen, "Original cleared chapters bypass intro replay")
		for repeat in range(2):
			h._check(save.mark_seen(input.side, "ch2") == OK and save.mark_cleared(input.side, "ch1") == OK, "Native campaign persistence succeeds")
		StatusHelper.compare(h, save.cleared[input.side], input.cleared, "Original once-only cleared IDs")
		StatusHelper.compare(h, save.seen[input.side], input.seen, "Original once-only intro IDs")
		StatusHelper.compare(h, save.cleared["SWARM" if input.side == "STEEL" else "STEEL"], input.other, "Campaign saves keep faction progress separate")
		var restored := CampaignProgress.new()
		restored.load_save(save.path)
		StatusHelper.compare(h, restored.cleared, save.cleared, "Native cleared progress survives ConfigFile reload")
		StatusHelper.compare(h, restored.seen, save.seen, "Native intro progress survives ConfigFile reload")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.path))
	for input: Dictionary in fixtures.campaignDeployments:
		var settings := CampaignRules.settings(int(input.index), input.side, input.pilot)
		StatusHelper.compare(h, CampaignRules.roster(int(input.index), input.side, input.pilot), input.roster, "Original launchStoryBattle assigned allies/enemies and Bot ID order")
		h._check(int(settings.team_size) == int(input.team_size), "Original per-chapter team size")
		h._check(settings.env.bot_difficulty == input.difficulty, "Original progressive story difficulty")
		for key: String in input.env:
			StatusHelper.compare(h, settings.env[key], input.env[key], "Original authored chapter environment " + key)
		for swapped in [false, true]:
			var map := Content.campaign_map(int(input.index), input.side, swapped)
			h._check(not map.is_empty() and map.config.defSide == input.defender and map.config.siege and map.lanes.size() == 1, "Original asymmetric single-lane campaign map")
			var towers: Array = map.structures.filter(func(actor): return actor.kind == "tower")
			h._check(towers.size() == 4 and towers.all(func(actor): return actor.side == input.defender), "Original defender has front/middle pairs; attacker has no towers")
		var session := SessionScript.new()
		h.add_child(session)
		var emitted: Array = []
		session.battle_started.connect(func(config, roster): emitted.append({"config": config.duplicate(true), "roster": roster.duplicate(true)}))
		session.config = settings
		session.active = true
		session.seats.add(1, 1, "test-campaign-host", input.side, "player", input.pilot)
		session.seats.set_ready(1, true)
		session.roster = [{"peer": 1, "side": input.side, "character": input.pilot, "bot": false}]
		session.start_battle()
		h._check(emitted.size() == 1, "Shared native room lifecycle starts a campaign once")
		if emitted.size() == 1:
			StatusHelper.compare(h, emitted[0].roster, input.roster, "Campaign room keeps authored pilots instead of automatic character fill")
		session.start_battle()
		h._check(emitted.size() == 1, "Duplicate campaign start cannot allocate another Bot roster")
		session.snapshot_timer.stop()
		session.free()
	h._check(CampaignRules.roster(-1, "STEEL", "t01").is_empty() and CampaignRules.roster(0, "GUER", "t06").is_empty() and CampaignRules.roster(0, "STEEL", "t01").is_empty(), "Malformed/non-roster campaign selections reject before deployment")
	for input: Dictionary in fixtures.campaignLineTiming:
		h._near(CampaignRules.line_seconds(input.value), input.seconds, "Original dialogue UTF-16 length and clamped line duration")
	for input: Dictionary in fixtures.campaignCamera:
		var pose := CampaignRules.camera_pose(input.camera, input.progress, input.landscape)
		h._check(absf(float(pose.scale) - float(input.result.scale)) <= 0.00051 and absf(float(pose.x) - float(input.result.x)) <= 0.0051 and absf(float(pose.y) - float(input.result.y)) <= 0.0051, "Original cinematic pan/zoom within source CSS string precision")
	for input: Dictionary in fixtures.campaignFocus:
		var focus := CampaignRules.focus_section(input.scroll, input.height, input.sections, int(input.active))
		StatusHelper.compare(h, focus, input.result, "Original crawl focus chooses nearest section across gaps and zero-height sections")
	for input: Dictionary in fixtures.campaignLeaders:
		StatusHelper.compare(h, CampaignRules.leaders(input.lines, input.side, input.transcript), input.result, "Original frequency/stable tie/viewer-relative dialogue portrait selection")
	await dialogue_lifecycle(h)
	await native_deployment(h, fixtures.campaignSpawns)
	print("CAMPAIGN_REFERENCE_PASS deployments=", fixtures.campaignDeployments.size(), " camera=", fixtures.campaignCamera.size(), " dialogue=", fixtures.campaignLineTiming.size())

static func dialogue_lifecycle(h: Node) -> void:
	var dialogue := CampaignDialogue.new()
	# Radio timers re-arm until their wall-clock deadline, so a synthetic timeout must advance this clock first.
	var clock := {"now": 1000.0}
	dialogue.clock_msec = func(): return clock.now
	h.add_child(dialogue)
	dialogue.side = "STEEL"
	var scene := CampaignRules.talk(0, "STEEL", 0)
	dialogue.track(1)
	dialogue.radio(scene)
	h._check(dialogue.at == 1 and dialogue.total == scene.lines.size() and dialogue.mouse_filter == Control.MOUSE_FILTER_IGNORE and dialogue.bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Live radio auto-starts without intercepting gameplay")
	var old_timer: Timer = dialogue.timers[0]
	h._near(old_timer.wait_time, CampaignRules.line_seconds(scene.lines[0].t), "Radio uses original line duration")
	dialogue.clear()
	h._check(dialogue.at == 0 and dialogue.total == 0 and dialogue.timers.is_empty() and dialogue.track_label.visible, "Clearing dialogue cancels timers while preserving siege track")
	old_timer.timeout.emit()
	h._check(dialogue.at == 0 and dialogue.bar == null, "Cancelled generation cannot restore an old radio line")
	dialogue.radio(scene)
	var line_timer: Timer = dialogue.timers[0]
	var deadline: float = clock.now + line_timer.wait_time * 1000
	clock.now = deadline - .001
	line_timer.timeout.emit()
	h._check(dialogue.at == 1 and dialogue.timers.size() == 1 and dialogue.timers[0] == line_timer, "An early radio timeout is rearmed and cannot advance the line before its wall deadline")
	clock.now = deadline
	line_timer.timeout.emit()
	h._check(dialogue.at == 2, "Live radio advances by timer without manual gameplay input")
	line_timer.timeout.emit()
	h._check(dialogue.at == 2, "A delivered line deadline advances the radio only once")
	dialogue.dispose()
	h._check(not dialogue.track_label.visible and dialogue.timers.is_empty(), "Room exit disposes radio and stage track")
	dialogue.queue_free()
	await h.get_tree().process_frame

static func native_deployment(h: Node, references: Array) -> void:
	for input: Dictionary in references:
		var simulation := BattleSimulation.new()
		h.add_child(simulation)
		var settings := CampaignRules.settings(int(input.index), input.side, input.roster[0].character, input.swapped)
		var map := Content.campaign_map(int(input.index), input.side, input.swapped)
		h._check(Content.campaign_available(int(input.index), input.side), "Both original campaign orientations require native terrain resources " + input.map)
		if not Content.campaign_available(int(input.index), input.side):
			simulation.queue_free()
			await h.get_tree().process_frame
			continue
		await simulation.setup(map, input.roster, settings.env, true)
		simulation.set_physics_process(false)
		StatusHelper.compare(h, simulation.siege_left, input.siege_left, "Original campaign combined tower/base/BOSS stage roster")
		StatusHelper.compare(h, simulation.siege_open, input.siege_open, "Original starting assault stage")
		StatusHelper.compare(h, simulation.boss_left, input.boss_left, "Original campaign BOSS seat distribution")
		h._check(simulation.pilots.size() == input.players.size(), "Source single-body campaign pilot count")
		for expected: Dictionary in input.players:
			var player: BattleUnit = simulation.pilots[int(expected.peer)]
			h._check(player.character == expected.character and player.side == expected.side and player.is_bot == expected.bot, "Native campaign preserves every authored role")
			h._check(Vector2(player.position.x, player.position.z).distance_to(Vector2(expected.position[0], expected.position[1])) < 0.01, "Original campaign horizontal spawn/hold coordinates " + expected.character)
			h._check(absf(BotRules.wrap_pi(player.yaw - float(expected.yaw))) < 0.00001, "Original campaign spawn heading")
			for key: String in ["hp", "max_hp", "shield", "max_shield", "armor"]:
				h._near(player.get(key), expected[key], "Original BOSS capacity/source initial defenses " + key)
			h._check(bool(player.special.get("boss", false)) == bool(expected.boss) and int(player.special.get("siege_stage", -1)) == int(expected.stage), "Original campaign defender/stage binding")
			if expected.hold != null:
				var hold: Dictionary = simulation.bot_holds[int(expected.peer)]
				h._check(Vector2(hold.x, hold.z).distance_to(Vector2(expected.hold.x, expected.hold.z)) < 0.01, "Original BOSS activity centre")
				h._near(hold.r, expected.hold.r, "Original BOSS half-tower-range activity bound")
		simulation.queue_free()
		await h.get_tree().process_frame
