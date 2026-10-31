extends RefCounted

signal finished
signal failed(operation: String, error: Error)

var mutex := Mutex.new()
var inputs: Array[Dictionary] = []
var source_frames := 0
var step := 0.0
var position := 0.0
var generated := 0
var body_frames := -1
var primed_frames := 0
var clock: AudioEffectCapture
var origin := 0
var armed := false
var stopping := false
var announced := false
var failure := ""
var last_service_usec := 0
var max_service_gap_usec := 0
var max_pump_usec := 0

static func prepare(source: AudioStreamWAV, rate: float) -> Dictionary:
	if source == null or source.stereo or source.loop_mode != AudioStreamWAV.LOOP_DISABLED \
		or source.format != AudioStreamWAV.FORMAT_16_BITS or not is_finite(rate) or rate <= 0:
		return {}
	var bytes := source.data
	if bytes.is_empty() or bytes.size() % 2 != 0:
		return {}
	# AudioParam stores Float32; the source budget retains the original double.
	var parameter := PackedFloat32Array([rate])[0]
	var increment := parameter * (float(source.mix_rate) / AudioServer.get_mix_rate())
	if not is_finite(increment) or increment <= 0:
		return {}
	var stream := AudioGeneratorFeed.new()
	stream.configure(AudioServer.get_mix_rate())
	return {"stream": stream, "gain": 1.0, "rate": 1.0, "bytes": bytes,
		"frames": bytes.size() / 2, "step": increment, "playback": stream.playback,
		"capacity": stream.playback.get_frames_available()}

func append(input: Dictionary) -> bool:
	if armed or stopping or not inputs.is_empty() and (source_frames != int(input.frames) or step != float(input.step)):
		return false
	source_frames = int(input.frames)
	step = float(input.step)
	inputs.append(input)
	return true

func prime(frames: int) -> bool:
	if inputs.is_empty() or generated != 0 or armed or stopping:
		return false
	for input: Dictionary in inputs:
		frames = mini(frames, input.playback.get_frames_available())
	if frames <= 0 or not _render(frames):
		return false
	primed_frames = frames
	return true

func arm(capture: AudioEffectCapture, start_frame: int) -> void:
	mutex.lock()
	clock = capture
	origin = start_frame
	armed = true
	last_service_usec = Time.get_ticks_usec()
	mutex.unlock()

func stop() -> void:
	mutex.lock()
	stopping = true
	mutex.unlock()

func stats() -> Dictionary:
	mutex.lock()
	var skips: Array[int] = []
	for input: Dictionary in inputs:
		skips.append(input.playback.get_skips())
	var result := {"generated": generated, "bodyFrames": body_frames, "primedFrames": primed_frames,
		"stopped": stopping, "finished": announced, "failure": failure, "skips": skips,
		"maxServiceGapUsec": max_service_gap_usec, "maxPumpUsec": max_pump_usec}
	mutex.unlock()
	return result

func pump() -> int:
	mutex.lock()
	var was_announced := announced
	var old_failure := failure
	var before := Time.get_ticks_usec()
	var result := _pump()
	max_pump_usec = maxi(max_pump_usec, Time.get_ticks_usec() - before)
	var completed := announced and not was_announced
	var fault := failure if old_failure.is_empty() else ""
	mutex.unlock()
	# Never invoke callbacks while holding the producer lock.
	if completed:
		finished.emit()
	if not fault.is_empty():
		failed.emit(fault, ERR_CANT_CREATE)
	return result

func _pump() -> int:
	if stopping:
		return -1
	if not armed:
		return 0
	var now := Time.get_ticks_usec()
	max_service_gap_usec = maxi(max_service_gap_usec, now - last_service_usec)
	last_service_usec = now
	var available := AudioGeneratorFeed.REFILL_FRAMES
	for input: Dictionary in inputs:
		if input.playback.get_skips() > 0:
			failure = "sample_buffer_underrun"
			stopping = true
			return -1
		available = mini(available, input.playback.get_frames_available())
	var played := clock.get_pushed_frames() + clock.get_discarded_frames() - origin
	if body_frames >= 0 and not announced and played >= body_frames + AudioGeneratorFeed.input_latency_frames(true):
		announced = true
	# A UI stall must not starve generators whose source audio has finished.
	if available < AudioGeneratorFeed.REFILL_FRAMES:
		return 0
	if not _render(AudioGeneratorFeed.REFILL_FRAMES):
		failure = "sample_buffer_push"
		stopping = true
		return -1
	return 1

func _render(frames: int) -> bool:
	var final_position := position
	for input: Dictionary in inputs:
		var output := PackedVector2Array()
		output.resize(frames)
		var cursor := position
		var bytes: PackedByteArray = input.bytes
		for frame in range(frames):
			if cursor >= source_frames:
				break
			var index := int(cursor)
			var fraction := cursor - index
			var first := float(bytes.decode_s16(index * 2)) / 32768.0
			var value: float
			if index == source_frames - 1 and index > 0:
				var previous := float(bytes.decode_s16((index - 1) * 2)) / 32768.0
				value = first + (first - previous) * fraction
			else:
				var second := float(bytes.decode_s16(mini(index + 1, source_frames - 1) * 2)) / 32768.0
				value = (1.0 - fraction) * first + fraction * second
			# AudioBufferSource interpolates in double, then stores Float32.
			output[frame] = Vector2(value, value)
			cursor += step
			if cursor >= source_frames and body_frames < 0:
				body_frames = generated + frame + 1
		if not input.playback.push_buffer(output):
			return false
		final_position = cursor
	position = final_position
	generated += frames
	return true
