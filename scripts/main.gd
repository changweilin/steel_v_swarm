extends Node

const Minimap = preload("res://scripts/minimap.gd")

var touch_controls: NativeTouchControls
var gyro: NativeGyro
var scope_overlay: ScopeOverlay
var hurt_overlay: HurtOverlay
var splat_overlay: BloodSplatOverlay
var death_overlay: DeathOverlay
var death_sequence := DeathSequenceState.new()
var death_owner: BattleUnit
var death_was_dead := false
var death_live: Dictionary = {}
var scope_state := ScopeState.new()
var view_lock := ViewLockState.new()
var view_frame := Transform3D.IDENTITY
var view_projection := Projection()
var view_ready := false
var view_alive := false
var view_fov := 0.0
var player_view := PlayerViewState.new()
var view_motion := Vector2.ZERO
var view_firing := false
var view_occlusion := ViewOcclusion.new()
var ui: CanvasLayer
var root: Control
var backdrop: ColorRect
var campaign_ui: CampaignUi
var campaign_dialogue: CampaignDialogue
var campaign_progress := CampaignProgress.new()
var campaign_result_saved := false
var lobby: PanelContainer
var menu: PanelContainer
var return_button: Button
var shop: PanelContainer
var hud: Control
var stats: Label
var scoreboard: VBoxContainer
var score_rows: Dictionary = {}
var feed: BattleFeed
var combat_feed := CombatFeedState.new()
var civilian_prompt: Label
var lock_warning: Label
var boss_hud: BossHud
var locked_until := 0.0
var ammo_label: Label
var notice: Label
var room_label: Label
var map_select: OptionButton
var side_select: OptionButton
var super_select: CheckButton
var super_buy: Button
var super_auto: CheckButton
var super_detail: Label
var ordinary_shop_hint: Label
var super_request_level := -1
var super_request_at := -100.0
var character_select: OptionButton
var time_select: OptionButton
var weather_select: OptionButton
var season_select: OptionButton
var size_select: SpinBox
var bot_select: OptionButton
var address: LineEdit
var player_name: LineEdit
var room_name: LineEdit
var restoring_deployment := false
var port: SpinBox
var start_button: Button
var ready_button: Button
var quick_button: Button
var fatal_watchdog := FatalWatchdog.new()
var fatal_dialog: AcceptDialog
var fatal_restart_button: Button
var fatal_timer: Timer
var fatal_paused := false
var fatal_closing := false
var loading_panel: PanelContainer
var loading_label: Label
var loading_waiters: Label
var minimap: Control
var pip_view: PipView
var simulation: BattleSimulation
var spectator_camera: SpectatorCamera
var hud_snapshot: Dictionary = {}
var selected_slot := "light"
var aiming := false
var aim_request := 0
var aim_state_clock := -INF
# Reliable `weapon_fire` events can overtake the first snapshot that creates the local pilot.
const PENDING_FIRE_LIMIT := 16
var pending_fire_events: Array[Dictionary] = []
var wheel_at := -100.0
var released_controls: Dictionary = {}
var yaw := 0.0
var pitch := 0.0
var held_jump := false
var overlay_open := false
var shop_buttons: Dictionary = {}
var creep_buttons: Array[Button] = []
var creep_shop_column: VBoxContainer
var smoke := false
var capture := false
var smoke_time := 0.0
var smoke_state_seen := false
var network_test := false
var network_lob_test := false
var network_lob_control_seen := false
var network_lob_shot_seen := false
var network_kinetic_test := false
var network_kinetic_light_seen := false
var network_kinetic_terminal_seen := false
var bound_pilot := 0
var bound_view_reset := -1
var capture_finished := false
var presentation_clock := 0.0
var body_frame := 0
var leaving_battle := false
var automatic_deployment := false
var presentation_frame := PresentationFrame.new()
var audio: BattleAudio
var audio_scene := AudioScene.new()
var audio_notice_serial := 0
var local_fire := LocalFireState.new()
var local_fire_signature: Dictionary = {}
var local_fire_dead := false
var local_fire_fallback_request := -1
var local_cast := LocalCastState.new()
var local_cast_notice_serial := 0
var local_cast_dead := false
var local_feedback := LocalCombatFeedback.new()
var local_defense := LocalDefenseState.new()
var control_status := ControlStatusState.new()
var control_flash_overlay: ControlFlashOverlay
var control_was_dead := false
var status_icons := StatusIconState.new()
var status_icon_strip: StatusIconStrip
var room_world_resources := RoomWorldResources.new()
var room_world_prebuild := RoomWorldPrebuild.new()
var retiring_simulation: WeakRef
var room_preload_box: VBoxContainer
var room_preload_label: Label
var room_preload_progress: ProgressBar

func _ready() -> void:
	add_child(room_world_resources)
	room_world_prebuild.resources = room_world_resources
	add_child(room_world_prebuild)
	room_world_prebuild.changed.connect(_update_preload_status)
	room_world_prebuild.progress.connect(func():
		if Session.phase == "loading":
			fatal_watchdog.load_progress = _fatal_now())
	room_world_resources.progress.connect(func(_path, _fraction):
		if Session.phase == "loading":
			fatal_watchdog.load_progress = _fatal_now())
	var arguments := OS.get_cmdline_user_args()
	Session.deployment.persist = get_script().resource_path == "res://scripts/main.gd" and not arguments.has("--server") and not arguments.has("--smoke") and not arguments.has("--capture") and not arguments.has("--capture-lobby") and not arguments.has("--network-test")
	var preference_error := Session.deployment.load_save()
	if preference_error != OK:
		push_error("Cannot read deployment preferences: " + error_string(preference_error))
	if not arguments.has("--server"):
		var balance_error := Content.initialize_local_balance(Session.deployment.persist)
		if balance_error != OK and balance_error != ERR_UNAVAILABLE:
			push_warning("Cannot read balance preferences: " + error_string(balance_error))
	death_sequence.output = _death_command
	campaign_progress.load_save()
	Session.battle_started.connect(_begin_battle)
	Session.battle_launched.connect(_battle_launched)
	Session.status_changed.connect(_status)
	Session.lobby_changed.connect(_update_lobby)
	Session.state_received.connect(_receive_state)
	# The source watchdog counts every delivered packet, including one a replica rejects.
	Session.snapshot_heard.connect(func(): fatal_watchdog.snapshot(_fatal_now()))
	Session.body_event_received.connect(_body_event_feedback)
	Session.room_cleared.connect(_room_cleared)
	Session.room_returned.connect(_room_returned)
	Session.battle_failed.connect(_battle_failed)
	Controls.set_view_pref(_argument("--view", Controls.view_pref), false)
	Controls.view_changed.connect(_view_preference_changed)
	player_view.preference_changed.connect(func(value): Controls.set_view_pref(value))
	local_cast.configure(Content.balance.get("controls", {}).get("casting", {}))
	local_fire.configure(Content.balance.get("controls", {}).get("weaponHud", {}))
	local_feedback.configure(Content.balance.get("controls", {}).get("localFeedback", {}))
	control_status.configure(Content.balance.get("controls", {}).get("controlEffects", {}))
	status_icons.configure(Content.balance.get("controls", {}).get("statusIcons", {}))
	local_fire.feedback = local_feedback
	local_cast.feedback = local_feedback
	local_defense.feedback = local_feedback
	local_defense.changed.connect(func(on):
		if is_instance_valid(simulation):
			simulation.owned_defense = on
		Session.act("defend", "on" if on else "off"))
	if not Controls.rules.is_empty():
		gyro = NativeGyro.new()
		add_child(gyro)
		gyro.configure(Controls)
		get_viewport().size_changed.connect(func():
			gyro.state.reset_basis()
			_control_hud_layout())
		gyro.look.connect(func(change):
			if simulation != null and not overlay_open and not simulation.over:
				_look(change))
		Controls.set_pref(_argument("--ctrl", Controls.pref))
	if not arguments.has("--server") and DisplayServer.get_name() != "headless":
		_setup_audio()
	_build_ui()
	local_feedback.message.connect(feed.push_message)
	control_status.notice.connect(feed.push_message)
	if audio != null:
		local_fire.empty_heavy.connect(func():
			local_fire_fallback_request = aim_request
			_set_aiming(false, false))
		for node: Node in root.find_children("*", "BaseButton", true, false):
			_connect_audio_button(node)
		get_tree().node_added.connect(_audio_node_added)
	_setup_fatal_watchdog()
	view_lock.cycled.connect(func(index, count):
		feed.push_message(Content.label("view_lock_count") % [index, count] if count > 0 else Content.label("view_lock_empty_scope" if aiming else "view_lock_empty_front")))
	Controls.changed.connect(_control_preferences_changed)
	Controls.power_changed.connect(_power_preference_changed)
	Controls.save_failed.connect(func(_error): _status("controls_save_failed"))
	automatic_deployment = arguments.has("--ready-start")
	network_test = arguments.has("--network-test")
	network_lob_test = arguments.has("--network-lob-test")
	network_kinetic_test = arguments.has("--network-kinetic-test")
	Session.dedicated = arguments.has("--server")
	Session.credential_store.path = _argument("--session-store", RoomCredential.SAVE_PATH)
	Session.credential_store.persist = not Session.dedicated and not arguments.has("--smoke") and not arguments.has("--capture") and not arguments.has("--capture-lobby") and not network_test and (get_script().resource_path == "res://scripts/main.gd" or arguments.has("--session-store"))
	if Session.dedicated:
		ui.visible = false
		var server_port := int(_argument("--port", "8620"))
		var settings := {"map_index": int(_argument("--map", "0")), "team_size": int(_argument("--team-size", "1")), "super": arguments.has("--super"), "ctrl": Controls.pref, "env": {"weather": "clear", "time": "day"}}
		if arguments.has("--season"):
			settings.env.season = _argument("--season", "summer")
		if arguments.has("--campaign"):
			var chapter := _argument("--campaign", "")
			var faction := _argument("--side", "STEEL")
			var chapters: Array = Content.campaign.get("chapters", [])
			var matches: Array = chapters.filter(func(item): return item.id == chapter)
			if matches.is_empty() or faction not in ["STEEL", "SWARM"]:
				get_tree().quit(1)
				return
			settings = CampaignRules.settings(chapters.find(matches[0]), faction, _argument("--character", matches[0][faction].heroes[0]))
			if settings.is_empty():
				get_tree().quit(1)
				return
			settings.map_index = 0
		if settings.map_index < 0 or settings.map_index >= Content.maps.size() or settings.team_size < 1 or settings.team_size > 5 or server_port < 1 or server_port > 65535:
			get_tree().quit(1)
			return
		var error := Session.host(settings, server_port, "websocket" if arguments.has("--websocket") else "enet")
		if error != OK:
			push_error(error_string(error))
			get_tree().quit(1)
		else:
			print("SERVER_READY port=", server_port)
	elif arguments.has("--smoke") or arguments.has("--capture"):
		smoke = arguments.has("--smoke")
		capture = arguments.has("--capture")
		_start_mode("offline")
	elif arguments.has("--connect"):
		Session.chosen_name = _argument("--name", "")
		Session.chosen_character = _argument("--character", "s01")
		Session.chosen_side = _argument("--side", "SWARM")
		var error := Session.join(_argument("--connect", "127.0.0.1"), int(_argument("--port", "8620")), "spectator" if arguments.has("--spectator") else "player")
		if error != OK:
			get_tree().quit(1)
	elif arguments.has("--capture-lobby"):
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/lobby.png")
		get_tree().quit()
	elif arguments.has("--quick-restart"):
		_quick_restart(_argument("--listen", "offline"))
	elif arguments.has("--campaign"):
		var chapter_id := _argument("--campaign", "ch1")
		var chapters: Array = Content.campaign.get("chapters", [])
		var matches: Array = chapters.filter(func(item): return item.id == chapter_id)
		var faction := _argument("--side", "STEEL")
		if matches.is_empty() or faction not in ["STEEL", "SWARM"]:
			get_tree().quit(1)
			return
		_start_campaign(CampaignRules.settings(chapters.find(matches[0]), faction, _argument("--character", matches[0][faction].heroes[0])))
	elif arguments.has("--super"):
		_start_mode("offline")
	else:
		var recovery := Session.restore_connection()
		if recovery != OK and recovery != ERR_DOES_NOT_EXIST:
			_status("failed")
		elif recovery == ERR_DOES_NOT_EXIST:
			if arguments.has("--resume"):
				_status("failed")
			elif arguments.is_empty() and get_script().resource_path == "res://scripts/main.gd" and not campaign_progress.prologue_seen and not Content.campaign.get("prologue", []).is_empty():
				lobby.hide()
				campaign_ui.first_visit(campaign_progress)

func _argument(key: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(key)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

func _build_ui() -> void:
	var death_layers: Dictionary = Content.balance.get("deathOverlay", {}).get("layers", {})
	ui = CanvasLayer.new()
	add_child(ui)
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	if OS.has_feature("web"):
		theme.default_font = preload("res://assets/fonts/NotoSansTC.ttf")
	else:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "sans-serif"])
		theme.default_font = font
	root.theme = theme
	backdrop = ColorRect.new()
	backdrop.color = Color("101b26")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	lobby = _panel(Vector2(800, 740))
	root.add_child(lobby)
	var lobby_scroll := ScrollContainer.new()
	lobby_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lobby.add_child(lobby_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	lobby_scroll.add_child(column)
	root.resized.connect(func():
		lobby.size = Vector2(minf(800, root.size.x - 24), minf(740, root.size.y - 24))
		lobby.position = -lobby.size / 2)
	var title := _label(Content.label("title"), 32)
	title.add_theme_color_override("font_color", Color("6cc8eb"))
	column.add_child(title)
	column.add_child(_label(Content.label("subtitle")))
	column.add_child(HSeparator.new())
	player_name = LineEdit.new()
	player_name.placeholder_text = Content.label("room_player_name")
	player_name.max_length = int(Content.balance.get("rooms", {}).get("names", {}).get("maximum", 0))
	player_name.text = _argument("--name", Session.deployment.player_name if not Session.deployment.player_name.is_empty() else Session.chosen_name)
	_row(column, "room_player_name", player_name)
	room_name = LineEdit.new()
	room_name.placeholder_text = Content.label("room_name")
	room_name.max_length = player_name.max_length
	room_name.text_submitted.connect(func(value):
		if Session.active:
			Session.set_room_info(value, bool(Session.config.get("is_public", true))))
	room_name.text_changed.connect(func(value):
		if not restoring_deployment and not Session.active:
			Session.deployment.remember_field("roomName", "superRoomName", DeploymentPreferences.trim(value), super_select.button_pressed))
	_row(column, "room_name", room_name)
	map_select = OptionButton.new()
	for map_data in Content.maps:
		map_select.add_item(map_data.name)
	_row(column, "map", map_select)
	map_select.item_selected.connect(func(index):
		if not restoring_deployment and not Session.active:
			Session.deployment.remember_field("lastVenueId", "superVenueId", Content.maps[index].id, super_select.button_pressed))
	size_select = SpinBox.new()
	size_select.min_value = 1
	size_select.max_value = 5
	size_select.value = int(Content.constants.TEAM.DEFAULT)
	size_select.value_changed.connect(func(value):
		if not restoring_deployment and not Session.active:
			Session.deployment.remember_field("teamSize", "superTeamSize", value, super_select.button_pressed))
	_row(column, "team", size_select)
	bot_select = OptionButton.new()
	for key: String in Content.constants.BOT_DIFF_KEYS:
		bot_select.add_item(Content.constants.BOT_DIFF[key].name)
		bot_select.set_item_metadata(bot_select.item_count - 1, key)
		if key == Content.constants.DEFAULT_BOT_DIFF:
			bot_select.select(bot_select.item_count - 1)
	_row(column, "bot_difficulty", bot_select)
	bot_select.item_selected.connect(func(index):
		if restoring_deployment:
			return
		Session.deployment.remember_field("botDiff", "superBotDiff", bot_select.get_item_metadata(index), bool(Session.config.get("super", false)) if Session.active else super_select.button_pressed)
		if Session.active:
			Session.set_bot_difficulty(bot_select.get_item_metadata(index)))
	side_select = OptionButton.new()
	for side in ["STEEL", "SWARM"]:
		side_select.add_item(Content.constants.SIDES[side].name)
	_row(column, "players", side_select)
	super_select = CheckButton.new()
	super_select.text = Content.label("super_mode")
	super_select.disabled = not Content.super_available()
	super_select.button_pressed = OS.get_cmdline_user_args().has("--super")
	column.add_child(super_select)
	character_select = OptionButton.new()
	_row(column, "character", character_select)
	side_select.item_selected.connect(func(index):
		if not restoring_deployment:
			Session.deployment.patch({"lastSide": "STEEL" if index == 0 else "SWARM"})
		_refresh_characters())
	super_select.toggled.connect(func(_enabled):
		if not restoring_deployment:
			_restore_deployment())
	character_select.item_selected.connect(func(index):
		if not restoring_deployment:
			Session.deployment.remember_character(Content.constants.SUPER_SIDE if super_select.button_pressed else "STEEL" if side_select.selected == 0 else "SWARM", character_select.get_item_metadata(index)))
	_refresh_characters()
	season_select = OptionButton.new()
	season_select.add_item(Content.label("room_random_season"))
	season_select.set_item_metadata(0, "random")
	for key: String in Content.constants.ENV.seasons:
		season_select.add_item(Content.constants.ENV.seasons[key].name)
		season_select.set_item_metadata(season_select.item_count - 1, key)
	_row(column, "season", season_select)
	time_select = OptionButton.new()
	time_select.add_item(Content.label("room_random_time"))
	time_select.set_item_metadata(0, "random")
	for key: String in Content.constants.ENV.times:
		time_select.add_item(Content.constants.ENV.times[key].name)
		time_select.set_item_metadata(time_select.item_count - 1, key)
	_row(column, "time", time_select)
	weather_select = OptionButton.new()
	weather_select.add_item(Content.label("room_random_weather"))
	weather_select.set_item_metadata(0, "random")
	for key: String in Content.constants.ENV.weathers:
		weather_select.add_item(Content.constants.ENV.weathers[key].name)
		weather_select.set_item_metadata(weather_select.item_count - 1, key)
	_row(column, "weather", weather_select)
	for selection: OptionButton in [season_select, time_select, weather_select]:
		selection.item_selected.connect(func(_index): _remember_environment())
	_restore_deployment()
	address = LineEdit.new()
	address.text = "127.0.0.1"
	if not OS.has_feature("solo_web"):
		_row(column, "address", address)
	else:
		column.add_child(address)
		address.hide()
	port = SpinBox.new()
	port.min_value = 1
	port.max_value = 65535
	port.value = 8620
	if not OS.has_feature("solo_web"):
		_row(column, "port", port)
	else:
		column.add_child(port)
		port.hide()
	var buttons := HBoxContainer.new()
	for entry in [["solo", "offline"], ["host", "enet"], ["join", "join"], ["room_join_spectator", "spectate"]]:
		var mode: String = entry[1]
		if OS.has_feature("solo_web") and mode != "offline":
			continue
		buttons.add_child(_button(Content.label(entry[0]), func(): _start_mode(mode)))
	column.add_child(buttons)
	column.add_child(_button(Content.label("story_campaign"), _open_campaign))
	quick_button = _button(Content.label("quick_start"), _quick_restart)
	quick_button.hide()
	column.add_child(quick_button)
	start_button = _button(Content.label("start"), Session.request_start_battle)
	start_button.visible = false
	column.add_child(start_button)
	ready_button = _button(Content.label("room_ready"), _toggle_ready)
	ready_button.hide()
	column.add_child(ready_button)
	room_label = _label("")
	column.add_child(room_label)
	room_preload_box = VBoxContainer.new()
	room_preload_label = _label("", 15)
	room_preload_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_preload_box.add_child(room_preload_label)
	room_preload_progress = ProgressBar.new()
	room_preload_progress.indeterminate = true
	room_preload_progress.show_percentage = false
	room_preload_progress.custom_minimum_size.y = 6
	room_preload_box.add_child(room_preload_progress)
	column.add_child(room_preload_box)
	room_preload_box.hide()
	column.add_child(RoomPlayerEditor.new())
	column.add_child(RoomBotEditor.new())
	loading_panel = _panel(Vector2(600, 220))
	var loading_column := VBoxContainer.new()
	loading_label = _label(Content.label("room_loading"), 22)
	loading_column.add_child(loading_label)
	loading_waiters = _label("")
	loading_waiters.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_column.add_child(loading_waiters)
	loading_column.add_child(_button(Content.label("leave"), _leave))
	loading_panel.add_child(loading_column)
	root.add_child(loading_panel)
	loading_panel.hide()
	var help := _label(Content.label("controls"), 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	column.add_child(_label(Content.label("pending"), 15))
	if gyro != null:
		var settings := ControlSettings.new()
		column.add_child(settings)
		settings.configure(Controls, gyro)
	if Content.balance_preferences != null:
		var balance_settings := BalanceSettings.new()
		column.add_child(balance_settings)
		balance_settings.configure(Content.balance_preferences)
	if audio != null:
		var audio_settings := AudioSettings.new()
		column.add_child(audio_settings)
		audio_settings.configure(audio.preferences)
	if Content.balance.has("view"):
		scope_overlay = ScopeOverlay.new()
		root.add_child(scope_overlay)
	if Content.balance.has("hurtPresentation"):
		hurt_overlay = HurtOverlay.new()
		root.add_child(hurt_overlay)
	if Content.balance.get("screenSplats", {}).has("paint"):
		splat_overlay = BloodSplatOverlay.new()
		root.add_child(splat_overlay)
	if Content.balance.has("deathOverlay"):
		death_overlay = DeathOverlay.new()
		root.add_child(death_overlay)
	if Content.balance.get("controls", {}).has("controlEffects"):
		control_flash_overlay = ControlFlashOverlay.new()
		root.add_child(control_flash_overlay)
		control_status.opacity.connect(control_flash_overlay.set_opacity)
	hud = Control.new()
	hud.z_index = int(death_layers.get("hud", 0))
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.hide()
	pip_view = PipView.new()
	hud.add_child(pip_view)
	boss_hud = BossHud.new()
	hud.add_child(boss_hud)
	boss_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_hud.position = Vector2(-250, 8)
	boss_hud.size = Vector2(500, 94)
	stats = _label("", 22)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.position = Vector2(24, 20)
	hud.add_child(stats)
	scoreboard = VBoxContainer.new()
	scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(scoreboard)
	feed = BattleFeed.new()
	hud.add_child(feed)
	feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	feed.position = Vector2(-730, 20)
	feed.size = Vector2(420, 0)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_label = _label("", 22)
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ammo_label.position = Vector2(24, -105)
	ammo_label.size = Vector2(950, 80)
	hud.add_child(ammo_label)
	status_icon_strip = StatusIconStrip.new()
	hud.add_child(status_icon_strip)
	status_icon_strip.hide()
	civilian_prompt = _label("", 16)
	civilian_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	civilian_prompt.position = Vector2(-300, -50)
	civilian_prompt.size = Vector2(600, 40)
	civilian_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(civilian_prompt)
	lock_warning = _label(Content.label("lock_warning"), 24)
	lock_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lock_warning.position = Vector2(-180, 90)
	lock_warning.size = Vector2(360, 40)
	lock_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_warning.add_theme_color_override("font_color", Color(1.0, 0.4, 0.25))
	lock_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_warning.hide()
	hud.add_child(lock_warning)
	var crosshair := _label("+", 28)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-8, -20)
	hud.add_child(crosshair)
	minimap = Minimap.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-270, 20)
	minimap.size = Vector2(250, 220)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap)
	menu = _panel(Vector2(640, 660))
	menu.z_index = int(death_layers.get("menu", 0))
	var menu_scroll := ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(menu_scroll)
	var menu_column := VBoxContainer.new()
	menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.add_child(menu_column)
	menu_column.add_child(_label(Content.label("pause"), 26))
	menu_column.add_child(RoomPlayerEditor.new())
	menu_column.add_child(_button(Content.label("resume"), func(): _overlay(menu, false)))
	return_button = _button(Content.label("room_return"), func():
		if Session.config.get("super", false):
			_leave()
		else:
			Session.request_return_to_room())
	return_button.hide()
	menu_column.add_child(return_button)
	menu_column.add_child(_button(Content.label("leave"), _leave))
	if gyro != null:
		var settings := ControlSettings.new()
		menu_column.add_child(settings)
		settings.configure(Controls, gyro)
	if Content.balance_preferences != null:
		var balance_settings := BalanceSettings.new()
		menu_column.add_child(balance_settings)
		balance_settings.configure(Content.balance_preferences)
	if audio != null:
		var audio_settings := AudioSettings.new()
		menu_column.add_child(audio_settings)
		audio_settings.configure(audio.preferences)
	root.resized.connect(func():
		menu.size = Vector2(minf(640, root.size.x - 24), minf(660, root.size.y - 24))
		menu.position = -menu.size / 2)
	root.add_child(menu)
	menu.hide()
	fatal_dialog = AcceptDialog.new()
	fatal_dialog.exclusive = true
	fatal_dialog.dialog_autowrap = true
	fatal_dialog.title = Content.label("fatal_title")
	fatal_dialog.get_ok_button().text = Content.label("fatal_close")
	fatal_restart_button = fatal_dialog.add_button(Content.label("fatal_restart"), false, "restart")
	fatal_dialog.confirmed.connect(_fatal_close)
	fatal_dialog.canceled.connect(_fatal_close)
	fatal_dialog.custom_action.connect(func(action):
		if action == "restart":
			_fatal_restart())
	root.add_child(fatal_dialog)
	shop = _panel(Vector2(700, 610))
	shop.z_index = int(death_layers.get("shop", 0))
	var shop_column := VBoxContainer.new()
	shop_column.add_theme_constant_override("separation", 12)
	var shop_scroll := ScrollContainer.new()
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop.add_child(shop_scroll)
	shop_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_scroll.add_child(shop_column)
	shop_column.add_child(_label(Content.label("shop"), 26))
	shop_column.add_child(_button(Content.label("resume"), func(): _overlay(shop, false)))
	shop_column.add_child(_label(Content.label("shop_hint"), 15))
	super_buy = _button(Content.label("super_upgrade"), func(): Session.act("buy", "super"))
	shop_column.add_child(super_buy)
	super_detail = _label("", 15)
	shop_column.add_child(super_detail)
	super_auto = CheckButton.new()
	super_auto.text = Content.label("super_auto")
	shop_column.add_child(super_auto)
	for item in Content.constants.ECON.UPGRADES:
		var track: String = item
		var button := _button(Content.constants.ECON.UPGRADES[item].name, func(): Session.act("buy", track))
		shop_column.add_child(button)
		shop_buttons[item] = button
	ordinary_shop_hint = _label(Content.label("creep_hint"), 14)
	shop_column.add_child(ordinary_shop_hint)
	creep_shop_column = VBoxContainer.new()
	creep_shop_column.add_theme_constant_override("separation", 8)
	shop_column.add_child(creep_shop_column)
	shop_column.add_child(_button(Content.label("close"), func(): _overlay(shop, false)))
	root.add_child(shop)
	shop.hide()
	campaign_ui = CampaignUi.new()
	campaign_ui.z_index = int(death_layers.get("menu", 0))
	root.add_child(campaign_ui)
	campaign_ui.deployment_requested.connect(_start_campaign)
	campaign_ui.closed.connect(func(): lobby.show(); backdrop.show())
	campaign_ui.return_requested.connect(_leave)
	campaign_dialogue = CampaignDialogue.new()
	campaign_dialogue.z_index = int(death_layers.get("dialogue", 0))
	root.add_child(campaign_dialogue)
	campaign_dialogue.hide()
	notice = _label("", 22)
	notice.z_index = int(death_layers.get("menu", 0))
	notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice.position = Vector2(-420, -170)
	notice.size = Vector2(840, 80)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(notice)
	if gyro != null:
		touch_controls = NativeTouchControls.new()
		touch_controls.z_index = int(death_layers.get("touch", 0))
		root.add_child(touch_controls)
		touch_controls.configure(Controls)
		touch_controls.command.connect(_touch_command)
		touch_controls.look.connect(_look)
		touch_controls.set_gyro_status(gyro.status)
		gyro.status_changed.connect(func(key):
			touch_controls.set_gyro_status(key)
			if key in ["gyro_orientation_missing", "gyro_motion_missing"] and simulation != null:
				_status(key))
		touch_controls.hide()

func _panel(dimensions: Vector2) -> PanelContainer:
	return NativeUi.panel(dimensions)

func _label(value: String, font_size: int = 18) -> Label:
	return NativeUi.label(value, font_size)

func _setup_audio() -> void:
	var metadata: Dictionary = Content.balance.get("audio", {})
	if not metadata.has("scene"):
		push_error("Missing original audio metadata; regenerate source content before enabling audio")
		return
	var owner := BattleAudio.new()
	add_child(owner)
	var error := owner.configure(metadata, Session.deployment.persist, Controls.low_power())
	if error != OK:
		owner.queue_free()
		push_error("Cannot configure native audio: " + error_string(error))
		return
	audio = owner
	audio_scene.configure(metadata)
	audio.set_scene("menu")

func _audio_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_audio_button.call_deferred(node)

func _connect_audio_button(node: Node) -> void:
	if not is_instance_valid(node) or not node is BaseButton or not is_ancestor_of(node):
		return
	var parent := node.get_parent()
	while parent != null:
		if parent is NativeTouchControls:
			return
		parent = parent.get_parent()
	var callback := _audio_click
	if not node.pressed.is_connected(callback):
		node.pressed.connect(callback)

func _audio_click() -> void:
	if audio != null:
		audio.ui("click")

func _button(value: String, callback: Callable) -> Button:
	return NativeUi.button(value, callback)

func _row(parent: VBoxContainer, key: String, control: Control) -> void:
	NativeUi.row(parent, key, control)

func _refresh_characters() -> void:
	character_select.clear()
	var side := "STEEL" if side_select.selected == 0 else "SWARM"
	side_select.disabled = super_select.button_pressed
	character_select.add_item(Content.label("room_random_character"))
	character_select.set_item_metadata(0, "")
	for id: String in RoomRoles.pool(Content.constants.SUPER_SIDE if super_select.button_pressed else side):
		var hero: Dictionary = Content.heroes[id]
		character_select.add_item("%s · %s" % [hero.code, hero.name])
		character_select.set_item_metadata(character_select.item_count - 1, id)

func _start_mode(mode: String) -> void:
	Session.chosen_name = Session.deployment.remember_name(player_name.text)
	Session.chosen_character = character_select.get_item_metadata(character_select.selected)
	Session.chosen_side = Content.constants.SUPER_SIDE if super_select.button_pressed else "STEEL" if side_select.selected == 0 else "SWARM"
	var error: Error
	var joining := mode in ["join", "spectate"]
	if joining:
		error = Session.join(address.text.strip_edges(), int(port.value), "spectator" if mode == "spectate" else "player")
	else:
		if map_select.selected < 0:
			_status("host_failed")
			return
		var settings := {"map_index": map_select.selected, "team_size": int(size_select.value), "room_name": room_name.text, "is_public": not super_select.button_pressed, "super": super_select.button_pressed, "ctrl": Controls.pref,
			"env": {"season": season_select.get_item_metadata(season_select.selected), "time": time_select.get_item_metadata(time_select.selected),
				"weather": weather_select.get_item_metadata(weather_select.selected), "bot_difficulty": bot_select.get_item_metadata(bot_select.selected)}}
		error = Session.host(settings, int(port.value), mode)
	if error != OK:
		_status("failed" if joining else "host_failed")
		return
	if mode == "offline":
		Session.set_ready(true)
		Session.start_battle()
	elif not joining:
		start_button.show()
		_status("waiting")

func _quick_restart(transport: String = "offline") -> void:
	Session.chosen_name = Session.deployment.remember_name(player_name.text)
	var error := Session.quick_restart(int(_argument("--port", str(int(port.value)))), transport)
	if error != OK:
		_status("host_failed")
		if OS.get_cmdline_user_args().has("--quick-restart"):
			get_tree().quit(1)

func _select_option(control: OptionButton, value: Variant) -> void:
	control.set_block_signals(true)
	for index in control.item_count:
		if control.get_item_metadata(index) == value:
			control.select(index)
			break
	control.set_block_signals(false)

func _restore_deployment() -> void:
	if Session.active or season_select == null:
		return
	restoring_deployment = true
	var selected := Session.deployment.enter(super_select.button_pressed, size_select.value)
	if selected.is_empty():
		restoring_deployment = false
		return
	size_select.value = float(selected.team_size)
	room_name.text = selected.room_name
	if not String(selected.venue_id).is_empty():
		map_select.select(Content.maps.find_custom(func(entry): return entry.id == selected.venue_id))
	side_select.select(1 if selected.side == "SWARM" else 0)
	_refresh_characters()
	_select_option(character_select, Session.deployment.character(Content.constants.SUPER_SIDE if super_select.button_pressed else selected.side))
	_select_option(bot_select, selected.bot_difficulty)
	_select_option(season_select, selected.env.season)
	_select_option(time_select, selected.env.time)
	_select_option(weather_select, selected.env.weather)
	restoring_deployment = false

func _remember_environment() -> void:
	if restoring_deployment or Session.active:
		return
	Session.deployment.remember_field("env", "superEnv", {"season": season_select.get_item_metadata(season_select.selected),
		"time": time_select.get_item_metadata(time_select.selected), "weather": weather_select.get_item_metadata(weather_select.selected)}, super_select.button_pressed)

func _update_preload_status() -> void:
	if room_preload_box == null:
		return
	room_preload_box.visible = Session.active and Session.phase == "room" and not Session.leaving and not Session.dedicated and not room_world_prebuild.selected.is_empty()
	if not room_preload_box.visible:
		return
	var failed := not room_world_prebuild.failure.is_empty()
	var ready := is_instance_valid(room_world_prebuild.prepared)
	room_preload_label.text = Content.label("room_preload_failed" if failed else "room_preload_ready" if ready else "room_preload_busy")
	room_preload_progress.visible = not failed and not ready

func _update_lobby() -> void:
	var world_retiring := retiring_simulation != null and retiring_simulation.get_ref() != null
	if Session.active and Session.phase == "room" and not Session.dedicated and not Session.leaving and not world_retiring:
		room_world_prebuild.request(Session.config)
	_update_preload_status()
	if return_button != null:
		return_button.visible = Session.phase == "over" and Session.is_room_host() and not Session.story_mode() and not Session.reconnecting and not Session.leaving
	if quick_button != null:
		quick_button.visible = not Session.active and Session.deployment.values.get("lastSession") is Dictionary
		quick_button.disabled = not Session.can_quick_restart() if quick_button.visible else true
	if player_name != null:
		player_name.editable = not Session.active
	if map_select != null:
		map_select.disabled = Session.active
		size_select.editable = not Session.active
		season_select.disabled = Session.active
		time_select.disabled = Session.active
		weather_select.disabled = Session.active
		if Session.active:
			size_select.set_block_signals(true)
			size_select.value = float(Session.config.get("team_size", size_select.value))
			size_select.set_block_signals(false)
			var environment: Dictionary = Session.config.get("env", {})
			_select_option(season_select, environment.get("season"))
			_select_option(time_select, environment.get("time"))
			_select_option(weather_select, environment.get("weather"))
	if room_name != null:
		room_name.editable = not Session.active or Session.is_room_host() and not Session.reconnecting and not Session.leaving
		if Session.active and not room_name.has_focus():
			room_name.text = Session.config.get("room_name", "")
	var players := PackedStringArray()
	var local_member: Dictionary = {}
	var waiting := PackedStringArray()
	for player in Session.roster:
		if player.get("mode", "player") == "spectator":
			players.append("%s · %s #%d%s" % [Content.label("room_join_spectator"), player.get("name", ""), int(player.peer), " ✕" if not player.get("connected", true) else ""])
			if int(player.peer) == Session.player_id():
				local_member = player
			continue
		var character: String = Content.heroes.get(player.character, {}).get("code", Content.label("room_random_character"))
		if not String(player.get("name", "")).is_empty():
			character = str(player.name) + " · " + character
		players.append("%s %s · %s%s" % ["●" if player.get("bot", false) or player.get("ready", false) else "○", Content.side_info(player.side).name, character, " ✕" if not player.get("connected", true) else ""])
		if int(player.peer) == Session.player_id():
			local_member = player
		if not player.get("bot", false) and not String(player.side).is_empty() and not player.get("loaded", false):
			waiting.append(character)
	room_label.text = "\n".join(players)
	side_select.get_parent().visible = not Session.active
	character_select.get_parent().visible = not Session.active
	super_select.visible = not Session.active
	side_select.disabled = Session.active or super_select.button_pressed
	character_select.disabled = Session.active
	super_select.disabled = Session.active or not Content.super_available()
	bot_select.disabled = Session.active and (not Session.is_room_host() or Session.reconnecting or Session.leaving or Session.story_mode())
	if Session.active:
		var difficulty: String = Session.config.get("env", {}).get("bot_difficulty", Content.constants.DEFAULT_BOT_DIFF)
		bot_select.set_block_signals(true)
		for index in bot_select.item_count:
			if bot_select.get_item_metadata(index) == difficulty:
				bot_select.select(index)
				break
		bot_select.set_block_signals(false)
	start_button.visible = Session.is_room_host() and Session.phase == "room" and not Session.reconnecting and not Session.leaving
	start_button.disabled = String(local_member.get("side", "")).is_empty() if Session.config.get("super", false) else not Session.all_ready()
	ready_button.visible = Session.active and Session.phase == "room" and not local_member.is_empty() and local_member.get("mode", "player") == "player" and not Session.config.get("super", false)
	ready_button.disabled = Session.reconnecting or Session.leaving or String(local_member.get("side", "")).is_empty()
	ready_button.text = Content.label("room_cancel_ready" if local_member.get("ready", false) else "room_ready")
	loading_label.text = Content.label("room_waiting_loaded" if Session.world_prepared else "room_loading")
	loading_waiters.text = "\n".join(waiting)
	if automatic_deployment:
		_deploy_when_ready.call_deferred()

func _toggle_ready() -> void:
	for player: Dictionary in Session.roster:
		if int(player.peer) == Session.player_id():
			Session.set_ready(not player.get("ready", false))
			return

func _deploy_when_ready() -> void:
	if not automatic_deployment or not Session.active or Session.phase != "room" or Session.reconnecting or Session.leaving:
		return
	for player: Dictionary in Session.roster:
		if int(player.peer) != Session.player_id():
			continue
		if player.get("mode", "player") == "spectator" or String(player.side).is_empty():
			if Session.is_room_host() and Session.all_ready():
				Session.request_start_battle()
			return
		if not player.get("ready", false):
			Session.set_ready(true)
		elif Session.is_room_host() and Session.all_ready():
			Session.request_start_battle()
		return

func _begin_battle(settings: Dictionary, players: Array) -> void:
	audio_scene.reset()
	audio_notice_serial = 0
	local_fire_signature.clear()
	local_feedback.reset()
	local_defense.defending = false
	local_defense.frozen = false
	control_status.reset()
	control_was_dead = false
	status_icons.reset()
	status_icon_strip.clear()
	local_fire_dead = false
	local_fire_fallback_request = -1
	local_fire.definitions.clear()
	local_fire.weapons.clear()
	local_fire.last_fire = {"light": 0.0, "heavy": 0.0}
	local_fire.recoil = RecoilState.new()
	local_fire.power = 0
	local_cast.cancel()
	local_cast.emp_left = 0
	local_cast.cooldowns = [0.0, 0.0]
	local_cast.charges = null
	local_cast.shield_expand_until = 0
	local_cast.def_jump_until = 0
	local_cast_notice_serial = 0
	local_cast_dead = false
	if audio != null:
		audio.stop_move()
	pip_view.clear()
	fatal_watchdog.shown = false
	fatal_dialog.hide()
	fatal_watchdog.loading(_fatal_now())
	spectator_camera = null
	hud_snapshot = {}
	_reset_death_view()
	aim_state_clock = -INF
	presentation_frame.clear()
	if simulation != null:
		simulation.queue_free()
	Session.simulation = null
	simulation = _create_simulation()
	simulation.owned_defense = local_defense.defending
	add_child(simulation)
	simulation.hide()
	lobby.hide()
	hud.hide()
	backdrop.show()
	menu.hide()
	shop.hide()
	overlay_open = false
	loading_panel.show()
	var map_data := Content.battle_map(settings)
	if map_data.is_empty():
		Session.fail_battle("Missing original imported map definition")
		return
	super_auto.button_pressed = map_data.config["super"]
	super_request_level = -1
	super_request_at = -100.0
	var loading_battle := simulation
	var loading_seats := Session.seats
	var loading_round := Session.round_id
	var prepared_world: BattleWorld
	if not Session.dedicated:
		prepared_world = await room_world_prebuild.take(settings, loading_battle)
		if not is_instance_valid(loading_battle) or simulation != loading_battle or not Session.active or Session.leaving or Session.seats != loading_seats or Session.round_id != loading_round:
			return
		if not Session.failure_reason.is_empty():
			return
		if prepared_world == null:
			if not room_world_prebuild.failure.is_empty():
				Session.fail_battle(room_world_prebuild.failure)
			return
	loading_battle.setup_progress.connect(func():
		if simulation == loading_battle and Session.round_id == loading_round:
			fatal_watchdog.load_progress = _fatal_now())
	loading_battle.failure_reported.connect(func(reason):
		if simulation == loading_battle and Session.seats == loading_seats and Session.round_id == loading_round:
			Session.fail_battle(reason))
	loading_battle.balance_profile = Content.local_balance if not Session.is_authority() or Session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer else null
	loading_battle.client_weapons.profile = Content.local_balance
	await loading_battle.setup(map_data, players, settings.env, Session.is_authority(), true, prepared_world)
	if not is_instance_valid(loading_battle) or simulation != loading_battle or not Session.active or Session.leaving or Session.seats != loading_seats or Session.round_id != loading_round:
		return
	if not Session.failure_reason.is_empty():
		return
	if not loading_battle.setup_complete or loading_battle.world == null:
		Session.fail_battle(loading_battle.setup_error)
		return
	if audio != null:
		audio.set_scene("battle")
	body_frame = 0
	pending_fire_events.clear()
	_refresh_creep_shop()
	Session.simulation = simulation
	simulation.view_snapshot_ready.connect(_prepare_death_snapshot)
	simulation.death_presented.connect(presentation_frame.receive)
	if hurt_overlay != null:
		simulation.self_hurt.connect(hurt_overlay.flash)
	if splat_overlay != null:
		simulation.screen_hurt.connect(_screen_hurt)
	if simulation.authoritative:
		simulation.body_event.connect(Session.broadcast_body_event)
		simulation.body_event.connect(_body_event_feedback)
	view_occlusion.dispose()
	view_occlusion.register_root(simulation.world)
	for unit: BattleUnit in simulation.units.values():
		_register_body_occluders(unit)
	simulation.unit_spawned.connect(_register_body_occluders)
	simulation.unit_view_removed.connect(view_occlusion.unregister_root)
	simulation.message.connect(func(peer, key):
		if simulation.authoritative:
			Session.notify_player(peer, key)
		elif peer == Session.player_id():
			_status(key))
	simulation.result.connect(_result)
	minimap.configure(map_data, Session.chosen_side, simulation.world.native_data.minimap_base)
	if not Session.dedicated:
		var lane_world: BattleWorld = simulation.world
		var graded := MinimapLaneState.classify(lane_world.lane_surface.lanes, {
			"tunnel": func(x: float, z: float): return lane_world.layers.tunnel_at(Vector2(x, z)),
			"deck": lane_world.visual_deck, "ground": lane_world.source_height})
		if not minimap.lane_view.configure(MinimapLaneState.groups(graded, map_data.config.get("laneIds", []))):
			Session.fail_battle("Missing original minimap lane stroke resources")
			return
	if touch_controls != null:
		touch_controls.set_map_near(false)
	lobby.hide()
	notice.text = ""
	feed.clear()
	combat_feed.clear()
	locked_until = 0
	lock_warning.hide()
	campaign_result_saved = false
	aiming = false
	selected_slot = "light"
	aim_request = 0
	released_controls.clear()
	view_lock.press(false)
	view_lock.clear_dead()
	view_lock.cycle = false
	view_lock.last_seek = 0
	view_ready = false
	view_alive = false
	if touch_controls != null:
		touch_controls.begin_match()
	view_motion = Vector2.ZERO
	view_firing = false
	bound_pilot = 0
	bound_view_reset = -1
	scope_state.clear()
	if scope_overlay != null:
		scope_overlay.clear()
	if hurt_overlay != null:
		hurt_overlay.clear()
	if splat_overlay != null:
		splat_overlay.reset_room()
	campaign_dialogue.dispose()
	campaign_dialogue.hide()
	if settings.has("campaign"):
		campaign_dialogue.side = settings.campaign.side
		campaign_dialogue.art_mode = campaign_progress.art_mode
		campaign_ui.hide()
	_sync_touch()
	_control_hud_layout()
	fatal_watchdog.local_loaded = true
	Session.prepare_complete(simulation, map_data)

func _battle_launched() -> void:
	if simulation == null:
		return
	fatal_watchdog.launched(_fatal_now())
	simulation.show()
	loading_panel.hide()
	backdrop.hide()
	hud.show()
	if simulation.authoritative and not Session.dedicated:
		simulation.apply_presentation_view(Session._state_for(Session.player_id()))
	campaign_dialogue.visible = Session.story_mode()
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot != null:
		yaw = pilot.yaw
		_bind_camera(pilot)
	elif not Session.dedicated:
		_observer_camera()
	_sync_touch()
	_control_hud_layout()

func _observer_camera() -> void:
	if is_instance_valid(spectator_camera):
		return
	spectator_camera = SpectatorCamera.new()
	simulation.add_child(spectator_camera)
	if not spectator_camera.configure(simulation):
		spectator_camera.queue_free()
		spectator_camera = null
		push_error("Spectator camera requires captured source metadata and a prepared world")
		return
	spectator_camera.state.notice.connect(feed.push_message)
	yaw = spectator_camera.state.yaw
	pitch = spectator_camera.state.pitch
	if touch_controls != null:
		touch_controls.set_spectating(true)

func _create_simulation() -> BattleSimulation:
	return BattleSimulation.new()

func _bind_camera(pilot: BattleUnit) -> void:
	var changed := bound_pilot != pilot.entity_id
	if changed or bound_view_reset != pilot.view_reset:
		yaw = pilot.yaw
		pitch = pilot.pitch
		bound_view_reset = pilot.view_reset
		bound_pilot = pilot.entity_id
		view_ready = false
		if changed and Content.balance.has("playerView"):
			player_view.configure(Content.balance.playerView, Controls.view_pref, yaw)
			yaw = player_view.set_aiming(aiming, yaw)
		elif not player_view.rules.is_empty():
			player_view.body_yaw = yaw
	if pilot.camera != null:
		pilot.camera.current = true
		pilot.render_view_mode = player_view.mode
		pilot.model.visible = player_view.mode == "tps" and pilot.alive()
		pilot.ensure_cockpit()
		pilot.cockpit.visible = player_view.mode != "tps" and pilot.alive()
		var echo_callback := simulation.present_echo.bind(pilot)
		if not pilot.cockpit.echo_fired.is_connected(echo_callback):
			pilot.cockpit.echo_fired.connect(echo_callback)

func _process(delta: float) -> void:
	_fatal_visibility()
	if simulation == null or Session.dedicated or not Session.launch_announced:
		return
	presentation_clock += delta
	delta = presentation_frame.advance(delta)
	_advance_look(delta)
	lock_warning.visible = float(Time.get_ticks_msec()) / 1000.0 < locked_until
	if simulation.lock_glow != null:
		simulation.lock_glow.advance(float(Time.get_ticks_msec()) / 1000.0)
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	simulation.step_remote_shots(simulation.presentation_time())
	if pilot != null:
		local_defense.observe_frame(_defense_frame(pilot), Time.get_ticks_usec() / 1000000.0)
		if pilot.alive() and not pilot.side.is_empty():
			control_status.advance(delta)
	if is_instance_valid(spectator_camera):
		_advance_spectator(delta)
	else:
		_advance_view(delta, pilot)
	_advance_local_fire(pilot)
	if pilot != null and pilot.alive():
		_remember_death_view(pilot)
	if not death_sequence.state.is_empty() and not simulation.over:
		death_sequence.advance(delta, simulation.world.visual_surface)
		if is_instance_valid(death_owner) and death_owner.camera != null:
			death_owner.camera.global_transform = death_sequence.frame
	if splat_overlay != null:
		splat_overlay.observe(pilot)
		splat_overlay.advance(delta)
	body_frame = (body_frame + 1) & 0xffffffff
	var owned_shield := {"defending": local_defense.defending, "expanded": local_cast.shield_expand_until > Time.get_ticks_usec() / 1000000.0}
	if pilot != null and pilot.first_person_shield != null:
		pilot.first_person_shield.update_view(pilot, delta, simulation.presentation_time(), player_view.mode, owned_shield)
	simulation.present_bodies(delta, simulation.presentation_time(), body_frame, get_viewport().get_camera_3d(), player_view, owned_shield)
	var geometry_aim_blend := 0.0
	if pilot != null and pilot.alive() and not pilot.side.is_empty() and pilot.camera != null:
		var stats_for_view: Dictionary = Content.constants.UNITS[pilot.kind]
		var base_for_view: float = stats_for_view.get("fovAir", stats_for_view.get("fov", 68)) if pilot.flying else stats_for_view.get("fov", 68)
		geometry_aim_blend = ScopeState.aim_blend(pilot.camera.fov, base_for_view, float(stats_for_view.get("zoomFov", base_for_view)))
	simulation.present_geometry_lod(get_viewport().get_camera_3d(), body_frame, geometry_aim_blend, Session.player_id())
	audio_scene.observe(audio, simulation, get_viewport().get_camera_3d(), pilot)
	if pilot != null and pilot.body != null and pilot.body.source_root != null:
		view_occlusion.update(simulation.presentation_time(), pilot.camera.global_transform, pilot.body,
			CameraPose.body_height(pilot.character, pilot.flying, SuperRules.body_scale(float(pilot.upgrades.get("super", 0)))), player_view.mode == "tps" and pilot.alive())
	boss_hud.update_view(simulation, pilot.camera if pilot != null else spectator_camera, float(Time.get_ticks_msec()) / 1000.0)
	simulation.step_dissolve_ghosts(delta)
	simulation.step_missile_presentations(delta)
	var map_position: Vector3 = spectator_camera.state.position if is_instance_valid(spectator_camera) else pilot.global_position if pilot != null else Vector3.ZERO
	minimap.focus = Vector2(map_position.x, map_position.z)
	minimap.hero_kind = pilot.kind if pilot != null else ""
	minimap.own_id = pilot.entity_id if pilot != null else 0
	minimap.heading = player_view.body_yaw if player_view.mode == "tps" else yaw
	minimap.view_peer = Session.player_id()
	minimap.view_dead = pilot == null or not pilot.alive()
	minimap.aiming = aiming
	minimap.weather_fog = float(simulation.weather_dynamics.get("fog", 0))
	minimap.missile_points = simulation.missile_presentations.values().map(func(view: MissilePresentation): return view.global_position)
	var map_now := float(Time.get_ticks_msec()) / 1000.0
	if minimap.advance(map_now):
		minimap.positions.clear()
		for row: Dictionary in minimap.state.get("units", []):
			var shown: BattleUnit = simulation.units.get(int(row.id))
			if shown != null and shown.model != null:
				minimap.positions[int(row.id)] = shown.model.global_position
		minimap.update_fog(map_now, simulation.world.active_columns, simulation.world.blocker_query)
	simulation.step_damage_fx(delta, float(Time.get_ticks_msec()) / 1000.0)
	simulation.world.step_scenery(delta, simulation.weather_dynamics)
	if pilot == null or pilot.cockpit == null:
		pip_view.update_view(simulation, pilot, Session.chosen_side, get_viewport().scaling_3d_scale)
		if is_instance_valid(spectator_camera):
			simulation.world.step_projectile_visuals(delta)
			simulation.world.sync_fogs(simulation._fog_snapshot() if simulation.authoritative else simulation.fog_view, "", simulation.clock)
			simulation.world.update_mine_view(spectator_camera.state.position, simulation.clock)
		return
	var scope := aiming
	var clock := simulation.clock if simulation.authoritative else presentation_clock
	pilot.cockpit.update_view(pilot, selected_slot, scope, delta, clock, player_view.mode)
	pilot.cockpit.visible = player_view.mode != "tps" and (pilot.alive() or not death_sequence.state.is_empty())
	if simulation.authoritative:
		simulation.world.sync_projectile_view(simulation.projectile_view(pilot), simulation.clock)
	simulation.world.step_projectile_visuals(delta)
	simulation.world.sync_fogs(simulation._fog_snapshot() if simulation.authoritative else simulation.fog_view, pilot.side, clock)
	simulation.world.update_mine_view(pilot.global_position, clock)
	if touch_controls != null:
		touch_controls.set_kind(pilot.kind)
	var civilian := simulation.nearest_civilian(pilot)
	if touch_controls != null:
		touch_controls.show_civilian(civilian != null and not overlay_open)
	civilian_prompt.visible = civilian != null and not overlay_open
	if civilian != null:
		var appearance := CivilianRules.appearance(civilian.entity_id, int(civilian.special.profession))
		civilian_prompt.text = Content.label("civilian_prompt") % [appearance.occupation, Content.side_info(civilian.special.civil_side).name]
	pip_view.update_view(simulation, pilot, Session.chosen_side, get_viewport().scaling_3d_scale)

# Original _moveAxis reads the stick's double f/r once mag is positive; the published
# Vector2 is rounded to Float32 and cannot carry these decisions.
func _touch_axis() -> Dictionary:
	var stick: Dictionary = touch_controls.state.move_stick
	if not float(stick.mag) > 0:
		return {"f": 0.0, "r": 0.0, "mag": 0.0}
	var forward := float(stick.y)
	var right := float(stick.x)
	return {"f": forward, "r": right, "mag": sqrt(forward * forward + right * right)}

func _advance_spectator(delta: float) -> void:
	var motion := Vector2(_control("right") - _control("left"), _control("back") - _control("forward"))
	var touch: Dictionary = touch_controls.held if touch_controls != null and touch_controls.visible else {}
	var touched := motion == Vector2.ZERO and touch_controls != null and touch_controls.visible and not overlay_open
	if touched:
		motion = touch_controls.state.axis
	if overlay_open:
		motion = Vector2.ZERO
	var axis := {"f": -motion.y, "r": motion.x, "mag": motion.length(),
		"boost": (_control("sprint") > 0 or touch.get("sprint", false)) and not overlay_open}
	if touched:
		axis.merge(_touch_axis(), true)
	var angles := spectator_camera.advance(clampf(delta, 0, float(Content.balance.view.frameCap)), Vector2(yaw, pitch), axis,
		(_control("rise") > 0 or touch.get("jump", false)) and not overlay_open,
		(_control("descend") > 0 or touch.get("dive", false)) and not overlay_open)
	yaw = angles.x
	pitch = angles.y
	view_frame = spectator_camera.global_transform
	view_projection = spectator_camera.get_camera_projection()
	var info: Dictionary = spectator_camera.state.hud(spectator_camera.rows.values())
	_render_player_panel(info, int(hud_snapshot.get("wave", 0)))
	if not simulation.over:
		notice.text = "%s %.1f" % [Content.label("respawn"), float(info.get("rs", 0))] if info.get("dead", false) else ""
	_refresh_standings(hud_snapshot.get("stats", {}))
	civilian_prompt.hide()
	if touch_controls != null:
		touch_controls.show_civilian(false)

func _remember_death_view(pilot: BattleUnit) -> void:
	if pilot.camera == null:
		return
	death_live = {"eye": pilot.camera.global_transform, "position": pilot.global_position, "velocity": pilot.velocity,
		"angles": Vector3(pitch, yaw, pilot.movement_roll), "flying": pilot.flying, "color": int(Color(Content.side_info(pilot.side).color).to_rgba32() >> 8)}

func _release_death_camera() -> void:
	if not is_instance_valid(death_owner) or death_owner.camera == null:
		return
	var camera := death_owner.camera
	var frame := camera.global_transform
	death_owner.presentation_camera_owned = false
	camera.top_level = false
	camera.global_transform = frame
	if death_owner.alive():
		death_owner.sync_view_camera()

func _reset_death_view() -> void:
	_release_death_camera()
	death_sequence.finish()
	death_owner = null
	death_was_dead = false
	death_live.clear()
	if death_overlay != null:
		death_overlay.clear()

func _observe_death_view(pilot: BattleUnit) -> void:
	if not is_instance_valid(death_owner) or death_owner != pilot:
		_release_death_camera()
		death_sequence.finish()
		death_owner = pilot
		death_was_dead = false
		death_live.clear()
	if pilot.alive():
		if death_was_dead:
			death_sequence.finish()
			_release_death_camera()
		death_was_dead = false
		return
	if death_was_dead or simulation.over:
		return
	death_was_dead = true
	if pilot.camera == null:
		return
	if death_live.is_empty():
		_remember_death_view(pilot)
	death_live.velocity = pilot.velocity
	death_live.flying = pilot.flying
	var camera := pilot.camera
	camera.fov = float(Content.constants.UNITS[pilot.kind].get("fovAir", Content.constants.UNITS[pilot.kind].fov)) if pilot.flying else float(Content.constants.UNITS[pilot.kind].fov)
	_set_aiming(false, false)
	if menu.visible:
		_overlay(menu, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var effects := simulation.world.ensure_combat_effects()
	death_sequence.random_sample = effects._sample_random
	if not death_sequence.begin(death_live, simulation.world.visual_surface):
		return
	pilot.presentation_camera_owned = true
	camera.top_level = true
	camera.global_transform = death_sequence.frame
	if hurt_overlay != null:
		hurt_overlay.clear()

func _prepare_death_snapshot(state: Dictionary) -> void:
	if Session.dedicated:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		return
	_bind_camera(pilot)
	if not simulation.authoritative:
		pilot.velocity = state.view_velocity
	_observe_death_view(pilot)

func _death_command(command: Dictionary) -> void:
	match command.type:
		"alert":
			if death_overlay != null:
				death_overlay.receive(command.on, command.flash)
			return
		"hitstop":
			presentation_frame.hold(float(command.seconds))
			return
		"cut":
			# The source's default wipe preference completes this callback synchronously.
			death_sequence.finish()
			return
	if simulation == null or simulation.world == null:
		return
	var effects := simulation.world.ensure_combat_effects()
	match command.type:
		"spark": effects.spark(command.point, float(command.radius), int(command.color))
		"explosion": effects.explosion(command.point, float(command.radius), int(command.color))
		"shock": effects.shock(command.point, float(command.radius), int(command.color))
		"mechanical": effects.mechanical_debris(command.point, command.big, command.accent)
		"comic": effects.comic(command.point, command.big, command.hue)
		"plume": effects.death_plume(command.point)
		"embers": effects.embers(command.point, int(command.count), float(command.spread))
		"smoke": effects.crash_smoke(command.point, float(command.size))
		"engulf": effects.engulf(command.frame)

func _advance_view(delta: float, pilot: BattleUnit) -> void:
	if not Content.balance.has("view"):
		return
	if pilot == null or pilot.camera == null:
		scope_state.clear()
		view_ready = false
		if scope_overlay != null:
			scope_overlay.clear()
		return
	var step := clampf(delta, 0, float(Content.balance.view.frameCap))
	var in_fire := false
	if not pilot.flying and not pilot.fluid_environment.get("air", false):
		for fire: Dictionary in simulation.fire_fields:
			var radius: float = float(Content.constants.HAZARDS[fire.kind].r) * float(fire.scale)
			if SourceNumeric.hypot(pilot.position.x - fire.position.x, pilot.position.z - fire.position.z) <= radius:
				in_fire = true
				break
	scope_state.advance(step, in_fire, float(simulation.weather_dynamics.get("effectiveFog", 0)), pilot.alive())
	if scope_overlay != null:
		scope_overlay.update_view(scope_state, aiming and pilot.alive())
	if not pilot.alive():
		if view_alive:
			view_lock.clear_dead()
		view_alive = false
		view_ready = false
		if touch_controls != null:
			touch_controls.set_view_lock(false)
		return
	view_alive = true
	var camera := pilot.camera
	if not view_ready:
		view_frame = camera.global_transform
		view_projection = camera.get_camera_projection()
		view_fov = camera.fov
		view_ready = true
	var weapon := simulation.client_weapon_definition(pilot, selected_slot)
	var reach := TargetingMath.maximum_range(weapon)
	var viewport := camera.get_viewport().get_visible_rect().size
	# Authority movement may add confusion turning after consuming raw input.
	var status_yaw := BotRules.wrap_pi(pilot.yaw - float(pilot.input_state.get("yaw", pilot.yaw))) if simulation.authoritative else 0.0
	if not player_view.rules.is_empty():
		var move := Basis(Vector3.UP, yaw + status_yaw) * Vector3(view_motion.x, 0, view_motion.y)
		if local_defense.frozen:
			move = Vector3.ZERO
		player_view.advance_body(step, move, yaw + status_yaw, local_defense.defending, view_firing)
	var change := view_lock.advance(step, float(Time.get_ticks_msec()) / 1000.0, Vector2(yaw + status_yaw, pitch), view_frame.origin,
		reach, overlay_open or simulation.over or pilot.side.is_empty(),
		func(keep, full): return _view_acquire(pilot, viewport, reach, keep, full), _view_point)
	_look(change, true)
	if touch_controls != null:
		touch_controls.set_view_lock(view_lock.lit)
	# Presentation never writes authority angles or confirms a damage lock.
	# Acquisition reads the preceding rendered camera, as in the source loop.
	var frame: Transform3D
	if player_view.mode == "tps":
		frame = simulation.third_person_camera(pilot, yaw + status_yaw, pitch, camera.get_camera_projection(), NAN, pilot.movement_roll)
	else:
		frame = Transform3D(pilot.recoil.basis(yaw + status_yaw, pitch, pilot.movement_roll), simulation.first_person_camera_origin_at(pilot, yaw + status_yaw))
	var unit_stats: Dictionary = Content.constants.UNITS[pilot.kind]
	var base: float = unit_stats.get("fovAir", unit_stats.get("fov", 68)) if pilot.flying else unit_stats.get("fov", 68)
	view_fov = ScopeState.fov_step(view_fov, float(unit_stats.get("zoomFov", base)) if aiming else base, step)
	camera.fov = view_fov
	var ring_y := pilot.body.ring_height(pilot.global_position.y) if pilot.body != null and pilot.body.source_root != null else NAN
	camera.global_transform = CameraPose.frame_ring(frame, camera.get_camera_projection(), Vector3(pilot.position.x, ring_y, pilot.position.z)) if player_view.mode == "tps" and is_finite(ring_y) else frame
	view_frame = camera.global_transform
	view_projection = camera.get_camera_projection()

func _view_candidates(pilot: BattleUnit) -> Array:
	var candidates: Array = []
	for target: BattleUnit in simulation.units.values():
		if not TargetingMath.foe(pilot.side, target.side, target.special.get("neutral", false)) or not target.alive() or not target.visible or target.model == null or not target.model.visible:
			continue
		var point := target.aim_point()
		if point.is_finite():
			candidates.append({"id": target.entity_id, "point": point})
	return candidates

func _view_acquire(pilot: BattleUnit, viewport: Vector2, reach: float, keep: int, full: bool) -> Variant:
	var candidates := _view_candidates(pilot)
	var radius := scope_state.radius(viewport)
	if not full and keep != 0:
		var current := candidates.filter(func(item): return int(item.id) == keep)
		if not TargetingMath.view_roster(pilot.global_position, view_frame, view_projection, viewport, current, reach, keep, aiming, radius, _view_obstruction).is_empty():
			return keep
	var roster := TargetingMath.view_roster(pilot.global_position, view_frame, view_projection, viewport, candidates, reach, keep, aiming, radius, _view_obstruction)
	return roster if full else TargetingMath.view_choice(roster, keep)

func _view_obstruction(start: Vector3, end: Vector3) -> float:
	var hit := simulation.world.obstruction_hit(start, end)
	return start.distance_to(hit.position) if not hit.is_empty() else INF

func _view_point(id: int) -> Vector3:
	var target: BattleUnit = simulation.units.get(id)
	if target == null or not target.alive() or not target.visible or target.model == null or not target.model.visible:
		return Vector3(INF, INF, INF)
	return target.aim_point()

func _control(action_name: String) -> float:
	var value := Input.get_action_strength(action_name)
	if action_name == "fire" and touch_controls != null and touch_controls.visible:
		value = float(Input.is_physical_key_pressed(KEY_KP_MULTIPLY))
		for device: int in Input.get_connected_joypads():
			value = maxf(value, float(Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)))
	if released_controls.has(action_name):
		if value > 0:
			return 0.0
		released_controls.erase(action_name)
	return value

func _look(change: Vector2, system: bool = false) -> void:
	if simulation == null or not Session.launch_announced or overlay_open or simulation.over:
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	var frozen := pilot != null and local_defense.frozen
	var angles := InputRules.look(yaw, pitch, change, frozen, bool(Controls.values.get("invertX", false)), bool(Controls.values.get("invertY", false)), system)
	yaw = angles.x
	pitch = angles.y

func _set_aiming(on: bool, notify: bool = true) -> void:
	if aiming == on:
		return
	if not player_view.rules.is_empty():
		yaw = player_view.set_aiming(on, yaw)
	aiming = on
	selected_slot = "heavy" if aiming else "light"
	if not notify:
		return
	local_fire_fallback_request = -1
	aim_request += 1
	Session.act("aim", ("on" if on else "off") + ":" + str(aim_request))

func _unhandled_input(event: InputEvent) -> void:
	if simulation == null or Session.dedicated or not Session.launch_announced or fatal_watchdog.shown:
		return
	if campaign_ui.visible:
		return
	if event is InputEventMouse and touch_controls != null and touch_controls.visible:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(-event.relative * float(Content.balance.controls.mouseSensitivity))
	if event.is_action_pressed("pause"):
		_input_command("menu", true)
	if event.is_action_pressed("shop"):
		_input_command("shop", true)
	if overlay_open:
		return
	if is_instance_valid(spectator_camera):
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_F: _spectator_command("special")
				KEY_Q: _spectator_command("previous")
				KEY_E: _spectator_command("swap")
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			spectator_camera.state.zoom(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	if event.is_action_pressed("aim"):
		var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
		var now := Time.get_ticks_msec() / 1000.0
		if pilot != null and pilot.alive() and now - wheel_at >= float(Content.balance.controls.wheelCooldown):
			wheel_at = now
			_input_command("aim", true)
	var actions := {"stance_ability": "special", "reload": "reload", "defense": "def", "attack": "atk",
		"defend": "shield", "map": "map", "civ_follow": "civ_follow", "civ_away": "civ_away", "rise": "jump"}
	for action_name: String in actions:
		if event.is_action_pressed(action_name):
			_input_command(actions[action_name], true)

func _input_command(action: String, on: bool) -> void:
	if simulation == null or Session.dedicated or not on or fatal_watchdog.shown:
		return
	if action == "menu":
		_overlay(menu, not menu.visible)
		return
	if action == "shop":
		if is_instance_valid(spectator_camera):
			return
		_overlay(shop, not shop.visible)
		return
	if overlay_open:
		return
	if action == "map":
		feed.push_message(minimap.toggle_mode())
		if touch_controls != null:
			touch_controls.set_map_near(minimap.near)
		return
	if action == "jump":
		held_jump = true
		return
	if is_instance_valid(spectator_camera):
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null or not pilot.alive():
		return
	match action:
		"aim": _set_aiming(not aiming)
		"special": _request_cast(pilot, InputRules.hold_slot(local_defense.defending))
		"def", "atk": _request_cast(pilot, action)
		"reload":
			if audio != null and local_fire.definitions.has(selected_slot):
				local_fire.reload(selected_slot, Time.get_ticks_usec() / 1000000.0)
			Session.act("reload", selected_slot)
		"shield": local_defense.request(_defense_frame(pilot), Time.get_ticks_usec() / 1000000.0)
		"civ_follow", "civ_away":
			var civilian := simulation.nearest_civilian(pilot)
			if civilian != null:
				Session.act(action, str(civilian.entity_id))

func _spectator_command(action: String) -> void:
	if not is_instance_valid(spectator_camera):
		return
	# The view setter can reset pitch; synchronize before and after every input.
	spectator_camera.refresh()
	var state := spectator_camera.state
	state.yaw = yaw
	state.pitch = pitch
	match action:
		"special": state.cycle(spectator_camera.rows.values())
		"previous": state.follow(-1, spectator_camera.rows.values())
		"swap": state.follow(1, spectator_camera.rows.values())
	yaw = state.yaw
	pitch = state.pitch

func _touch_command(action: String, on: bool) -> void:
	if is_instance_valid(spectator_camera) and action in ["special", "swap"]:
		if on:
			_spectator_command(action)
		return
	if action == "lock":
		if Content.balance.has("view"):
			view_lock.press(on)
		return
	if action == "gyro" and on:
		gyro.set_preference(not Controls.values.gyro)
		_status(gyro.status)
	elif action == "lefty" and on:
		Controls.set_value("lefty", not Controls.values.lefty)
	elif action.begins_with("unavailable_") and on:
		_status("touch_lock_pending" if action == "unavailable_lock" else "touch_squad_single")
	else:
		_input_command(action, on)

func _sync_touch() -> void:
	var in_battle := simulation != null and Session.launch_announced and not Session.dedicated and not campaign_ui.visible
	if touch_controls != null:
		touch_controls.sync(in_battle, overlay_open or simulation != null and simulation.over)
	if gyro != null:
		gyro.set_enabled(in_battle)
	if in_battle:
		var pad := Controls.scheme() == "pad"
		var mode := Input.MOUSE_MODE_VISIBLE if overlay_open or simulation.over or pad else Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode != mode:
			Input.mouse_mode = mode

func _control_preferences_changed() -> void:
	_power_preference_changed()
	_suppress_held_controls()
	if touch_controls != null:
		touch_controls.reset()
	_sync_touch()
	_control_hud_layout()

func _power_preference_changed() -> void:
	if audio != null:
		audio.set_low_power(Controls.low_power())
	if simulation != null and simulation.world != null and simulation.world.combat_effects != null:
		simulation.world.combat_effects.low_power = Controls.low_power()

func _view_preference_changed(value: String) -> void:
	if simulation == null or player_view.rules.is_empty():
		return
	yaw = player_view.select_mode(value, yaw)
	if player_view.mode != "tps":
		view_occlusion.clear()
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot != null:
		_bind_camera(pilot)

func _screen_hurt(event: Dictionary) -> void:
	if splat_overlay != null and simulation != null:
		splat_overlay.receive(event, simulation.pilots.get(Session.player_id()))

func _defense_frame(pilot: BattleUnit) -> Dictionary:
	return {"side": pilot.side, "dead": not pilot.alive(), "shop": overlay_open,
		"shield": pilot.shield, "frozen": local_defense.frozen}

func _request_cast(pilot: BattleUnit, slot: String) -> void:
	var now := Time.get_ticks_usec() / 1000000.0
	var definition := Content.local_ability(pilot.character, slot, pilot.combat_level(slot))
	var frame := {"side": pilot.side, "dead": not pilot.alive(), "shop": overlay_open,
		"frozen": local_defense.frozen, "emp": local_cast.emp_left > 0,
		"power": local_fire.power if audio != null else pilot.power, "snow": simulation.weather_dynamics.get("snowCdMul", 1),
		"locked": int(hud_snapshot.get("lock", {}).get("target", 0)) != 0}
	if not local_cast.can_request(definition, slot, now, frame):
		local_cast.notify_rejection(now)
		return
	var point := pilot.global_position
	if ControlPreferences.truthy(definition.range):
		var camera := get_viewport().get_camera_3d()
		if camera == null:
			return
		var reach := maxf(float(definition.range) * float(local_cast.timing.aimRangeMultiplier), float(local_cast.timing.aimMinimumRange))
		point = simulation.presentation_aim(pilot, camera, reach, player_view.mode == "tps").point
	if not point.is_finite():
		push_error("Cast input has no finite native presentation target")
		return
	var source_point := AbilityTarget.wire_point(point.x, point.z)
	if not source_point.is_finite():
		push_error("Cast input exceeds the native point representation")
		return
	if not local_cast.request(definition, slot, now, frame):
		return
	Session.cast_at(slot, source_point)

func _sync_local_cast(pilot: BattleUnit, events: Array, clock: float, published_controls: Dictionary) -> void:
	if pilot == null:
		return
	local_cast.sync(ActorSnapshot.abilities(pilot, clock) if simulation.authoritative else pilot.public_abilities,
		float(published_controls.get("castLeft", 0)), float(published_controls.get("empLeft", 0)))
	if not pilot.alive() or local_cast_dead:
		local_cast.cancel()
	local_cast_dead = not pilot.alive()
	for event: Dictionary in events:
		var serial := int(event.get("notice_serial", 0))
		if serial <= local_cast_notice_serial:
			continue
		local_cast_notice_serial = serial
		if int(event.get("actor", 0)) != pilot.entity_id:
			continue
		match str(event.get("type", "")):
			"cast_start": local_cast.started(float(event.get("duration", 0)), Time.get_ticks_usec() / 1000000.0)
			"cast", "die", "respawn": local_cast.cancel()

func _sync_local_fire(pilot: BattleUnit, events: Array) -> void:
	if audio == null or pilot == null:
		return
	var signature := {"character": pilot.character, "light": pilot.combat_level("light"), "heavy": pilot.combat_level("heavy")}
	if signature != local_fire_signature:
		var refill: bool = not local_fire_signature.is_empty() and (signature.light != local_fire_signature.light or signature.heavy != local_fire_signature.heavy)
		local_fire.set_weapons({"light": simulation.client_weapon_definition(pilot, "light"),
			"heavy": simulation.client_weapon_definition(pilot, "heavy")}, refill)
		local_fire_signature = signature
	local_fire.power = pilot.power
	if local_fire_dead and pilot.alive():
		local_fire.refill()
	local_fire_dead = not pilot.alive()
	for event: Dictionary in events:
		if event.get("type") == "loot" and event.get("ammo", false) and int(event.get("peer", 0)) == pilot.peer_id:
			local_fire.refill()

func _advance_local_fire(pilot: BattleUnit) -> void:
	if audio == null or pilot == null or not pilot.alive() or local_fire_signature.is_empty() or simulation.over:
		return
	var now := Time.get_ticks_usec() / 1000000.0
	local_fire.tick(now)
	if not view_firing:
		local_fire.recoil.release_fire()
	local_fire.reload_factor = float(simulation.weather_dynamics.get("snowCdMul", 1))
	var slot := selected_slot
	var ready := local_fire.attempt(slot, now, {"side": pilot.side, "dead": false, "shop": overlay_open,
		"firing": view_firing, "frozen": local_defense.frozen,
		"casting": local_cast.is_casting(now),
		"emp": local_cast.emp_left > 0, "defending": local_defense.defending, "shield": pilot.shield,
		"aiming": aiming, "moving": InputRules.moving(Session.local_command), "weather_rate": simulation.weather_attack_rate(pilot)})
	if ready:
		audio.fire(local_fire.definitions[slot], slot, pilot.side)

func _body_event_feedback(event: Dictionary) -> void:
	if simulation == null or event.get("type") != "weapon_fire" or not event.has("serial"):
		return
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null:
		if pending_fire_events.size() >= PENDING_FIRE_LIMIT:
			pending_fire_events.pop_front()
		pending_fire_events.append(event)
		return
	if int(event.actor) != pilot.entity_id:
		return
	_bind_camera(pilot)
	pilot.cockpit.fire_feedback(event)
	if event.get("empty_heavy", false) and aiming and int(event.get("aim_request", aim_request)) >= aim_request:
		aim_state_clock = maxf(aim_state_clock, float(event.clock))
		_set_aiming(false, false)

func _register_body_occluders(unit: BattleUnit) -> void:
	if unit.model != null:
		view_occlusion.register_root(unit.model)

func _control_hud_layout() -> void:
	if minimap == null:
		return
	var area := NativeUi.safe_area(hud)
	var inset_right := area.end.x - hud.size.x
	var inset_bottom := area.end.y - hud.size.y
	var mirrored := Controls.scheme() == "pad" and bool(Controls.values.get("screenLefty", false))
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if mirrored else Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(area.position.x + 20 if mirrored else inset_right - minimap.size.x - 20, area.position.y + 20)
	stats.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if mirrored else Control.PRESET_TOP_LEFT)
	stats.position = Vector2(inset_right - 524 if mirrored else area.position.x + 24, area.position.y + 20)
	stats.size.x = 500
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if mirrored else Control.PRESET_BOTTOM_LEFT)
	ammo_label.position = Vector2(inset_right - 974 if mirrored else area.position.x + 24, inset_bottom - 105)
	ammo_label.size = Vector2(950, 80)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	status_icon_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT if mirrored else Control.PRESET_BOTTOM_LEFT)
	status_icon_strip.position = Vector2(inset_right - 424 if mirrored else area.position.x + 24, inset_bottom - 155)
	status_icon_strip.size = Vector2(400, 45)
	status_icon_strip.alignment = FlowContainer.ALIGNMENT_END if mirrored else FlowContainer.ALIGNMENT_BEGIN
	feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT if mirrored else Control.PRESET_TOP_RIGHT)
	feed.position = Vector2(area.position.x + 290 if mirrored else inset_right - 730, area.position.y + 20)
	feed.size.x = 420

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		fatal_paused = true
		fatal_watchdog.visibility(true, _fatal_now())
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		fatal_paused = false
		fatal_watchdog.visibility(false, _fatal_now())
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and simulation != null and not Session.dedicated:
		_overlay(menu, true)

func _advance_look(delta: float) -> void:
	_sync_touch()
	if touch_controls != null:
		touch_controls.tick(delta)
	var sticks := Input.get_connected_joypads()
	if not sticks.is_empty() and not overlay_open:
		_look(Vector2(-Input.get_joy_axis(sticks[0], JOY_AXIS_RIGHT_X), -Input.get_joy_axis(sticks[0], JOY_AXIS_RIGHT_Y)) * delta * 2)
	if not overlay_open:
		var keys: Dictionary = {}
		for digit: int in [1, 2, 3, 4, 6, 7, 8, 9]:
			keys["Numpad" + str(digit)] = _control("look_" + str(digit)) > 0
		var pad := InputRules.numpad(keys)
		_look(pad * float(Content.balance.controls.numpadLookSpeed) * delta)

func _physics_process(delta: float) -> void:
	if simulation == null or Session.dedicated or not Session.launch_announced:
		return
	if is_instance_valid(spectator_camera):
		return
	var motion := Vector2(_control("right") - _control("left"), _control("back") - _control("forward")).limit_length()
	var touch: Dictionary = touch_controls.held if touch_controls != null and touch_controls.visible else {}
	var move_magnitude := motion.length()
	if motion == Vector2.ZERO and touch_controls != null and touch_controls.visible:
		motion = touch_controls.state.axis
		move_magnitude = _touch_axis().mag
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot != null and not pilot.alive():
		touch["fire"] = false
		if Input.get_action_strength("fire") > 0:
			released_controls["fire"] = true
	var command := {"move": motion if not overlay_open else Vector2.ZERO,
		"move_mag": move_magnitude if not overlay_open else 0.0,
		"yaw": yaw, "pitch": pitch, "vertical": maxf(_control("rise"), float(touch.get("jump", false))) - maxf(_control("descend"), float(touch.get("dive", false))) if not overlay_open else 0.0,
		"jump": held_jump and not overlay_open, "fire": (_control("fire") > 0 or touch.get("fire", false)) and not overlay_open,
		"jump_held": (_control("rise") > 0 or touch.get("jump", false)) and not overlay_open,
		"level_move": bool(Controls.values.get("levelMove", false)),
		"slot": selected_slot, "aim": aiming,
		"view_mode": player_view.mode if not player_view.mode.is_empty() else "fpv",
		"view_restore": player_view.restore,
		"sprint": (_control("sprint") > 0 or touch.get("sprint", false)) and not overlay_open}
	view_motion = command.move
	view_firing = command.fire
	held_jump = false
	if network_lob_test:
		command.aim = true
		command.fire = true
		command.slot = "heavy"
		command.pitch = -0.15
		selected_slot = "heavy"
	if network_kinetic_test:
		command.aim = true
		command.fire = true
		command.slot = "heavy" if smoke_time > 1 else "light"
		command.pitch = -0.15
		selected_slot = command.slot
	var submitted := command.duplicate()
	if not network_lob_test and not network_kinetic_test and not smoke and not capture:
		submitted.erase("aim")
		submitted.erase("slot")
	Session.command(submitted)
	var local_pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if local_pilot != null and local_pilot.camera != null and not local_pilot.presentation_camera_owned:
		if not simulation.authoritative:
			local_pilot.yaw = yaw
			local_pilot.pitch = pitch
			local_pilot.sync_view_camera()
		var unit_stats: Dictionary = Content.constants.UNITS[local_pilot.kind]
		local_pilot.camera.fov = unit_stats.get("zoomFov", 35) if command.aim else unit_stats.get("fov", 68)
	if network_test:
		smoke_time += delta
		var lob_ready := not network_lob_test or (network_lob_control_seen and network_lob_shot_seen)
		var kinetic_ready := not network_kinetic_test or (network_kinetic_light_seen and network_kinetic_terminal_seen)
		if smoke_time > 3 and smoke_state_seen and simulation.pilots.has(Session.player_id()) and lob_ready and kinetic_ready:
			print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
			if network_lob_test:
				print("NETWORK_LOB_PASS control=", network_lob_control_seen, " shot=", network_lob_shot_seen)
			if network_kinetic_test:
				print("NETWORK_KINETIC_PASS light=", network_kinetic_light_seen, " heavyTerminal=", network_kinetic_terminal_seen)
			Session.stop()
			get_tree().quit()
		elif smoke_time > 10:
			push_error("NETWORK_TEST_TIMEOUT")
			get_tree().quit(1)
	if (smoke or capture) and not capture_finished:
		smoke_time += delta
		if smoke_time > 6:
			capture_finished = true
			if capture:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://tests/battle.png")
				simulation.world._exit_tree()
			var invalid_positions := false
			for unit: BattleUnit in simulation.units.values():
				if not unit.position.is_finite():
					invalid_positions = true
			var ground_supported := local_pilot != null and (local_pilot.flying or local_pilot.is_on_floor())
			if smoke and (simulation.units.size() < 10 or not smoke_state_seen or invalid_positions or not ground_supported):
				push_error("SMOKE_FAILED")
				get_tree().quit(1)
			else:
				print("SMOKE_PASS units=", simulation.units.size(), " wave=", simulation.wave)
				get_tree().quit()

# Original relay event branch: a starburst 9 above the terrain, independent of the feed.
func _relay_activation(event: Dictionary) -> void:
	if event.type != "relay" or Session.dedicated:
		return
	var point: Vector3 = event.position
	var height := simulation.world.ground_height(point.x, point.z) + 9
	var color := Color(Content.side_info(event.side).color).to_rgba32() >> 8 if not str(event.side).is_empty() else 0x66ffe0
	simulation.world.ensure_combat_effects().spark(Vector3(point.x, height, point.z), 8, color)

func _receive_state(state: Dictionary) -> void:
	fatal_watchdog.snapshot(_fatal_now())
	smoke_state_seen = true
	presentation_clock = state.clock
	hud_snapshot = state
	if simulation == null:
		return
	_receive_audio(state.get("events", []))
	if Session.story_mode():
		var stages: Dictionary = state.get("siege", {}).get("open", {})
		var foe := "SWARM" if Session.config.campaign.side == "STEEL" else "STEEL"
		campaign_dialogue.track(int(stages.get(foe, -1)))
		for event: Dictionary in state.events:
			if event.type == "siege_talk" and event.side == foe and int(event.stage) < int(Content.constants.SIEGE.BASE):
				campaign_dialogue.radio(CampaignRules.talk(int(Session.config.campaign.index), Session.config.campaign.side, int(event.stage)))
	minimap.accept_snapshot(state)
	simulation.world.sync_projectile_view(state.get("projectile_view", []), float(state.clock))
	if Session.is_authority():
		simulation.apply_presentation_view(state)
		simulation.receive_body_events(state.events, simulation.presentation_time())
		simulation.present_world_events(state.events)
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	var published_controls: Dictionary = state.get("control_status", {})
	if pilot != null and published_controls.is_empty():
		push_error("Missing owned control-state publication; matching native client and authority content are required")
		return
	if pilot != null:
		var held := pending_fire_events.duplicate()
		pending_fire_events.clear()
		for event: Dictionary in held:
			_body_event_feedback(event)
		var defense_frame := _defense_frame(pilot)
		defense_frame.frozen = float(published_controls.get("freezeLeft", 0)) > 0
		local_defense.observe_snapshot(defense_frame, Time.get_ticks_usec() / 1000000.0)
		control_status.observe(published_controls)
		var dead := not pilot.alive()
		if dead != control_was_dead:
			control_status.clear_flash()
		control_was_dead = dead
	var icon_values := published_controls.duplicate()
	icon_values.merge(state.get("status_icons", {}), true)
	status_icon_strip.sync(status_icons.observe(icon_values, Time.get_ticks_usec() / 1000000.0, pilot == null))
	_sync_local_cast(pilot, state.get("events", []), float(state.clock), published_controls)
	_sync_local_fire(pilot, state.get("events", []))
	if pilot == null:
		if not Session.dedicated:
			_observer_camera()
		if is_instance_valid(spectator_camera):
			for event: Dictionary in state.events:
				if combat_feed.accept(event):
					_relay_activation(event)
					for text: String in CombatFeedState.messages(event, 0, Session.player_id(), ""):
						feed.push_message(text)
		return
	if is_instance_valid(spectator_camera):
		spectator_camera.free()
		spectator_camera = null
		if touch_controls != null:
			touch_controls.set_spectating(false)
	_bind_camera(pilot)
	var aim_control: Dictionary = state.get("aim_control", {})
	if not aim_control.is_empty() and int(aim_control.request) >= aim_request and float(state.clock) >= aim_state_clock:
		var pending_fallback := local_fire_fallback_request == aim_request and bool(aim_control.on)
		if not pending_fallback:
			local_fire_fallback_request = -1
			_set_aiming(bool(aim_control.on), false)
	if not simulation.authoritative:
		simulation.apply_owner_recoil(state)
		pilot.sync_view_camera()
	for event: Dictionary in state.events:
		if combat_feed.accept(event):
			_relay_activation(event)
			_supply_notice(event, pilot)
			if event.type == "burn" and int(event.get("actor", 0)) == pilot.entity_id:
				status_icons.burn_at = Time.get_ticks_usec() / 1000000.0
			for text: String in CombatFeedState.messages(event, pilot.entity_id, pilot.peer_id, pilot.side):
				feed.push_message(text)
	for text: String in combat_feed.slope_notice(bool(state.get("movement_feedback", {}).get("slope_blocked", false)),
		float(Time.get_ticks_msec()) / 1000, float(state.clock)):
		feed.push_message(text)
	simulation.apply_footprint({} if shop.visible else state.get("footprint", {}), state.get("lock", {}))
	simulation.apply_skill_footprint(state.get("skill_footprint", {}))
	var lock_changed := simulation.apply_lock_glow(state.get("lock", {}))
	if lock_changed:
		var target: BattleUnit = simulation.units.get(simulation.lock_glow.target_id)
		feed.push_message(Content.label("lock_notice") % Content.constants.UNITS.get(target.kind, {}).get("name", target.kind))
	for event: Dictionary in state.events:
		locked_until = LockGlowPresentation.warning_until(locked_until, event, pilot.peer_id, float(Time.get_ticks_msec()) / 1000.0)
		if event.type == "hurt" and int(event.get("attacker", 0)) == pilot.entity_id and int(event.actor) == simulation.lock_glow.target_id:
			simulation.lock_glow.flash(float(Time.get_ticks_msec()) / 1000.0)
	var control: Dictionary = state.get("fire_control", {})
	if network_kinetic_test:
		for event in state.events:
			if event.type != "shot" or int(event.actor) != pilot.entity_id:
				continue
			if event.get("slot") == "light" and event.start.distance_to(event.end) < 20:
				network_kinetic_light_seen = true
			if event.get("slot") == "heavy" and event.get("terminal", false):
				network_kinetic_terminal_seen = true
	if network_lob_test:
		if not control.is_empty() and control.points is PackedVector3Array and control.points.size() > 1:
			var actor_state: Dictionary = state.units.filter(func(actor): return int(actor.peer) == Session.player_id())[0]
			var eye: Vector3 = actor_state.position + Vector3.UP * Content.heroes[actor_state.character].height * Content.constants.SELF_F.eye
			if not control.origin.is_finite() or control.points[0].distance_to(control.origin) > 0.01 or control.origin.distance_to(eye) < 0.1:
				push_error("NETWORK_LOB_ORIGIN_MISMATCH")
				get_tree().quit(1)
			network_lob_control_seen = true
		for event in state.events:
			if event.type == "shot" and int(event.actor) == pilot.entity_id and event.start.distance_to(event.end) < 20:
				network_lob_shot_seen = true
	simulation.world.aim_arc(control)
	_bind_camera(pilot)
	if not simulation.authoritative:
		pilot.yaw = yaw
		pilot.pitch = pitch
		pilot.sync_view_camera()
	pilot.cockpit.control = control
	for event: Dictionary in state.events:
		if event.type == "weapon_fire" and int(event.actor) == pilot.entity_id:
			pilot.cockpit.fire_feedback(event)
	pilot.cockpit.sync_authority_pose(state.weapon_pose)
	_update_player_panel(pilot, state)
	if not control.is_empty():
		var status := "lob_close" if control.close else "lob_blocked" if not control.ok else "lob_aa" if control.aa else "lob_high" if control.high else "lob_45"
		ammo_label.text += " · " + Content.label(status)
	var lock_state: Dictionary = state.get("lock", {})
	if not lock_state.is_empty() and int(lock_state.get("anchor", 0)) != 0:
		ammo_label.text += " · " + Content.label("locked")
	var reachability: Dictionary = state.get("reachability", {})
	if not reachability.is_empty() and reachability.slot == selected_slot:
		var status := "reach_warning" if reachability.warn else "reach_clear" if reachability.ok else "reach_blocked"
		ammo_label.text += " · " + Content.label(status)
	if not pilot.alive():
		notice.text = "" if not death_sequence.state.is_empty() else Content.label("boss_down") if pilot.special.get("boss", false) else "%s %.1f" % [Content.label("respawn"), maxf(0, pilot.respawn_at - state.clock)]
	elif not state.over and notice.text.begins_with(Content.label("respawn")):
		notice.text = ""
	for item in shop_buttons:
		shop_buttons[item].visible = pilot.side != Content.constants.SUPER_SIDE
		var level: int = int(pilot.upgrades[item])
		var def: Dictionary = Content.constants.ECON.UPGRADES[item]
		var button: Button = shop_buttons[item]
		if level >= int(def.max):
			button.text = "%s · %s" % [def.name, Content.label("max")]
			button.disabled = true
		else:
			var step: Dictionary = Content.constants.ECON.UPG_STEPS[level]
			button.text = "%s Lv%d · $%d · %s %d" % [def.name, level, int(step.price), Content.label("score"), int(step.score)]
			button.disabled = pilot.money < step.price or pilot.score < step.score
	var levels: Array = simulation.creep_upgrades.get(pilot.side, [])
	var super_pilot: bool = pilot.side == Content.constants.SUPER_SIDE
	super_buy.visible = super_pilot
	super_auto.visible = super_pilot
	super_detail.visible = super_pilot
	ordinary_shop_hint.visible = not super_pilot
	creep_shop_column.visible = not super_pilot
	if super_pilot:
		var level := int(pilot.upgrades.get("super", 0))
		var full := level >= int(Content.constants.SUPER_UPG.MAX)
		super_buy.text = Content.label("super_upgrade_state") % [level, int(Content.constants.SUPER_UPG.MAX), int(Content.constants.SUPER_UPG.PRICE)]
		super_buy.disabled = full or pilot.money < float(Content.constants.SUPER_UPG.PRICE)
		super_detail.text = Content.label("super_growth") % [SuperRules.combat_level(level), SuperRules.body_scale(level)]
		if full:
			super_auto.button_pressed = false
		var now := Time.get_ticks_msec() / 1000.0
		if not state.over and super_auto.button_pressed and not super_buy.disabled and (super_request_level != level or now - super_request_at >= float(Content.balance["super"].reserveResend)):
			super_request_level = level
			super_request_at = now
			Session.act("buy", "super")
	for lane in range(creep_buttons.size()):
		var button: Button = creep_buttons[lane]
		var level: int = int(levels[lane]) if lane < levels.size() else 0
		var rule: Dictionary = Content.constants.CREEP_UPG
		button.text = "%s %d · Lv%d · $%d" % [Content.label("creep_upgrade"), lane + 1, level, int(rule.PRICE)]
		button.disabled = lane >= levels.size() or not simulation.upgrades_maxed(pilot) or level >= int(rule.MAX) or pilot.money < rule.PRICE

func _update_player_panel(pilot: BattleUnit, snapshot: Dictionary) -> void:
	var info := {"hp": pilot.hp, "max": pilot.max_hp, "sp": pilot.shield, "msp": pilot.max_shield,
		"mp": pilot.power, "mm": pilot.max_power, "money": pilot.money, "kn": pilot.score,
		"lift": maxf(0, pilot.lift), "upg": pilot.upgrades, "defending": local_defense.defending}
	for slot: String in ["light", "heavy"]:
		var weapon := simulation.client_weapon_definition(pilot, slot)
		if audio != null and local_fire.weapons.has(slot):
			info[slot] = local_fire.hud(slot, pilot.combat_level(slot), Time.get_ticks_usec() / 1000000.0)
		else:
			info[slot] = {"name": weapon.name, "lvl": pilot.combat_level(slot), "ammo": pilot.ammo.get(slot, 0), "mag": weapon.mag,
				"reload": maxf(0, float(pilot.reload_at.get(slot, 0)) - float(snapshot.clock))}
	for slot: String in ["def", "atk"]:
		var ability := Content.local_ability(pilot.character, slot, pilot.combat_level(slot))
		var displayed := local_cast.hud(ability, slot, pilot.combat_level(slot),
			local_fire.power if audio != null else pilot.power, float(simulation.weather_dynamics.get("snowCdMul", 1)))
		var remaining := int(displayed.charges)
		var seconds := float(displayed.cd)
		var charges := "%d/%d" % [remaining, int(displayed.maxCharges)] if int(displayed.maxCharges) > 1 else ""
		info[slot] = {"name": ability.name, "lvl": pilot.combat_level(slot), "cd": seconds,
			"ready": displayed.ready, "charges": charges,
			"remaining": remaining, "maximum": int(displayed.maxCharges)}
		if touch_controls != null:
			touch_controls.mirror(slot, seconds, info[slot].ready, false, charges)
	if touch_controls != null:
		var active: Dictionary = info["def" if local_defense.defending else "atk"]
		touch_controls.mirror("special", active.cd, float(active.cd) <= float(Controls.rules.touchHud.cooldownThreshold), false, active.charges)
		var dodge_cd := maxf(0, float(pilot.status.get("iframe_cooldown_until", 0)) - float(snapshot.clock)) if pilot.kind == "drone" else 0.0
		# Source pad readiness uses mobil.mp, which lift-only entries do not carry.
		touch_controls.mirror("jump", dodge_cd, dodge_cd <= float(Controls.rules.touchHud.cooldownThreshold), false)
	if local_cast.cast_left > 0:
		info.cast_seconds = local_cast.cast_left
	_render_player_panel(info, int(snapshot.wave))
	_refresh_standings(snapshot.get("stats", {}))

func _render_player_panel(info: Dictionary, wave: int) -> void:
	stats.text = str(info.get("who", ""))
	ammo_label.text = ""
	if info.get("spec", false) and not info.get("follow", false):
		return
	if not stats.text.is_empty():
		stats.text += "\n"
	stats.text += "%s %.0f/%.0f  |  %s %.0f/%.0f  |  %s %.0f/%.0f\n%s %.0f  |  %s %.0f  |  %s %d" % [
		Content.label("hp"), info.hp, info.max, Content.label("shield"), info.sp, info.msp,
		Content.label("power"), info.mp, info.mm, Content.label("credits"), info.money, Content.label("score"), info.kn, Content.label("wave"), wave]
	var unknown: String = Content.balance.spectator.unknownName
	stats.text += "\n" + Content.label("lift") + " " + (unknown if info.lift == null else "%.0f/%.0f" % [info.lift, Content.constants.FLIGHT.LIFT_MAX])
	if info.get("defending", false):
		stats.text += " · " + Content.label("defending")
	for slot: String in ["def", "atk"]:
		var ability: Dictionary = info[slot]
		stats.text += "\n%s Lv%s" % [ability.name, str(ability.lvl)]
		if ability.has("remaining"):
			stats.text += " · %s %d/%d" % [Content.label("charges"), int(ability.remaining), int(ability.maximum)]
		if float(ability.cd) > 0:
			stats.text += " · %.1f" % float(ability.cd)
	if info.has("cast_seconds"):
		stats.text += "\n%s %.1f" % [Content.label("casting"), info.cast_seconds]
	var upgrades: Variant = info.get("upg")
	if upgrades is Dictionary:
		var values: PackedStringArray = []
		for key: String in Content.constants.ECON.UPGRADES:
			values.append("%s Lv%d" % [Content.constants.ECON.UPGRADES[key].name, int(upgrades.get(key, 0))])
		if upgrades.has("super"):
			values.append("%s Lv%d" % [Content.side_info(Content.constants.SUPER_SIDE).name, int(upgrades["super"])])
		stats.text += "\n" + " · ".join(values)
	for slot: String in ["light", "heavy"]:
		var weapon: Dictionary = info[slot]
		if not ammo_label.text.is_empty():
			ammo_label.text += "\n"
		ammo_label.text += "%s · %s %s/%d" % [weapon.name, Content.label("ammo"), unknown if weapon.ammo == null else str(int(weapon.ammo)), int(weapon.mag)]
		if float(weapon.reload) > 0:
			ammo_label.text += " · %s %.1f" % [Content.label("reload"), weapon.reload]

func _refresh_standings(standings: Dictionary) -> void:
	scoreboard.position = Vector2(stats.position.x, stats.position.y + stats.get_minimum_size().y + 12)
	for side: String in standings:
		if not score_rows.has(side):
			var row := _label("", 16)
			row.add_theme_color_override("font_color", Color(Content.side_info(side).color))
			scoreboard.add_child(row)
			score_rows[side] = row
		var total: Dictionary = standings[side]
		score_rows[side].text = Content.label("match_stats") % [Content.side_info(side).name, int(total.kills), int(total.assists), str(total.creepKills), int(total.deaths)]
	for side: String in score_rows:
		score_rows[side].visible = standings.has(side)

func _refresh_creep_shop() -> void:
	if creep_shop_column == null:
		return
	creep_buttons.clear()
	for child: Node in creep_shop_column.get_children():
		child.queue_free()
	for lane in range(simulation.world.paths.size()):
		var selected_lane := lane
		var button := _button(Content.label("creep_upgrade"), func(): Session.act("buy_creep", str(selected_lane)))
		creep_shop_column.add_child(button)
		creep_buttons.append(button)

func _suppress_held_controls() -> void:
	held_jump = false
	view_lock.press(false)
	for action_name: String in ["forward", "back", "left", "right", "rise", "descend", "sprint", "fire", "look_1", "look_2", "look_3", "look_4", "look_6", "look_7", "look_8", "look_9"]:
		if Input.get_action_strength(action_name) > 0:
			released_controls[action_name] = true

func _overlay(panel: Control, show_panel: bool) -> void:
	if fatal_watchdog.shown:
		return
	if show_panel:
		_suppress_held_controls()
	menu.hide()
	shop.hide()
	panel.visible = show_panel
	if panel == shop and show_panel and simulation != null:
		simulation.apply_footprint({})
	overlay_open = show_panel
	_sync_touch()

func _result(winner: String) -> void:
	if Session.dedicated:
		return
	death_sequence.finish()
	if Session.config.has("campaign"):
		campaign_dialogue.dispose()
		campaign_dialogue.hide()
	if _campaign_participant():
		var selection: Dictionary = Session.config.campaign
		var won: bool = winner == selection.side
		if won and not campaign_result_saved:
			campaign_result_saved = true
			if campaign_progress.mark_cleared(selection.side, selection.chapter) != OK:
				notice.text = Content.label("story_save_failed")
		campaign_ui.show_result(int(selection.index), selection.side, won, simulation.match_stats, campaign_progress)
		menu.hide()
		shop.hide()
		overlay_open = true
		_sync_touch()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Session.chosen_side.is_empty():
		notice.text = Content.label("room_spectator_result") % Content.side_info(winner).name
	else:
		notice.text = Content.label("super_result") % Content.side_info(winner).name if Session.chosen_side == Content.constants.SUPER_SIDE else Content.label("victory" if winner == Session.chosen_side else "defeat")
	_overlay(menu, true)

func _campaign_participant() -> bool:
	return Session.story_mode() and Session.chosen_mode == "player" and not Session.chosen_side.is_empty() and Session.chosen_side == Session.config.campaign.side

func _supply_notice(event: Dictionary, pilot: BattleUnit) -> void:
	var own := int(event.get("peer", 0)) == pilot.peer_id or int(event.get("actor", 0)) == pilot.entity_id
	match event.type:
		"civact":
			if own:
				feed.push_message(Content.label("civilian_away" if event.action == "away" else "civilian_follow"))
		"civfree":
			if own:
				feed.push_message(Content.label("civilian_freed") % int(event.count))
		"civaid":
			if own:
				var name: String = CivilianRules.appearance(int(event.civilian), int(event.profession)).occupation
				var reward := Content.label("civilian_medkit") % [int(event.hp), int(event.shield)] if event.reward == "medkit" else Content.label("civilian_battery") % [int(event.power), float(event.cooldown)] if event.reward == "battery" else Content.label("civilian_money") % int(event.value)
				feed.push_message(Content.label("civilian_aid") % [name, reward])
		"civkill":
			if own:
				var who := Content.label("civilian_enemy_spy" if event.spy and event.civil_side != pilot.side else "civilian_own_spy" if event.spy else "civilian_enemy" if event.civil_side != pilot.side else "civilian_own")
				feed.push_message(Content.label("civilian_killed") % [who, int(event.value)])
		"airfall":
			feed.push_message(Content.label("airfall") % int(event.count))
		"airdrop":
			if own:
				var size_name := Content.label("airdrop_size_" + str(event.size))
				match event.reward:
					"medkit": feed.push_message(Content.label("airdrop_medkit") % [size_name, int(event.hp), int(event.shield)])
					"battery": feed.push_message(Content.label("airdrop_battery") % [size_name, int(event.power), float(event.cooldown)])
					_: feed.push_message(Content.label("airdrop_money") % [size_name, int(event.value)])
			elif event.side != pilot.side:
				feed.push_message(Content.label("airdrop_enemy") % Content.side_info(event.side).name)
		"loot":
			if not own:
				return
			if event.get("ammo", false):
				feed.push_message(Content.label("loot_ammo"))
			elif event.get("affix", "") != "":
				var affix: Dictionary = Content.constants.AFFIXES[event.affix]
				feed.push_message(Content.label("loot_affix") % [affix.name, affix.desc, float(affix.dur)])
			else:
				feed.push_message(Content.label("loot_money") % int(event.value))
		"relay":
			if event.side == pilot.side:
				feed.push_message(Content.label("relay_allied") % int(Content.constants.FIELD.RELAY.VISION_S))
			else:
				feed.push_message(Content.label("relay_enemy") % Content.side_info(event.side).name)
		"sam":
			if int(event.get("target_peer", 0)) == pilot.peer_id or int(event.get("target", 0)) == pilot.entity_id:
				feed.push_message(Content.label("ambush_warning"))
		"mine_blast":
			if own:
				feed.push_message(Content.label("mine_warning"))
		"siege":
			var stage: int = int(event.stage)
			if stage >= 0 and stage < Content.constants.SIEGE.NAMES.size():
				feed.push_message(Content.label("siege_allied" if event.side == pilot.side else "siege_enemy") % Content.constants.SIEGE.NAMES[stage])

func _fatal_now() -> int:
	return Time.get_ticks_msec() + 1

func _setup_fatal_watchdog() -> void:
	fatal_watchdog.rules = Content.balance.get("rooms", {}).get("fatal", {}).duplicate(true)
	fatal_watchdog.last_frame = _fatal_now()
	if fatal_watchdog.rules.is_empty():
		return
	fatal_timer = Timer.new()
	fatal_timer.wait_time = float(fatal_watchdog.rules.POLL_MS) / 1000.0
	fatal_timer.timeout.connect(_fatal_poll)
	add_child(fatal_timer)
	fatal_timer.start()
	RenderingServer.frame_post_draw.connect(_fatal_frame)

func _fatal_frame() -> void:
	fatal_watchdog.last_frame = _fatal_now()

func _fatal_visibility() -> void:
	if is_inside_tree():
		fatal_watchdog.visibility(fatal_paused or get_window().mode == Window.MODE_MINIMIZED, _fatal_now())

func _fatal_phase() -> String:
	if not Session.active:
		return "room"
	return "loading" if not Session.launch_announced and Session.started else Session.phase

func _fatal_poll() -> void:
	if Session.dedicated or fatal_closing:
		return
	_fatal_visibility()
	var now := _fatal_now()
	if DisplayServer.get_name() == "headless":
		fatal_watchdog.last_frame = now
	var reason := fatal_watchdog.reason(_fatal_phase(), not Session.reconnecting, simulation != null, now)
	if not reason.is_empty():
		_show_fatal(Content.label(reason))

func _solo_session() -> bool:
	return Session.active and not Session.dedicated and Session.is_authority() and Session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func _battle_failed(detail: String) -> void:
	if simulation != null:
		simulation.set_physics_process(false)
	if Session.dedicated:
		push_error(detail)
		return
	var template: String = Content.balance.get("rooms", {}).get("ui", {}).get("fatal_battle", "")
	_show_fatal(template % detail if not template.is_empty() else detail, true)

func _show_fatal(reason: String, force: bool = false) -> void:
	if not fatal_watchdog.reveal(_fatal_phase(), force):
		if not fatal_watchdog.shown:
			notice.text = reason
		return
	if Session.dedicated or DisplayServer.get_name() == "headless":
		push_error(reason)
		get_tree().quit(1)
		return
	_suppress_held_controls()
	menu.hide()
	shop.hide()
	overlay_open = true
	_sync_touch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fatal_restart_button.visible = _solo_session()
	fatal_dialog.dialog_text = reason
	fatal_dialog.popup_centered_clamped(Vector2i(640, 240), 0.9)

func _fatal_close() -> void:
	if fatal_closing:
		return
	fatal_closing = true
	fatal_dialog.hide()
	campaign_dialogue.dispose()
	campaign_ui.cinematic.dispose()
	await Session.leave()
	fatal_watchdog.shown = false
	fatal_watchdog.load_started = 0
	fatal_watchdog.load_progress = 0
	fatal_watchdog.local_loaded = false
	fatal_watchdog.launched(_fatal_now())
	campaign_ui.hide()
	_room_returned()
	fatal_closing = false

func _fatal_restart() -> void:
	if fatal_closing:
		return
	var solo := _solo_session()
	await _fatal_close()
	if solo and Session.can_quick_restart():
		await get_tree().process_frame
		if not Session.active:
			_quick_restart()

func _status(key: String) -> void:
	notice.text = Content.label(key)
	if key in ["disconnected", "failed"] and simulation != null:
		_leave()

func _leave() -> void:
	if leaving_battle:
		return
	leaving_battle = true
	if audio != null:
		audio.stop_move()
		audio.set_scene("menu")
	_reset_death_view()
	view_occlusion.dispose()
	var selection: Dictionary = Session.config.campaign.duplicate() if _campaign_participant() else {}
	campaign_dialogue.dispose()
	campaign_dialogue.hide()
	campaign_ui.cinematic.dispose()
	await Session.leave()
	view_lock.press(false)
	view_lock.clear_dead()
	view_ready = false
	scope_state.clear()
	if scope_overlay != null:
		scope_overlay.clear()
	if touch_controls != null:
		touch_controls.sync(false, true)
	if gyro != null:
		gyro.set_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not selection.is_empty():
		loading_panel.hide()
		if simulation != null:
			simulation.set_physics_process(false)
			simulation.queue_free()
			simulation = null
		hud.hide()
		menu.hide()
		shop.hide()
		overlay_open = false
		bound_pilot = 0
		selected_slot = "light"
		campaign_ui.open(campaign_progress, selection.side)
		leaving_battle = false
		return
	_room_returned()
	leaving_battle = false

func _receive_audio(events: Array) -> void:
	if audio == null:
		return
	var camera := get_viewport().get_camera_3d()
	for event: Dictionary in events:
		var serial := int(event.get("notice_serial", 0))
		if serial <= audio_notice_serial:
			continue
		audio_notice_serial = serial
		var actor: BattleUnit = simulation.units.get(int(event.get("actor", 0)))
		var source := AudioEvent.source_event(event, actor.peer_id if actor != null else 0)
		if not source.is_empty():
			audio.on_source_event(source, camera.global_transform if camera != null else null, Session.player_id())

func _room_cleared() -> void:
	room_world_prebuild.clear()
	control_status.reset()
	control_was_dead = false
	status_icons.reset()
	status_icon_strip.clear()
	audio_scene.reset()
	audio_notice_serial = 0
	if audio != null:
		audio.stop_move()
		audio.set_scene("menu")
	if pip_view != null:
		pip_view.clear()
	if minimap != null:
		minimap.clear()
	spectator_camera = null
	hud_snapshot = {}
	_reset_death_view()
	view_occlusion.dispose()
	if simulation != null:
		# A native world holds most of the mesh RID budget. Loading the next one on
		# worker threads while this one is freed races the renderer's RID owner.
		retiring_simulation = weakref(simulation)
		simulation.tree_exited.connect(_update_lobby, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		simulation.queue_free()
		simulation = null
	view_ready = false
	bound_pilot = 0
	loading_panel.hide()
	scope_state.clear()
	presentation_frame.clear()
	campaign_dialogue.dispose()
	if scope_overlay != null:
		scope_overlay.clear()

func _room_returned() -> void:
	_room_cleared()
	hud.hide()
	menu.hide()
	shop.hide()
	campaign_dialogue.hide()
	backdrop.show()
	lobby.visible = not Session.dedicated
	overlay_open = false
	view_lock.press(false)
	view_lock.clear_dead()
	bound_view_reset = -1
	view_motion = Vector2.ZERO
	view_firing = false
	released_controls.clear()
	if hurt_overlay != null:
		hurt_overlay.clear()
	if splat_overlay != null:
		splat_overlay.reset_room()
	if gyro != null:
		gyro.set_enabled(false)
	_sync_touch()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _open_campaign() -> void:
	if Session.active:
		return
	lobby.hide()
	campaign_ui.open(campaign_progress, "STEEL" if side_select.selected == 0 else "SWARM")

func _start_campaign(settings: Dictionary) -> void:
	if settings.is_empty():
		_status("story_content_missing")
		return
	Session.chosen_name = Session.deployment.remember_name(player_name.text)
	var error := Session.host(settings, int(port.value), "offline")
	if error != OK:
		_status("story_map_missing" if error == ERR_UNAVAILABLE else "host_failed")
		campaign_ui.open(campaign_progress, settings.campaign.side)
		return
	Session.set_ready(true)
	Session.start_battle()
