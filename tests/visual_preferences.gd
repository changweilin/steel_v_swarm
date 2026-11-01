extends "res://tests/run.gd"

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/visual_preferences.json")
	_check(capture.get("formatVersion") == 1 and capture.get("source") is Dictionary and capture.get("fixtures") is Dictionary,
		"Capture original visual preference programs before native verification")
	if failures > 0:
		_finish_visuals()
		return
	var source: Dictionary = capture.source
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == source.inputs[path], "Original visual reference generator is current: " + path)
	for path: String in source.sourceInputs:
		_check(provenance.get("inputs", {}).get(path) == source.sourceInputs[path], "Original visual input matches imported source: " + path)
	_check(capture.get("metadata") == Content.balance.get("visual"), "Native visual catalog retains the exact original declarations")
	if failures > 0:
		_finish_visuals()
		return
	VisualTests.run(self, capture.fixtures)
	_persistence()
	_finish_visuals()

func _persistence() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var path := "res://build/sol-visual-persistence.cfg"
	var preferences := VisualPreferences.new()
	preferences.configure(Content.balance.visual)
	preferences.save_path = path
	preferences.select_preset(Content.balance.visual.presets[1].id)
	preferences.set_value("worldTextLang", "en")
	preferences.set_value("foam", .75)
	var file := ConfigFile.new()
	_check(file.load(path) == OK, "Native visual preference transactions persist successfully")
	_check(file.get_sections() == PackedStringArray(["visual"]) and file.get_section_keys("visual").size() == 2,
		"Native settings persist only original preset and signage language")
	for key: String in preferences.saved_values():
		_check(file.get_value("visual", key) == preferences.saved_values()[key], "Native saved visual value: " + key)
	var restored := VisualPreferences.new()
	restored.configure(Content.balance.visual)
	restored.load_save(path)
	_check(restored.saved_values() == preferences.saved_values(), "Native ConfigFile reload restores the original persisted selection")
	_check(restored.value("foam") == restored.selected_preset().values.foam,
		"Session-only renderer overrides reset to the selected source preset on reload")
	preferences.free()
	restored.free()
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Native visual persistence fixture cleans up its own file")

func _finish_visuals() -> void:
	print("VISUAL_PREFERENCES assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
