extends RefCounted

var mutex := Mutex.new()
var thread := Thread.new()
var wake := Semaphore.new()
var pending: Array[RefCounted] = []
var quitting := false
var active_count := 0

func start() -> Error:
	if quitting:
		return ERR_UNCONFIGURED
	if thread.is_started():
		return OK
	return thread.start(_run, Thread.PRIORITY_HIGH)

func add(stream: RefCounted) -> bool:
	mutex.lock()
	var accepted := not quitting and thread.is_started()
	var awaken := accepted and active_count == 0 and pending.is_empty()
	if accepted:
		pending.append(stream)
	mutex.unlock()
	if awaken:
		wake.post()
	return accepted

func stop() -> void:
	mutex.lock()
	quitting = true
	pending.clear()
	mutex.unlock()
	wake.post()
	if thread.is_started():
		thread.wait_to_finish()

func count() -> int:
	mutex.lock()
	var result := active_count + pending.size()
	mutex.unlock()
	return result

func _run() -> void:
	var active: Array[RefCounted] = []
	while true:
		mutex.lock()
		var done := quitting
		active.append_array(pending)
		pending.clear()
		active_count = active.size()
		mutex.unlock()
		if done:
			break
		if active.is_empty():
			wake.wait()
			continue
		var index := 0
		var mixed := false
		while index < active.size():
			# One native refill per voice preserves later admission deadlines.
			var result: int = active[index].pump()
			if result < 0:
				active.remove_at(index)
			else:
				mixed = mixed or result > 0
				index += 1
		if not mixed:
			OS.delay_usec(1000)
	mutex.lock()
	active_count = 0
	mutex.unlock()
