class_name SceneryMotion
extends RefCounted

const BindingLifetime = preload("res://scripts/scenery_binding_lifetime.gd")

var spec: Dictionary
var pivot: Node3D
var angles: Array = [0.0, 0.0, 0.0]
var angle := 0.0
var paused := false
var elapsed := 0.0
var materials: Array[Material] = []
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
	return not retired and is_instance_valid(pivot) and not pivot.is_queued_for_deletion()

func _current(token: int) -> bool:
	return _active() and token == revision

func _retire_binding(binding_generation: int, binding_instance: int) -> void:
	if generation != binding_generation or lifetime_id != binding_instance:
		return
	lifetime = null
	retire()

func retire() -> void:
	if retired:
		return
	retired = true
	ready = false
	generation += 1
	revision += 1
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	lifetime = null
	lifetime_id = 0
	pivot = null
	spec = {}
	materials.clear()

static func create_anchor(source: Dictionary) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "SceneryMotion_%d" % int(source.id)
	var matrix: Array = source.anchor
	anchor.transform = Transform3D(Basis(Vector3(matrix[0], matrix[1], matrix[2]), Vector3(matrix[4], matrix[5], matrix[6]),
		Vector3(matrix[8], matrix[9], matrix[10])), Vector3(matrix[12], matrix[13], matrix[14]))
	var node := Node3D.new()
	node.name = "Pivot"
	node.transform = _frame(source, BodyPose.vector(source.position), source.rotation)
	anchor.add_child(node)
	return anchor

static func _frame(source: Dictionary, position: Vector3, rotation: Array, size: Variant = null) -> Transform3D:
	var q: Quaternion
	if source.kind == "rotor":
		# Original edge rotors use YXZ; evaluate their unbounded spin before Float32 storage.
		q = SourceQuaternion.multiply(SourceQuaternion.axis_angle(Vector3.UP, rotation[1]),
			SourceQuaternion.axis_angle(Vector3.RIGHT, rotation[0]))
		q = SourceQuaternion.multiply(q, SourceQuaternion.axis_angle(Vector3.BACK, rotation[2]))
	else:
		q = WeaponPresentation.source_rotation({"rotation": rotation, "order": source.order})
	var local_scale: Vector3 = BodyPose.vector(source.scale) if size == null else size
	return Transform3D(SourceQuaternion.basis(q).scaled_local(local_scale), position)

func configure(node: Node3D, source: Dictionary, phase: Variant = null) -> bool:
	if retired or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	generation += 1
	revision += 1
	var token := revision
	ready = false
	if is_instance_valid(lifetime):
		lifetime.controller = null
		lifetime.queue_free()
	spec = source
	pivot = node
	angles = source.rotation.duplicate()
	angle = float(source.get("angle", source.get("phase", 0)))
	elapsed = float(source.get("start", 0)) if phase == null else float(phase) * float(source.range)
	materials.clear()
	lifetime = BindingLifetime.new()
	lifetime_id = lifetime.get_instance_id()
	lifetime.controller = weakref(self)
	lifetime.generation = generation
	# A tree transfer retains the binding; only native deletion closes it.
	node.add_child(lifetime)
	if not _current(token):
		return false
	if source.kind == "waterfall_sheet":
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			# Opacity belongs to this waterfall, never to the saved shared scene.
			var overrides: Array[Material] = []
			for surface in range(mesh.mesh.get_surface_count()):
				var original := mesh.get_active_material(surface)
				if not (original is StandardMaterial3D or (original is ShaderMaterial and original.get_shader_parameter("uSourceAlbedo") is Color)):
					push_error("Original waterfall sheet requires its captured native material")
					return false
				overrides.append(original.duplicate())
			mesh.material_override = null
			if not _current(token):
				return false
			for surface in range(overrides.size()):
				mesh.set_surface_override_material(surface, overrides[surface])
				if not _current(token):
					return false
				materials.append(overrides[surface])
		if materials.is_empty():
			push_error("Missing original waterfall sheet geometry")
			return false
	ready = true
	return true

func advance(delta: float, now: float, weather: Dictionary) -> void:
	if not ready or not _active() or (spec.kind == "part" and (paused or not is_finite(now))):
		return
	revision += 1
	var token := revision
	var position := pivot.position
	var wind := maxf(0, float(weather.get("windAmp", 1)))
	var wave := maxf(0, float(weather.get("waveAmp", 1)))
	if spec.kind in ["cruiser", "vessel_wake", "moored"] and float(weather.get("waveAmp", 1)) <= 0.001:
		return
	var size := BodyPose.vector(spec.scale)
	match spec.kind:
		"part":
			var motion: Dictionary = spec.motion
			var phase := now * float(motion.speed) + float(motion.get("phase", 0))
			angles[{"x": 0, "y": 1, "z": 2}[motion.axis]] = fmod(phase, TAU) if motion.kind == "spin" else sin(phase) * float(motion.get("amplitude", 0.08))
		"rotor":
			var heading: Array = weather.get("windDir", [1, 0])
			var normal := float(heading[0]) * sin(float(spec.fry)) + float(heading[1]) * cos(float(spec.fry))
			var cross_flow := float(heading[0]) * cos(float(spec.fry)) - float(heading[1]) * sin(float(spec.fry))
			var sign_value := 1 if normal <= -0.05 else -1 if normal >= 0.05 else 1 if cross_flow >= 0 else -1
			var step := 0.0 if is_nan(delta) else clampf(delta, 0, 0.25)
			angle += step * float(spec.constants.ROTOR_RAD_S) * wind * sign_value * (0.35 + 0.65 * absf(normal))
			angles[1] = clampf(atan2(-cross_flow, maxf(0.1, -normal)) * 0.12, -0.08, 0.08)
			angles[2] = angle
		"float":
			var a := now * float(spec.constants.FLOAT_FREQ) + float(spec.phase)
			var heave := sin(a) * 0.76 + sin(a * 1.87 + float(spec.phase) * 0.7) * 0.24
			position.y = float(spec.baseY) + heave * float(spec.constants.FLOAT_AMP_M) * wave
			angles[0] = sin(a * 0.83) * float(spec.constants.FLOAT_TILT) * wave
			angles[2] = sin(a * 0.67 + 1.3) * float(spec.constants.FLOAT_TILT) * wave
		"machine":
			angles[2] = sin(now * float(spec.constants.MACHINE_FREQ) + float(spec.phase)) * float(spec.constants.MACHINE_SWING)
		"smoke", "dust":
			var a := now * float(spec.constants.PLUME_FREQ) + float(spec.phase)
			var drift := float(spec.constants.PLUME_DRIFT_M) * wind
			position.x = sin(a * 0.73) * drift
			position.y = float(spec.baseY) + (sin(a) * 0.5 + 0.5) * float(spec.constants.PLUME_RISE_M)
			position.z = cos(a * 0.61 + float(spec.phase)) * drift * (1.0 if spec.kind == "dust" else 0.55)
		"waterfall_sheet":
			elapsed += delta
			var index := int(spec.index)
			size.x = 1 + sin(elapsed * 2.4 + index) * 0.05
			var alpha := (0.85 if index == 0 else 0.55) + sin(elapsed * (3 + index)) * 0.1
			for material: Material in materials:
				if material is StandardMaterial3D:
					var color := (material as StandardMaterial3D).albedo_color
					color.a = alpha
					(material as StandardMaterial3D).albedo_color = color
				else:
					var shader_material := material as ShaderMaterial
					var color: Color = shader_material.get_shader_parameter("uSourceAlbedo")
					color.a = alpha
					shader_material.set_shader_parameter("uSourceAlbedo", color)
				if not _current(token):
					return
		"waterfall_foam":
			elapsed += delta
			size = Vector3.ONE * (1 + sin(elapsed * 3.2) * 0.12)
		"cruiser":
			angle += float(spec.speed) / float(spec.radius) * float(spec.rotDir) * delta
			position = Vector3(clampf(float(spec.cx) + cos(angle) * float(spec.radius), spec.minX, spec.maxX),
				float(spec.waterY) + 0.1, clampf(float(spec.cz) + sin(angle) * float(spec.radius), spec.minZ, spec.maxZ))
			angles[1] = atan2(-sin(angle) * float(spec.radius) * float(spec.rotDir), cos(angle) * float(spec.radius) * float(spec.rotDir))
			angles[2] = sin(now * 2.2 + float(spec.phase)) * 0.04
			angles[0] = sin(now * 1.7 + float(spec.phase)) * 0.03
		"vessel_wake":
			size = Vector3(1 + sin(now * 4.2 + float(spec.phase)) * 0.06, 1, 1 + cos(now * 3.6 + float(spec.phase)) * 0.08)
		"moored":
			position.y = float(spec.baseY) + sin(now * float(spec.frequency) + float(spec.phase)) * float(spec.bobAmp)
			angles[2] = cos(now * float(spec.frequency) * 1.3 + float(spec.phase)) * 0.06
	pivot.transform = _frame(spec, position, angles, size)
