class_name AudioVoice
extends Node

const PcmGain = preload("res://scripts/audio_pcm_gain.gd")
const SampleStream = preload("res://scripts/audio_sample_stream.gd")

signal failed(operation: String, error: Error)

var buses: AudioBuses
var players: Array[AudioStreamPlayer] = []
var routes: Array[StringName] = []
var pending := 0
var disposed := false
var sample_mixer: RefCounted

func start(clip: NativeAudioClip, routing: AudioBuses, gain: float, pan: float, rate: float = 1) -> Error:
	if not players.is_empty() or disposed:
		return ERR_ALREADY_IN_USE
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(routing) or routing.is_queued_for_deletion() or not routing.available():
		return ERR_UNCONFIGURED
	if clip == null or not clip.valid() or not is_finite(gain) or gain < 0 or not is_finite(pan) or not is_finite(rate) or rate <= 0:
		return ERR_INVALID_PARAMETER
	if clip.source.get("layer") == "sample":
		if clip.centered != null or clip.channel_count not in [1, 2]:
			return ERR_UNAVAILABLE
		sample_mixer = SampleStream.new()
		sample_mixer.finished.connect(dispose, CONNECT_DEFERRED)
		sample_mixer.failed.connect(_sample_failed, CONNECT_DEFERRED)
	buses = routing
	buses.retiring.connect(dispose, CONNECT_ONE_SHOT)
	var matrix: Array[Dictionary] = AudioPan.routes(pan, clip.channel_count) if clip.channel_count > 0 else []
	for index in range(clip.panned.size()):
		var bus := buses.voice_bus(float(matrix[index].pan))
		if bus == &"" or not _active():
			if bus != &"" and is_instance_valid(buses):
				buses.release_voice(bus)
			dispose()
			return ERR_UNCONFIGURED
		routes.append(bus)
		var normalization := clip.panned_gains[index] if not clip.panned_gains.is_empty() else 1.0
		var prepared := SampleStream.prepare(clip.panned[index], rate) if clip.source.get("layer") == "sample" \
			else {"stream": clip.panned[index], "gain": 1.0, "rate": rate}
		if prepared.is_empty() or sample_mixer != null and not sample_mixer.append(prepared):
			dispose()
			return ERR_UNAVAILABLE
		if not _player(prepared.stream, bus, gain * float(matrix[index].gain) * normalization * float(prepared.gain), float(prepared.rate)):
			return ERR_UNCONFIGURED
	if clip.centered != null:
		var prepared := SampleStream.prepare(clip.centered, rate) if clip.source.get("layer") == "sample" \
			else {"stream": clip.centered, "gain": 1.0, "rate": rate}
		if prepared.is_empty():
			dispose()
			return ERR_UNAVAILABLE
		if not _player(prepared.stream, buses.sfx, gain * clip.centered_gain * float(prepared.gain), float(prepared.rate)):
			return ERR_UNCONFIGURED
	return OK if _play() else ERR_UNCONFIGURED

func start_synthesis(stems: Array[Dictionary], routing: AudioBuses, pan: float) -> Error:
	if not players.is_empty() or disposed:
		return ERR_ALREADY_IN_USE
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(routing) or routing.is_queued_for_deletion() or not routing.available():
		return ERR_UNCONFIGURED
	if stems.is_empty() or not is_finite(pan):
		return ERR_INVALID_PARAMETER
	var prepared: Array[Dictionary] = []
	for stem: Dictionary in stems:
		var stream: AudioStreamWAV = stem.get("stream") as AudioStreamWAV
		if stream == null or stream.stereo or stream.get_length() <= 0 or stem.get("route") not in ["panned", "centered"] or not is_finite(float(stem.get("gain", NAN))) or float(stem.gain) < 0:
			return ERR_INVALID_DATA
		var effects: Array[AudioEffect] = []
		var correction := 1.0
		for captured: Dictionary in stem.effects:
			var effect := AudioSourceFilter.create(captured)
			if effect == null:
				return ERR_UNAVAILABLE
			effects.append(effect)
			correction *= AudioSourceFilter.gain_correction(captured)
		var normalization := float(stem.gain) * correction
		if stem.route == "panned":
			var matrix: Dictionary = AudioPan.routes(pan, 1)[0]
			var panner := AudioEffectPanner.new()
			panner.pan = matrix.pan
			effects.append(panner)
			normalization *= float(matrix.gain)
		prepared.append({"stream": stream, "gain": normalization, "effects": effects})
	buses = routing
	buses.retiring.connect(dispose, CONNECT_ONE_SHOT)
	for stem: Dictionary in prepared:
		var bus := buses.sfx
		if not stem.effects.is_empty():
			bus = buses.effect_bus(stem.effects)
			if bus == &"" or not _active():
				if bus != &"" and is_instance_valid(buses):
					buses.release_voice(bus)
				dispose()
				return ERR_UNCONFIGURED
			routes.append(bus)
		if not _player(stem.stream, bus, stem.gain, 1):
			return ERR_UNCONFIGURED
	return OK if _play() else ERR_UNCONFIGURED

func _play() -> bool:
	if not _active():
		dispose()
		return false
	if sample_mixer != null:
		var interval := AudioServer.get_time_to_next_mix() + AudioServer.get_time_since_last_mix()
		var frames := AudioGeneratorFeed.startup_frames(interval, AudioServer.get_mix_rate())
		if not sample_mixer.prime(frames) or buses.sample_worker.start() != OK:
			dispose()
			return false
	pending = players.size()
	# Native WAV starts do not lock the driver; submit all stems in one mix boundary.
	AudioServer.lock()
	if sample_mixer != null:
		sample_mixer.arm(buses.clock_capture, buses.clock_capture.get_pushed_frames() + buses.clock_capture.get_discarded_frames())
	for player: AudioStreamPlayer in players:
		player.play()
	AudioServer.unlock()
	if sample_mixer != null and not buses.sample_worker.add(sample_mixer):
		dispose()
		return false
	return true

func _sample_failed(operation: String, error: Error) -> void:
	if disposed:
		return
	dispose()
	failed.emit(operation, error)

func _active() -> bool:
	if disposed or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(buses) or buses.is_queued_for_deletion() or not buses.available():
		return false
	for player: AudioStreamPlayer in players:
		if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree() or player.get_parent() != self:
			return false
	return true

func _player(stream: AudioStream, bus: StringName, gain: float, rate: float) -> bool:
	if not _active():
		return false
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	player.bus = bus
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_linear = PcmGain.native_gain(stream, gain)
	player.pitch_scale = rate
	player.finished.connect(_finished)
	player.tree_exiting.connect(dispose, CONNECT_ONE_SHOT)
	players.append(player)
	add_child(player)
	if not _active():
		dispose()
		return false
	return true

func _finished() -> void:
	if disposed:
		return
	pending -= 1
	if pending == 0:
		dispose()

func dispose() -> void:
	if disposed:
		return
	disposed = true
	if sample_mixer != null:
		sample_mixer.stop()
	if is_instance_valid(buses) and buses.retiring.is_connected(dispose):
		buses.retiring.disconnect(dispose)
	for player: AudioStreamPlayer in players:
		if is_instance_valid(player):
			player.stop()
	queue_free()

func _exit_tree() -> void:
	disposed = true
	if sample_mixer != null:
		sample_mixer.stop()
	if is_instance_valid(buses) and buses.retiring.is_connected(dispose):
		buses.retiring.disconnect(dispose)
	for player: AudioStreamPlayer in players:
		if is_instance_valid(player):
			player.stop()
	if is_instance_valid(buses):
		for name: StringName in routes:
			buses.release_voice(name)
	routes.clear()
