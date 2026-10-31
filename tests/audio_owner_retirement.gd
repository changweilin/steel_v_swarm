extends Node

const MusicTests = preload("res://tests/audio_music_suite.gd")
const AmbienceTests = preload("res://tests/audio_ambience_suite.gd")
const MovementTests = preload("res://tests/audio_move_suite.gd")
const HELD_URL := "audio/__sol_owner__/held.sol_owner_audio"
const HELD_PATH := "res://assets/" + HELD_URL
const PROBE_URL := "audio/__sol_owner__/probe.sol_owner_audio"
const PROBE_PATH := "res://assets/" + PROBE_URL

class Silent:
	static func stream() -> AudioStreamWAV:
		var wave := AudioStreamWAV.new()
		wave.mix_rate = 48000
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		var bytes := PackedByteArray()
		bytes.resize(96000)
		wave.data = bytes
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = 48000
		return wave

class ProbeLoop extends AudioLoopPlayer:
	var opens := 0
	func open(_url: String, destination: StringName) -> Error:
		opens += 1
		stream = Silent.stream()
		bus = destination
		if play_when_loaded:
			play()
		loaded.emit()
		return OK

class Music extends AudioMusic:
	var created: Array[ProbeLoop] = []
	func _make_player() -> AudioLoopPlayer:
		var player := ProbeLoop.new()
		created.append(player)
		return player

class Ambience extends AudioAmbience:
	var created: Array[ProbeLoop] = []
	func _make_player() -> AudioLoopPlayer:
		var player := ProbeLoop.new()
		created.append(player)
		return player

class Fallback extends AudioMusicFallback:
	func _clip(_arrangement: String) -> NativeAudioClip:
		var clip := NativeAudioClip.new()
		clip.channel_count = 0
		clip.centered = Silent.stream()
		return clip

class Loader extends ResourceFormatLoader:
	var started := Semaphore.new()
	var release := Semaphore.new()
	var probe_loads := 0
	var before_exists := Callable()
	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["sol_owner_audio"])
	func _handles_type(type: StringName) -> bool:
		return type in [&"AudioStream", &"AudioStreamOggVorbis", &"Resource"]
	func _get_resource_type(_path: String) -> String:
		return "AudioStreamOggVorbis"
	func _exists(path: String) -> bool:
		if path == PROBE_PATH and before_exists.is_valid():
			var callback := before_exists
			before_exists = Callable()
			callback.call()
		return path in [HELD_PATH, PROBE_PATH]
	func _load(path: String, _original: String, _threads: bool, _cache: int) -> Variant:
		if path == HELD_PATH:
			started.post()
			release.wait()
		else:
			probe_loads += 1
		return AudioStreamOggVorbis.new()

class Guard extends RefCounted:
	var returned := Semaphore.new()
	var release: Semaphore
	var timed_out := false
	func run() -> void:
		var deadline := Time.get_ticks_msec() + 3000
		while not returned.try_wait() and Time.get_ticks_msec() < deadline:
			OS.delay_msec(1)
		if Time.get_ticks_msec() >= deadline:
			timed_out = true
			release.post()

var assertions := 0
var failures: Array[String] = []
var metadata: Dictionary
var profile := AudioPreferences.new()

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.000001, description)

func _source_programs() -> void:
	var capture: Dictionary = Content.read_json("res://data/audio_lifecycle.json")
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	# These isolated programs consume audio/data modules, not mixed-event RNG state.
	# The complete audio_lifecycle scene retains its separate full provenance gate.
	for path: String in ["public/js/audio.js", "public/js/data.js"]:
		_check(capture.source.sourceInputs[path] == provenance.inputs[path], "Retain the original isolated owner source identity: " + path)
	for path: String in ["tools/audio_music_references.mjs", "tools/audio_ambience_references.mjs", "tools/audio_ambience_capture.mjs", "tools/audio_move_references.mjs"]:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == capture.source.inputs[path], "Retain the original owner reference generator: " + path)
	if failures.is_empty():
		MusicTests.run(self, capture.fixtures, metadata)
		AmbienceTests.run(self, capture.fixtures, metadata)
		MovementTests.run(self, capture.fixtures, metadata)

func _routing() -> AudioBuses:
	var routing := AudioBuses.new()
	add_child(routing)
	_check(routing.configure() == OK, "Create a native routing context")
	AudioServer.set_bus_mute(AudioServer.get_bus_index(routing.sfx), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(routing.bgm), true)
	return routing

func _owners(routing: AudioBuses) -> void:
	var music := Music.new()
	add_child(music)
	_check(music.configure(metadata, profile, routing) == OK, "Configure streamed music")
	music.state.set_scene("menu")
	music.state.unlock()
	var track: ProbeLoop = music.created[0]
	_check(track.playing, "Music consumes player readiness")
	get_tree().paused = true
	remove_child(music)
	_check(music.retired and music.state.disposed and track.retired and not track.playing and track.stream == null,
		"Detachment retires the stream even during SceneTree pause")
	_check(music.fade_timer.is_stopped() and music.grace_timer.is_stopped(), "Retirement cancels both music clocks")
	add_child(music)
	_check(music.configure(metadata, profile, routing) == ERR_UNCONFIGURED, "Reattachment requires a new music owner")
	music._command({"op": "register", "name": "battle", "url": "audio/bgm/battle.mp3"})
	_check(music.created.size() == 1, "Late retired commands cannot allocate tracks")
	get_tree().paused = false
	music.free()
	var ambience := Ambience.new()
	add_child(ambience)
	_check(ambience.configure(metadata, routing) == OK, "Configure ambience")
	ambience.state.unlocked = true
	ambience.set_ambience({})
	var bed: ProbeLoop = ambience.created[0]
	_check(bed.playing, "A location bed starts on readiness")
	remove_child(ambience)
	_check(ambience.retired and ambience.state.disposed and not bed.playing and bed.stream == null,
		"Ambience detachment releases the retained stream")
	add_child(ambience)
	_check(ambience.configure(metadata, routing) == ERR_UNCONFIGURED, "Retired ambience cannot reconnect disposed state")
	ambience._register("late", "audio/late.ogg")
	_check(ambience.created.size() == 1, "Late ambience registration cannot allocate")
	ambience.free()
	var fallback := Fallback.new()
	add_child(fallback)
	_check(fallback.configure(metadata, profile, routing) == OK, "Configure procedural fallback")
	fallback.start("menu")
	var voice: Dictionary = fallback.current
	remove_child(fallback)
	_check(fallback.retired and voice.envelope.disconnected and not voice.player.playing and voice.player.stream == null,
		"Fallback retirement disconnects the envelope and complete voice")
	add_child(fallback)
	_check(fallback.configure(metadata, profile, routing) == ERR_UNCONFIGURED, "A retired fallback cannot reactivate")
	fallback.start("battle")
	_check(fallback.voices.is_empty(), "Retired fallback input cannot start voices")
	fallback.free()
	var unused := AudioLoopPlayer.new()
	add_child(unused)
	remove_child(unused)
	add_child(unused)
	_check(unused.open(HELD_URL, routing.bgm) == ERR_UNCONFIGURED, "An unused detached player also has a terminal lifetime")
	unused.free()

func _reentrant(routing: AudioBuses) -> void:
	var state := AudioAmbienceState.new()
	state.configure(metadata)
	state.unlocked = true
	state.registered.connect(func(_id, _url): state.dispose(), CONNECT_ONE_SHOT)
	state.set_ambience({metadata.ambience[0].id: 0.0})
	_check(state.disposed and state.beds.is_empty(), "Synchronous disposal cannot access or recreate cleared beds")
	var music := Music.new()
	add_child(music)
	music.child_entered_tree.connect(func(_child): music.queue_free(), CONNECT_ONE_SHOT)
	_check(music.configure(metadata, profile, routing) == ERR_UNCONFIGURED and music.get_child_count() == 1,
		"Configuration retirement prevents further timer/fallback allocation")
	await get_tree().process_frame
	var ambience := Ambience.new()
	add_child(ambience)
	_check(ambience.configure(metadata, routing) == OK, "Configure reentrant ambience")
	ambience.child_entered_tree.connect(func(_child): ambience.queue_free(), CONNECT_ONE_SHOT)
	ambience.state.unlocked = true
	ambience.set_ambience({})
	_check(ambience.created.size() == 1 and ambience.created[0].opens == 0, "Queued child admission prevents opening a stream")
	await get_tree().process_frame
	var movement := AudioMove.new()
	add_child(movement)
	_check(movement.configure(metadata, routing, false) == OK, "Configure reentrant movement")
	movement.child_entered_tree.connect(func(_child): movement.queue_free(), CONNECT_ONE_SHOT)
	movement.unlock(routing.context_seconds())
	movement.set_move("stomp", .8)
	_check(movement.voices.stomp.disposed and movement.voices.stomp.input_players.is_empty() and not movement.thread.is_started(),
		"Queued movement admission cannot configure a voice or start its worker")
	await get_tree().process_frame
	var separate := _routing()
	var voice := AudioMoveVoice.new()
	add_child(voice)
	voice.child_entered_tree.connect(func(_child): separate.free(), CONNECT_ONE_SHOT)
	var bank := preload("res://scripts/audio_resource_snapshot.gd").new().movement()
	var initial := {"gain": .5, "pan": 0.0, "rate": 1.0, "wet": 0.0}
	_check(voice.configure("stomp", metadata, bank, separate, initial, 0) == ERR_UNCONFIGURED,
		"Routing retirement during child admission cancels voice configuration")
	_check(voice.disposed and voice.input_players.size() == 1 and not voice.input_players[0].playing and voice.output_player == null,
		"Reentrant routing retirement owns the admitted input and prevents later allocation")
	voice.free()

func _decoder(routing: AudioBuses) -> void:
	var loader := Loader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	var probe := AudioLoopPlayer.new()
	add_child(probe)
	loader.before_exists = func(): remove_child(probe)
	_check(probe.open(PROBE_URL, routing.bgm) == ERR_UNCONFIGURED and loader.probe_loads == 0 and probe.pending_path.is_empty(),
		"Synchronous availability retirement cannot start an orphan decode")
	probe.free()
	var music := AudioMusic.new()
	add_child(music)
	var held := metadata.duplicate(true)
	held.music.menu.hi = HELD_URL
	_check(music.configure(held, profile, routing) == OK, "Configure a held native decoder")
	music.state.set_scene("menu")
	music.state.unlock()
	var deadline := Time.get_ticks_msec() + 5000
	var started := loader.started.try_wait()
	while not started and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		started = loader.started.try_wait()
	_check(started, "The threaded request is confirmed live before retirement")
	var guard := Guard.new()
	guard.release = loader.release
	var thread := Thread.new()
	thread.start(guard.run)
	remove_child(music)
	guard.returned.post()
	thread.wait_to_finish()
	_check(not guard.timed_out, "Retirement never waits for the held decoder")
	music.free()
	loader.release.post()
	deadline = Time.get_ticks_msec() + 5000
	while ResourceLoader.load_threaded_get_status(HELD_PATH) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(ResourceLoader.load_threaded_get_status(HELD_PATH) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"The independent drain collects completion after owner destruction")
	ResourceLoader.remove_resource_format_loader(loader)

func _routing_loss(routing: AudioBuses) -> void:
	var music := Music.new()
	var ambience := Ambience.new()
	var fallback := Fallback.new()
	for owner: Node in [music, ambience, fallback]:
		add_child(owner)
	_check(music.configure(metadata, profile, routing) == OK and ambience.configure(metadata, routing) == OK
		and fallback.configure(metadata, profile, routing) == OK, "Configure shared context consumers")
	music.state.set_scene("menu")
	music.state.unlock()
	ambience.state.unlocked = true
	ambience.set_ambience({})
	fallback.start("menu")
	var movement := AudioMove.new()
	add_child(movement)
	_check(movement.configure(metadata, routing, false) == OK, "Configure movement on the retiring context")
	movement.unlock(routing.context_seconds())
	movement.set_move("stomp", .8)
	var deadline := Time.get_ticks_msec() + 5000
	while (not movement.voices.has("stomp") or not movement.voices.stomp.activated) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(movement.voices.has("stomp") and movement.voices.stomp.activated, "Routing loss exercises an active movement worker")
	var moving: AudioMoveVoice = movement.voices.stomp
	var sfx := AudioVoice.new()
	add_child(sfx)
	var clip := NativeAudioClip.new()
	clip.panned.append(Silent.stream())
	_check(sfx.start(clip, routing, .5, .25) == OK and sfx.players[0].playing, "Routing loss exercises a playing routed SFX")
	var sampled := AudioVoice.new()
	add_child(sampled)
	var sample_clip := NativeAudioClip.new()
	sample_clip.source = {"layer": "sample"}
	var sample_wave := Silent.stream()
	sample_wave.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sample_clip.panned.append(sample_wave)
	_check(sampled.start(sample_clip, routing, .5, .25) == OK and sampled.sample_mixer != null,
		"Routing loss exercises sample streaming alongside the movement worker")
	var sample_worker: RefCounted = routing.sample_worker
	var fallback_voice: Dictionary = fallback.current
	var track: ProbeLoop = music.created[0]
	var bed: ProbeLoop = ambience.created[0]
	var names: Array[StringName] = routing.owned.duplicate()
	routing.free()
	_check(music.retired and ambience.retired and fallback.retired and not track.playing and not bed.playing
		and not fallback_voice.player.playing, "Context retirement stops consumers before their routes disappear")
	_check(movement.state.disposed and not movement.thread.is_started() and moving.disposed
		and not moving.output_player.playing, "Context retirement joins the movement worker and stops its native output")
	_check(sfx.disposed and not sfx.players[0].playing, "Context retirement stops SFX before its route can fall back to Master")
	_check(sampled.disposed and not sampled.players[0].playing and sampled.sample_mixer.stats().stopped \
		and not sample_worker.thread.is_started(), "Context retirement joins sample streaming before releasing its playback and buses")
	for owner: Node in [music, ambience, fallback]:
		owner.free()
	movement.free()
	deadline = Time.get_ticks_msec() + 3000
	while names.any(func(name): return AudioServer.get_bus_index(name) >= 0) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02, true, false, true).timeout
	_check(names.all(func(name): return AudioServer.get_bus_index(name) < 0), "Native routes drain without playing orphans")

func _run() -> void:
	metadata = Content.balance.audio
	profile.configure(metadata)
	_source_programs()
	var routing := _routing()
	_owners(routing)
	await _reentrant(routing)
	await _decoder(routing)
	await _routing_loss(routing)
	print("AUDIO_OWNER_RETIREMENT assertions=", assertions, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
