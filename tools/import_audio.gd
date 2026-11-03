extends Node

const ResourcePublisher = preload("res://tools/source_resource_publisher.gd")
const ClipIdentity = preload("res://scripts/audio_clip_identity.gd")
const ResourceIdentity = preload("res://scripts/audio_resource_identity.gd")
const SynthesisImport = preload("res://tools/audio_synthesis_import.gd")
const ResourceSnapshot = preload("res://scripts/audio_resource_snapshot.gd")
const MoveImport = preload("res://tools/audio_move_import.gd")
var catalogue_path := AudioSampleLibrary.CATALOGUE_PATH

func _ready() -> void:
	_import.call_deferred()

func _import() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument != "--samples-only":
			_fail("Unsupported audio import argument: " + argument)
			return
	var data: Dictionary = Content.read_json("res://data/audio_clips.json")
	if data.get("formatVersion") != 1 or not data.get("samples") is Dictionary or not data.get("source") is Dictionary or not data.get("failures") is Dictionary:
		_fail("Regenerate original decoded source audio")
		return
	if DirAccess.make_dir_recursive_absolute("res://assets/audio/native") != OK and not DirAccess.dir_exists_absolute("res://assets/audio/native"):
		_fail("Cannot create native audio resource directory")
		return
	var catalogue := NativeAudioCatalogue.new()
	catalogue.source = data.source.duplicate(true)
	catalogue.failures = data.failures.duplicate(true)
	var count := 0
	for id: String in data.samples:
		if not id.is_valid_identifier() or not data.samples[id] is Array:
			_fail("Unsupported source sound identifier: " + id)
			return
		var paths: Array[String] = []
		var hashes: Array[String] = []
		for index in range(data.samples[id].size()):
			var sample: Dictionary = data.samples[id][index]
			var clip := _clip(id, sample)
			if clip == null:
				return
			var hash := ClipIdentity.digest(clip)
			var path := "res://assets/audio/native/%s_%s.res" % [id, hash]
			if FileAccess.file_exists(path):
				var existing := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as NativeAudioClip
				if ClipIdentity.digest(existing) != hash:
					_fail("Existing content-addressed source clip is invalid: " + path)
					return
			elif await ResourcePublisher.publish(clip, path, get_tree()) != OK:
				_fail("Cannot save native source audio: " + path)
				return
			paths.append(path)
			hashes.append(hash)
			count += 1
		catalogue.sample_paths[id] = paths
		catalogue.sample_hashes[id] = hashes
	if OS.get_cmdline_user_args().has("--samples-only"):
		if not _retain_resources(catalogue):
			return
		await _publish_catalogue(catalogue, count)
		return
	var synth_data: Dictionary = Content.read_json("res://data/audio_synth.json")
	if synth_data.get("formatVersion") != 1 or not synth_data.get("sounds") is Array or synth_data.get("source") != data.source:
		_fail("Regenerate original independent synthesis stems")
		return
	var captured_ids := []
	for sound: Variant in synth_data.sounds:
		if not sound is Dictionary or not sound.get("id") is String:
			_fail("Invalid original synthesis identifier")
			return
		captured_ids.append(sound.id)
	var expected_ids: Array = Content.balance.audio.synthesisIds.duplicate()
	captured_ids.sort()
	expected_ids.sort()
	if captured_ids != expected_ids:
		_fail("Incomplete original synthesis resource set")
		return
	for sound: Dictionary in synth_data.sounds:
		if not str(sound.get("id", "")).is_valid_identifier() or catalogue.synthesis_ids.has(str(sound.id)):
			_fail("Invalid original synthesis identifier")
			return
		var synthesis := SynthesisImport.build(sound, {"id": sound.id, "audioSha256": data.source.audioSha256, "noiseSha256": synth_data.noiseSha256})
		if synthesis == null:
			_fail("Invalid captured source synthesis: " + str(sound.id))
			return
		for stem: NativeAudioStem in synthesis.stems:
			for effect: Dictionary in stem.effects:
				if AudioSourceFilter.create(effect) == null:
					_fail("Unsupported original post-envelope synthesis effect: " + str(sound.id))
					return
		if not await _publish_resource(catalogue, "synthesis_" + str(sound.id), synthesis):
			return
		catalogue.synthesis_ids.append(str(sound.id))
	var music_data: Dictionary = Content.read_json("res://data/audio_music.json")
	if music_data.get("formatVersion") != 1 or not music_data.get("music") is Array or music_data.get("source") != data.source:
		_fail("Regenerate original procedural music arrangements")
		return
	for music: Dictionary in music_data.music:
		if music.get("mood") not in ["menu", "battle"] or not music.get("channels") is Array or music.channels.size() != 1:
			_fail("Invalid captured original procedural music")
			return
		if not is_finite(float(music.get("maximumLoopError", INF))) or float(music.maximumLoopError) >= .00002:
			_fail("Original procedural arrangement does not repeat within capture precision")
			return
		var sample := music.duplicate(true)
		sample.url = "source://audio.js/_procTick/" + str(music.mood)
		sample.index = 0
		sample.sha256 = data.source.audioSha256
		var clip := _clip("music_" + str(music.mood), sample)
		if clip == null:
			return
		clip.channel_count = 0
		clip.centered = clip.panned[0]
		clip.centered_gain = clip.panned_gains[0]
		clip.panned.clear()
		clip.panned_gains.clear()
		clip.centered.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.centered.loop_begin = int(music.loopBegin)
		clip.centered.loop_end = int(music.loopEnd)
		clip.source.layer = "procedural_music"
		clip.source.noiseSha256 = music_data.noiseSha256
		clip.source.arrangement = music.duplicate(true)
		clip.source.arrangement.erase("channels")
		if clip.centered.loop_begin <= 0 or clip.centered.loop_end != int(music.frames) or clip.centered.loop_end != clip.centered.loop_begin * 2 or not clip.valid():
			_fail("Invalid original procedural music loop: " + str(music.mood))
			return
		if not await _publish_resource(catalogue, "music_" + str(music.mood), clip):
			return
	if not await _movement(data.source, catalogue):
		return
	catalogue.complete_resources = true
	await _publish_catalogue(catalogue, count)

func _retain_resources(catalogue: NativeAudioCatalogue) -> bool:
	if not FileAccess.file_exists(catalogue_path):
		return true
	var previous := ResourceLoader.load(catalogue_path, "", ResourceLoader.CACHE_MODE_IGNORE) as NativeAudioCatalogue
	if previous == null:
		_fail("Cannot read the previous native audio catalogue")
		return false
	if not previous.complete_resources:
		return true
	if not previous.valid() or previous.source != catalogue.source:
		_fail("Samples-only import requires the same complete source catalogue; run the full audio importer")
		return false
	if not _resource_cohort(previous, catalogue):
		return false
	catalogue.complete_resources = true
	catalogue.synthesis_ids = previous.synthesis_ids.duplicate()
	catalogue.resource_paths = previous.resource_paths.duplicate()
	catalogue.resource_hashes = previous.resource_hashes.duplicate()
	return true

func _publish_resource(catalogue: NativeAudioCatalogue, key: String, resource: Resource) -> bool:
	var hash := ResourceIdentity.digest(resource)
	if not key.is_valid_identifier() or hash.is_empty() or catalogue.resource_paths.has(key):
		_fail("Invalid/duplicate original audio resource: " + key)
		return false
	var path := "res://assets/audio/native/%s_%s.res" % [key, hash]
	if not FileAccess.file_exists(path):
		if await ResourcePublisher.publish(resource, path, get_tree()) != OK:
			_fail("Cannot publish original audio resource: " + path)
			return false
	var stored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if stored == null or ResourceIdentity.digest(stored) != hash:
		_fail("Existing content-addressed original audio resource is invalid: " + path)
		return false
	catalogue.resource_paths[key] = path
	catalogue.resource_hashes[key] = hash
	return true

func _publish_catalogue(catalogue: NativeAudioCatalogue, count: int) -> void:
	if not catalogue.valid():
		_fail("Cannot save invalid native source audio catalogue")
		return
	if catalogue.complete_resources and not _resource_cohort(catalogue):
		return
	if await ResourcePublisher.publish(catalogue, catalogue_path, get_tree()) != OK:
		_fail("Cannot save native source audio catalogue")
		return
	print("Imported original audio takes: ", count, " synthesisProbesRemainReferenceOnly=true")
	get_tree().quit()

func _resource_cohort(catalogue: NativeAudioCatalogue, incoming_samples: NativeAudioCatalogue = null) -> bool:
	var reader := ResourceSnapshot.new()
	reader.catalogue = catalogue
	var noise_hash := ""
	var sample_rate := 0
	for key: String in catalogue.resource_paths:
		var resource: Resource
		var rate := 0
		if key == "movement":
			resource = reader.movement()
			if resource != null:
				rate = resource.noise.mix_rate
		elif key.begins_with("synthesis_"):
			resource = reader.synthesis(key.trim_prefix("synthesis_"))
			if resource != null:
				rate = resource.sample_rate
		elif key in ["music_menu", "music_battle"]:
			resource = reader.music(key.trim_prefix("music_"))
			if resource != null:
				rate = resource.centered.mix_rate
		if resource == null:
			_fail("Missing or invalid native audio cohort resource: " + key)
			return false
		var hash: Variant = resource.source.get("noiseSha256")
		if not NativeAudioCatalogue._valid_hash(hash) or rate <= 0:
			_fail("Missing original shared noise identity/rate: " + key)
			return false
		if noise_hash.is_empty():
			noise_hash = hash
			sample_rate = rate
		elif hash != noise_hash or rate != sample_rate:
			_fail("Mixed original shared noise or context rates: " + key)
			return false
	if noise_hash.is_empty() or not _samples_at_rate(catalogue, sample_rate):
		return false
	return incoming_samples == null or _samples_at_rate(incoming_samples, sample_rate)

func _samples_at_rate(catalogue: NativeAudioCatalogue, sample_rate: int) -> bool:
	if not catalogue.valid():
		_fail("Invalid native sample cohort index")
		return false
	for id: String in catalogue.sample_paths:
		for index in range(catalogue.sample_paths[id].size()):
			var path: String = catalogue.sample_paths[id][index]
			var clip := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as NativeAudioClip if ResourceLoader.exists(path) else null
			if not ClipIdentity.matches(clip, id, catalogue.sample_hashes[id][index]):
				_fail("Missing or invalid native sample cohort resource: " + path)
				return false
			var declared: Variant = clip.source.get("sampleRate")
			if not (declared is int or declared is float) or not is_finite(float(declared)) or float(declared) != sample_rate:
				_fail("Mixed or missing original sample context rate: " + id)
				return false
			var streams: Array[AudioStreamWAV] = clip.panned.duplicate()
			if clip.centered != null:
				streams.append(clip.centered)
			for stream: AudioStreamWAV in streams:
				if stream.mix_rate != sample_rate:
					_fail("Mixed native sample PCM context rates: " + id)
					return false
	return true

func _movement(provenance: Dictionary, catalogue: NativeAudioCatalogue) -> bool:
	var data: Dictionary = Content.read_json("res://data/audio_move.json")
	var bank := MoveImport.build(data, provenance, Content.balance.audio.moveGraphs)
	if bank == null:
		_fail("Invalid original movement noise or oscillator periods")
		return false
	return await _publish_resource(catalogue, "movement", bank)

func _clip(id: String, sample: Dictionary) -> NativeAudioClip:
	if not sample.get("channels") is Array or sample.channels.size() not in [1, 2] or float(sample.get("sampleRate", 0)) <= 0 or float(sample.get("frames", 0)) <= 0:
		_fail("Invalid captured source audio dimensions: " + id)
		return null
	if float(sample.sampleRate) != floorf(float(sample.sampleRate)) or float(sample.frames) != floorf(float(sample.frames)):
		_fail("Noninteger captured source audio dimensions: " + id)
		return null
	var clip := NativeAudioClip.new()
	clip.channel_count = sample.channels.size()
	clip.source = {"layer": "sample", "id": id, "url": sample.url, "take": sample.index, "sha256": sample.sha256,
		"sampleRate": sample.sampleRate, "frames": sample.frames}
	for channel: Dictionary in sample.channels:
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = int(sample.sampleRate)
		wave.data = Marshalls.base64_to_raw(channel.pcm)
		if wave.data.size() != int(sample.frames) * 2:
			_fail("Source audio PCM byte count mismatch: " + id)
			return null
		clip.panned.append(wave)
		clip.panned_gains.append(float(channel.gain))
	if not clip.valid():
		_fail("Invalid captured source audio clip: " + id)
		return null
	return clip

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
