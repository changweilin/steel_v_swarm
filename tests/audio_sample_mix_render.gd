extends Node

const PAD := 4096
const FLOAT_ERROR := 8.0 * 0.00000011920928955078125

class TracedVoice extends AudioVoice:
	var marker: AudioStreamWAV
	var marker_bus: StringName
	func _play() -> bool:
		routes.append(marker_bus)
		return _player(marker, marker_bus, 1, 1) and super._play()

var buses: AudioBuses
var capture: AudioEffectCapture
var sink: StringName
var profile: Dictionary
var clips: Dictionary = {}
var conversion_errors: Dictionary = {}
var identities: Dictionary = {}
var results: Array[Dictionary] = []
var failures: Array[String] = []

func _check(value: bool, message: String) -> bool:
	if not value:
		failures.append(message)
		push_error(message)
	return value

func _ready() -> void:
	_run.call_deferred()

func _source() -> bool:
	if not _check(AudioServer.get_driver_name() != "Dummy", "Sample waveform acceptance requires a native device audio driver"):
		return false
	var rate := int(AudioServer.get_mix_rate())
	profile = Content.read_json("res://data/audio_sample_waveforms/%d.json" % rate)
	if not _check(profile.get("formatVersion") == 1 and profile.get("scope") == "original-sample-context-waveforms" and profile.get("sampleRate") == rate,
		"Capture original sample playback for the active native context rate"):
		return false
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in profile.source.sourceInputs:
		if not _check(provenance.inputs.get(path) == profile.source.sourceInputs[path], "Accepted original sample bytes: " + path):
			return false
	for path: String in profile.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		if not _check(text.sha256_text() == profile.source.inputs[path], "Current original sample producer: " + path):
			return false
	var parent: Dictionary = profile.source.contextProfile
	if not _check(FileAccess.get_sha256("res://" + str(parent.path)) == parent.sha256, "The original parent context remains exact"):
		return false
	var ids: Array = []
	for sample: Dictionary in profile.samples:
		ids.append(sample.id)
		if not _check(sample.index == 0 and sample.url == Content.balance.audio.samples.get(sample.id) and sample.sampleRate == rate \
			and sample.frames > 0 and sample.channels.size() == 2 \
			and sample.sha256 == provenance.inputs.get("public/" + str(sample.url)), "Complete original stereo take identity"):
			return false
	ids.sort()
	var expected: Array = Content.balance.audio.samples.keys()
	expected.sort()
	return _check(ids == expected and profile.probes.size() == ids.size() * 9, "Every original take and rate/pan program occurs")

func _clip(sample: Dictionary) -> NativeAudioClip:
	var clip := NativeAudioClip.new()
	clip.channel_count = sample.channels.size()
	clip.source = {"layer": "sample", "id": sample.id, "url": sample.url, "take": sample.index,
		"sha256": sample.sha256, "sampleRate": sample.sampleRate, "frames": sample.frames}
	var errors := PackedFloat64Array()
	for encoded: String in sample.channels:
		var stem := NativeAudioStem.new()
		stem.values = Marshalls.base64_to_raw(encoded).to_float32_array()
		if not _check(stem.values.size() == int(sample.frames), "Complete decoded original sample channel"):
			return null
		# Reuse the existing PCM conversion, with a constant unity envelope.
		stem.envelope.assign([{"operation": "setValueAtTime", "time": 0.0, "constant": 1.0}])
		var rendered := stem.render(1, int(sample.sampleRate))
		if not _check(not rendered.is_empty(), "Convert the original channel without decoder/resampler substitution"):
			return null
		var stream: AudioStreamWAV = rendered.stream
		var bytes := stream.data
		var maximum := 0.0
		for index in range(stem.values.size()):
			maximum = maxf(maximum, absf(stem.values[index] - float(bytes.decode_s16(index * 2)) / 32768.0 * float(rendered.gain)))
		errors.append(maximum)
		clip.panned.append(stream)
		clip.panned_gains.append(float(rendered.gain))
	conversion_errors[str(sample.id) + ":" + str(int(sample.index))] = errors
	return clip

func _marker(rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	var bytes := PackedByteArray()
	bytes.resize((PAD * 2 + 4) * 2)
	for index in range(4):
		bytes.encode_s16((PAD + index) * 2, [16384, -16384, 32767, -8192][index])
	stream.data = bytes
	return stream

func _rejections() -> void:
	var prepare := preload("res://scripts/audio_sample_stream.gd")
	var source := _marker(int(profile.sampleRate))
	for rate: float in [0.0, -1.0, NAN, INF, 1e-100, 1e100]:
		_check(prepare.prepare(source, rate).is_empty(), "Reject invalid or unrepresentable source playback rates")
	_check(prepare.prepare(null, 1).is_empty(), "Reject an absent original PCM stream")
	for mode: String in ["stereo", "loop", "codec", "empty", "partial"]:
		var invalid := source.duplicate() as AudioStreamWAV
		match mode:
			"stereo": invalid.stereo = true
			"loop": invalid.loop_mode = AudioStreamWAV.LOOP_FORWARD
			"codec": invalid.format = AudioStreamWAV.FORMAT_IMA_ADPCM
			"empty": invalid.data = PackedByteArray()
			"partial": invalid.data = PackedByteArray([1])
		_check(prepare.prepare(invalid, 1).is_empty(), "Reject an unsupported source PCM shape: " + mode)

func _marker_start(trace: PackedVector2Array) -> int:
	var pattern := [.5, -.5, 32767.0 / 32768.0, -.25]
	for index in range(trace.size() - 3):
		var matches := true
		for offset in range(4):
			matches = matches and absf(trace[index + offset].x - float(pattern[offset])) <= FLOAT_ERROR \
				and absf(trace[index + offset].y - float(pattern[offset])) <= FLOAT_ERROR
		if matches:
			return index - PAD
	return -1

func _case(probe: Dictionary) -> void:
	var words := Marshalls.base64_to_raw(probe.controls.data).to_float64_array()
	var key := str(probe.id) + ":" + str(int(probe.take))
	var clip: NativeAudioClip = clips[key]
	var marker_capture := AudioEffectCapture.new()
	marker_capture.buffer_length = 4
	var voice := TracedVoice.new()
	voice.marker = _marker(int(profile.sampleRate))
	voice.marker_bus = buses.capture_bus([marker_capture])
	add_child(voice)
	AudioServer.lock()
	capture.clear_buffer()
	marker_capture.clear_buffer()
	AudioServer.unlock()
	# AudioParam stores the rate as Float32; the captured scalar is its actual value.
	var before := Time.get_ticks_usec()
	if not _check(voice.start(clip, buses, words[0], words[1], words[3]) == OK, "Start the original sample and independent native timing tracer"):
		voice.free()
		return
	var preparation_usec := Time.get_ticks_usec() - before
	var mixer := voice.sample_mixer
	voice.failed.connect(func(operation: String, error: Error): _check(false, operation + ": " + error_string(error)))
	var tolerance := FLOAT_ERROR
	for error: float in conversion_errors[key]:
		# Linear interpolation has L1 gain 1; the last-frame extrapolation has
		# weights (1+fraction, -fraction), whose absolute sum is at most 3.
		tolerance += absf(words[0]) * error * (3.0 if words[3] != 1 else 1.0)
	_check(preload("res://scripts/audio_clip_identity.gd").digest(clip) == identities[key], "Playback never mutates imported PCM or logical clip duration")
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(voice) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.01, true, false, true).timeout
	if not _check(not is_instance_valid(voice), "Sample streams finish and release every native voice"):
		voice.free()
	await get_tree().create_timer(maxf(0, float(probe.frames) / profile.sampleRate - clip.duration() / words[3]) + .1, true, false, true).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var trace := marker_capture.get_buffer(marker_capture.get_frames_available())
	var start := _marker_start(trace)
	if not _check(start >= 0 and start + int(probe.frames) <= frames.size(), "Independent PCM timing and complete original frames"):
		return
	# A generator primes one inactive native refill before its first source frame.
	start += AudioGeneratorFeed.input_latency_frames(true) - AudioGeneratorFeed.input_latency_frames(false)
	if not _check(start + int(probe.frames) <= frames.size(), "Complete source body and EOF after the known generator latency"):
		return
	var diagnostics: Dictionary = mixer.stats()
	_check(diagnostics.stopped and diagnostics.finished and diagnostics.failure.is_empty() \
		and diagnostics.skips.all(func(value): return value == 0), "A complete sample drains without a native generator underrun")
	var left := Marshalls.base64_to_raw(probe.channels[0]).to_float32_array()
	var right := Marshalls.base64_to_raw(probe.channels[1]).to_float32_array()
	var maximum := 0.0
	var worst := 0
	for index in range(int(probe.frames)):
		var error := maxf(absf(frames[start + index].x - left[index]), absf(frames[start + index].y - right[index]))
		if error > maximum:
			maximum = error
			worst = index
	var result := {"id": probe.id, "take": probe.take, "gain": words[0], "pan": words[1], "rate": words[3],
		"start": start, "frames": probe.frames, "maximumError": maximum, "tolerance": tolerance, "worst": worst, "preparationUsec": preparation_usec,
		"stream": diagnostics}
	results.append(result)
	_check(maximum <= tolerance, "Original sample waveform: " + JSON.stringify(result))

func _stress(offset: int) -> void:
	var subjects: Array[Dictionary] = []
	for index in range(int(Content.balance.audio.maxVoices)):
		var probe: Dictionary = profile.probes[((index + offset) * 13) % profile.probes.size()]
		var key := str(probe.id) + ":" + str(int(probe.take))
		var marker_capture := AudioEffectCapture.new()
		marker_capture.buffer_length = 4
		var voice := TracedVoice.new()
		voice.marker = _marker(int(profile.sampleRate))
		voice.marker_bus = buses.capture_bus([marker_capture])
		add_child(voice)
		subjects.append({"probe": probe, "clip": clips[key], "key": key, "voice": voice, "trace": marker_capture})
	# Every independent trace and the summed output share this capture origin.
	AudioServer.lock()
	capture.clear_buffer()
	for subject: Dictionary in subjects:
		subject.trace.clear_buffer()
	AudioServer.unlock()
	for subject: Dictionary in subjects:
		var words := Marshalls.base64_to_raw(subject.probe.controls.data).to_float64_array()
		var before := Time.get_ticks_usec()
		if not _check(subject.voice.start(subject.clip, buses, words[0], words[1], words[3]) == OK, "Admit the complete source voice-limit corpus"):
			return
		subject.admission_usec = Time.get_ticks_usec() - before
		subject.mixer = subject.voice.sample_mixer
		subject.voice.failed.connect(func(operation: String, error: Error): _check(false, operation + ": " + error_string(error)))
	_check(buses.sample_worker.thread.is_started(), "One native worker services the shared sample context")
	# Native mixing and sample feeding must progress while the UI cannot process.
	OS.delay_msec(1200)
	var deadline := Time.get_ticks_msec() + 5000
	while subjects.any(func(subject): return is_instance_valid(subject.voice)) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.01, true, false, true).timeout
	_check(subjects.all(func(subject): return not is_instance_valid(subject.voice)), "Every source-limited sample retires after a UI stall")
	var required_frames := 0
	for subject: Dictionary in subjects:
		var trace: AudioEffectCapture = subject.trace
		var start := _marker_start(trace.get_buffer(trace.get_frames_available()))
		_check(start >= 0, "Every simultaneous sample retains its independent PCM tracer")
		subject.start = start + AudioGeneratorFeed.input_latency_frames(true) - AudioGeneratorFeed.input_latency_frames(false) if start >= 0 else -1
		if subject.start >= 0:
			required_frames = maxi(required_frames, int(subject.start) + int(subject.probe.frames))
	# Each archive includes a fixed slow-rate EOF window. Native completion of a
	# faster take can precede that window even when another voice finishes later.
	deadline = Time.get_ticks_msec() + 3000
	while capture.get_frames_available() < required_frames and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.01, true, false, true).timeout
	_check(capture.get_discarded_frames() == 0, "The complete simultaneous sample capture never overflows")
	var frames := capture.get_buffer(capture.get_frames_available())
	var expected := PackedVector2Array()
	expected.resize(frames.size())
	var tolerance := FLOAT_ERROR * subjects.size()
	var admissions: Array[Dictionary] = []
	for subject: Dictionary in subjects:
		var start := int(subject.start)
		if start < 0:
			continue
		var probe: Dictionary = subject.probe
		var words := Marshalls.base64_to_raw(probe.controls.data).to_float64_array()
		if not _check(start + int(probe.frames) <= expected.size(), "The source-limit capture retains all EOF tails"):
			continue
		var left := Marshalls.base64_to_raw(probe.channels[0]).to_float32_array()
		var right := Marshalls.base64_to_raw(probe.channels[1]).to_float32_array()
		for frame in range(int(probe.frames)):
			expected[start + frame] += Vector2(left[frame], right[frame])
		for error: float in conversion_errors[subject.key]:
			tolerance += absf(words[0]) * error * (3.0 if words[3] != 1 else 1.0)
		var diagnostics: Dictionary = subject.mixer.stats()
		_check(diagnostics.stopped and diagnostics.finished and diagnostics.failure.is_empty() \
			and diagnostics.skips.all(func(value): return value == 0), "Concurrent source playback never underruns during the UI stall")
		_check(preload("res://scripts/audio_clip_identity.gd").digest(subject.clip) == identities[subject.key], "Concurrent playback retains imported sample identity")
		admissions.append({"id": probe.id, "rate": words[3], "pan": words[1], "start": start,
			"admissionUsec": subject.admission_usec, "stream": diagnostics})
	var maximum := 0.0
	var worst := 0
	for frame in range(frames.size()):
		var error := maxf(absf(frames[frame].x - expected[frame].x), absf(frames[frame].y - expected[frame].y))
		if error > maximum:
			maximum = error
			worst = frame
	_check(buses.sample_worker.count() == 0, "Completed sample mixers leave the context worker")
	var result := {"voices": subjects.size(), "offset": offset, "stallMsec": 1200, "maximumError": maximum,
		"tolerance": tolerance, "worst": worst, "admissions": admissions}
	results.append(result)
	_check(maximum <= tolerance, "Source-limited mixed sample waveform: " + JSON.stringify(result))

func _cleanup() -> void:
	if is_instance_valid(buses):
		var names: Array[StringName] = buses.owned.duplicate()
		buses.free()
		var deadline := Time.get_ticks_msec() + 3000
		while names.any(func(name): return AudioServer.get_bus_index(name) >= 0) and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(.02, true, false, true).timeout
		_check(names.all(func(name): return AudioServer.get_bus_index(name) < 0), "Every native sample route drains")
	var index := AudioServer.get_bus_index(sink)
	if index > 0:
		AudioServer.remove_bus(index)

func _run() -> void:
	if not _source():
		get_tree().quit(1)
		return
	_rejections()
	for sample: Dictionary in profile.samples:
		var clip := _clip(sample)
		if clip == null:
			get_tree().quit(1)
			return
		clips[str(sample.id) + ":" + str(int(sample.index))] = clip
		identities[str(sample.id) + ":" + str(int(sample.index))] = preload("res://scripts/audio_clip_identity.gd").digest(clip)
	AudioServer.add_bus()
	sink = StringName("SampleMixSink_%d" % get_instance_id())
	AudioServer.set_bus_name(AudioServer.bus_count - 1, sink)
	AudioServer.set_bus_mute(AudioServer.bus_count - 1, true)
	buses = AudioBuses.new()
	add_child(buses)
	if not _check(buses.configure() == OK, "Configure independent sample capture routes"):
		get_tree().quit(1)
		return
	AudioServer.set_bus_send(AudioServer.get_bus_index(buses.sfx), sink)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 4
	AudioServer.add_bus_effect(AudioServer.get_bus_index(buses.sfx), capture)
	var selected := ""
	var unity := OS.get_cmdline_user_args().has("--unity")
	var stress := OS.get_cmdline_user_args().has("--stress")
	var stress_offset := 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--id="):
			selected = argument.trim_prefix("--id=")
		if argument.begins_with("--stress-offset="):
			var value := argument.trim_prefix("--stress-offset=")
			if _check(value.is_valid_int() and value.to_int() >= 0 and value.to_int() < profile.probes.size(), "Select an original sample stress corpus offset"):
				stress_offset = value.to_int()
	if stress:
		await _stress(stress_offset)
	else:
		for probe: Dictionary in profile.probes:
			var words := Marshalls.base64_to_raw(probe.controls.data).to_float64_array()
			if (selected.is_empty() or probe.id == selected) and (not unity or words[3] == 1):
				await _case(probe)
		_check(results.size() == (21 if unity else 63) / (7 if not selected.is_empty() else 1), "Complete selected original sample corpus")
	await _cleanup()
	DirAccess.make_dir_recursive_absolute("res://artifacts/sol")
	var file := FileAccess.open("res://artifacts/sol/audio-sample-stress-native.json" if stress else "res://artifacts/sol/audio-sample-mix-native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"driver": AudioServer.get_driver_name(), "sampleRate": profile.sampleRate, "cases": results, "failures": failures}, "\t"))
	file.close()
	print("AUDIO_SAMPLE_STRESS" if stress else "AUDIO_SAMPLE_MIX", " cases=", results.size(), " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
