extends RefCounted

const Helper = preload("res://tests/status_suite.gd")
const ClipTests = preload("res://tests/audio_clip_suite.gd")
const MusicTests = preload("res://tests/audio_music_suite.gd")
const AmbienceTests = preload("res://tests/audio_ambience_suite.gd")
const MusicEnvelopeTests = preload("res://tests/audio_music_envelope_suite.gd")
const SynthesisTests = preload("res://tests/audio_synthesis_suite.gd")
const SceneTests = preload("res://tests/audio_scene_suite.gd")
const MoveTests = preload("res://tests/audio_move_suite.gd")
const LocalFireTests = preload("res://tests/local_fire_suite.gd")
const PcmGain = preload("res://scripts/audio_pcm_gain.gd")

class RecordedPreferences extends AudioPreferences:
	var writes: Array = []
	var fail := false

	func _save() -> void:
		if fail:
			save_failed.emit(ERR_CANT_CREATE)
		else:
			writes.append(saved_values())

static func run(h: Node, fixtures: Dictionary) -> void:
	if not Content.balance.has("audio") or not fixtures.has("audioEvents") or not fixtures.has("audioPan"):
		h._check(false, "Regenerate original audio routing and voice-budget references")
		return
	var rules: Dictionary = Content.balance.audio
	var audio := AudioRules.new()
	audio.configure(rules)
	_preferences(h, fixtures, rules)
	ClipTests.run(h)
	MusicTests.run(h, fixtures, rules)
	AmbienceTests.run(h, fixtures, rules)
	MusicEnvelopeTests.run(h, fixtures, rules)
	SynthesisTests.run(h, rules)
	SceneTests.run(h, fixtures, rules)
	MoveTests.run(h, fixtures, rules)
	LocalFireTests.run(h, fixtures)
	_panning(h, fixtures.audioPan)
	await _buses(h)
	for fixture: Dictionary in fixtures.audioFire:
		h._check(audio.fire_id(fixture.definition, fixture.slot, fixture.side) == fixture.id, "Original fire timbre follows shared trajectory classification and faction/light/fan gates")
	for fixture: Dictionary in fixtures.audioSpatial:
		Helper.compare(h, audio.spatial(_camera(fixture.camera), fixture.x, fixture.z, fixture.y), fixture.result, "Original 3D distance, optional height, horizontal pan and strict audibility boundary")
	for fixture: Dictionary in fixtures.audioEvents:
		Helper.compare(h, audio.event_plan(fixture.event, _camera(fixture.camera), "you"), fixture.result, "Original audio events preserve self suppression, civilian silence, pre-dispatch distance gates and untranslated cast slots")
	if not fixtures.has("audioNativeEvents"):
		h._check(false, "Regenerate native event adaptation references from the original audio consumer")
	for fixture: Dictionary in fixtures.get("audioNativeEvents", []):
		var event: Dictionary = fixture.native.duplicate(true)
		for key: String in ["position", "point", "start", "end"]:
			if event.has(key):
				var values: Array = event[key]
				event[key] = Vector3(values[0], values[1], values[2])
		var source := AudioEvent.source_event(event, int(fixture.actorPeer))
		Helper.compare(h, audio.event_plan(source, _camera(fixture.camera), 101), fixture.result,
			"Native event adapter retains server Z, absent shot/death/cast heights, source altitude and owner identities")
	h._check(AudioEvent.source_event({"type": "shot", "physical": true}).is_empty(), "Native physical projectile frames do not create additional source fire sounds")
	for fixture: Dictionary in fixtures.audioAmbience:
		Helper.compare(h, audio.ambience_mix(fixture.query), fixture.result, "Original ambience declaration order wins without overlapping zone gains")
	for fixture: Dictionary in fixtures.audioMusic:
		h._check(audio.music_url(fixture.name, fixture.low) == fixture.url, "Original BGM scene/codec lookup and unknown-scene rejection")
	for program: Dictionary in fixtures.audioGates:
		var budget := AudioVoiceBudget.new()
		budget.configure(rules)
		for frame: Dictionary in program.frames:
			budget.active = int(frame.active)
			h._check(budget.allow(frame.id, frame.now) == (not frame.result.is_empty()), "Original first-interval suppression and voice-cap ordering")
			Helper.compare(h, budget.last, frame.last, "A voice-cap rejection still advances the same-sound deduplication timestamp")
	for fixture: Dictionary in fixtures.audioCounts:
		var budget := AudioVoiceBudget.new()
		budget.configure(rules)
		budget.reserve(fixture.duration, 10)
		h._check(budget.active == int(fixture.during), "Original voice reservation count")
		budget.advance(10 + float(fixture.delay) / 1000.0 - .000001)
		h._check(budget.active == int(fixture.during), "Voice budget includes the original release grace interval")
		budget.advance(10 + float(fixture.delay) / 1000.0 + .000001)
		h._check(budget.active == int(fixture.after), "Voice reservations expire independently of audio node lifetime")
	var paused_budget := AudioVoiceBudget.new()
	paused_budget.configure(rules)
	var timer_case: Dictionary = fixtures.audioCounts[0]
	paused_budget.reserve(float(timer_case.duration), 100)
	paused_budget.last.ui_click = 10.0
	var timer_now := 100.0 + float(timer_case.delay) / 1000.0 + .000001
	h._check(not paused_budget.allow("ui_click", 10.0, timer_now) and paused_budget.active == int(timer_case.after), "Wall-clock voice retirement continues while a suspended audio clock preserves deduplication")
	for program: Dictionary in fixtures.audioSamples:
		var budget := AudioVoiceBudget.new()
		budget.configure(rules)
		for frame: Dictionary in program.frames:
			var cursor := {"value": 0}
			var random := func() -> float:
				var value := float(frame.rolls[int(cursor.value)])
				cursor.value += 1
				return value
			var choice := budget.sample_choice("sample", program.durations, random)
			Helper.compare(h, choice, {"index": frame.index, "rate": frame.rate, "duration": frame.duration}, "Original take selection avoids repeats and counts rate-adjusted sample duration")
			h._check(cursor.value == frame.draws, "One-take samples do not consume an unnecessary selection random draw")

static func _preferences(h: Node, fixtures: Dictionary, rules: Dictionary) -> void:
	for program: Dictionary in fixtures.audioPreferences:
		var preferences := RecordedPreferences.new()
		preferences.configure(rules, program.saved)
		Helper.compare(h, preferences.snapshot(), program.initial, "Original legacy master/muted migration and nullish dual-channel defaults")
		for frame: Dictionary in program.frames:
			preferences.call(str(frame.method).to_snake_case(), frame.value)
			Helper.compare(h, preferences.snapshot(), frame.result, "Original audio clamp/truthiness and independent volume/on state")
			Helper.compare(h, preferences.writes, frame.writes, "Audio setters persist even identical assignments and master toggles retain channel volumes")
	for fixture: Dictionary in fixtures.audioFailedReads:
		var preferences := AudioPreferences.new()
		preferences.configure(rules)
		Helper.compare(h, preferences.snapshot(), fixture.result, "Original empty/malformed storage defaults")
	var failed := RecordedPreferences.new()
	failed.configure(rules)
	failed.fail = true
	var errors: Array = []
	failed.save_failed.connect(func(error: Error): errors.append(error))
	failed.set_sfx(.2)
	failed.set_sfx_on(false)
	failed.set_bgm_on(true)
	failed.set_master_on(false)
	Helper.compare(h, failed.snapshot(), fixtures.audioFailedWrite, "Audio storage errors do not undo in-memory settings")
	h._check(errors.size() == 4, "Native audio persistence reports each failure without interrupting later updates")
	_storage(h, rules)
	_panels(h, rules)

static func _storage(h: Node, rules: Dictionary) -> void:
	var preferences := AudioPreferences.new()
	preferences.configure(rules)
	preferences.persist = true
	preferences.save_path = "user://audio-fixture-%d.cfg" % Time.get_ticks_usec()
	h._check(preferences.load_save() == OK, "Missing native audio profile retains original defaults")
	preferences.set_sfx(.23)
	preferences.set_bgm(.61)
	preferences.set_sfx_on(false)
	var restored := AudioPreferences.new()
	restored.configure(rules)
	restored.persist = true
	restored.save_path = preferences.save_path
	h._check(restored.load_save() == OK and restored.snapshot() == preferences.snapshot(), "ConfigFile audio round trip preserves independent channels")
	var file := FileAccess.open(preferences.save_path, FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	h._check(restored.load_save() != OK and restored.sfx_volume == rules.masterDefault and restored.bgm_volume == rules.bgmDefault, "Malformed native audio storage restores defaults and reports its read error")
	h._check(DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences.save_path)) == OK, "Remove isolated audio profile")

static func _panels(h: Node, rules: Dictionary) -> void:
	var preferences := AudioPreferences.new()
	preferences.configure(rules)
	var first := AudioSettings.new()
	var second := AudioSettings.new()
	h.add_child(first)
	h.add_child(second)
	first.configure(preferences)
	second.configure(preferences)
	preferences.set_master_on(false)
	first.widgets.sfx.slider.value = 30
	h._check(preferences.sfx_on and not preferences.bgm_on and second.widgets.sfx.slider.value == 30 and second.widgets.sfx.switch.button_pressed, "Positive volume automatically enables only its own channel and synchronizes both native mounts")
	first.widgets.sfx.slider.value = 0
	h._check(preferences.sfx_on, "Zero volume does not rewrite the channel's on/off preference")
	second.widgets.bgm.slider.value = 55
	h._check(preferences.master_on() and first.widgets.bgm.slider.value == 55, "Independent channel controls restore the master-on state when both are on")
	first.master_button.pressed.emit()
	h._check(not preferences.sfx_on and not preferences.bgm_on and preferences.bgm_volume == .55, "Master mute preserves both stored volumes")
	first.free()
	second.free()

static func _camera(value: Variant) -> Variant:
	if value == null:
		return null
	var elements: Array = value.matrixWorld.elements
	return Transform3D(Basis(Vector3(elements[0], elements[1], elements[2]), Vector3(elements[4], elements[5], elements[6]), Vector3(elements[8], elements[9], elements[10])),
		Vector3(value.position.x, value.position.y, value.position.z))

static func _panning(h: Node, fixtures: Array) -> void:
	for fixture: Dictionary in fixtures:
		var routes := AudioPan.routes(fixture.pan, fixture.input.size())
		var left := 0.0
		var right := 0.0
		for index in range(routes.size()):
			var route: Dictionary = routes[index]
			# Apply the native AudioEffectPanner mono mix to the converted parameters.
			left += float(fixture.input[index]) * float(route.gain) * (1.0 - float(route.pan))
			right += float(fixture.input[index]) * float(route.gain) * (1.0 + float(route.pan))
		h._near(left, fixture.left, "Original real WebAudio graph left-channel impulse coefficient")
		h._near(right, fixture.right, "Original real WebAudio graph right-channel impulse coefficient")

static func _buses(h: Node) -> void:
	var original_count := AudioServer.bus_count
	var master_volume := AudioServer.get_bus_volume_db(0)
	var master_mute := AudioServer.is_bus_mute(0)
	var external := "AudioFixture_%d" % Time.get_ticks_usec()
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, external)
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(external), .37)
	var buses := AudioBuses.new()
	h.add_child(buses)
	h._check(buses.configure() == OK and AudioServer.bus_count == original_count + 3, "Native audio creates independent SFX/BGM buses without resetting the app's bus layout")
	h._check(buses.set_sfx_gain(.23) == OK and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(buses.sfx)), .23), "Native SFX gain routes through the owned bus")
	h._check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(buses.bgm)), 1), "BGM player fades remain independent of SFX bus volume")
	var clock_before := buses.context_seconds()
	var clock_deadline := Time.get_ticks_msec() + 2000
	while buses.context_seconds() <= clock_before and Time.get_ticks_msec() < clock_deadline:
		await h.get_tree().create_timer(.02, true, false, true).timeout
	h._check(buses.context_seconds() > clock_before, "Native audio context clock follows driver mixes even before transient voices exist")
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 48000
	var samples := PackedByteArray()
	samples.resize(2048)
	samples.fill(0)
	wave.data = samples
	var clip := NativeAudioClip.new()
	clip.channel_count = 2
	clip.panned.assign([wave, wave])
	clip.panned_gains.assign([.4, .8])
	clip.centered = wave
	clip.centered_gain = .5
	clip.reservation_seconds = .24
	h._check(clip.valid(), "Captured stereo inputs and centered layers use separate native mono resources")
	var voice := AudioVoice.new()
	buses.add_child(voice)
	h._check(voice.start(clip, buses, .7, .75, 1.07) == OK and voice.players.size() == 3 and voice.routes.size() == 2, "One source sound uses native players with separate panned inputs and a centered layer")
	for bus_name: StringName in voice.routes:
		var bus_index := AudioServer.get_bus_index(bus_name)
		h._check(AudioServer.get_bus_send(bus_index) == buses.sfx and AudioServer.get_bus_effect(bus_index, 0) is AudioEffectPanner, "Native panner sends into the shared SFX bus")
	if not voice.players.is_empty():
		h._check(voice.players[-1].bus == buses.sfx and is_equal_approx(voice.players[-1].volume_linear, PcmGain.native_gain(wave, .35)), "A centered synthesis layer bypasses panning and restores its captured normalization gain")
	var voice_routes: Array[StringName] = voice.routes.duplicate()
	voice.free()
	h._check(await _removed(h, voice_routes), "Retired voice routes wait for native fade-out mixes before deletion")
	h._check(buses.owned.size() == 2 and AudioServer.bus_count == original_count + 3, "Releasing one sound removes its voice routes but retains permanent channel buses")
	var permanent_routes: Array[StringName] = buses.owned.duplicate()
	buses.free()
	h._check(await _removed(h, permanent_routes), "Permanent bus teardown completes after native stream retirement")
	h._check(AudioServer.bus_count == original_count + 1 and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(external)), .37), "Audio teardown preserves unrelated buses and their volume")
	h._check(AudioServer.get_bus_volume_db(0) == master_volume and AudioServer.is_bus_mute(0) == master_mute, "Audio setup and teardown do not overwrite Master settings")
	AudioServer.remove_bus(AudioServer.get_bus_index(external))

static func _removed(h: Node, names: Array[StringName]) -> bool:
	var deadline := Time.get_ticks_msec() + 2000
	while names.any(func(name): return AudioServer.get_bus_index(name) >= 0) and Time.get_ticks_msec() < deadline:
		await h.get_tree().create_timer(.02, true, false, true).timeout
	return names.all(func(name): return AudioServer.get_bus_index(name) < 0)
