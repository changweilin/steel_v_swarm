class_name PetalPresentation
extends RefCounted

const BindingLifetime = preload("res://scripts/scenery_binding_lifetime.gd")

var profile: Dictionary = {}
var parts: Array = []
var meshes: Dictionary = {}
var motion := PetalMotion.new()
var probe: Callable
var code_at: Callable
var time := 0.0
var source_root: Node3D
var retired := false
var ready := false
var generation := 0
var revision := 0
var lifetime: BindingLifetime
var lifetime_id := 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()

func _active() -> bool:
	return not retired and is_instance_valid(source_root) and not source_root.is_queued_for_deletion()

func _current(token: int) -> bool:
	return _active() and revision == token

func _release_binding() -> void:
	profile = {}
	parts.clear()
	meshes.clear()
	motion.rules = {}
	probe = Callable()
	code_at = Callable()
	ready = false
	source_root = null
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	lifetime = null
	lifetime_id = 0

func _retire_binding(binding_generation: int, binding_instance: int) -> void:
	if generation != binding_generation or lifetime_id != binding_instance:
		return
	lifetime = null
	retire()

func retire() -> void:
	if retired:
		return
	retired = true
	generation += 1
	revision += 1
	_release_binding()

func configure(root: Node3D, source: Dictionary, season: String, low: bool, height: Callable, ground_code: Callable) -> bool:
	if retired or not is_instance_valid(root) or root.is_queued_for_deletion():
		return false
	generation += 1
	revision += 1
	var token := revision
	_release_binding()
	source_root = root
	lifetime = BindingLifetime.new()
	lifetime_id = lifetime.get_instance_id()
	lifetime.controller = weakref(self)
	lifetime.generation = generation
	root.add_child(lifetime)
	if not _current(token):
		return false
	time = 0
	probe = height
	code_at = ground_code
	for variant: Dictionary in source.variants:
		if variant.season == season and bool(variant.low) == low:
			profile = variant
	if profile.is_empty():
		push_error("Missing original petal season/power-mode capture")
		return false
	motion.rules = profile.constants
	time = float(profile.time)
	parts = profile.parts.duplicate(true)
	for node: MultiMeshInstance3D in root.find_children("*", "MultiMeshInstance3D", true, false):
		if node.has_meta("source_petal_mesh"):
			meshes[int(node.get_meta("source_petal_mesh"))] = node
			node.visible = false
			if not _current(token):
				return false
	for batch: Dictionary in profile.batches:
		var node: MultiMeshInstance3D = meshes.get(int(batch.id))
		if node == null or node.multimesh == null or node.multimesh.instance_count != int(batch.count) or node.multimesh.mesh.get_surface_count() != 1:
			push_error("Missing original petal tone MultiMesh")
			return false
		node.multimesh = MultiMeshCopy.duplicate_of(node.multimesh)
		if not _current(token):
			return false
		var material: Material = node.material_override if node.material_override != null else node.multimesh.mesh.surface_get_material(0)
		if material == null:
			push_error("Missing original petal tone material")
			return false
		node.material_override = material.duplicate()
		if not _current(token):
			return false
		node.material_override.render_priority = int(batch.priority)
		if not _current(token):
			return false
		node.visible = true
		if not _current(token):
			return false
		RenderingServer.instance_set_ignore_culling(node.get_instance(), true)
	ready = true
	return true

func advance(delta: float, dynamics: Dictionary) -> void:
	if not ready or not _active() or parts.is_empty():
		return
	revision += 1
	var token := revision
	var step := 0.0 if is_nan(delta) else clampf(delta, 0, float(motion.rules.DT_MAX))
	time += step
	for part: Dictionary in parts:
		motion.advance(part, step, time, dynamics)
		if float(part.get("groundTime", 0)) > 0 and not ControlPreferences.truthy(part.get("wasGrounded")):
			var ground: Variant = probe.call(float(part.cx) + float(part.ox), float(part.cz) + float(part.oz))
			if not _current(token):
				return
			part.restY = ground
			var code := int(code_at.call(float(part.cx) + float(part.ox), float(part.cz) + float(part.oz)))
			if not _current(token):
				return
			part.restDry = code == 0
		part.wasGrounded = float(part.get("groundTime", 0)) > 0
		var resting := bool(part.wasGrounded) or ControlPreferences.truthy(part.get("lifted"))
		var base: Variant = part.get("restY") if resting else part.y0
		var visible := BodyMotionState._finite(base) and (not resting or bool(part.get("restDry", false)))
		var position := Vector3(float(part.cx) + float(part.ox), float(base) + float(part.oy) if visible else 0, float(part.cz) + float(part.oz))
		var rotation := SourceQuaternion.axis_angle(Vector3(part.ax, part.ay, part.az), part.ang)
		if float(part.get("groundTime", 0)) > 0:
			rotation = SourceQuaternion.multiply(SourceQuaternion.axis_angle(Vector3.RIGHT, -PI / 2),
				SourceQuaternion.axis_angle(Vector3.BACK, float(part.a)))
		var fade: Variant = part.get("fade")
		var size := float(part.sz) * (1.0 if fade == null else float(fade)) if visible else 0.0
		var transform := Transform3D(SourceQuaternion.basis(rotation).scaled_local(Vector3(size * float(motion.rules.ASPECT), size, size)), position)
		for batch: Dictionary in profile.batches:
			if int(batch.tone) == int(part.tone):
				meshes[int(batch.id)].multimesh.set_instance_transform(int(part.mi), transform)
				if not _current(token):
					return
				break
