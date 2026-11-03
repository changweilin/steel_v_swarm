extends "res://scripts/main.gd"

# Populated full snapshots keep flowing while the authority publishes stamped room
# updates. Delay that grows with match time means control traffic queues behind them.
# The fixed client frame models the measured populated 5-7 FPS headless client, so
# the verdict depends on neither this machine nor the cost of the rolled world.
const CLIENT_FRAME_MILLISECONDS := 170
const PROBES := 12
const PROBE_SECONDS := 2.0
const DEADLINE_SECONDS := 40.0
# ENet retransmits on a slow client spike transiently; unbounded queues far exceed these.
const LATENCY_LIMIT_SECONDS := 4.0
const GROWTH_LIMIT_SECONDS := 1.0

var elapsed := 0.0
var launched_at := 0
var frames := 0
var next_probe := 0.0
var probe_id := 0
var seen_probe := 0
var snapshots := 0
var latencies: Array[float] = []

func _ready() -> void:
	super._ready()
	network_test = false
	if not Session.dedicated:
		Session.lobby_changed.connect(_lobby_changed)
		Session.snapshot_heard.connect(func(): snapshots += 1)

func _process(delta: float) -> void:
	super._process(delta)
	if Session.dedicated or not Session.launch_announced:
		return
	if launched_at == 0:
		launched_at = Time.get_ticks_msec()
	frames += 1
	OS.delay_msec(CLIENT_FRAME_MILLISECONDS)

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	if Session.dedicated:
		if Session.launch_announced and Session.phase == "game" and elapsed >= next_probe:
			next_probe = elapsed + PROBE_SECONDS
			probe_id += 1
			Session.config["lobby_probe"] = [probe_id, Time.get_unix_time_from_system()]
			Session._publish_membership()
		return
	super._physics_process(delta)
	var seconds := (Time.get_ticks_msec() - launched_at) / 1000.0 if launched_at > 0 else 0.0
	if seconds > DEADLINE_SECONDS:
		_fail("NETWORK_LOBBY_LATENCY_TIMEOUT probes=%d latencies=%s" % [latencies.size(), latencies])
		return
	if latencies.size() < PROBES:
		return
	var third: int = PROBES / 3
	var early: float = _mean(latencies.slice(0, third))
	var late: float = _mean(latencies.slice(-third))
	var worst: float = latencies.max()
	var report := "early=%.3f late=%.3f max=%.3f snapshots=%d frames=%d seconds=%.1f latencies=%s" % [early, late, worst, snapshots, frames, seconds, latencies]
	if worst > LATENCY_LIMIT_SECONDS or late - early > GROWTH_LIMIT_SECONDS:
		_fail("NETWORK_LOBBY_LATENCY_GROWTH " + report)
		return
	print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
	print("NETWORK_LOBBY_LATENCY_PASS ", report)
	Session.stop()
	get_tree().quit()

func _lobby_changed() -> void:
	var probe: Variant = Session.config.get("lobby_probe")
	if not probe is Array or not Session.launch_announced or int(probe[0]) <= seen_probe:
		return
	seen_probe = int(probe[0])
	latencies.append(Time.get_unix_time_from_system() - float(probe[1]))

func _mean(values: Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / values.size()

func _fail(reason: String) -> void:
	push_error(reason)
	get_tree().quit(1)
