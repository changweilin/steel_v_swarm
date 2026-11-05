shader_type canvas_item;
// CSS `filter: grayscale(amount)` followed by element `opacity`, as a CanvasGroup
// material. A CSS filter applies to the element's composited layer (background,
// frame and image together), so the group's children must hold the whole element;
// filtering each child separately rounds twice and loses the source order.
// Chromium applies the matrix to unpremultiplied 8-bit sRGB values (no linearRGB
// conversion for shorthand filters) and rounds to the nearest byte.
uniform sampler2D group_texture : hint_screen_texture, filter_nearest, repeat_disable;
// grayscale() amount; `filter: none` is amount 0, which transitions interpolate to.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = textureLod(group_texture, SCREEN_UV, 0.0);
	if (color.a > 0.0) {
		color.rgb /= color.a;
	}
	float a = clamp(amount, 0.0, 1.0);
	if (a > 0.0) {
		// Filter Effects 1 grayscale matrix: rows sum to one and no entry is
		// negative for a in [0, 1], so in-range input never needs clamping.
		float b = 1.0 - a;
		mat3 grayscale = mat3(
			vec3(0.2126 + 0.7874 * b, 0.2126 - 0.2126 * b, 0.2126 - 0.2126 * b),
			vec3(0.7152 - 0.7152 * b, 0.7152 + 0.2848 * b, 0.7152 - 0.7152 * b),
			vec3(0.0722 - 0.0722 * b, 0.0722 - 0.0722 * b, 0.0722 + 0.9278 * b));
		color.rgb = clamp(grayscale * color.rgb, 0.0, 1.0);
	}
	COLOR = vec4(color.rgb, color.a * clamp(opacity, 0.0, 1.0));
}
