extends RefCounted

static func run(h: Node, fixtures: Dictionary) -> void:
	for key: String in ["celUniformShader", "celUniformCases", "celUniformEntries"]:
		if not fixtures.has(key):
			h._check(false, "Regenerate original Three WebGL uniform upload references")
			return
	var shader := Shader.new()
	shader.code = fixtures.celUniformShader
	var material := ShaderMaterial.new()
	material.shader = shader
	var entries: Dictionary = fixtures.celUniformEntries
	var names: Array = entries.keys()
	if not SourceCelUniforms.bind(material, null, entries, names):
		h._check(false, "Bind original typed source uniforms to the native shader schema")
		return
	for fixture: Dictionary in fixtures.celUniformCases:
		var values := _flatten(material.get_shader_parameter(fixture.name))
		h._check(values.size() == fixture.values.size(), "Original scalar/vector/matrix/array uniform component count")
		if fixture.type == "bool":
			var expected_bools: Array = []
			for val: Variant in fixture.values:
				expected_bools.append(1 if int(val) != 0 else 0)
			h._check(values == expected_bools, "Effective shader boolean semantics: " + fixture.name)
		elif fixture.finite:
			var bytes := PackedFloat32Array(values).to_byte_array() if fixture.kind == "f32" else PackedInt32Array(values).to_byte_array()
			h._check(bytes == PackedByteArray(fixture.bytes), "Original WebGL uniform upload bits: " + fixture.name)
		else:
			for index in range(mini(values.size(), fixture.values.size())):
				var expected: Variant = fixture.values[index]
				if expected is String:
					h._check(is_nan(values[index]) if expected == "NaN" else is_inf(values[index]) and signf(values[index]) == (-1 if expected == "-Infinity" else 1),
						"Explicit source non-finite uniform state survives native conversion")
	var first: String = names[0]
	var second: String = names[1]
	var previous: Variant = material.get_shader_parameter(first)
	var invalid: Dictionary = entries.duplicate(true)
	invalid[first] = {"type": "number", "value": .75}
	invalid[second] = {"type": "undefined"}
	var rejected := SourceCelUniforms.prepare(material, null, invalid, [first, second])
	h._check(not rejected.ok and material.get_shader_parameter(first) == previous,
		"An invalid required uniform rejects the complete transaction before any material parameter changes")
	var matrix := SourceCelUniforms.decode(null, {"type": "mat4", "value": range(12)}, {"type": TYPE_PROJECTION})
	h._check(not matrix.ok, "Incomplete source matrices cannot silently acquire an affine fourth row")
	var mixed := SourceCelUniforms.decode(null, {"type": "array", "value": [
		{"type": "vec4", "value": [1, 2, 3, 4]}, {"type": "vec3", "value": [5, 6, 7]}]}, {"type": TYPE_PACKED_VECTOR4_ARRAY})
	h._check(not mixed.ok, "Incompatible source array element widths cannot be flattened into fabricated vectors")
	_samplers(h, fixtures)
	_material_storage(h, fixtures)

static func _material_storage(h: Node, fixtures: Dictionary) -> void:
	var bundle := SourceCelData.new()
	if not bundle.configure(fixtures.celSamplerBundle, SourceTextureImages.new()) or bundle.programs.is_empty():
		h._check(false, "Prepare original cel programs for shared material storage")
		return
	var source := {"program": 0, "defines": {}, "uniforms": fixtures.celUniformEntries}
	var first := StandardMaterial3D.new()
	var second := StandardMaterial3D.new()
	h._check(bundle.attach(first, source) and bundle.attach(second, source.duplicate(true)), "Attach independent copies of original typed cel material values")
	h._check(bundle.material_sources.size() == 1 and first.get_meta("source_cel") == second.get_meta("source_cel"), "Equal original material descriptions share one native Resource table entry")
	h._check(SourceCelData.material_source(first) == source and SourceCelData.material_source(second) == source, "Shared material references retain every original typed uniform")
	first.vertex_color_use_as_albedo = true
	second.vertex_color_use_as_albedo = true
	var shared := SourceCelVertexColors.material(first)
	h._check(shared != null and shared == SourceCelVertexColors.material(second), "Equal float-colour surfaces share one material RID under the engine's global limit")
	second.albedo_color = Color(.5, .25, .75)
	h._check(shared != SourceCelVertexColors.material(second), "Distinct float-colour surface state keeps its own material")
	var legacy := StandardMaterial3D.new()
	legacy.set_meta("source_cel", source)
	legacy.set_meta("source_cel_data", bundle)
	h._check(SourceCelData.material_source(legacy) == source, "Previously packed dictionary material descriptions remain readable")
	var path := "user://cel-material-storage-%d.res" % Time.get_ticks_usec()
	var saved := ResourceSaver.save(first, path, ResourceSaver.FLAG_COMPRESS)
	h._check(saved == OK, "Save the shared source material through native ResourceSaver")
	if saved != OK:
		return
	var loaded := ResourceLoader.load(path, "Material", ResourceLoader.CACHE_MODE_IGNORE) as Material
	h._check(loaded != null and SourceCelData.material_source(loaded) == source, "Native ResourceLoader retains the shared material index and exact source values")
	loaded = null
	h._check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove only the native shared-material test resource")

static func _samplers(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("celSamplerBundle") or fixtures.celSamplerBundle.celSamplers.is_empty():
		h._check(false, "Regenerate original cel sampler resources for uniform binding")
		return
	var bundle := SourceCelData.new()
	if not bundle.configure(fixtures.celSamplerBundle, SourceTextureImages.new()):
		h._check(false, "Decode original cel sampler uniform resources")
		return
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D u_image; uniform sampler2D u_images[2]; void fragment() { ALBEDO = vec3(1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	var entry := {"type": "sampler", "value": 0}
	var source := {"u_image": entry, "u_images": {"type": "array", "value": [entry, {"type": "null"}]}}
	h._check(SourceCelUniforms.bind(material, bundle, source, ["u_image", "u_images"]), "Native scalar/array sampler uniforms retain original texture identity and explicit null slots")
	h._check(material.get_shader_parameter("u_image") == bundle.texture(0), "Uniform binding reuses the shared source texture resource")
	var images: Variant = material.get_shader_parameter("u_images")
	h._check(images is Array and images.size() == 2 and images[0] == bundle.texture(0) and images[1] == null,
		"Native sampler arrays keep original ordering without allocating placeholder images")

static func _flatten(value: Variant) -> Array:
	match typeof(value):
		TYPE_BOOL: return [1 if value else 0]
		TYPE_INT, TYPE_FLOAT: return [value]
		TYPE_VECTOR2, TYPE_VECTOR2I: return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I: return [value.x, value.y, value.z]
		TYPE_VECTOR4, TYPE_VECTOR4I: return [value.x, value.y, value.z, value.w]
		TYPE_BASIS, TYPE_PROJECTION:
			var result: Array = []
			for column in range(3 if value is Basis else 4):
				result.append_array(_flatten(value[column]))
			return result
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_INT32_ARRAY: return Array(value)
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			var result: Array = []
			for element: Variant in value:
				result.append_array(_flatten(element))
			return result
	return []
