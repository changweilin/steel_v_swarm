shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float source_size = 0.45;
uniform float source_opacity = 0.6;
uniform vec3 source_colour = vec3(1.0);
uniform bool source_vertex_colours = true;
uniform bool source_size_attenuation = true;
uniform float source_pixel_ratio = 1.0;

void vertex() {
	POINT_SIZE = source_size * source_pixel_ratio;
	if (source_size_attenuation && PROJECTION_MATRIX[2][3] == -1.0) {
		vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		POINT_SIZE = source_size * VIEWPORT_SIZE.y * 0.5 / -view.z;
	}
}

vec3 source_encode(vec3 color) {
	return mix(1.055 * pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) - vec3(0.055), color * 12.92, lessThan(color, vec3(0.0031308)));
}

// Same correction as source_vertex_color.gdshader.template's unlit path: Compatibility
// decodes ALBEDO with a cubic and presents with a toeless power curve, while Three.js
// writes the sRGB encoding of the linear colour and blends that against the target.
vec3 source_compat_unlit(vec3 linear) {
	vec3 target = pow((max(source_encode(linear), vec3(0.0)) + vec3(0.055)) / 1.055, vec3(2.4));
	vec3 value = max(source_encode(target), vec3(0.0));
	for (int step = 0; step < 4; step++) {
		vec3 decoded = value * (value * (value * 0.305306011 + 0.682171111) + 0.012522878);
		value -= (decoded - target) / (value * (value * 0.915918033 + 1.364342222) + 0.012522878);
	}
	return mix(value, max(target / 0.012522878, vec3(-0.0092)), lessThanEqual(target, vec3(0.0)));
}

void fragment() {
	vec3 linear = source_colour * (source_vertex_colours ? COLOR.rgb : vec3(1.0));
	ALBEDO = OUTPUT_IS_SRGB ? source_compat_unlit(linear) : linear;
	ALPHA = source_opacity;
}
