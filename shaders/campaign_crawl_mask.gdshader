shader_type canvas_item;
render_mode blend_premul_alpha;
// CSS `mask-image: linear-gradient(...)` on a scroll viewport, as a CanvasGroup
// material. The group must hold the viewport's already-composed contents.
// Chromium paints the contents into an RGBA8 layer, rasterizes the mask gradient
// to one alpha byte per pixel, applies it to every premultiplied channel (DstIn)
// and stores the layer as bytes again before compositing it source-over.
uniform sampler2D group_texture : hint_screen_texture, filter_nearest, repeat_disable;
// Unscrolled mask box in render-target pixels: x = top edge, y = height. The
// gradient runs to bottom over the box; outside it the mask clips to transparent.
uniform vec2 mask_box = vec2(0.0, 1.0);
// Four colour stops: offsets along the box height and their alphas.
uniform vec4 stop_offsets = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 stop_alphas = vec4(1.0);

float unorm8(float value) {
	return floor(clamp(value, 0.0, 1.0) * 255.0 + 0.5) / 255.0;
}

float stop_alpha(float t) {
	if (t <= stop_offsets.x) {
		return stop_alphas.x;
	}
	for (int i = 0; i < 3; i++) {
		float start = stop_offsets[i];
		float end = stop_offsets[i + 1];
		if (t <= end) {
			// Coincident stops are a hard transition to the later stop.
			return end > start ? mix(stop_alphas[i], stop_alphas[i + 1], (t - start) / (end - start)) : stop_alphas[i + 1];
		}
	}
	return stop_alphas.w;
}

float mask_alpha(float pixel_y) {
	if (mask_box.y <= 0.0 || pixel_y < mask_box.x || pixel_y >= mask_box.x + mask_box.y) {
		return 0.0;
	}
	return unorm8(stop_alpha((pixel_y - mask_box.x) / mask_box.y));
}

void fragment() {
	vec4 layer = textureLod(group_texture, SCREEN_UV, 0.0);
	// SCREEN_UV addresses pixel centres with the origin at the top-left.
	float alpha = mask_alpha(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y);
	vec4 masked = layer * alpha;
	COLOR = vec4(unorm8(masked.r), unorm8(masked.g), unorm8(masked.b), unorm8(masked.a));
}
