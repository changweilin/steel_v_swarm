class_name BattleAudio
extends Node

signal failed(operation: String, error: Error)

var preferences := AudioPreferences.new()
var rules := AudioRules.new()
var budget := AudioVoiceBudget.new()
var resources := preload("res://scripts/audio_resource_snapshot.gd").new()
var samples := AudioSampleLibrary.new()
var synthesis := AudioSynthesisLibrary.new()
var random := RandomNumberGenerator.new()
var buses: AudioBuses
var music: AudioMusic
var ambience: AudioAmbience
var movement: AudioMove
var configured := false
var unlocked := false
var disposed := false
var low_power := false
var clock_origin_usec := 0
var context_origin := 0.0

func configure(metadata: Dictionary, persist: bool = false, low: bool = false) -> Error:
	if configured or disposed:
		return ERR_ALREADY_IN_USE
	if not _alive():
		return ERR_UNCONFIGURED
	for key: String in ["synthesisIds", "musicTiming", "ambienceTiming", "proceduralMusic", "settings", "samples", "moveGraphs", "moveTiming"]:
		if not metadata.has(key):
			return ERR_INVALID_DATA
	process_mode = Node.PROCESS_MODE_ALWAYS
	low_power = low
	rules.configure(metadata)
	budget.configure(metadata)
	samples.resources = resources
	synthesis.resources = resources
	synthesis.configure(metadata)
	preferences.configure(metadata)
	preferences.persist = persist
	preferences.save_failed.connect(func(error: Error) -> void: _failure("save_preferences", error))
	var preference_error := preferences.load_save()
	if preference_error != OK:
		_failure("load_preferences", preference_error)
	if not _alive():
		_retire()
		return ERR_UNCONFIGURED
	random.randomize()
	buses = AudioBuses.new()
	add_child(buses)
	if not _alive():
		_retire()
		return ERR_UNCONFIGURED
	var error := buses.configure()
	if error != OK:
		_retire()
		return error
	if not _alive() or not buses.available():
		_retire()
		return ERR_UNCONFIGURED
	buses.retiring.connect(_routing_retired, CONNECT_ONE_SHOT)
	music = AudioMusic.new()
	music.resources = resources
	add_child(music)
	if not _alive():
		_retire()
		return ERR_UNCONFIGURED
	error = music.configure(metadata, preferences, buses)
	if error != OK:
		_retire()
		return error
	music.state.low_power = low_power
	music.track_failed.connect(func(_scene: String, failure: Error) -> void: failed.emit("music", failure))
	ambience = AudioAmbience.new()
	add_child(ambience)
	if not _alive():
		_retire()
		return ERR_UNCONFIGURED
	error = ambience.configure(metadata, buses)
	if error != OK:
		_retire()
		return error
	ambience.state.low_power = low_power
	ambience.bed_failed.connect(func(_id: String, failure: Error) -> void: failed.emit("ambience", failure))
	movement = AudioMove.new()
	movement.resources = resources
	add_child(movement)
	if not _alive():
		_retire()
		return ERR_UNCONFIGURED
	error = movement.configure(metadata, buses, low_power)
	if error != OK:
		_retire()
		return error
	movement.failed.connect(func(_category: String, operation: String, failure: Error) -> void: _failure("movement_" + operation, failure))
	configured = true
	return OK

func _input(event: InputEvent) -> void:
	if not configured or disposed:
		return
	if event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed:
		unlock()

func unlock() -> void:
	if not _ready_for_input() or unlocked:
		return
	var effective_gain := VisualPreferences._number(preferences.sfx_volume) if ControlPreferences.truthy(preferences.sfx_on) else 0.0
	if not is_finite(effective_gain) or effective_gain < 0:
		_retire()
		_failure("unlock_volume" if not is_finite(effective_gain) else "unsupported_sfx_polarity", ERR_INVALID_PARAMETER if not is_finite(effective_gain) else ERR_UNAVAILABLE)
		return
	clock_origin_usec = Time.get_ticks_usec()
	context_origin = buses.context_seconds()
	var error := samples.load_samples(low_power)
	if error != OK:
		_failure("load_samples", error)
	if not _ready_for_input():
		return
	music.state.unlock()
	if not _ready_for_input():
		return
	ambience.state.unlocked = true
	movement.unlock(context_origin)
	unlocked = true

func set_scene(name: String) -> void:
	if _ready_for_input():
		music.state.set_scene(name)

func set_low_power(on: bool) -> void:
	if not _ready_for_input():
		return
	low_power = on
	music.state.low_power = on
	ambience.state.low_power = on
	movement.set_low_power(on)
	if not _ready_for_input():
		return
	if not on and unlocked and not samples.loaded:
		var error := samples.load_samples(false)
		if error != OK:
			_failure("load_samples", error)
		if not _ready_for_input():
			return
		music.state.register_current()

func set_ambience(query: Dictionary) -> void:
	if _ready_for_input():
		ambience.set_ambience(query)

func set_move(category: String, gain: float, pan: float = 0, rate: float = 1, wet: float = 0) -> void:
	if _can_play():
		movement.set_move(category, gain, pan, rate, wet)

func stop_move() -> void:
	if _ready_for_input():
		movement.stop_move()

func fire(definition: Variant, slot: String, side: String) -> void:
	if not _can_play():
		return
	var id := rules.fire_id(definition, slot, side)
	if not id.is_empty():
		_play(id, float(rules.rules.ownFire.heavy if slot == "heavy" else rules.rules.ownFire.light), 0)

func on_source_event(event: Dictionary, source_camera: Variant, own_id: Variant) -> void:
	if not _can_play() or not event.has("e"):
		return
	for plan: Dictionary in rules.event_plan(event, source_camera, own_id):
		_play(plan.id, float(plan.gain), float(plan.pan))

func ui(id: String) -> void:
	if not _can_play():
		return
	var plan: Dictionary = rules.rules.ui.get(id, rules.rules.ui.unknown)
	_play(plan.id, float(plan.gain), float(plan.pan))

func _can_play() -> bool:
	return unlocked and _ready_for_input()

func _alive() -> bool:
	return not disposed and is_inside_tree() and not is_queued_for_deletion()

func _ready_for_input() -> bool:
	return configured and _alive() and is_instance_valid(buses) and not buses.is_queued_for_deletion() and buses.available()

func _play(id: String, gain: float, pan: float) -> void:
	if not _can_play():
		return
	if not budget.allow(id, _now(), _wall_now()):
		return
	if not is_finite(gain) or gain < 0 or not is_finite(pan):
		_failure("voice_parameters", ERR_INVALID_PARAMETER)
		return
	var voice := _make_voice()
	if not _can_play():
		voice.free()
		return
	add_child(voice)
	if not _can_play() or voice.disposed or voice.is_queued_for_deletion() or not voice.is_inside_tree():
		voice.free()
		return
	voice.failed.connect(_failure)
	var error: Error
	var duration: float
	if samples.has_sample(id, low_power):
		var takes: Array = samples.buffers[id]
		var durations: Array = takes.map(func(clip: NativeAudioClip) -> float: return clip.duration())
		var choice := budget.sample_choice(id, durations, _sample_random)
		error = voice.start(takes[int(choice.index)], buses, gain, pan, float(choice.rate))
		duration = float(choice.duration)
	else:
		var definition := synthesis.definition(id)
		if not _can_play():
			voice.free()
			return
		if definition == null:
			voice.free()
			if rules.rules.synthesisIds.has(id):
				_failure("load_synthesis", ERR_UNAVAILABLE)
			return
		var stems := synthesis.render(id, gain)
		if not _can_play():
			voice.free()
			return
		error = voice.start_synthesis(stems, buses, pan)
		duration = definition.reservation_seconds
	if not _can_play():
		voice.free()
		return
	if error != OK:
		voice.free()
		_failure("start_voice", error)
		return
	budget.reserve(duration, _wall_now())

func _make_voice() -> AudioVoice:
	return AudioVoice.new()

func _sample_random() -> float:
	# Math.random excludes one; native randf includes both endpoints.
	return float(random.randi()) / 4294967296.0

func _now() -> float:
	return buses.context_seconds() - context_origin if unlocked else 0.0

func _wall_now() -> float:
	return (Time.get_ticks_usec() - clock_origin_usec) / 1000000.0

func _process(_delta: float) -> void:
	if _can_play():
		budget.advance(_wall_now())

func _failure(operation: String, error: Error) -> void:
	push_error("Audio " + operation + ": " + error_string(error))
	failed.emit(operation, error)

func _retire() -> void:
	if disposed:
		return
	disposed = true
	configured = false
	if is_instance_valid(music):
		music._retire()
	if is_instance_valid(ambience):
		ambience._retire()
	if is_instance_valid(movement):
		movement._retire()
	for child: Node in get_children():
		if child is AudioVoice:
			child.dispose()
	if is_instance_valid(buses):
		buses.retire()

func _exit_tree() -> void:
	_retire()

func _routing_retired() -> void:
	_retire()
