class_name SourceFixtureSections
extends RefCounted

static func load_sections(registry: Dictionary, path: String, requested: Variant = null) -> Dictionary:
	var result := {}
	var order: Array = registry.get("sectionOrder", [])
	var sections: Dictionary = registry.get("sections", {})
	if order.size() != sections.size() or order.is_empty():
		_fail("Invalid source fixture registry: " + path)
		return {}
	var names: Array = order if requested == null else requested
	for key: String in names:
		if not sections.has(key):
			_fail("Missing original fixture section: " + key)
			return {}
		var section: Dictionary = sections[key]
		var parts: Array = section.get("parts", [])
		if parts.is_empty():
			_fail("Empty source fixture partition list: " + key)
			return {}
		var values: Array = []
		for index in parts.size():
			var part: Dictionary = parts[index]
			var value: Variant = load_part(registry, path, key, index)
			if section.kind == "array":
				if not value is Array or value.size() != int(part.count):
					_fail("Source fixture partition row count mismatch: " + part.path)
					return {}
				values.append_array(value)
			else:
				if parts.size() != 1:
					_fail("Invalid scalar source fixture partition count: " + key)
					return {}
				result[key] = value
		if section.kind == "array":
			if values.size() != int(section.count):
				_fail("Source fixture section lost captured rows: " + key)
				return {}
			result[key] = values
	return result

static func load_part(registry: Dictionary, base: String, key: String, index: int) -> Variant:
	var section: Dictionary = registry.get("sections", {}).get(key, {})
	var parts: Array = section.get("parts", [])
	if index < 0 or index >= parts.size():
		_fail("Invalid original fixture partition index: " + key)
		return null
	var part: Dictionary = parts[index]
	var name: String = part.path
	if not name.begins_with("fixture_parts/") or name.contains("..") or name.contains("\\"):
		_fail("Invalid original fixture partition path: " + name)
		return null
	var path := base.get_base_dir().path_join(name)
	if FileAccess.get_sha256(path) != part.sha256:
		_fail("Original fixture partition hash mismatch: " + path)
		return null
	var value: Variant = Content.read_json(path)
	if registry.get("numericEncoding") == "f64-le":
		var numeric: Dictionary = part.get("numbers", {})
		var numeric_name: String = numeric.get("path", "")
		if not numeric_name.begins_with("fixture_parts/") or numeric_name.contains("..") or numeric_name.contains("\\"):
			_fail("Invalid original numeric fixture partition path")
			return null
		var numeric_path := base.get_base_dir().path_join(numeric_name)
		if FileAccess.get_sha256(numeric_path) != numeric.get("sha256"):
			_fail("Original numeric fixture partition hash mismatch: " + numeric_path)
			return null
		var numbers := FileAccess.get_file_as_bytes(numeric_path)
		if numbers.size() != int(numeric.get("bytes", -1)) or numbers.size() != int(numeric.get("count", -1)) * 8:
			_fail("Original numeric fixture partition length mismatch: " + numeric_path)
			return null
		var restored := restore_numeric_tape(value, numbers)
		if not restored.ok:
			_fail(str(restored.error) + ": " + numeric_path)
			return null
		value = restored.value
	if section.kind == "array" and (not value is Array or value.size() != int(part.count)):
		_fail("Original fixture partition row count mismatch: " + path)
		return null
	return value

## Restores every numeric leaf of a captured JSON value tree from its native
## float64 little-endian tape, in the producer's depth-first order. Strings,
## booleans and nulls keep their parsed values and the tree keeps its shape.
## Callers validate the storage paths and hashes of both inputs first.
## Returns {"ok": bool, "value": Variant, "error": String}; on failure the
## captured tree is returned unchanged and no partial restoration is exposed.
static func restore_numeric_tape(value: Variant, numbers: PackedByteArray) -> Dictionary:
	if numbers.size() % 8 != 0:
		return {"ok": false, "value": value, "error": "Original numeric tape is not a whole number of float64 words"}
	var count := _count_numbers(value)
	if count * 8 > numbers.size():
		return {"ok": false, "value": value, "error": "Original numeric tape ended before its value tree"}
	if count * 8 < numbers.size():
		return {"ok": false, "value": value, "error": "Original numeric tape was not fully consumed"}
	var cursor := [0]
	var restored: Variant = _restore_numbers(value.duplicate(true) if value is Dictionary or value is Array else value, numbers, cursor)
	return {"ok": true, "value": restored, "error": ""}

static func _count_numbers(value: Variant) -> int:
	var count := 0
	if value is Dictionary:
		for item: Variant in value.values():
			count += _count_numbers(item)
	elif value is Array:
		for item: Variant in value:
			count += _count_numbers(item)
	elif value is float or value is int:
		count = 1
	return count

# The word count is validated before restoration, so every leaf has a word.
static func _restore_numbers(value: Variant, numbers: PackedByteArray, cursor: Array) -> Variant:
	if value is Dictionary:
		for key: Variant in value:
			value[key] = _restore_numbers(value[key], numbers, cursor)
	elif value is Array:
		for index in value.size():
			value[index] = _restore_numbers(value[index], numbers, cursor)
	elif value is float or value is int:
		value = numbers.decode_double(int(cursor[0]))
		cursor[0] += 8
	return value

static func _fail(message: String) -> void:
	push_error(message)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.quit(1)
