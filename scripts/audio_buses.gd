class_name AudioBuses
extends Node

signal retiring

var sfx: StringName
var bgm: StringName
var owned: Array[StringName] = []
var serial := 0
var configured := false
var disposed := false
var clock_capture: AudioEffectCapture
var clock_rate := 0.0
var capture_sink: StringName
var sample_worker := preload("res://scripts/audio_sample_worker.gd").new()

func configure() -> Error:
	if configured or disposed:
		return ERR_ALREADY_IN_USE
	if not is_inside_tree():
		return ERR_UNCONFIGURED
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx = _create_bus("SFX", &"Master")
	bgm = _create_bus("BGM", &"Master")
	clock_rate = AudioServer.get_mix_rate()
	clock_capture = AudioEffectCapture.new()
	clock_capture.buffer_length = .01
	AudioServer.add_bus_effect(AudioServer.get_bus_index(sfx), clock_capture)
	configured = true
	return OK

func context_seconds() -> float:
	if clock_capture == null or clock_rate <= 0:
		return 0
	# Counting discarded frames keeps time advancing without retaining additional PCM.
	return float(clock_capture.get_pushed_frames() + clock_capture.get_discarded_frames()) / clock_rate

func capture_bus(effects: Array[AudioEffect]) -> StringName:
	if not available():
		return &""
	if capture_sink == &"":
		capture_sink = _create_bus("CaptureSink", &"Master")
		AudioServer.set_bus_mute(AudioServer.get_bus_index(capture_sink), true)
	serial += 1
	var bus_name := _create_bus("Capture_%d" % serial, capture_sink)
	for effect: AudioEffect in effects:
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), effect)
	return bus_name

func available() -> bool:
	return configured and not disposed and is_inside_tree() and AudioServer.get_bus_index(sfx) > 0 and AudioServer.get_bus_index(bgm) > 0

func _create_bus(suffix: String, parent: StringName) -> StringName:
	var bus_name := StringName("SVS_%d_%s" % [get_instance_id(), suffix])
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, str(bus_name))
	AudioServer.set_bus_send(index, parent)
	AudioServer.set_bus_volume_linear(index, 1.0)
	bus_name = AudioServer.get_bus_name(index)
	owned.append(bus_name)
	return bus_name

func set_sfx_gain(gain: float) -> Error:
	if not available():
		return ERR_UNCONFIGURED
	if not is_finite(gain) or gain < 0:
		push_error("Audio SFX gain must be finite and nonnegative")
		return ERR_INVALID_PARAMETER
	var index := AudioServer.get_bus_index(sfx)
	if index < 0:
		return ERR_UNCONFIGURED
	AudioServer.set_bus_volume_linear(index, gain)
	return OK

func voice_bus(pan: float) -> StringName:
	var effect := AudioEffectPanner.new()
	effect.pan = pan
	return effect_bus([effect])

func effect_bus(effects: Array[AudioEffect]) -> StringName:
	if not available():
		push_error("Audio voice routing requires active channel buses")
		return &""
	serial += 1
	var bus_name := _create_bus("Voice_%d" % serial, sfx)
	for effect: AudioEffect in effects:
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), effect)
	return bus_name

func release_voice(bus_name: StringName) -> void:
	if bus_name == sfx or bus_name == bgm or not owned.has(bus_name):
		return
	owned.erase(bus_name)
	_retire(get_tree(), [bus_name])

static func _mix_interval() -> Dictionary:
	var before := Time.get_ticks_usec() / 1000000.0
	var since := AudioServer.get_time_since_last_mix()
	var after := Time.get_ticks_usec() / 1000000.0
	return {"earliest": before - since, "latest": after - since}

static func _retire(tree: SceneTree, names: Array[StringName]) -> void:
	for bus_name: StringName in names:
		var index := AudioServer.get_bus_index(bus_name)
		if index > 0:
			AudioServer.set_bus_mute(index, true)
	# stop() requests a mixer fade-out. Retain its routes until two later mixes.
	# Bracket the mix timestamp so a delayed main-thread query cannot fake progress.
	var previous := _mix_interval()
	var completed := 0
	while completed < 2:
		await tree.create_timer(.02, true, false, true).timeout
		var current := _mix_interval()
		if float(current.earliest) > float(previous.latest) + .000002:
			completed += 1
			previous = current
	for bus_name: StringName in names:
		var index := AudioServer.get_bus_index(bus_name)
		if index > 0:
			AudioServer.remove_bus(index)

func retire() -> void:
	if disposed:
		return
	disposed = true
	retiring.emit()
	sample_worker.stop()
	var names: Array[StringName] = owned.duplicate()
	owned.clear()
	if not names.is_empty():
		_retire(get_tree(), names)

func _exit_tree() -> void:
	retire()
