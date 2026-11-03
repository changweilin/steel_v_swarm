extends Node

# Public numeric-tape boundary of SourceFixtureSections: a captured JSON value
# tree plus native float64 little-endian words restores exact source doubles.
var assertions := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(message)

func _words(hex_words: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for word: String in hex_words:
		bytes.append_array(word.hex_decode())
	return bytes

func _word(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _ready() -> void:
	# Little-endian words: signed zero, the documented Chromium double whose
	# decimal round trip lost bits, smallest subnormal, largest finite, 0.1 + 0.2,
	# negative one and an integer that a JSON parser may expose as int.
	var words := ["0000000000000080", "0000004026a681bc", "0100000000000000", "ffffffffffffef7f",
		"343333333333d33f", "000000000000f0bf", "0000000000c05e40"]
	var text := '{"label":"sphere","position":[0,1,{"flag":true,"none":null}],"normal":[[2,3],[4]],"count":5,"name":"keep","tail":[6]}'
	var tree: Variant = JSON.parse_string(text)
	var before := JSON.stringify(tree)
	var restored := SourceFixtureSections.restore_numeric_tape(tree, _words(words))
	_check(restored.ok and restored.error.is_empty(), "A complete tape restores its captured value tree")
	var value: Dictionary = restored.value
	_check(value.keys() == ["label", "position", "normal", "count", "name", "tail"], "Restoration keeps the captured key order")
	_check(value.label == "sphere" and value.name == "keep", "Strings are not numeric words")
	_check(value.position[2].flag == true and value.position[2].none == null, "Booleans and nulls are not numeric words")
	_check(value.position.size() == 3 and value.normal.size() == 2 and value.normal[0].size() == 2 and value.normal[1].size() == 1, "Restoration preserves nested array shape")
	var leaves := [value.position[0], value.position[1], value.normal[0][0], value.normal[0][1], value.normal[1][0], value.count, value.tail[0]]
	for index in leaves.size():
		_check(leaves[index] is float, "Restored numeric leaf is a native double: " + str(index))
		_check(_word(leaves[index]) == words[index], "Restored double keeps exact source bits: " + words[index] + " actual=" + _word(leaves[index]))
	_check(is_zero_approx(value.position[0]) and 1.0 / value.position[0] < 0.0, "Signed zero survives restoration")
	_check(JSON.stringify(tree) == before, "The captured value tree is never mutated")
	var scalar := SourceFixtureSections.restore_numeric_tape(0.0, _words(["0000000000000080"]))
	_check(scalar.ok and _word(scalar.value) == "0000000000000080", "A scalar captured value restores from one word")
	var empty := SourceFixtureSections.restore_numeric_tape({"label": "none"}, PackedByteArray())
	_check(empty.ok and empty.value == {"label": "none"}, "A tree without numbers accepts an empty tape")
	var short := SourceFixtureSections.restore_numeric_tape(tree, _words(words.slice(0, words.size() - 1)))
	_check(not short.ok and short.error.contains("ended before"), "An incomplete tape is rejected")
	_check(JSON.stringify(short.value) == before, "A rejected incomplete tape exposes no partial restoration")
	var extra := SourceFixtureSections.restore_numeric_tape(tree, _words(words + ["0000000000000000"]))
	_check(not extra.ok and extra.error.contains("not fully consumed"), "An extra word is rejected")
	_check(JSON.stringify(extra.value) == before, "A rejected extra-word tape exposes no partial restoration")
	var ragged := _words(words)
	ragged.append(0)
	var partial := SourceFixtureSections.restore_numeric_tape(tree, ragged)
	_check(not partial.ok and partial.error.contains("whole number"), "A tape with a partial word is rejected")
	print("SOURCE_NUMERIC_TAPE_PASS " if failures == 0 else "SOURCE_NUMERIC_TAPE_FAIL ", assertions, " assertions, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
