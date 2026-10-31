class_name AudioPreferences
extends RefCounted

signal changed(operation: String, values: Dictionary)
signal save_failed(error: Error)

const SAVE_PATH := "user://audio.cfg"

var rules: Dictionary = {}
var sfx_volume: Variant = 0.0
var bgm_volume: Variant = 0.0
var sfx_on: Variant = true
var bgm_on: Variant = true
var persist := false
var save_path := SAVE_PATH

func configure(metadata: Dictionary, saved: Variant = {}) -> void:
	rules = metadata
	if saved is Dictionary and saved.get("sfxVol") != null:
		sfx_volume = _clamp(saved.sfxVol)
		bgm_volume = _clamp(_value(saved, "bgmVol", rules.bgmDefault))
		sfx_on = _value(saved, "sfxOn", true)
		bgm_on = _value(saved, "bgmOn", true)
	else:
		# The original legacy branch deliberately does not clamp master.
		sfx_volume = _value(saved, "master", rules.masterDefault)
		bgm_volume = rules.bgmDefault
		sfx_on = not ControlPreferences.truthy(_value(saved, "muted", false))
		bgm_on = sfx_on

static func _value(saved: Variant, key: String, fallback: Variant) -> Variant:
	return saved[key] if saved is Dictionary and saved.get(key) != null else fallback

static func _clamp(input: Variant) -> Variant:
	var number := VisualPreferences._number(input)
	if number < 0:
		return 0.0
	if number > 1:
		return 1.0
	return input

func saved_values() -> Dictionary:
	return {"sfxVol": sfx_volume, "bgmVol": bgm_volume, "sfxOn": sfx_on, "bgmOn": bgm_on}.duplicate(true)

func master_on() -> Variant:
	return bgm_on if ControlPreferences.truthy(sfx_on) else sfx_on

func snapshot() -> Dictionary:
	var values := saved_values()
	values.masterOn = master_on()
	return values

func set_sfx(value: Variant) -> void:
	sfx_volume = _clamp(value)
	_commit("sfx")

func set_bgm(value: Variant) -> void:
	bgm_volume = _clamp(value)
	_commit("bgm")

func set_sfx_on(value: Variant) -> void:
	sfx_on = ControlPreferences.truthy(value)
	_commit("sfx_on")

func set_bgm_on(value: Variant) -> void:
	bgm_on = ControlPreferences.truthy(value)
	_commit("bgm_on", true)

func set_master_on(value: Variant) -> void:
	sfx_on = ControlPreferences.truthy(value)
	bgm_on = sfx_on
	_commit("master_on", true)

func _commit(operation: String, save_first: bool = false) -> void:
	if save_first:
		_save()
	changed.emit(operation, snapshot())
	if not save_first:
		_save()

func _save() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	file.set_value("audio", "values", saved_values())
	var error := file.save(save_path)
	if error != OK:
		save_failed.emit(error)

func load_save() -> Error:
	if not persist:
		return OK
	var file := ConfigFile.new()
	var error := _parse(file)
	if error != OK:
		configure(rules)
		return OK if error == ERR_FILE_NOT_FOUND else error
	configure(rules, file.get_value("audio", "values", {}))
	return OK

## ConfigFile.load reports a malformed section header through the engine error log, so
## headers are checked first and the file is parsed only once they are well formed.
func _parse(file: ConfigFile) -> Error:
	if not FileAccess.file_exists(save_path):
		return ERR_FILE_NOT_FOUND
	var reader := FileAccess.open(save_path, FileAccess.READ)
	if reader == null:
		return FileAccess.get_open_error()
	var text := reader.get_as_text()
	reader.close()
	if not _headers_valid(text):
		return ERR_PARSE_ERROR
	return file.parse(text)

static func _headers_valid(text: String) -> bool:
	var depth := 0
	var quoted := false
	var escaped := false
	for line: String in text.split("\n"):
		var trimmed := line.strip_edges()
		if depth == 0 and not quoted and trimmed.begins_with("["):
			var close := trimmed.find("]")
			if close < 0:
				return false
			var rest := trimmed.substr(close + 1).strip_edges()
			if not rest.is_empty() and not rest.begins_with(";"):
				return false
			continue
		for character: String in line:
			if escaped:
				escaped = false
			elif quoted and character == "\\":
				escaped = true
			elif character == "\"":
				quoted = not quoted
			elif not quoted:
				if character == ";":
					break
				if character in "[{":
					depth += 1
				elif character in "]}":
					depth = maxi(0, depth - 1)
	return true
