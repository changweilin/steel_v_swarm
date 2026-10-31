extends Node

const Raster = preload("res://tests/raster_compare.gd")
const HDR := 1.059999942779541
const SIZE := 24

var assertions := 0
var failures := 0
var report: Array = []

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func _run() -> void:
	_encoding()
	_storage()
	if DisplayServer.get_name() == "headless":
		_check(false, "Float vertex colour raster qualification requires a rendered session")
		_finish()
		return
	await _source_rasters()
	await _native_parity()
	_finish()

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/cel_vertex_colors")
	var file := FileAccess.open("res://build/cel_vertex_colors/report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, " "))
		file.close()
	print("CEL_VERTEX_COLORS assertions=", assertions, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func _encoding() -> void:
	var rgb := SourceCelVertexColors.encode([HDR, -0.25, 0.5], 3, 1)
	_check(rgb.ok and rgb.value == PackedFloat32Array([HDR, -0.25, 0.5, 1.0]), "RGB source colours keep HDR and signed channels with a neutral alpha")
	var rgba := SourceCelVertexColors.encode(PackedFloat64Array([HDR, 0.25, 0.5, -0.75]), 4, 1)
	_check(rgba.ok and rgba.value == PackedFloat32Array([HDR, 0.25, 0.5, -0.75]), "RGBA source colours keep their captured alpha")
	var negative_zero := SourceCelVertexColors.encode([SourceCelUniforms.NEGATIVE_ZERO, 0.0, 1.0], 3, 1)
	_check(negative_zero.ok and negative_zero.value.to_byte_array().slice(0, 4) == PackedFloat32Array([SourceCelUniforms.NEGATIVE_ZERO]).to_byte_array(), "Signed zero survives Float32 storage")
	_check(not SourceCelVertexColors.encode([1.0, 1.0], 3, 1).ok, "Reject an incomplete vertex colour layout")
	_check(not SourceCelVertexColors.encode([1.0, 1.0, 1.0], 2, 1).ok, "Reject an undeclared colour width")
	_check(not SourceCelVertexColors.encode([NAN, 1.0, 1.0], 3, 1).ok, "Reject a non-finite source colour")
	_check(not SourceCelVertexColors.encode(["1", 1.0, 1.0], 3, 1).ok, "Reject a non-numeric source colour")
	_check(not SourceCelVertexColors.encode([1.06, 1.0, 1.0], 3, 1).ok, "Reject a double that a Float32 attribute would round")

func _quad(colors: PackedFloat32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(-1, 1, 0), Vector3(1, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)])
	# Godot's front-face winding is opposite Three.js.
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 2, 3, 1])
	var flags := 0
	if not colors.is_empty():
		arrays[SourceCelVertexColors.ARRAY_SLOT] = colors
		flags = SourceCelVertexColors.FORMAT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh

func _storage() -> void:
	var colors: PackedFloat32Array = SourceCelVertexColors.encode([HDR, 0.5, -0.25, 0.125, 0.25, 0.375, HDR, HDR, HDR, 0.0, 1.0, 0.75], 3, 4).value
	var mesh := _quad(colors)
	var base := StandardMaterial3D.new()
	base.vertex_color_use_as_albedo = true
	var bundle := SourceCelData.new()
	var cel := {"program": 0, "defines": {"TOON": ""}, "uniforms": {}}
	bundle.programs = [{"vertex": "", "fragment": "", "chunks": {}}]
	_check(bundle.attach(base, cel), "Attach a captured cel declaration before float colour binding")
	var material := SourceCelVertexColors.material(base)
	_check(material != null, "Build the shared float colour material")
	if material == null:
		return
	_check(SourceCelData.material_source(material) == cel, "Float colour materials keep the shared cel table reference")
	mesh.surface_set_material(0, material)
	var path := "user://cel-vertex-colors-%d.res" % Time.get_ticks_usec()
	_check(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) == OK, "Save a float colour mesh through native ResourceSaver")
	var loaded := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	_check(loaded != null and loaded != mesh, "Reload an independent float colour mesh")
	if loaded != null:
		var restored: Variant = loaded.surface_get_arrays(0)[SourceCelVertexColors.ARRAY_SLOT]
		_check(restored is PackedFloat32Array and restored.to_byte_array() == colors.to_byte_array(), "Native disk reload keeps every Float32 colour byte")
		var reloaded := loaded.surface_get_material(0)
		_check(SourceCelData.material_source(reloaded) == cel, "Native disk reload keeps the shared cel declaration")
		_check(reloaded is ShaderMaterial and reloaded.shader.code == material.shader.code, "Native disk reload keeps the float colour shader")
	loaded = null
	_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove only the test-owned colour resource")

func _capture(node: Node3D, camera: Camera3D, light := false) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	camera.environment = environment
	viewport.add_child(camera)
	viewport.add_child(node)
	if light:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 40, 0)
		viewport.add_child(sun)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.3, 0.3, 0.35)
	for frame in range(3):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.free()
	return image

func _orthographic() -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.near = 0.1
	camera.far = 10.0
	camera.position = Vector3(0, 0, 1)
	return camera

func _source_material(item: Dictionary, float_colors: bool) -> Material:
	var base := StandardMaterial3D.new()
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.albedo_color = Color.hex((int(item.albedoHex) << 8) | 0xff)
	base.vertex_color_use_as_albedo = item.vertexColors or not item.instanceColor.is_empty()
	if item.transparent:
		base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return SourceCelVertexColors.material(base, item.vertexColors) if float_colors else base

func _source_node(item: Dictionary, mesh: ArrayMesh) -> Node3D:
	if item.instanceColor.is_empty():
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		return instance
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = 1
	batch.set_instance_transform(0, Transform3D.IDENTITY)
	batch.set_instance_color(0, Color(item.instanceColor[0], item.instanceColor[1], item.instanceColor[2]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = batch
	return node

func _source_rasters() -> void:
	var capture: Dictionary = Content.read_json("res://tests/fixtures/cel_vertex_colors.json")
	_check(capture.get("formatVersion") == 1 and capture.get("cases") is Array, "Capture original Three vertex colour rasters first")
	if failures > 0:
		return
	var provenance: Dictionary = Content.read_json("res://data/provenance.json")
	for path: String in capture.source.inputs:
		var text := FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").replace("\r", "\n")
		_check(text.sha256_text() == capture.source.inputs[path], "Vertex colour raster generator is current: " + path)
	for path: String in capture.source.sourceInputs:
		_check(provenance.inputs.get(path) == capture.source.sourceInputs[path], "Vertex colour raster matches imported source: " + path)
	for item: Dictionary in capture.cases:
		var colors := PackedFloat32Array()
		if item.vertexColors:
			var encoded := SourceCelVertexColors.encode(Marshalls.base64_to_raw(item.colors).to_float64_array(), int(item.colorSize), 4)
			_check(encoded.ok, item.name + ": captured colours fit the native attribute")
			if not encoded.ok:
				continue
			colors = encoded.value
		var mesh := _quad(colors)
		mesh.surface_set_material(0, _source_material(item, item.vertexColors or not item.instanceColor.is_empty()))
		var actual: Image = await _capture(_source_node(item, mesh), _orthographic())
		var expected := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, Marshalls.base64_to_raw(item.rgba))
		var result := Raster.compare(actual, expected, 1.0 / 255.0)
		report.append({"case": item.name, "pixels": result.pixels, "maximum": result.maximum * 255.0})
		_check(result.pixels == 0, "%s: native raster matches original Three pixels (%d differ, maximum %f)" % [item.name, result.pixels, result.maximum * 255.0])
		if item.name == "hdr_rgb":
			await _clamped_control(item, expected)

# RGBA8 storage must fail this raster, or the source comparison proves nothing.
func _clamped_control(item: Dictionary, expected: Image) -> void:
	var values := Marshalls.base64_to_raw(item.colors).to_float64_array()
	var colors := PackedColorArray()
	for offset in range(0, values.size(), 3):
		colors.append(Color(values[offset], values[offset + 1], values[offset + 2]).clamp())
	var mesh := _quad(PackedFloat32Array())
	var arrays := mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_COLOR] = colors
	var clamped := ArrayMesh.new()
	clamped.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	clamped.surface_set_material(0, _source_material(item, false))
	var node := MeshInstance3D.new()
	node.mesh = clamped
	var actual: Image = await _capture(node, _orthographic())
	var result := Raster.compare(actual, expected, 1.0 / 255.0)
	report.append({"case": "clamped_control", "pixels": result.pixels, "maximum": result.maximum * 255.0})
	_check(result.pixels > 0, "Clamped RGBA8 colours differ from the original HDR raster")

func _variant(configure: Callable) -> StandardMaterial3D:
	var base := StandardMaterial3D.new()
	base.vertex_color_use_as_albedo = true
	base.albedo_color = Color.hex(0xb0c4deff)
	base.roughness = 0.6
	base.metallic = 0.2
	configure.call(base)
	return base

func _native_parity() -> void:
	var image := Image.create_empty(2, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(1, 0.5, 0.25, 1))
	image.set_pixel(1, 0, Color(0.25, 1, 0.5, 0.25))
	image.set_pixel(0, 1, Color(0.5, 0.25, 1, 0.75))
	image.set_pixel(1, 1, Color(1, 1, 1, 0))
	var texture := ImageTexture.create_from_image(image)
	var variants := {
		"opaque_lit": func(_base: StandardMaterial3D) -> void: pass,
		"double_sided": func(base: StandardMaterial3D) -> void: base.cull_mode = BaseMaterial3D.CULL_DISABLED,
		"unshaded": func(base: StandardMaterial3D) -> void: base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED,
		"transparent": func(base: StandardMaterial3D) -> void:
			base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			base.albedo_color.a = 0.58
			base.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED,
		"additive": func(base: StandardMaterial3D) -> void: base.blend_mode = BaseMaterial3D.BLEND_MODE_ADD,
		"texture_scissor": func(base: StandardMaterial3D) -> void:
			base.albedo_color = Color.WHITE
			base.albedo_texture = texture
			base.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			base.alpha_scissor_threshold = 0.5,
		"emission": func(base: StandardMaterial3D) -> void:
			base.emission_enabled = true
			base.emission = Color.hex(0x402010ff)
			base.emission_energy_multiplier = 1.5,
	}
	# White colours are transfer-neutral, so any difference belongs to material state.
	var floats := PackedFloat32Array()
	for vertex in range(4):
		floats.append_array(PackedFloat32Array([1, 1, 1, 1]))
	for name: String in variants:
		var reference := _quad(PackedFloat32Array())
		reference.surface_set_material(0, _variant(variants[name]))
		var native := _quad(floats)
		var material := SourceCelVertexColors.material(_variant(variants[name]))
		_check(material != null, name + ": build the float colour material")
		if material == null:
			continue
		native.surface_set_material(0, material)
		var expected: Image = await _capture(_tilted(reference), _perspective(), true)
		var actual: Image = await _capture(_tilted(native), _perspective(), true)
		var result := Raster.compare(actual, expected, 1.0 / 255.0)
		report.append({"case": "parity_" + name, "pixels": result.pixels, "maximum": result.maximum * 255.0})
		_check(result.pixels == 0, "%s: float colours match native material shading (%d differ, maximum %f)" % [name, result.pixels, result.maximum * 255.0])
	await _lit_equivalence()

# Lit shading has no shared source raster. A constant colour must instead equal a
# plain material whose albedo already holds the source's linear product.
func _lit_equivalence() -> void:
	var tint := Vector3(HDR, 0.5, 0.25)
	var albedo := Color.hex(0xb0c4deff)
	var linear := albedo.srgb_to_linear()
	var product := Color(linear.r * tint.x, linear.g * tint.y, linear.b * tint.z)
	var floats := PackedFloat32Array()
	for vertex in range(4):
		floats.append_array(PackedFloat32Array([tint.x, tint.y, tint.z, 1]))
	var native := _quad(floats)
	native.surface_set_material(0, SourceCelVertexColors.material(_variant(func(_base: StandardMaterial3D) -> void: pass)))
	var reference := _quad(PackedFloat32Array())
	reference.surface_set_material(0, _variant(func(base: StandardMaterial3D) -> void:
		base.vertex_color_use_as_albedo = false
		base.albedo_color = product.linear_to_srgb()))
	var expected: Image = await _capture(_tilted(reference), _perspective(), true)
	var actual: Image = await _capture(_tilted(native), _perspective(), true)
	var result := Raster.compare(actual, expected, 1.0 / 255.0)
	report.append({"case": "lit_linear_product", "pixels": result.pixels, "maximum": result.maximum * 255.0})
	_check(result.pixels == 0, "Lit float colours multiply in linear light (%d differ, maximum %f)" % [result.pixels, result.maximum * 255.0])

func _tilted(mesh: ArrayMesh) -> Node3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation_degrees = Vector3(-25, 20, 0)
	return node

func _perspective() -> Camera3D:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 2.5)
	return camera
