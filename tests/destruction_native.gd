extends "res://tests/run.gd"

const DestructionTests = preload("res://tests/destruction_suite.gd")
const SourceHelper = preload("res://tests/status_suite.gd")

func _run() -> void:
	failure_report = FileAccess.open(FAILURE_REPORT, FileAccess.WRITE)
	_check(failure_report != null, "Preserve every particle acceptance failure")
	if failure_report == null:
		_finish_capture()
		return
	var capture: Dictionary = Content.read_json("res://tests/fixtures/destruction.json")
	_check(capture.get("formatVersion") == 1 and capture.get("source") is Dictionary and
		capture.get("fixtures") is Dictionary and capture.get("metadata") is Dictionary and capture.get("textures") is Dictionary,
		"Capture original mechanical debris and comic state before native verification")
	if failures > 0:
		_finish_capture()
		return
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	var source: Dictionary = capture.source
	_check(source.get("inputs") is Dictionary and not source.inputs.is_empty() and
		source.get("sourceInputs") is Dictionary and not source.sourceInputs.is_empty(), "Particle source/generator identities are present")
	if failures > 0:
		_finish_capture()
		return
	for path: String in source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == source.inputs[path], "Particle capture generator is current: " + path)
	for path: String in source.sourceInputs:
		_check(provenance.get("inputs", {}).get(path) == source.sourceInputs[path], "Particle source matches the imported content: " + path)
	for key: String in capture.metadata:
		SourceHelper.compare(self, Content.balance.destruction.get(key), capture.metadata[key], "Original particle metadata: " + key)
	if failures > 0:
		_finish_capture()
		return
	for key: String in capture.textures:
		var expected := Image.new()
		var decoded := expected.load_png_from_buffer(Marshalls.base64_to_raw(capture.textures[key]))
		_check(decoded == OK, "Original comic texture decodes: " + key)
		var texture := load("res://assets/ui/combat-%s.png" % key) as Texture2D
		_check(texture != null, "Original comic texture has a native resource: " + key)
		if decoded != OK or texture == null:
			continue
		var actual := texture.get_image()
		expected.convert(Image.FORMAT_RGBA8)
		actual.convert(Image.FORMAT_RGBA8)
		var raw := Image.new()
		var raw_decoded := raw.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/ui/combat-%s.png" % key))
		_check(raw_decoded == OK, "Captured comic PNG decodes before native import: " + key)
		if raw_decoded != OK:
			continue
		raw.convert(Image.FORMAT_RGBA8)
		_check(raw.get_size() == expected.get_size() and raw.get_data() == expected.get_data(),
			"Original comic canvas pixels match the captured PNG: " + key)
		_check(actual.get_size() == expected.get_size() and actual.get_data() == expected.get_data(),
			"Original comic canvas pixels survive native texture import: " + key)
	var effects := DestructionTests.PaddedEffects.new()
	add_child(effects)
	var arguments := OS.get_cmdline_user_args()
	_check(not (arguments.has("--comic") and arguments.has("--mechanical")), "Choose one particle family or run the complete fixture")
	var cases := 0
	for mode: String in ["mechanicalDebris", "comicPops"]:
		if arguments.has("--comic") and mode != "comicPops" or arguments.has("--mechanical") and mode != "mechanicalDebris":
			continue
		for item: Dictionary in capture.fixtures[mode]:
			cases += 1
			var draws := {"count": 0}
			var samples: Array = item.random
			effects.random_sample = func():
				var value := float(samples[int(draws.count) % samples.size()])
				draws.count += 1
				return value
			effects.low_power = item.get("low", false)
			for index in range(int(item.padding)):
				effects.effects.append({"obj": null, "ttl": 100.0, "duration": 100.0, "age": 0.0})
			if mode == "mechanicalDebris":
				effects.mechanical_debris(BodyPose.vector(item.point), item.big, item.accent)
			else:
				effects.comic(BodyPose.vector(item.point), item.big, item.hue)
			if arguments.has("--witness") and mode == "mechanicalDebris" and item == capture.fixtures.mechanicalDebris[0]:
				_write_witness(effects, item, int(draws.count))
			_check(int(draws.count) == int(item.draws), "Original particle admission preserves random draw order")
			DestructionTests._compare(self, effects, item.initial, mode)
			for step: Dictionary in item.steps:
				effects.advance(float(step.delta))
				_check(effects.effects.size() == step.count, "Original particle cap, expiry and reverse-order retirement")
				DestructionTests._compare(self, effects, step.effects, mode)
			for effect: Dictionary in effects.effects:
				effects._drop(effect)
			effects.effects.clear()
	if effects.free_nodes.has("comic"):
		_check(effects.free_nodes.comic.size() <= int(Content.balance.npcShots.limits.pools.comic), "Comic retention obeys its source pool budget")
	effects.free()
	print("DESTRUCTION_NATIVE_CASES ", cases)
	_finish_capture()

func _finish_capture() -> void:
	if failure_report != null:
		failure_report.close()
	print("DESTRUCTION_NATIVE assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _write_witness(effects: CombatEffects, item: Dictionary, draws: int) -> void:
	var debris: MechanicalDebris = effects.effects[-1].obj
	var batches: Array = []
	for batch: MultiMeshInstance3D in debris.batches:
		var native := batch.multimesh.get_instance_transform(0)
		var color := batch.multimesh.get_instance_color(0)
		batches.append({"scale": native.basis.get_scale(), "position": native.origin,
			"color": [color.r, color.g, color.b], "buffer": Array(batch.multimesh.buffer)})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/sol"))
	var file := FileAccess.open("res://artifacts/sol/destruction-witness.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"sourceDraws": item.draws, "nativeDraws": draws, "source": item.initial, "native": batches}, "\t"))
