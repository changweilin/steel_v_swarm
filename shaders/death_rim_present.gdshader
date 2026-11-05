shader_type canvas_item;
uniform sampler2D shadow_texture : filter_linear, repeat_disable;
uniform vec2 target_size;
uniform vec2 canvas_size;
uniform float padding;
uniform vec4 rim_color : source_color;
uniform float opacity;
void fragment() {
	float shadow = texture(shadow_texture, (UV * canvas_size + vec2(padding)) / target_size).a;
	// Chromium paints the shadow colour as 8-bit RGBA: alpha 0.55 draws as 140/255.
	vec4 color = round(clamp(rim_color, 0.0, 1.0) * 255.0) / 255.0;
	COLOR = vec4(color.rgb, color.a * opacity * shadow);
}
