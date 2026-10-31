extends Node

const Helper = preload("res://tests/status_suite.gd")

class Manager extends BattleAudio:
	var context_time := 10.0
	var wall_time := 20.0
	var created := 0
	var draws := 0
	var before_admission := Callable()
	var player_admission := Callable()
	func _now() -> float:
		return context_time
	func _wall_now() -> float:
		return wall_time
	func _sample_random() -> float:
		draws += 1
		return super._sample_random()
	func _make_voice() -> AudioVoice:
		created += 1
		var voice := super._make_voice()
		if player_admission.is_valid():
			voice.child_entered_tree.connect(func(_child): player_admission.call(), CONNECT_ONE_SHOT)
		if before_admission.is_valid():
			before_admission.call()
		return voice

class LoadingSamples extends AudioSampleLibrary:
	var callback := Callable()
	func load_samples(_low: bool) -> Error:
		callback.call()
		return OK

class RejectedManager extends Manager:
	var rejected: Array[Dictionary] = []
	func _failure(operation: String, error: Error) -> void:
		rejected.append({"operation": operation, "error": error})

class RefusingSampleWorker extends "res://scripts/audio_sample_worker.gd":
	var refuse_start := false
	func start() -> Error:
		return ERR_CANT_CREATE if refuse_start else super.start()
	func add(_stream: RefCounted) -> bool:
		return false

class QueuingRoutes extends AudioBuses:
	func effect_bus(effects: Array[AudioEffect]) -> StringName:
		var result := super.effect_bus(effects)
		queue_free()
		return result

var assertions := 0
var failures: Array[String] = []
var prefixes: Array[String] = []

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < .000001, message)

func _ready() -> void:
	_run.call_deferred()

func _source_programs() -> void:
	var reference: Dictionary = Content.read_json("res://data/audio_manager/fixtures.json")
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	_check(reference.source.formatVersion == 1, "Load the original isolated manager programs")
	for path: String in reference.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == reference.source.inputs[path], "Manager reference producer is current: " + path)
	for path: String in reference.source.sourceInputs:
		_check(provenance.inputs[path] == reference.source.sourceInputs[path], "The isolated audio module matches imported runtime metadata")
	if not failures.is_empty():
		return
	for program: Dictionary in reference.audioGates:
		var budget := AudioVoiceBudget.new()
		budget.configure(Content.balance.audio)
		for frame: Dictionary in program.frames:
			budget.active = int(frame.active)
			_check(budget.allow(frame.id, frame.now) == not frame.result.is_empty(), "Preserve original strict deduplication and voice-cap gates")
			Helper.compare(self, budget.last, frame.last, "A cap rejection retains the original deduplication timestamp")
	for fixture: Dictionary in reference.audioCounts:
		var budget := AudioVoiceBudget.new()
		budget.configure(Content.balance.audio)
		budget.reserve(fixture.duration, 10)
		_check(budget.active == int(fixture.during), "Reserve the original source voice count")
		budget.advance(10 + float(fixture.delay) / 1000 - .000001)
		_check(budget.active == int(fixture.during), "Retain the original wall-clock release grace")
		budget.advance(10 + float(fixture.delay) / 1000 + .000001)
		_check(budget.active == int(fixture.after), "Release the original independent wall deadline")
	for program: Dictionary in reference.audioSamples:
		var budget := AudioVoiceBudget.new()
		budget.configure(Content.balance.audio)
		for frame: Dictionary in program.frames:
			var cursor := {"value": 0}
			var choice := budget.sample_choice("sample", program.durations, func():
				var value := float(frame.rolls[cursor.value])
				cursor.value += 1
				return value)
			Helper.compare(self, choice, {"index": frame.index, "rate": frame.rate, "duration": frame.duration}, "Preserve original sample selection, jitter and counted duration")
			_check(cursor.value == int(frame.draws), "Preserve the exact private random draw budget")

func _manager(value: Manager = null) -> Manager:
	var manager: Manager = value if value != null else Manager.new()
	add_child(manager)
	_check(manager.configure(Content.balance.audio) == OK, "Configure a native manager without starting BGM or movement")
	prefixes.append("SVS_%d_" % manager.buses.get_instance_id())
	AudioServer.set_bus_mute(AudioServer.get_bus_index(manager.buses.sfx), true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(manager.buses.bgm), true)
	# Exercise an already-unlocked context without changing gesture or driver policy.
	manager.unlocked = true
	manager.random.seed = 1234
	var wave := AudioStreamWAV.new()
	wave.mix_rate = 48000
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	var pcm := PackedByteArray()
	pcm.resize(96000)
	wave.data = pcm
	var clip := NativeAudioClip.new()
	clip.source = {"layer": "sample"}
	clip.panned.append(wave)
	manager.samples.buffers.ui_click = [clip]
	manager.samples.loaded = true
	return manager

func _normal() -> void:
	var manager := _manager()
	manager._play("ui_click", .5, .25)
	var voice: AudioVoice = manager.get_children().filter(func(child): return child is AudioVoice)[0]
	_check(voice.players[0].playing and manager.draws == 1 and manager.budget.active == 1,
		"A live native sample plays, consumes one random draw and reserves one source voice")
	_check(voice.sample_mixer != null and manager.buses.sample_worker.thread.is_started(),
		"The native manager admits imported samples through its shared streaming worker")
	manager._play("ui_click", .5, .25)
	_check(manager.created == 1 and manager.draws == 1 and manager.budget.active == 1, "Source deduplication precedes allocation and private randomness")
	var notifications := {"count": 0}
	manager.buses.retiring.connect(func(): notifications.count += 1)
	manager._retire()
	manager.buses.retire()
	_check(notifications.count == 1, "Repeated context retirement emits one terminal notification")
	_check(manager.disposed and not manager.configured and manager.buses.disposed and manager.music.retired
		and manager.ambience.retired and manager.movement.state.disposed and not voice.players[0].playing,
		"Terminal manager retirement closes every native consumer and route")
	_check(not manager.buses.sample_worker.thread.is_started() and voice.sample_mixer.stats().stopped,
		"Manager retirement joins sample feeding before destroying native routes")
	var last := manager.budget.last.duplicate()
	manager._play("late", .5, 0)
	manager.ui("unknown")
	_check(manager.created == 1 and manager.draws == 1 and manager.budget.last == last,
		"Late public and internal playback cannot mutate a retired budget")
	manager.free()

func _sample_failures() -> void:
	for refuse_start: bool in [true, false]:
		var manager := _manager(RejectedManager.new()) as RejectedManager
		var worker := RefusingSampleWorker.new()
		worker.refuse_start = refuse_start
		manager.buses.sample_worker = worker
		manager._play("ui_click", .5, 0)
		_check(manager.draws == 1 and manager.budget.active == 0 and worker.count() == 0,
			"Failed sample worker admission retains the consumed source draw without reserving a voice")
		_check(manager.rejected == [{"operation": "start_voice", "error": ERR_UNCONFIGURED}]
			and manager.get_children().all(func(child): return not child is AudioVoice),
			"Worker startup and queue rejection retire every partially admitted native player")
		manager.free()
		_check(not worker.thread.is_started(), "Rejected sample contexts cannot retain idle worker threads")
	var manager := _manager(RejectedManager.new()) as RejectedManager
	manager._play("ui_click", .5, 0)
	var voice: AudioVoice = manager.get_children().filter(func(child): return child is AudioVoice)[0]
	var mixer: RefCounted = voice.sample_mixer
	# Deliberately stop only the producer. Native playback must expose a real
	# underrun and propagate it through the normal deferred owner failure path.
	manager.buses.sample_worker.stop()
	var deadline := Time.get_ticks_msec() + 3000
	while mixer.stats().skips.all(func(value): return value == 0) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02, true, false, true).timeout
	_check(mixer.stats().skips.any(func(value): return value > 0), "The fault program reaches a real native generator underrun: " + JSON.stringify(mixer.stats()))
	_check(mixer.pump() == -1, "A starved sample rejects further producer work")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(voice) and manager.rejected == [{"operation": "sample_buffer_underrun", "error": ERR_CANT_CREATE}],
		"Asynchronous sample failure retires the voice and reaches the manager exactly once")
	_check(manager.draws == 1 and manager.budget.active == 1,
		"Native playback failure cannot refund or redraw the original source reservation")
	manager.free()

func _queued() -> void:
	for target: String in ["manager", "routing"]:
		var manager := _manager()
		if target == "manager":
			manager.queue_free()
		else:
			manager.buses.queue_free()
		manager._play("ui_click", .5, 0)
		manager.ui("click")
		_check(manager.created == 0 and manager.draws == 0 and manager.budget.last.is_empty(),
			"Queued " + target + " retirement rejects playback before deduplication and allocation")
		manager.free()

func _admissions() -> void:
	var factory := _manager()
	factory.before_admission = factory._retire
	factory._play("ui_click", .5, 0)
	_check(factory.created == 1 and factory.draws == 0 and factory.budget.active == 0,
		"Retirement during voice construction prevents admission, randomness and reservation")
	factory.free()
	for mode: String in ["queue", "detach", "routing", "voice"]:
		var manager := _manager()
		var interrupted := func(child):
			match mode:
				"queue": manager.queue_free()
				"detach": remove_child(manager)
				"routing": manager.buses.retire()
				"voice": child.queue_free()
		manager.child_entered_tree.connect(interrupted, CONNECT_ONE_SHOT)
		manager._play("ui_click", .5, 0)
		_check(manager.created == 1 and manager.draws == 0 and manager.budget.active == 0,
			mode + ": reentrant child admission cannot consume a take or reserve a voice")
		manager.free()
	for synthesized: bool in [false, true]:
		var manager := _manager()
		manager.low_power = synthesized
		manager.player_admission = manager._retire
		manager._play("ui_click", .5, 0)
		_check(manager.disposed and manager.budget.active == 0 and manager.draws == (0 if synthesized else 1),
			"Native player admission retirement cannot reserve a partially started sample or synthesis")
		manager.free()

func _loading() -> void:
	var manager := _manager()
	manager.unlocked = false
	var loading := LoadingSamples.new()
	loading.callback = manager._retire
	manager.samples = loading
	manager.unlock()
	_check(manager.disposed and not manager.unlocked and not manager.music.state.unlocked
		and not manager.ambience.state.unlocked and not manager.movement.state.unlocked,
		"Synchronous sample-load retirement cannot continue unlocking later consumers")
	manager.free()

func _player_admissions() -> void:
	for synthesized: bool in [false, true]:
		var manager := _manager(RejectedManager.new()) as RejectedManager
		manager.low_power = synthesized
		manager.child_entered_tree.connect(func(voice: Node):
			voice.child_entered_tree.connect(func(player: Node): player.queue_free(), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
		manager._play("ui_click", .5, 0)
		_check(manager.budget.active == 0 and manager.get_children().all(func(child): return not child is AudioVoice),
			"Queued native player admission cannot reserve or retain a failed voice")
		_check(manager.rejected == [{"operation": "start_voice", "error": ERR_UNCONFIGURED}],
			"Sample and synthesis report rejected native player admission")
		_check(manager.draws == (0 if synthesized else 1), "Cancelled player admission preserves the already-consumed source draw budget")
		manager.free()
	for synthesized: bool in [false, true]:
		for mode: String in ["current", "earlier", "routing"]:
			var manager := _manager()
			var wave: AudioStreamWAV = manager.samples.buffers.ui_click[0].panned[0]
			var clip := _multi_clip(wave)
			var voice := AudioVoice.new()
			manager.add_child(voice)
			var admitted: Array[Node] = []
			voice.child_entered_tree.connect(func(player: Node):
				admitted.append(player)
				if mode == "current":
					player.queue_free()
				elif mode == "routing":
					manager.buses.queue_free()
				elif admitted.size() == 2:
					admitted[0].queue_free())
			var error: Error
			if synthesized:
				var stems: Array[Dictionary] = []
				for _index in range(3):
					stems.append({"stream": wave, "gain": 1.0, "route": "panned", "effects": []})
				error = voice.start_synthesis(stems, manager.buses, 0)
			else:
				error = voice.start(clip, manager.buses, 1, 0)
			_check(error == ERR_UNCONFIGURED and voice.disposed, "Retire partial native voice admission: " + mode)
			_check(admitted.size() == (2 if mode == "earlier" else 1), "Stop allocating players after native admission cancellation: " + mode)
			_check(voice.players.all(func(player): return not is_instance_valid(player) or not player.playing),
				"Cancelled sample and synthesis stems never start")
			manager.free()

func _multi_clip(wave: AudioStreamWAV) -> NativeAudioClip:
	var clip := NativeAudioClip.new()
	clip.channel_count = 2
	clip.panned.append_array([wave, wave])
	clip.centered = wave
	return clip

func _player_losses() -> void:
	for mode: String in ["queue", "detach", "free"]:
		var manager := _manager()
		var voice := AudioVoice.new()
		manager.add_child(voice)
		var clip := _multi_clip(manager.samples.buffers.ui_click[0].panned[0])
		_check(voice.start(clip, manager.buses, 1, 0) == OK, "Admit complete native voice before leaf loss")
		var players := voice.players.duplicate()
		var leaf: AudioStreamPlayer = players[0]
		match mode:
			"queue": leaf.queue_free()
			"detach": voice.remove_child(leaf)
			"free": leaf.free()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not is_instance_valid(voice), "Physical player loss retires its voice: " + mode)
		_check(players.all(func(player): return not is_instance_valid(player) or not player.playing),
			"Physical player loss stops every admitted stem: " + mode)
		if is_instance_valid(leaf):
			leaf.free()
		manager.free()

func _routing_admissions() -> void:
	for synthesized: bool in [false, true]:
		var manager := _manager()
		var routing := QueuingRoutes.new()
		add_child(routing)
		_check(routing.configure() == OK, "Configure routing before native admission interruption")
		prefixes.append("SVS_%d_" % routing.get_instance_id())
		var voice := AudioVoice.new()
		manager.add_child(voice)
		var clip: NativeAudioClip = manager.samples.buffers.ui_click[0]
		var error: Error
		if synthesized:
			var stems: Array[Dictionary] = [{"stream": clip.panned[0], "gain": 1.0, "route": "panned", "effects": []}]
			error = voice.start_synthesis(stems, routing, 0)
		else:
			error = voice.start(clip, routing, 1, 0)
		_check(error == ERR_UNCONFIGURED and voice.disposed and voice.players.is_empty(),
			"Routing loss before the first player retires the failed voice immediately")
		_check(not routing.retiring.is_connected(voice.dispose), "Rejected native routing cannot retain a stale retirement observer")
		routing.free()
		manager.free()

func _stem_completion() -> void:
	var manager := _manager()
	var original: AudioStreamWAV = manager.samples.buffers.ui_click[0].panned[0]
	var short := original.duplicate() as AudioStreamWAV
	short.data = original.data.slice(0, 480)
	var tail := original.duplicate() as AudioStreamWAV
	var silence := PackedByteArray()
	silence.resize(960000)
	silence.fill(0)
	tail.data = silence
	var clip := NativeAudioClip.new()
	clip.channel_count = 2
	clip.panned.append_array([short, tail])
	var voice := AudioVoice.new()
	manager.add_child(voice)
	_check(voice.start(clip, manager.buses, 1, 0) == OK, "Admit native stems with different completion times")
	var deadline := Time.get_ticks_msec() + 3000
	while is_instance_valid(voice) and voice.players[0].playing and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.01, true, false, true).timeout
	_check(is_instance_valid(voice) and not voice.disposed and voice.pending == 1 and voice.players[1].playing,
		"Natural short-stem completion preserves the remaining native stem and voice")
	if is_instance_valid(voice):
		voice.dispose()
	manager.free()

func _configuration() -> void:
	var queued := Manager.new()
	add_child(queued)
	queued.queue_free()
	_check(queued.configure(Content.balance.audio) == ERR_UNCONFIGURED and queued.get_child_count() == 0,
		"A queued manager cannot allocate a routing context")
	queued.free()
	for stop_at: int in [1, 2, 3, 4]:
		var manager := Manager.new()
		add_child(manager)
		manager.child_entered_tree.connect(func(_child):
			if manager.get_child_count() == stop_at:
				manager.queue_free())
		_check(manager.configure(Content.balance.audio) == ERR_UNCONFIGURED and manager.disposed
			and manager.get_child_count() == stop_at and manager.buses.disposed,
			"Configuration retirement stops at the admitted child without later allocation")
		prefixes.append("SVS_%d_" % manager.buses.get_instance_id())
		manager.free()

func _remaining_routes() -> Array[StringName]:
	var names: Array[StringName] = []
	for index in range(AudioServer.bus_count):
		var name := AudioServer.get_bus_name(index)
		if prefixes.any(func(prefix): return str(name).begins_with(prefix)):
			names.append(name)
	return names

func _run() -> void:
	_source_programs()
	if failures.is_empty():
		_normal()
		await _sample_failures()
		_queued()
		_admissions()
		_player_admissions()
		_routing_admissions()
		await _player_losses()
		await _stem_completion()
		_loading()
		_configuration()
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 3000
	while not _remaining_routes().is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(.02, true, false, true).timeout
	_check(_remaining_routes().is_empty(), "All interrupted native routing generations drain without orphan buses")
	print("AUDIO_MANAGER_RETIREMENT assertions=", assertions, " failures=", failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
