shader_type canvas_item;
render_mode blend_disabled, unshaded;

// One pass of Skia's Ganesh mask blur. Every target stores the A8 coverage as a byte in
// all channels; scripts/source_inset_shadow.gd plans the pass order and rectangles.
// 0 mask, 1 bilinear rescale, 2 last rescale with its edge padding, 3 Gaussian, 4 tile copy.
uniform int mode = 0;
uniform vec2 target_size = vec2(1.0);
uniform sampler2D source : filter_nearest, repeat_disable;
uniform sampler2D edge_source : filter_nearest, repeat_disable;
// Rectangles are left, top, right, bottom.
uniform vec4 outer_rect;
uniform vec4 hole_rect;
uniform vec2 content_size;
uniform vec4 src_rect;
uniform vec4 dst_rect;
uniform vec4 subset_rect;
uniform vec4 edge_bounds;
uniform ivec4 clamp_bounds;
uniform ivec2 src_offset;
uniform ivec2 direction;
uniform int radius = 0;
uniform float sigma = 1.0;
uniform ivec2 mask_origin;

float unorm8(float value) {
	return round(clamp(value, 0.0, 1.0) * 255.0) / 255.0;
}

float overlap(vec2 pixel, vec4 rect) {
	vec2 size = max(min(pixel + vec2(1.0), rect.zw) - max(pixel, rect.xy), vec2(0.0));
	return size.x * size.y;
}

float fetch(sampler2D image, ivec2 texel) {
	return texelFetch(image, clamp(texel, ivec2(0), textureSize(image, 0) - ivec2(1)), 0).a;
}

// Texel centres sit at half-integers; the coordinate is already clamped to its subset.
float bilinear(sampler2D image, vec2 point) {
	vec2 scaled = point - vec2(0.5);
	vec2 base = floor(scaled);
	vec2 blend = scaled - base;
	ivec2 texel = ivec2(base);
	float top = mix(fetch(image, texel), fetch(image, texel + ivec2(1, 0)), blend.x);
	float bottom = mix(fetch(image, texel + ivec2(0, 1)), fetch(image, texel + ivec2(1, 1)), blend.x);
	return mix(top, bottom, blend.y);
}

// Skia's fillRectToRect maps dst pixel centres linearly onto the src rectangle.
vec2 rect_to_rect(vec2 pixel, vec4 from_rect, vec4 to_rect) {
	return from_rect.xy + (pixel + vec2(0.5) - to_rect.xy) * (from_rect.zw - from_rect.xy) / (to_rect.zw - to_rect.xy);
}

float resample(vec2 pixel) {
	vec2 point = rect_to_rect(pixel, src_rect, dst_rect);
	return bilinear(source, clamp(point, subset_rect.xy + vec2(0.5), subset_rect.zw - vec2(0.5)));
}

// The last rescale step surrounds its result with one padding texel. Skia fills that
// border by downscaling the outermost source rows and columns directly, without a subset
// constraint, and copies the four source corners.
float rescale_with_edges(vec2 pixel) {
	bool left = pixel.x < dst_rect.x;
	bool right = pixel.x >= dst_rect.z;
	bool top = pixel.y < dst_rect.y;
	bool bottom = pixel.y >= dst_rect.w;
	if (!(left || right || top || bottom)) {
		return resample(pixel);
	}
	vec2 point = rect_to_rect(pixel, edge_bounds, dst_rect);
	if (left) {
		point.x = edge_bounds.x + 0.5;
	} else if (right) {
		point.x = edge_bounds.z - 0.5;
	}
	if (top) {
		point.y = edge_bounds.y + 0.5;
	} else if (bottom) {
		point.y = edge_bounds.w - 0.5;
	}
	if ((left || right) && (top || bottom)) {
		return fetch(edge_source, ivec2(floor(point)));
	}
	return bilinear(edge_source, point);
}

float gaussian(ivec2 pixel) {
	float sum = 0.0;
	float total = 0.0;
	ivec2 center = pixel + src_offset;
	for (int i = -radius; i <= radius; i++) {
		float weight = exp(-float(i * i) / (2.0 * sigma * sigma));
		ivec2 texel = clamp(center + direction * i, clamp_bounds.xy, clamp_bounds.zw - ivec2(1));
		sum += weight * texelFetch(source, texel, 0).a;
		total += weight;
	}
	return sum / total;
}

void fragment() {
	vec2 pixel = floor(UV * target_size);
	float value = 0.0;
	if (mode == 0) {
		if (all(lessThan(pixel, content_size))) {
			value = overlap(pixel, outer_rect) - overlap(pixel, hole_rect);
		}
	} else if (mode == 1) {
		value = resample(pixel);
	} else if (mode == 2) {
		value = rescale_with_edges(pixel);
	} else if (mode == 3) {
		value = gaussian(ivec2(pixel));
	} else {
		value = fetch(source, ivec2(pixel) + mask_origin);
	}
	value = unorm8(value);
	COLOR = vec4(value);
}
