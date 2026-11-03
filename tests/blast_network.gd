extends "res://scripts/main.gd"

# Controlled source camera/height inputs isolate delivery from map de-clipping.
class FeedbackSimulation extends BattleSimulation:
	func camera_origin(unit: BattleUnit) -> Vector3:
		return unit.position + Vector3.UP * unit.height * .5
	func _recoil_next() -> float:
		return .5

var elapsed := 0.0
var fixture_peer := 0
var phase := 0
var requested := false
var expected_serial := -1
var local_report: Dictionary = {}
var global_report: Dictionary = {}
var reference: Dictionary = {}
var frozen_resources: Array = []
var expected_velocity := Vector3.ZERO
var expected_impulse := Vector2.ZERO

func _ready() -> void:
	super._ready()
	network_test = false

func _create_simulation() -> BattleSimulation:
	return FeedbackSimulation.new()

func _physics_process(delta: float) -> void:
	if Session.launch_announced:
		elapsed += delta
	# The client launches after the authority and owns this deadline.
	if not Session.dedicated and elapsed > 18:
		_fail("NETWORK_BLAST_TIMEOUT phase=%d" % phase)
		return
	if simulation == null or not Session.launch_announced:
		return
	if Session.dedicated:
		if fixture_peer == 0:
			for unit: BattleUnit in simulation.pilots.values():
				if unit.peer_id > 1:
					fixture_peer = unit.peer_id
					simulation.set_physics_process(false)
		return
	super._physics_process(delta)
	var pilot: BattleUnit = simulation.pilots.get(Session.player_id())
	if pilot == null or not view_ready:
		return
	if not requested:
		requested = true
		_start_fixture.rpc_id(1)
	if expected_serial < 0 or pilot.blast_received_serial < expected_serial:
		return
	if not simulation.presented_blast_serials.has("local") or int(simulation.presented_blast_serials.get("global", -1)) < expected_serial:
		return
	var expected: Dictionary = reference.steps[1]
	var velocity := Vector3(expected.velocity[0], expected.velocity[1] if reference.flying else expected.lift, expected.velocity[2])
	if pilot.velocity.distance_to(velocity) > .0002 or absf(pilot.recoil.trauma - float(expected.trauma)) > .000001:
		_fail("Transported owner velocity/trauma differs from the original two-stage blast sequence")
		return
	var effects := simulation.world.combat_effects.effects.size()
	var trauma := pilot.recoil.trauma
	var before := pilot.velocity
	simulation.receive_body_events([local_report], simulation.presentation_time())
	simulation.present_world_events([local_report, global_report])
	if simulation.world.combat_effects.effects.size() != effects or pilot.recoil.trauma != trauma or pilot.velocity != before:
		_fail("RPC/snapshot replay renewed a blast, impulse or camera trauma")
		return
	expected_serial = -1
	_verify_fixture.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _start_fixture() -> void:
	if not Session.dedicated or fixture_peer == 0 or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer:
		return
	_emit_fixture()

func _emit_fixture() -> void:
	var pilot: BattleUnit = simulation.pilots[fixture_peer]
	pilot.height = 16
	pilot.position.x = floorf(pilot.position.x)
	pilot.position.y = ceilf(pilot.position.y)
	pilot.flying = phase == 1
	pilot.velocity = Vector3.ZERO
	pilot.impulse_velocity = Vector2.ZERO
	pilot.recoil.clear_active()
	pilot.recoil.trauma = 0
	var fixtures: Dictionary = Content.read_json("res://data/fixtures.json", ["blastFeedbackSequences"])
	reference = fixtures.blastFeedbackSequences.filter(func(item): return bool(item.flying) == pilot.flying)[0]
	var point := pilot.position + Vector3.UP * pilot.height * .5 + Vector3.RIGHT
	frozen_resources = _resources(pilot)
	simulation._publish_local_blast(pilot, point, float(reference.radius))
	var local: Dictionary = simulation.events.back()
	simulation._publish_blast_event({"type": "boom", "actor": pilot.entity_id, "position": point, "radius": float(reference.radius), "side": pilot.side})
	var global: Dictionary = simulation.events.back()
	var expected: Dictionary = reference.steps[1]
	expected_velocity = Vector3(expected.velocity[0], expected.velocity[1] if pilot.flying else expected.lift, expected.velocity[2])
	expected_impulse = Vector2.ZERO if pilot.flying else Vector2(expected.velocity[0], expected.velocity[2])
	_expect_fixture.rpc_id(Session.seats.transport_for(fixture_peer), reference, local, global)

@rpc("authority", "call_remote", "reliable")
func _expect_fixture(source: Dictionary, local: Dictionary, global: Dictionary) -> void:
	reference = source
	local_report = local
	global_report = global
	expected_serial = int(global.blast_serial)

@rpc("any_peer", "call_remote", "reliable")
func _verify_fixture() -> void:
	if not Session.dedicated or fixture_peer == 0 or Session.seats.player_for(multiplayer.get_remote_sender_id()) != fixture_peer:
		return
	var pilot: BattleUnit = simulation.pilots[fixture_peer]
	if _resources(pilot) != frozen_resources or pilot.velocity.distance_to(expected_velocity) > .0002 or pilot.impulse_velocity.distance_to(expected_impulse) > .0002:
		_fail("Blast publication changed resources/RNG or repeated the authority impulse")
		return
	if phase == 0:
		phase = 1
		_emit_fixture()
	else:
		_finish_fixture.rpc_id(Session.seats.transport_for(fixture_peer))

@rpc("authority", "call_remote", "reliable")
func _finish_fixture() -> void:
	print("NETWORK_PASS peer=", Session.player_id(), " units=", simulation.units.size())
	print("NETWORK_BLAST_PASS source=true ground=true air=true immediate=true publication=true recoil=true replay=true resources=true")
	Session.stop()
	get_tree().quit()

func _resources(pilot: BattleUnit) -> Array:
	return [pilot.hp, pilot.shield, pilot.power, pilot.money, pilot.ammo.duplicate(true), simulation.clock, simulation.rng.state, simulation.projectile_rng.state]

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
