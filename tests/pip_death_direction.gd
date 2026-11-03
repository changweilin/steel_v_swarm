extends "res://tests/run.gd"

const Carrier = preload("res://scripts/carrier_rules.gd")

func _bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func _double(hex: String) -> float:
	return hex.hex_decode().decode_double(0)

func _run() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/pip_death_direction.json")
	_check(capture.get("formatVersion") == 1 and capture.get("rows") is Array and capture.rows.size() == 522,
		"Original death-view direction capture contains both camera branches")
	var mismatches := 0
	var witness := ""
	for row: Dictionary in capture.rows:
		var point := [_double(row.pointBits[0]), _double(row.pointBits[1]), _double(row.pointBits[2])]
		var enemy := [_double(row.enemyBits[0]), _double(row.enemyBits[1])]
		var dx := float(enemy[0]) - float(point[0])
		var dz := float(enemy[1]) - float(point[2])
		var distance := Carrier.hypot2(dx, dz)
		if distance == 0.0 or is_nan(distance):
			distance = 1.0
		var reach := 100.0 if row.mode == "source" else 80.0
		var target_y := float(point[1]) + 1.0 if row.mode == "source" else _double(row.groundBits) + 18.0 - 6.0
		var offset_x := dx / distance * reach
		var offset_z := dz / distance * reach
		var actual := [_bits(float(point[0]) + offset_x), _bits(target_y), _bits(float(point[2]) + offset_z)]
		if actual != row.targetBits:
			mismatches += 1
			if witness.is_empty():
				witness = str({"mode": row.mode, "point": point, "enemy": enemy, "enemy_bits": [_bits(float(enemy[0])), _bits(float(enemy[1]))], "distance_bits": _bits(distance), "z_bits": [_bits(float(point[2])), _bits(dz), _bits(dz / distance), _bits(offset_z)], "actual": actual, "expected": row.targetBits})
	_check(mismatches == 0, "Carrier hypot candidate matches Chromium death-view targets; mismatches=" + str(mismatches) + " first=" + witness)
	print("PIP_DEATH_DIRECTION assertions=", assertions, " failures=", failures, " cases=", capture.rows.size(), " mismatches=", mismatches)
	get_tree().quit(0 if failures == 0 else 1)
