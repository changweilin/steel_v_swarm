extends Node

var assertions := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func _tape(words: PackedStringArray) -> PackedByteArray:
	var bytes := PackedByteArray()
	for word: String in words:
		bytes.append_array(word.hex_decode())
	return bytes

func _run() -> void:
	# Little-endian words: a double Godot's JSON parser rounds by one unit, -0, the
	# smallest subnormal and the largest finite double.
	var words := PackedStringArray(["0000004026a681bc", "0000000000000080", "0100000000000000", "ffffffffffffef7f"])
	var numbers := _tape(words)
	var tree: Variant = JSON.parse_string('{"text":"1.5","flag":true,"none":null,"rows":[0.1,{"nested":0.2},[0.3]],"last":0.4,"empty":[]}')
	var snapshot: Variant = tree.duplicate(true)
	var restored := SourceFixtureSections.restore_numbers(tree, numbers)
	_check(restored.ok, "A complete tape restores every number leaf")
	if not restored.ok:
		_finish()
		return
	var value: Dictionary = restored.value
	var actual := PackedFloat64Array([value.rows[0], value.rows[1].nested, value.rows[2][0], value.last])
	_check(actual.to_byte_array() == numbers, "Number leaves take original float64 words in JSON order")
	_check(value.keys() == snapshot.keys() and value.text == "1.5" and value.flag == true and value.none == null and value.empty == [] and value.rows.size() == 3,
		"Strings, booleans, nulls, empty arrays and key order keep their captured shape")
	for label: String in ["incomplete", "extra", "torn"]:
		var source: Variant = snapshot.duplicate(true)
		var bytes := numbers.slice(0, 24) if label == "incomplete" else numbers + numbers.slice(0, 8) if label == "extra" else numbers.slice(0, 31)
		_check(not SourceFixtureSections.restore_numbers(source, bytes).ok, "Reject a tape with %s words" % label)
		_check(source == snapshot, "A rejected tape leaves the captured tree unchanged: " + label)
	_check(not SourceFixtureSections.restore_numbers([PackedFloat64Array([1.0])], numbers.slice(0, 8)).ok, "Reject a non-JSON packed leaf instead of skipping its numbers")
	var scalar := SourceFixtureSections.restore_numbers(0.5, numbers.slice(1 * 8, 2 * 8))
	_check(scalar.ok and PackedFloat64Array([scalar.value]).to_byte_array() == numbers.slice(8, 16), "A scalar root restores one exact word")
	# The shared fixture loader keeps its hash/path checks and tape behavior.
	var selected: Dictionary = Content.read_json("res://data/fixtures.json", ["rng"])
	_check(selected.get("rng") is Array and not selected.rng.is_empty(), "Published fixture sections still restore through the shared boundary")
	_finish()

func _finish() -> void:
	print("NUMERIC_TAPE assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
