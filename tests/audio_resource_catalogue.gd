extends Node

const Snapshot = preload("res://scripts/audio_resource_snapshot.gd")
const Identity = preload("res://scripts/audio_resource_identity.gd")
const ClipIdentity = preload("res://scripts/audio_clip_identity.gd")
const Publisher = preload("res://tools/source_resource_publisher.gd")

class Reader extends Snapshot:
	var path: String
	func _read_catalogue() -> NativeAudioCatalogue:
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as NativeAudioCatalogue if ResourceLoader.exists(path) else null

class Importer extends "res://tools/import_audio.gd":
	var rejections: Array[String] = []
	func _ready() -> void:
		pass
	func _fail(message: String) -> void:
		rejections.append(message)

var assertions := 0
var failures: Array[String] = []
var owned_paths: Array[String] = []
var source_hash: String

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _wave(value: int, rate: int = 48000, frames: int = 2) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	bytes.encode_s16(0, value)
	wave.data = bytes
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_begin = 0
	wave.loop_end = frames
	return wave

func _synthesis(id: String, revision: int) -> NativeAudioSynthesis:
	var resource := NativeAudioSynthesis.new()
	resource.sample_rate = 48000
	resource.frames = 2
	resource.reservation_seconds = 0.2
	resource.maximum_gain = 2.0
	resource.source = {"id": id, "audioSha256": source_hash, "noiseSha256": str(revision).repeat(64)}
	var stem := NativeAudioStem.new()
	stem.values = PackedFloat32Array([0.25, revision * 0.25])
	stem.envelope.assign([{"operation": "setValueAtTime", "time": 0.0, "constant": 1.0}])
	resource.stems.append(stem)
	return resource

func _music(mood: String, revision: int) -> NativeAudioClip:
	var resource := NativeAudioClip.new()
	resource.channel_count = 0
	resource.centered = _wave(revision)
	resource.centered.loop_begin = 1
	resource.source = {"layer": "procedural_music", "id": "music_" + mood, "sha256": source_hash, "noiseSha256": str(revision).repeat(64)}
	return resource

func _movement(revision: int) -> NativeAudioMoveBank:
	var resource := NativeAudioMoveBank.new()
	resource.source = {"audioSha256": source_hash, "noiseSha256": str(revision).repeat(64)}
	resource.noise = _wave(revision, 48000, 48000)
	for category: String in ["engine", "rotor", "wingflap", "stomp"]:
		resource.oscillators[category] = {"1": PackedFloat32Array([0.25, revision * 0.25])}
	return resource

func _stage(importer: Importer, id: String, revision: int) -> NativeAudioCatalogue:
	var catalogue := NativeAudioCatalogue.new()
	catalogue.source = {"audioSha256": source_hash}
	catalogue.synthesis_ids.assign([id])
	var resources := {"synthesis_" + id: _synthesis(id, revision),
		"music_menu": _music("menu", revision), "music_battle": _music("battle", revision),
		"movement": _movement(revision)}
	for key: String in resources:
		var path := "res://assets/audio/native/%s_%s.res" % [key, Identity.digest(resources[key])]
		_check(not FileAccess.file_exists(path), "Publication probe owns a fresh resource path")
		if FileAccess.file_exists(path):
			continue
		owned_paths.append(path)
		_check(await importer._publish_resource(catalogue, key, resources[key]), "Stage and verify a complete native audio dependency")
	catalogue.complete_resources = true
	_check(catalogue.valid(), "The complete index contains every declared synthesis, music and movement dependency")
	return catalogue

func _reader(path: String) -> Reader:
	var reader := Reader.new()
	reader.path = path
	return reader

func _reject_mixed_cohorts(importer: Importer, catalogue: NativeAudioCatalogue, manifest: String, id: String) -> void:
	var published_hash := FileAccess.get_sha256(manifest)
	for key: String in ["synthesis_" + id, "music_menu", "movement"]:
		for field: String in ["noise", "rate", "missing"]:
			var candidate := catalogue.duplicate(true) as NativeAudioCatalogue
			var resource := ResourceLoader.load(candidate.resource_paths[key], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).duplicate(true)
			if field == "noise":
				resource.source.noiseSha256 = "f".repeat(64)
			elif field == "missing":
				resource.source.erase("noiseSha256")
			elif resource is NativeAudioSynthesis:
				resource.sample_rate = 44100
			elif resource is NativeAudioMoveBank:
				resource.noise.mix_rate = 44100
				resource.noise.loop_end = 44100
			else:
				resource.centered.mix_rate = 44100
			candidate.resource_paths.erase(key)
			candidate.resource_hashes.erase(key)
			var path := "res://assets/audio/native/%s_%s.res" % [key, Identity.digest(resource)]
			owned_paths.append(path)
			_check(await importer._publish_resource(candidate, key, resource), "Stage a individually valid dependency with a different cohort: " + key + "/" + field)
			_check(candidate.valid(), "A complete fingerprint index alone cannot prove a shared source context")
			await importer._publish_catalogue(candidate, 0)
			_check(importer.rejections.size() == 1 and FileAccess.get_sha256(manifest) == published_hash,
				"Reject a mixed cohort before switching the published index: " + key + "/" + field)
			importer.rejections.clear()
			_check(await Publisher.publish(candidate, manifest, get_tree()) == OK, "Inject an inconsistent legacy index into the test-owned manifest")
			var partial := NativeAudioCatalogue.new()
			partial.source = catalogue.source.duplicate(true)
			_check(not importer._retain_resources(partial) and not partial.complete_resources and partial.resource_paths.is_empty(),
				"Samples-only import cannot retain a mixed source context: " + key + "/" + field)
			_check(importer.rejections.size() == 1, "Partial import reports the source-cohort rejection")
			importer.rejections.clear()
			_check(await Publisher.publish(catalogue, manifest, get_tree()) == OK, "Restore the accepted test-owned catalogue")
			published_hash = FileAccess.get_sha256(manifest)

func _with_sample(catalogue: NativeAudioCatalogue, id: String, mode: String) -> NativeAudioCatalogue:
	var clip := NativeAudioClip.new()
	clip.source = {"layer": "sample", "id": id, "url": "probe://cohort", "take": 0,
		"sha256": source_hash, "sampleRate": 48000, "frames": 2, "probe": mode}
	var wave := _wave(1)
	wave.loop_mode = AudioStreamWAV.LOOP_DISABLED
	clip.panned.append(wave)
	match mode:
		"context_rate":
			clip.source.sampleRate = 44100
			wave.mix_rate = 44100
		"stream_rate": wave.mix_rate = 44100
		"declared_rate": clip.source.sampleRate = 44100
		"missing_rate": clip.source.erase("sampleRate")
		"string_rate": clip.source.sampleRate = "48000"
	var hash := ClipIdentity.digest(clip)
	var path := "res://assets/audio/native/%s_%s.res" % [id, hash]
	_check(not hash.is_empty() and not FileAccess.file_exists(path), "The sample-cohort probe owns a fresh fingerprint path")
	if mode != "missing_file":
		if mode == "altered":
			wave.data = PackedByteArray([2, 0, 0, 0])
		owned_paths.append(path)
		_check(await Publisher.publish(clip, path, get_tree()) == OK, "Stage a controlled sample dependency: " + mode)
	var candidate := catalogue.duplicate(true) as NativeAudioCatalogue
	candidate.sample_paths[id] = [path]
	candidate.sample_hashes[id] = [hash]
	_check(candidate.valid(), "A sample fingerprint index alone does not prove source context or payload integrity")
	return candidate

func _reject_mixed_samples(importer: Importer, catalogue: NativeAudioCatalogue, manifest: String, id: String) -> void:
	var valid := await _with_sample(catalogue, id, "valid")
	_check(importer._resource_cohort(valid), "Matching sample PCM and declarations share the complete source context")
	var valid_partial := NativeAudioCatalogue.new()
	valid_partial.source = valid.source.duplicate(true)
	valid_partial.sample_paths = valid.sample_paths.duplicate(true)
	valid_partial.sample_hashes = valid.sample_hashes.duplicate(true)
	_check(importer._retain_resources(valid_partial) and valid_partial.complete_resources,
		"Matching incoming samples retain the complete source cohort")
	for mode: String in ["context_rate", "stream_rate", "declared_rate", "missing_rate", "string_rate", "missing_file", "altered"]:
		var candidate := await _with_sample(catalogue, id, mode)
		var published_hash := FileAccess.get_sha256(manifest)
		await importer._publish_catalogue(candidate, 1)
		_check(importer.rejections.size() == 1 and FileAccess.get_sha256(manifest) == published_hash,
			"Reject inconsistent sample publication without replacing the current catalogue: " + mode)
		importer.rejections.clear()
		_check(await Publisher.publish(catalogue, manifest, get_tree()) == OK, "Retain the valid source catalogue before incoming-sample validation")
		var partial := NativeAudioCatalogue.new()
		partial.source = candidate.source.duplicate(true)
		partial.sample_paths = candidate.sample_paths.duplicate(true)
		partial.sample_hashes = candidate.sample_hashes.duplicate(true)
		published_hash = FileAccess.get_sha256(manifest)
		_check(not importer._retain_resources(partial) and not partial.complete_resources and partial.resource_paths.is_empty()
			and importer.rejections.size() == 1 and FileAccess.get_sha256(manifest) == published_hash,
			"Incoming samples cannot retain an incompatible or unverified cohort: " + mode)
		importer.rejections.clear()
		_check(await Publisher.publish(candidate, manifest, get_tree()) == OK, "Inject only the test-owned legacy sample index: " + mode)
		published_hash = FileAccess.get_sha256(manifest)
		var retained := NativeAudioCatalogue.new()
		retained.source = catalogue.source.duplicate(true)
		_check(not importer._retain_resources(retained) and not retained.complete_resources and retained.resource_paths.is_empty()
			and importer.rejections.size() == 1 and FileAccess.get_sha256(manifest) == published_hash,
			"Previously published samples are verified before retaining their resource generation: " + mode)
		importer.rejections.clear()
		_check(await Publisher.publish(catalogue, manifest, get_tree()) == OK, "Restore the complete source catalogue after a sample rejection")

func _reject_source_rate_collision(importer: Importer, restore: NativeAudioCatalogue, manifest: String) -> void:
	var current := ResourceLoader.load(Snapshot.CATALOGUE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as NativeAudioCatalogue
	var archive: Dictionary = Content.read_json("res://data/audio_sample_waveforms/48000.json")
	var matching_source: bool = current != null and current.valid() \
		and archive.get("scope") == "original-sample-context-waveforms" and archive.sampleRate == 48000 \
		and archive.source.audioSha256 == current.source.audioSha256
	_check(matching_source, "The captured device-rate samples share the shipped original audio module")
	if not matching_source:
		return
	var takes: Array = archive.samples.filter(func(sample): return sample.id == "fire_light_ballistic")
	_check(takes.size() == 1, "The original device-rate collision probe contains exactly one captured take")
	if takes.size() != 1:
		return
	var captured: Dictionary = takes[0].duplicate(true)
	var channels: Array[Dictionary] = []
	for encoded: String in captured.channels:
		var stem := NativeAudioStem.new()
		stem.values = Marshalls.base64_to_raw(encoded).to_float32_array()
		stem.envelope.assign([{"operation": "setValueAtTime", "time": 0.0, "constant": 1.0}])
		var rendered := stem.render(1, int(captured.sampleRate))
		_check(not rendered.is_empty(), "Convert the original device-rate channel with the existing PCM factory")
		if rendered.is_empty():
			return
		channels.append({"pcm": Marshalls.raw_to_base64(rendered.stream.data), "gain": rendered.gain})
	captured.channels = channels
	var clip := importer._clip(captured.id, captured)
	# Keep the captured signal and identity fields; isolate ownership of this probe.
	clip.source.publicationProbe = source_hash
	var hash := ClipIdentity.digest(clip)
	var path := "res://assets/audio/native/%s_%s.res" % [captured.id, hash]
	if not FileAccess.file_exists(path):
		owned_paths.append(path)
		_check(await Publisher.publish(clip, path, get_tree()) == OK, "Stage the actual 48,000 Hz source take without changing its legacy counterpart")
	var candidate := current.duplicate(true) as NativeAudioCatalogue
	candidate.sample_paths[captured.id] = [path]
	candidate.sample_hashes[captured.id] = [hash]
	_check(await Publisher.publish(current, manifest, get_tree()) == OK, "Inspect the shipped source generation through an isolated manifest")
	var before := FileAccess.get_sha256(manifest)
	await importer._publish_catalogue(candidate, 7)
	_check(importer.rejections.size() == 1 and importer.rejections[0].begins_with("Mixed or missing original sample context rate:")
		and FileAccess.get_sha256(manifest) == before, "The actual 48,000 Hz source capture cannot replace one take in the shipped 47,360 Hz cohort")
	importer.rejections.clear()
	var partial := NativeAudioCatalogue.new()
	partial.source = candidate.source.duplicate(true)
	partial.sample_paths = candidate.sample_paths.duplicate(true)
	partial.sample_hashes = candidate.sample_hashes.duplicate(true)
	_check(not importer._retain_resources(partial) and not partial.complete_resources and partial.resource_paths.is_empty()
		and importer.rejections.size() == 1 and importer.rejections[0].begins_with("Mixed or missing original sample context rate:")
		and FileAccess.get_sha256(manifest) == before, "Same-module samples-only import still rejects a different original context rate")
	importer.rejections.clear()
	_check(await Publisher.publish(restore, manifest, get_tree()) == OK, "Retain the controlled source generation after the original-capture rejection")

func _run() -> void:
	var id := "publication_probe_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	source_hash = id.sha256_text()
	var manifest := "user://" + id + ".res"
	owned_paths.append(manifest)
	var importer := Importer.new()
	add_child(importer)
	var waiting := _reader(manifest)
	_check(waiting.snapshot() == null and waiting.attempted, "A missing catalogue remains unavailable without selecting a generation")
	var first := await _stage(importer, id, 1)
	_check(await Publisher.publish(first, manifest, get_tree()) == OK, "Publish the initial complete catalogue")
	_check(waiting.snapshot() != null and waiting.catalogue.resource_paths == first.resource_paths,
		"An owner can retry catalogue acquisition until its first valid generation is available")
	var original := _reader(manifest)
	_check(original.snapshot() != null and original.resources.is_empty(), "Capture the index without eagerly loading native audio payloads")
	var original_bytes := FileAccess.get_sha256(manifest)
	var first_paths := first.resource_paths.duplicate()
	var first_hashes := {}
	for path: String in first_paths.values():
		first_hashes[path] = FileAccess.get_sha256(path)
	var replacement := await _stage(importer, id, 2)
	_check(FileAccess.get_sha256(manifest) == original_bytes, "Stopping after dependency staging retains the previous published catalogue")
	for path: String in first_paths.values():
		_check(FileAccess.get_sha256(path) == first_hashes[path], "Staging a replacement never overwrites an earlier generation's dependency")
	_check(await Publisher.publish(replacement, manifest, get_tree()) == OK, "Switch the entire native resource index atomically")
	var current := _reader(manifest)
	_check(original.synthesis(id).stems[0].values[1] == 0.25 and current.synthesis(id).stems[0].values[1] == 0.5,
		"Late readers of a retained index cannot mix in newer synthesis stems")
	_check(original.music("menu").centered.data.decode_s16(0) == 1 and current.music("menu").centered.data.decode_s16(0) == 2,
		"Music fallback PCM follows the retained catalogue generation")
	_check(original.movement().noise.data.decode_s16(0) == 1 and current.movement().noise.data.decode_s16(0) == 2,
		"Movement noise and oscillator periods follow the retained catalogue generation")
	importer.catalogue_path = manifest
	var samples_only := NativeAudioCatalogue.new()
	samples_only.source = replacement.source.duplicate()
	_check(importer._retain_resources(samples_only) and samples_only.valid() and samples_only.resource_paths == replacement.resource_paths,
		"Samples-only publication retains the complete dependency generation when its source agrees")
	var mismatched := NativeAudioCatalogue.new()
	mismatched.source = {"audioSha256": "f".repeat(64)}
	_check(not importer._retain_resources(mismatched) and not mismatched.complete_resources,
		"Samples-only publication rejects a different source rather than mixing native generations")
	_check(importer.rejections.size() == 1, "A mismatched partial publication reports its failure")
	importer.rejections.clear()
	_check(importer._resource_cohort(ResourceLoader.load(Snapshot.CATALOGUE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)),
		"The currently shipped original synthesis, movement and music retain one noise/context cohort")
	await _reject_mixed_cohorts(importer, replacement, manifest, id)
	await _reject_mixed_samples(importer, replacement, manifest, id + "_sample")
	await _reject_source_rate_collision(importer, replacement, manifest)
	var changed := _synthesis(id, 1)
	changed.stems[0].envelope[0].constant = 1.0000000000000002
	_check(Identity.digest(changed) != first.resource_hashes["synthesis_" + id], "Synthesis identity retains full-precision envelope coefficients")
	var altered := _movement(1)
	altered.noise_gain = 1.0000000000000002
	_check(Identity.digest(altered) != first.resource_hashes.movement, "Movement identity retains full-precision normalization")
	var invalid_synthesis := _synthesis(id, 1)
	invalid_synthesis.stems[0].values[0] = NAN
	_check(Identity.digest(invalid_synthesis).is_empty(), "Nonfinite synthesis samples cannot enter a content-addressed catalogue")
	var invalid_bank := _movement(1)
	invalid_bank.oscillators.engine["1"][0] = INF
	_check(Identity.digest(invalid_bank).is_empty(), "Nonfinite oscillator periods cannot enter a content-addressed catalogue")
	for field: String in ["missing", "path", "hash", "duplicate", "incomplete"]:
		var invalid := replacement.duplicate(true) as NativeAudioCatalogue
		match field:
			"missing": invalid.resource_paths.erase("movement")
			"path": invalid.resource_paths.movement = false
			"hash": invalid.resource_hashes.movement = "-" + "0".repeat(63)
			"duplicate": invalid.synthesis_ids.append(id)
			"incomplete": invalid.complete_resources = false
		_check(not invalid.valid(), "Reject inconsistent resource indexes: " + field)
	var corrupt_path: String = replacement.resource_paths["synthesis_" + id]
	_check(await Publisher.publish(changed, corrupt_path, get_tree()) == OK, "Inject a mismatched resource only into this test-owned path")
	var corrupt_bytes := FileAccess.get_sha256(corrupt_path)
	var rejected := NativeAudioCatalogue.new()
	_check(not await importer._publish_resource(rejected, "synthesis_" + id, _synthesis(id, 2)), "Reject an existing fingerprint path with altered resource contents")
	_check(rejected.resource_paths.is_empty() and FileAccess.get_sha256(corrupt_path) == corrupt_bytes,
		"Failed dependency validation neither registers nor overwrites the rejected file")
	var later := _reader(manifest)
	_check(later.synthesis(id) == null and current.synthesis(id).stems[0].values[1] == 0.5,
		"Fresh readers reject corruption while retained resource instances remain isolated")
	_check(importer.rejections.size() == 1 and importer.rejections[0].begins_with("Existing content-addressed original audio resource is invalid:"),
		"The rejection reports the exact resource-integrity failure")
	var retained_corruption := NativeAudioCatalogue.new()
	retained_corruption.source = replacement.source.duplicate()
	_check(not importer._retain_resources(retained_corruption) and not retained_corruption.complete_resources
		and importer.rejections.size() == 2 and importer.rejections[1].begins_with("Missing or invalid native audio cohort resource:"),
		"Samples-only import verifies every retained dependency before reusing a complete index")
	var manager := BattleAudio.new()
	add_child(manager)
	_check(manager.configure(Content.balance.audio) == OK, "Configure the real audio manager without playing audio")
	_check(manager.samples.resources == manager.resources and manager.synthesis.resources == manager.resources
		and manager.music.fallback.resources == manager.resources and manager.movement.resources == manager.resources,
		"All native audio consumers share one catalogue snapshot")
	_check(not manager.resources.attempted, "Configuration preserves first-gesture lazy catalogue loading")
	manager.free()
	importer.free()
	for path: String in owned_paths:
		_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove only the probe's own native publication")
	print("AUDIO_RESOURCE_CATALOGUE assertions=", assertions, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
