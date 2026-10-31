class_name ControlPreferences
extends Node

signal changed
signal view_changed(value: String)
signal power_changed
signal save_failed(error: Error)

const SAVE_PATH := "user://controls.cfg"

var rules: Dictionary = {}
var values: Dictionary = {}
var pref := ""
var pick := ""
var device_pick := ""
var room := ""
var persist := true
var view_pref := "fpv"
var power_pref: Variant = null

func _ready() -> void:
	if not Content.balance.has("mobile"):
		push_error("Missing original mobile/control metadata; regenerate source content")
		return
	configure(Content.balance.mobile)
	load_save()

func configure(metadata: Dictionary) -> void:
	rules = metadata
	values = rules.touchDefaults.duplicate(true)
	for group: String in ["lookPrefs", "movePrefs"]:
		for key: String in rules[group]:
			values[key] = rules[group][key].def
	pref = rules.defaultMode
	pick = ""
	device_pick = ""
	room = ""
	power_pref = null
	if Content.balance.has("playerView"):
		view_pref = Content.balance.playerView.defaultMode

static func source_bool(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is String:
		return true if value == "true" else false if value == "false" else fallback
	if value is int or value is float:
		return true if value == 1 else false if value == 0 else fallback
	return fallback

static func truthy(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	if value is String:
		return not value.is_empty()
	if value is int or value is float:
		return value != 0 and not is_nan(float(value))
	return true

func normalize(key: String, value: Variant) -> Variant:
	if key in ["invertX", "invertY", "levelMove"]:
		return source_bool(value)
	if key == "gyroSrc":
		return value if value is String and value in rules.gyroSources else rules.touchDefaults.gyroSrc
	if key in ["gyroSens", "lookSens"]:
		var number := 0.0
		if value is float or value is int or value is bool:
			number = float(value)
		elif value is String and value.strip_edges().is_valid_float():
			number = value.to_float()
		return clampf(number if is_finite(number) else rules.sensitivity.min, rules.sensitivity.min, rules.sensitivity.max)
	return truthy(value)

func load_save(path: String = SAVE_PATH) -> void:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Cannot load control preferences: " + error_string(error))
		return
	for key: String in values:
		if file.has_section_key("input", key):
			values[key] = normalize(key, file.get_value("input", key))
	if not file.has_section_key("input", "screenLefty") and file.has_section_key("input", "lefty"):
		values.screenLefty = values.lefty
	var saved = file.get_value("control", "mode", pref)
	if saved is String and saved in rules.modeKeys:
		pref = saved
	saved = file.get_value("control", "scheme", "")
	if saved is String and saved in rules.schemeKeys:
		pick = saved
	saved = file.get_value("control", "view_mode", view_pref)
	if saved is String and saved in Content.balance.get("playerView", {}).get("modeKeys", []):
		view_pref = saved
	power_pref = file.get_value("presentation", "low_power", null) if file.has_section_key("presentation", "low_power") else null
	changed.emit()
	view_changed.emit(view_pref)
	power_changed.emit()

func save(path: String = SAVE_PATH) -> Error:
	if not persist:
		return OK
	var file := ConfigFile.new()
	for key: String in values:
		file.set_value("input", key, values[key])
	file.set_value("control", "mode", pref)
	file.set_value("control", "scheme", pick)
	file.set_value("control", "view_mode", view_pref)
	if power_pref != null:
		file.set_value("presentation", "low_power", power_pref)
	var error := file.save(path)
	if error != OK:
		push_error("Cannot save control preferences: " + error_string(error))
		save_failed.emit(error)
	return error

func low_power() -> bool:
	return scheme() == "pad" if power_pref == null else power_pref is String and power_pref == "1"

func set_low_power(on: bool) -> void:
	var next := "1" if on else "0"
	if power_pref is String and power_pref == next:
		return
	power_pref = next
	save()
	power_changed.emit()

func set_value(key: String, value: Variant) -> bool:
	if not values.has(key):
		return false
	var next = normalize(key, value)
	if values[key] != next:
		values[key] = next
		save()
		changed.emit()
	return true

func set_pref(value: String) -> bool:
	if value not in rules.get("modeKeys", []):
		return false
	if pref != value:
		var before := mode()
		pref = value
		save()
		if mode() != before:
			changed.emit()
	return true

func set_view_pref(value: String, save_preference: bool = true) -> bool:
	if value not in Content.balance.get("playerView", {}).get("modeKeys", []):
		return false
	if view_pref != value:
		view_pref = value
		if save_preference:
			save()
		view_changed.emit(value)
	return true

func set_scheme(value: String) -> bool:
	if mode() != rules.get("defaultMode") or value not in rules.get("schemeKeys", []):
		return false
	if scheme() != value:
		pick = value
		save()
		changed.emit()
	return true

# Only Session's authority broadcast supplies the room override.
func set_room(value: String) -> void:
	var next := value if value in rules.get("modeKeys", []) else ""
	if room != next:
		room = next
		changed.emit()

func mode() -> String:
	return room if not room.is_empty() else pref

static func device_scheme(touch: bool, coarse: bool, no_hover: bool, screen_size: Vector2) -> String:
	var width := screen_size.x if screen_size.x != 0 else 9999.0
	var height := screen_size.y if screen_size.y != 0 else 9999.0
	return "pad" if touch and (coarse and no_hover or minf(width, height) <= 820) else "kbm"

func scheme() -> String:
	if mode() != rules.get("defaultMode"):
		return mode()
	if not pick.is_empty():
		return pick
	if device_pick.is_empty():
		device_pick = detected_scheme()
	return device_pick

func detected_scheme() -> String:
	var mobile := OS.get_name() in ["Android", "iOS"]
	return device_scheme(DisplayServer.is_touchscreen_available(), mobile, mobile, Vector2(DisplayServer.screen_get_size()))
