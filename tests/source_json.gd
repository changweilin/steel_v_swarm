extends Node

const Meshes = preload("res://tools/source_world_meshes.gd")
var assertions := 0
var failures: Array[String] = []
var differences: Array = []

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _ready() -> void:
	_run.call_deferred()

func _bits(values: Variant, expected: String, label: String) -> void:
	var actual := PackedFloat64Array(values).to_byte_array()
	var source := Marshalls.base64_to_raw(expected)
	if actual != source:
		var changed := 0
		var first: Array = []
		for offset in range(0, mini(actual.size(), source.size()), 8):
			if actual.slice(offset, offset + 8) != source.slice(offset, offset + 8):
				changed += 1
				if first.size() < 4:
					first.append({"index": offset / 8, "expectedBytes": source.slice(offset, offset + 8).hex_encode(),
						"actualBytes": actual.slice(offset, offset + 8).hex_encode(),
						"expected": source.decode_double(offset), "actual": actual.decode_double(offset)})
		differences.append({"label": label, "changed": changed, "actualBytes": actual.size(), "expectedBytes": source.size(), "first": first})
	_check(actual == source, label)

func _run() -> void:
	var fixture: Dictionary = Content.read_json("res://artifacts/sol/source-json/fixture.json")
	_check(fixture.get("formatVersion") == 1, "Capture original Chromium numeric buffers before native source verification")
	if not fixture.has("source"):
		get_tree().quit(1)
		return
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in fixture.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == fixture.source.inputs[path], "Current source numeric producer: " + path)
	for path: String in fixture.source.sourceInputs:
		_check(provenance.inputs[path] == fixture.source.sourceInputs[path], "Original numeric geometry matches source provenance: " + path)
	var reader := Meshes.new(fixture.manifest, fixture.resourceRoot)
	var rows: Array = []
	for mesh: Dictionary in reader:
		rows.append(mesh)
	_check(reader.valid and rows.size() == fixture.cases.size(), "Read complete source JSON chunks and float64 sidecars")
	for index in range(mini(rows.size(), fixture.cases.size())):
		var item: Dictionary = fixture.cases[index]
		var payload: Dictionary = JSON.parse_string(item.payload)
		var tape := PackedByteArray()
		for field: String in ["positions", "normal", "matrix"]:
			tape.append_array(Marshalls.base64_to_raw(item.expected[field]))
		var restored_payload := SourceFixtureSections.restore_numbers(payload, tape)
		_check(restored_payload.ok, "Restore original browser JSON scalar bits through numeric tape")
		if restored_payload.ok:
			payload = restored_payload.value
		if int(item.get("transferArrays", 0)) == 0:
			var restored_row := SourceFixtureSections.restore_numbers(rows[index], tape)
			_check(restored_row.ok, "Restore inline source chunk scalar bits through numeric tape")
			if restored_row.ok:
				rows[index] = restored_row.value
		for field: String in item.expected:
			_bits(payload[field], item.expected[field], "Original browser JSON scalar bits survive native parsing: " + field)
			_bits(rows[index][field], item.expected[field], "Original inline/sidecar source numeric bits survive native decoding: " + field)
		_bits(item.metadata.matrix, item.expected.matrix, "Shared streaming publication preserves inline metadata signed zero")
	var resource := Resource.new()
	resource.set_meta("source_meshes", rows)
	var path := "user://source-json-bits.res"
	_check(ResourceSaver.save(resource, path) == OK, "Save native original numeric metadata")
	var loaded := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded != null and loaded != resource, "Reload an independent native numeric resource")
	if loaded != null:
		var restored: Array = loaded.get_meta("source_meshes", [])
		_check(restored.size() == fixture.cases.size(), "Native resource reload preserves source row count")
		for index in range(mini(restored.size(), fixture.cases.size())):
			for field: String in fixture.cases[index].expected:
				_bits(restored[index][field], fixture.cases[index].expected[field], "Original signed/finite source bits survive native resource reload: " + field)
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove only the test-owned native resource")
	var report := FileAccess.open("res://artifacts/sol/source-json/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"differences": differences}))
	report.close()
	print("SOURCE_JSON assertions=", assertions, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
