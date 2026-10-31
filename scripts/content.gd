extends Node

var balance: Dictionary
var maps: Array
var text: Dictionary
var constants: Dictionary
var heroes: Dictionary
var structures: Dictionary
var campaign: Dictionary = {}
var art_cache: Dictionary = {}
var balance_preferences: BalancePreferences
var local_balance: BalanceDefinitions
var fixture_registry: Dictionary = {}

func _ready() -> void:
	balance = read_json("res://data/balance.json")
	maps = read_json("res://data/maps.json")
	constants = balance.constants
	heroes = balance.heroes
	structures = read_json("res://data/structures.json")
	text = read_json("res://data/ui.json")
	if FileAccess.file_exists("res://data/campaign.json"):
		campaign = read_json("res://data/campaign.json")
	_install_input()

func read_json(path: String, fixture_sections: Variant = null) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Required content missing: " + path)
		get_tree().quit(1)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("Invalid content: " + path + ": " + parser.get_error_message())
		get_tree().quit(1)
		return {}
	if parser.data is Dictionary and parser.data.get("fixtureFormat") == "source-sections-v1":
		fixture_registry = parser.data
		return SourceFixtureSections.load_sections(parser.data, path, fixture_sections)
	return parser.data

func fixture_sections_for(script: Script, recursive := true) -> Array:
	if fixture_registry.is_empty():
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/fixtures.json")) != OK:
			push_error("Invalid source fixture registry")
			get_tree().quit(1)
			return []
		fixture_registry = parser.data
	var path := script.resource_path.trim_prefix("res://")
	var consumer: Dictionary = fixture_registry.get("consumers", {}).get(path, {})
	if consumer.is_empty() or FileAccess.get_sha256(script.resource_path) != consumer.sha256:
		push_error("Regenerate source fixture consumer dependencies: " + path)
		get_tree().quit(1)
		return []
	return consumer.get("all" if recursive else "direct", [])

func read_fixture_part(key: String, index: int) -> Variant:
	return SourceFixtureSections.load_part(fixture_registry, "res://data/fixtures.json", key, index)

func weapon(character: String, slot: String, level: float = 1) -> Dictionary:
	if level > 4 or level != floorf(level):
		return heroes[character]["super"].weapons[slot][SuperRules.level(roundf((level - 1) * 20.0 / 3.0))]
	var tiers: Array = heroes[character].weapons[slot]
	return tiers[clampi(int(level) - 1, 0, tiers.size() - 1)]

func ability(character: String, slot: String, level: float = 1) -> Dictionary:
	if level > 4 or level != floorf(level):
		return heroes[character]["super"].abilities[slot][SuperRules.level(roundf((level - 1) * 20.0 / 3.0))]
	var tiers: Array = heroes[character].abilities[slot]
	return tiers[clampi(int(level) - 1, 0, tiers.size() - 1)]

func initialize_local_balance(persist: bool) -> Error:
	if local_balance != null:
		return OK
	if not balance.get("balancePreferences", {}).has("definitions"):
		return ERR_UNAVAILABLE
	balance_preferences = BalancePreferences.new()
	balance_preferences.configure(balance.balancePreferences)
	balance_preferences.persist = persist
	var error := balance_preferences.load_save()
	local_balance = BalanceDefinitions.new()
	local_balance.configure(balance_preferences, balance.balancePreferences.definitions)
	return error

func local_weapon(character: String, slot: String, level: float = 1) -> Dictionary:
	return local_balance.weapon(character, slot, level) if local_balance != null else weapon(character, slot, level)

func local_ability(character: String, slot: String, level: float = 1) -> Dictionary:
	return local_balance.ability(character, slot, level) if local_balance != null else ability(character, slot, level)

func local_view_curve() -> Dictionary:
	return local_balance.view_curve() if local_balance != null else balance.bodyRules.curve

func map_variant(index: int, size: int, swapped: bool = false) -> Dictionary:
	var entry: Dictionary = maps[clampi(index, 0, maps.size() - 1)]
	var variants: Dictionary = entry.get("swapped_variants", {}) if swapped else entry.variants
	if not variants.has(str(clampi(size, 1, 5))):
		return {}
	var variant: Dictionary = variants[str(clampi(size, 1, 5))].duplicate(true)
	variant.native_world = "res://assets/worlds/%s%s_%d.res" % [entry.id, "_swap" if swapped else "", clampi(size, 1, 5)]
	return variant

func side_info(side: String) -> Dictionary:
	if constants.SIDES.has(side):
		return constants.SIDES[side]
	if constants.THIRD.SIDES.has(side):
		return constants.THIRD.SIDES[side]
	if side == constants.SUPER_SIDE:
		return constants.SUPER_INFO
	return balance.side_unknown

func super_available() -> bool:
	return balance.has("super") and heroes.values().all(func(hero): return hero.has("super"))

func campaign_map(index: int, side: String, swapped: bool = false) -> Dictionary:
	var chapter := CampaignRules.chapter(index)
	if chapter.is_empty():
		return {}
	for entry: Dictionary in campaign.get("maps", []):
		if entry.chapter == chapter.id and entry.side == side and bool(entry.swapped) == swapped:
			var variant: Dictionary = entry.variants[str(int(chapter.teamSize))].duplicate(true)
			variant.native_world = "res://assets/worlds/%s_%d.res" % [entry.id, int(chapter.teamSize)]
			return variant
	return {}

func battle_map(settings: Dictionary) -> Dictionary:
	var result := campaign_map(int(settings.campaign.index), settings.campaign.side, settings.campaign.swapped) if settings.has("campaign") else map_variant(int(settings.map_index), int(settings.team_size), bool(settings.get("swapped", false)))
	if not result.is_empty():
		result.config["super"] = bool(settings.get("super", false)) and not settings.has("campaign")
	return result

func campaign_available(index: int, side: String) -> bool:
	var chapter := CampaignRules.chapter(index)
	if chapter.is_empty():
		return false
	for swapped in [false, true]:
		var map := campaign_map(index, side, swapped)
		if map.is_empty():
			return false
		var path := WorldVariant.path(map.native_world, chapter.env)
		if path.is_empty() or not ResourceLoader.exists(path):
			return false
	return true

func campaign_art(id: String, kind: String = "avatar", mode: String = "char") -> Texture2D:
	var path: String = campaign.get("art", {}).get(id, {}).get("mech" if mode == "mech" else "char", {}).get(kind, "")
	return story_texture(path)

func story_texture(path: String, mipmaps: bool = false) -> Texture2D:
	if path.is_empty() or not path.begins_with("assets/"):
		return null
	var native_path := "res://" + path
	var key := native_path + ("/mipmaps" if mipmaps else "")
	if art_cache.has(key):
		return art_cache[key]
	if not ResourceLoader.exists(native_path):
		return null
	# A failed native decode is unavailable art, never a cached or derived texture.
	var texture := load(native_path) as Texture2D
	if texture == null:
		return null
	if mipmaps:
		# Renderers may return the texture's retained image; derive levels from a copy.
		var image := texture.get_image()
		if image == null or image.is_empty():
			return null
		var data := Image.new()
		data.copy_from(image)
		if data.generate_mipmaps() != OK:
			return null
		texture = ImageTexture.create_from_image(data)
	art_cache[key] = texture
	return texture

func label(key: String) -> String:
	return str(balance.get("rooms", {}).get("ui", {}).get(key, text.get(key, key)))

func _install_input() -> void:
	var keys := {"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"rise": [KEY_SPACE], "descend": [KEY_C, KEY_CTRL], "sprint": [KEY_SHIFT], "reload": [KEY_R],
		"shop": [KEY_B], "map": [KEY_M], "defense": [KEY_Q], "attack": [KEY_E], "civ_follow": [KEY_G], "civ_away": [KEY_H],
		"defend": [KEY_F], "pause": [KEY_ESCAPE], "fire": [KEY_KP_MULTIPLY], "stance_ability": [KEY_KP_DIVIDE],
		"aim": [KEY_KP_ADD, KEY_KP_SUBTRACT],
		"look_1": [KEY_KP_1], "look_2": [KEY_KP_2], "look_3": [KEY_KP_3], "look_4": [KEY_KP_4],
		"look_6": [KEY_KP_6], "look_7": [KEY_KP_7], "look_8": [KEY_KP_8], "look_9": [KEY_KP_9]}
	for action: String in keys:
		InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for spec: Array in [["fire", MOUSE_BUTTON_LEFT], ["stance_ability", MOUSE_BUTTON_RIGHT], ["aim", MOUSE_BUTTON_WHEEL_UP], ["aim", MOUSE_BUTTON_WHEEL_DOWN]]:
		var event := InputEventMouseButton.new()
		event.button_index = int(spec[1])
		InputMap.action_add_event(spec[0], event)
	InputMap.action_add_event("fire", _joy_button(JOY_BUTTON_RIGHT_SHOULDER))
	InputMap.action_add_event("aim", _joy_button(JOY_BUTTON_LEFT_SHOULDER))
	InputMap.action_add_event("rise", _joy_button(JOY_BUTTON_A))
	InputMap.action_add_event("defense", _joy_button(JOY_BUTTON_X))
	InputMap.action_add_event("attack", _joy_button(JOY_BUTTON_Y))
	for spec in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0],
		["forward", JOY_AXIS_LEFT_Y, -1.0], ["back", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = spec[1]
		event.axis_value = spec[2]
		InputMap.action_add_event(spec[0], event)

func _joy_button(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event

