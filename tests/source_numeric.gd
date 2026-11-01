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

# Fixture words are hexadecimal IEEE-754 integers, most significant byte first.
static func _number(word: String) -> float:
	var bytes := word.hex_decode()
	bytes.reverse()
	return bytes.decode_double(0)

func _run() -> void:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_hypot.json"))
	_check(capture.get("cases", []).size() > 4096, "Regenerate the original Chromium Math.hypot corpus")
	for row: Array in capture.get("cases", []):
		var x := _number(row[0])
		var y := _number(row[1])
		var result: float = SourceNumeric.hypot(x, y)
		var actual := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
		actual.encode_double(0, result)
		actual.reverse()
		# Chromium's NaN payload is not observable; every other result compares by bits.
		var same: bool = is_nan(result) and is_nan(_number(row[2])) or actual.hex_encode() == row[2]
		_check(same, "Original Chromium Math.hypot bits: %s %s" % [row[0], row[1]])
		_check(CarrierRules.hypot2(x, y) == result or is_nan(result), "Carrier distances share the accepted browser binding")
	print("SOURCE_NUMERIC_TEST assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
