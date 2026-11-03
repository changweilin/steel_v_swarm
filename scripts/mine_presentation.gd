class_name MinePresentation
extends Node3D

var entries: Dictionary = {}
var last_check := 0.0
var wall_clock := Callable()
var retired := false
var revision := 0

func _active() -> bool:
	return not retired and not is_queued_for_deletion()

func _current(token: int) -> bool:
	return _active() and token == revision

func _release(visual: MeshInstance3D) -> void:
	if is_instance_valid(visual):
		visual.visible = false
		if is_instance_valid(visual):
			visual.queue_free()

func retire() -> void:
	if retired:
		return
	retired = true
	revision += 1
	wall_clock = Callable()
	var roots := entries.values()
	entries.clear()
	for visual: MeshInstance3D in roots:
		_release(visual)
	visible = false

func _exit_tree() -> void:
	retire()

func sync(states: Array) -> void:
	if not _active():
		return
	revision += 1
	var token := revision
	var seen := {}
	for state: Dictionary in states:
		var id := int(state.id)
		seen[id] = true
		if entries.has(id):
			continue
		var path := "res://assets/hazards/mine_bump.scn"
		if not ResourceLoader.exists(path):
			push_error("Missing original mine model; regenerate and pack hazard content")
			continue
		var visual: MeshInstance3D = load(path).instantiate()
		visual.mesh = visual.mesh.duplicate(true)
		visual.position = state.position
		entries[id] = visual
		add_child(visual)
		if not _current(token):
			return
	for id: int in entries.keys():
		if not seen.has(id):
			var visual: MeshInstance3D = entries[id]
			entries.erase(id)
			_release(visual)
			if not _current(token):
				return

func update_view(observer: Vector3, now: float) -> void:
	if not _active():
		return
	var token := revision
	var observed_at := float(wall_clock.call()) if wall_clock.is_valid() else now
	if not _current(token):
		return
	if observed_at - last_check < 0.12:
		return
	revision += 1
	token = revision
	last_check = observed_at
	var cfg: Dictionary = Content.constants.GAME.MINES
	for visual: MeshInstance3D in entries.values():
		var distance := _distance(observer, visual.position)
		visual.visible = distance <= float(cfg.SEE_M)
		if not _current(token):
			return
		if not visual.visible:
			continue
		var opacity := minf(1, (float(cfg.SEE_M) - distance) / maxf(1, float(cfg.SEE_M) - float(cfg.CLEAR_M)))
		for surface in range(visual.mesh.get_surface_count()):
			var material: Material = visual.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				(material as StandardMaterial3D).albedo_color.a = opacity
			elif material is ShaderMaterial:
				var shader_material := material as ShaderMaterial
				var color: Color = shader_material.get_shader_parameter("uSourceAlbedo")
				color.a = opacity
				shader_material.set_shader_parameter("uSourceAlbedo", color)
			if not _current(token):
				return

static func _distance(first: Vector3, second: Vector3) -> float:
	# V8's three-argument Math.hypot compensates the normalized sum before sqrt.
	# https://github.com/nodejs/node/blob/v24.16.0/deps/v8/src/builtins/math.tq
	var a := absf(float(first.x) - float(second.x))
	var b := absf(float(first.y) - float(second.y))
	var c := absf(float(first.z) - float(second.z))
	if is_inf(a) or is_inf(b) or is_inf(c):
		return INF
	if is_nan(a) or is_nan(b) or is_nan(c):
		return NAN
	var largest := maxf(maxf(a, b), c)
	if largest == 0:
		return 0.0
	a /= largest
	b /= largest
	c /= largest
	var power_a := a * a
	var power_b := b * b
	var compensation := (power_a + power_b) - power_a - power_b
	var power_c := c * c - compensation
	return sqrt(power_a + power_b + power_c) * largest
