class_name RoomSnapshotWindow
extends RefCounted

# Full snapshots a client has not acknowledged. Two preserve the 8 Hz cadence across
# one tick of round-trip delay. A slower client receives fewer, fresher states, and
# reliable control traffic queues behind at most this many.
const MAXIMUM_UNACKNOWLEDGED := 2
# A stalled client keeps only its newest reports so one catch-up snapshot stays
# bounded. Older reports are lost to that client; authoritative state is not.
const MAXIMUM_HELD_EVENTS := 512

var unacknowledged: Dictionary = {}
var held: Dictionary = {}

func is_full(peer: int) -> bool:
	return unacknowledged.get(peer, []).size() >= MAXIMUM_UNACKNOWLEDGED

func is_held(peer: int) -> bool:
	return held.has(peer)

func hold(peer: int, events: Array) -> void:
	var kept: Array = held.get(peer, [])
	kept.append_array(events)
	held[peer] = kept.slice(-MAXIMUM_HELD_EVENTS)

func release(peer: int) -> Array:
	var kept: Array = held.get(peer, [])
	held.erase(peer)
	return kept

func sent(peer: int, serial: int) -> void:
	if not unacknowledged.has(peer):
		unacknowledged[peer] = []
	unacknowledged[peer].append(serial)

# Cumulative: reliable ordering means an acknowledgement covers every earlier serial.
func acknowledge(peer: int, serial: int) -> void:
	var serials: Array = unacknowledged.get(peer, [])
	while not serials.is_empty() and int(serials[0]) <= serial:
		serials.pop_front()

func forget(peer: int) -> void:
	unacknowledged.erase(peer)
	held.erase(peer)

func clear() -> void:
	unacknowledged.clear()
	held.clear()
