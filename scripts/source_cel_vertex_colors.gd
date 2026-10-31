class_name SourceCelVertexColors
extends RefCounted

# Three multiplies diffuse by Float32 vertex colours without clamping. Godot's
# ARRAY_COLOR is RGBA8, so active source colours bind to this attribute instead.
const ARRAY_SLOT := Mesh.ARRAY_CUSTOM2
const FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
const TEMPLATE := "res://shaders/source_vertex_color.gdshader.template"

static var shaders: Dictionary = {}

static func encode(values: Variant, color_size: int, vertices: int) -> Dictionary:
	if not (values is Array or values is PackedFloat64Array) or color_size not in [3, 4] or vertices <= 0 or values.size() != vertices * color_size:
		return _failure("Original vertex colours do not match the vertex layout")
	var encoded := PackedFloat32Array()
	encoded.resize(vertices * 4)
	for vertex in range(vertices):
		var alpha := vertex * 4 + 3
		# A source vec3 varying leaves diffuse alpha untouched.
		encoded[alpha] = 1.0
		for channel in range(color_size):
			var value: Variant = values[vertex * color_size + channel]
			if not (value is float or value is int) or not is_finite(float(value)):
				return _failure("Invalid original vertex colour component")
			var offset := vertex * 4 + channel
			encoded[offset] = value
			if float(encoded[offset]) != float(value):
				return _failure("Original vertex colour does not fit its Float32 attribute")
	return {"ok": true, "value": encoded}

# Consumers read material state from shader parameters, never from albedo_color.
# Instance-tinted surfaces without source vertex colours pass float_colors = false;
# they have no ARRAY_SLOT data but still need the source's linear multiplication.
static func material(base: StandardMaterial3D, float_colors := true) -> ShaderMaterial:
	if base == null or not base.vertex_color_use_as_albedo:
		push_error("Float vertex colours require an active original vertex colour material")
		return null
	if base.blend_mode not in [BaseMaterial3D.BLEND_MODE_MIX, BaseMaterial3D.BLEND_MODE_ADD] \
			or base.shading_mode not in [BaseMaterial3D.SHADING_MODE_PER_PIXEL, BaseMaterial3D.SHADING_MODE_UNSHADED] \
			or base.transparency not in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
		push_error("Unsupported native state for original float vertex colours")
		return null
	var shader := _shader(base, float_colors)
	if shader == null:
		return null
	var result := ShaderMaterial.new()
	result.shader = shader
	result.render_priority = base.render_priority
	for property: StringName in base.get_meta_list():
		result.set_meta(property, base.get_meta(property))
	result.set_shader_parameter("uSourceAlbedo", base.albedo_color)
	result.set_shader_parameter("uSourceRoughness", base.roughness)
	result.set_shader_parameter("uSourceMetallic", base.metallic)
	result.set_shader_parameter("uSourceSpecular", base.metallic_specular)
	if base.albedo_texture != null:
		result.set_shader_parameter("uSourceTexture", base.albedo_texture)
	if base.emission_enabled:
		result.set_shader_parameter("uSourceEmission", base.emission)
		result.set_shader_parameter("uSourceEmissionEnergy", base.emission_energy_multiplier)
	if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		result.set_shader_parameter("uSourceAlphaScissor", base.alpha_scissor_threshold)
	return result

static func _shader(base: StandardMaterial3D, float_colors: bool) -> Shader:
	var modes: Array[String] = ["blend_add" if base.blend_mode == BaseMaterial3D.BLEND_MODE_ADD else "blend_mix"]
	modes.append("depth_draw_never" if base.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED else "depth_draw_always" if base.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_ALWAYS else "depth_draw_opaque")
	modes.append("cull_disabled" if base.cull_mode == BaseMaterial3D.CULL_DISABLED else "cull_front" if base.cull_mode == BaseMaterial3D.CULL_FRONT else "cull_back")
	modes.append_array(["diffuse_burley", "specular_schlick_ggx"])
	if base.no_depth_test:
		modes.append("depth_test_disabled")
	var defines := ""
	if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		modes.append("unshaded")
		defines += "#define SOURCE_UNSHADED\n"
	if float_colors:
		defines += "#define SOURCE_FLOAT_COLOR\n"
	if base.albedo_texture != null:
		defines += "#define SOURCE_TEXTURE\n"
	if base.emission_enabled:
		defines += "#define SOURCE_EMISSION\n"
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		defines += "#define SOURCE_ALPHA\n"
	if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		defines += "#define SOURCE_ALPHA_SCISSOR\n"
	var code := FileAccess.get_file_as_string(TEMPLATE)
	if code.is_empty():
		push_error("Missing original float vertex colour shader template")
		return null
	code = code.replace("__RENDER_MODES__", ", ".join(modes)).replace("__DEFINES__", defines).replace("__SAMPLER__", SourceTextureImages.sampler_hint(base))
	var key := code.sha256_text()
	if not shaders.has(key):
		var shader := Shader.new()
		shader.code = code
		shaders[key] = shader
	return shaders[key]

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
