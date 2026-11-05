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

# source_trigonometry.json words are IEEE-754 integers, most significant byte first.
static func _number(word: String) -> float:
	var bytes := word.hex_decode()
	bytes.reverse()
	return bytes.decode_double(0)

# lock_glow.json and pip_composition.json store little-endian bytes.
static func _little(word: String) -> float:
	return word.hex_decode().decode_double(0)

static func _bytes(value: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes

func _same(actual: float, expected: float) -> bool:
	# Chromium's NaN payload is not observable; every other result compares by bits.
	return is_nan(actual) and is_nan(expected) or _bytes(actual) == _bytes(expected)

func _run() -> void:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_trigonometry.json"))
	_check(capture.get("cases", []).size() > 6144, "Regenerate the original Chromium Math.sin/Math.cos corpus")
	var started := Time.get_ticks_usec()
	var calls := 0
	for row: Array in capture.get("cases", []):
		var x := _number(row[0])
		_check(_same(SourceTrigonometry.sin(x), _number(row[1])), "Original Chromium Math.sin bits: " + str(row[0]))
		_check(_same(SourceTrigonometry.cos(x), _number(row[2])), "Original Chromium Math.cos bits: " + str(row[0]))
		calls += 2
	var elapsed := Time.get_ticks_usec() - started
	var glow: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/lock_glow.json"))
	_check(glow.get("cases", []).size() == 300, "Original lock-glow pulse corpus is present")
	for item: Dictionary in glow.get("cases", []):
		_check(_same(SourceTrigonometry.sin(_little(item.phaseBits)), _little(item.sineBits)), "Original lock-glow pulse sine: " + str(item.phaseBits))
	var pip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pip_composition.json"))
	_check(pip.get("poseCases", []).size() > 0, "Original PiP pose corpus is present")
	for item: Dictionary in pip.get("poseCases", []):
		var half := _little(item.yawBits) / 2
		var quaternion: Array = item.draw.quaternionBits
		_check(_same(SourceTrigonometry.sin(half), _little(quaternion[1])), "Original PiP yaw half-angle sine: " + str(item.yawBits))
		_check(_same(SourceTrigonometry.cos(half), _little(quaternion[3])), "Original PiP yaw half-angle cosine: " + str(item.yawBits))
	print("SOURCE_TRIGONOMETRY_TEST assertions=", assertions, " failures=", failures, " microseconds_per_call=", float(elapsed) / maxi(calls, 1))
	get_tree().quit(0 if failures == 0 else 1)
