shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 viewport_size = vec2(1.0);
uniform bool scoped = false;
uniform float radius_vmin = 0.0;
uniform float ring_width = 0.0;
uniform vec4 ring_color : source_color;
uniform float fire_opacity = 0.0;
uniform float fire_blur = 0.0;
uniform vec3 fire_stops;
uniform vec4 fire_color_0 : source_color;
uniform vec4 fire_color_1 : source_color;
uniform vec4 fire_color_2 : source_color;
uniform float weather_opacity = 0.0;
uniform vec2 weather_stops;
uniform float weather_inner_vmin = 0.0;
uniform vec4 weather_color_0 : source_color;
uniform vec4 weather_color_1 : source_color;
uniform vec4 weather_color_2 : source_color;

vec4 gradient_mix(vec4 a, vec4 b, float amount) {
	float t = clamp(amount, 0.0, 1.0);
	float alpha = mix(a.a, b.a, t);
	vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, t);
	return vec4(alpha > 0.0 ? rgb / alpha : vec3(0.0), alpha);
}

vec3 unorm8(vec3 value) {
	return floor(clamp(value, 0.0, 1.0) * 255.0 + 0.5) / 255.0;
}

// Chromium rasterizes each CSS gradient into an RGBA8 premultiplied tile through
// Skia's GPU dither: an 8x8 ordered table (no X^Y mix, unlike the CPU stage),
// stored as bytes, offset by -0.5 and scaled by one 8-bit step.
float skia_dither(vec2 pixel) {
	int x = int(mod(pixel.x, 8.0));
	int y = int(mod(pixel.y, 8.0));
	int m = (y & 1) << 5 | (x & 1) << 4 | (y & 2) << 2 | (x & 2) << 1 | (y & 4) >> 1 | (x & 4) >> 2;
	float table = floor((float(m) / 64.0 - 63.0 / 128.0 + 0.5) * 255.0 + 0.5) / 255.0;
	return (table - 0.5) / 255.0;
}

// Element opacity without a render surface is applied before the dither.
vec4 gradient_tile(vec4 straight, float opacity, vec2 pixel) {
	float coverage = unorm8(vec3(straight.a * opacity)).x;
	vec3 premultiplied = clamp(straight.rgb * coverage + vec3(skia_dither(pixel)), vec3(0.0), vec3(coverage));
	return vec4(unorm8(premultiplied), coverage);
}

vec3 composite(vec3 below, vec4 tile) {
	return unorm8(tile.rgb + below * (1.0 - tile.a));
}

vec3 scope_color(vec3 input_color, float distance_px, float radius, vec2 pixel) {
	if (!scoped) {
		return input_color;
	}
	if (distance_px >= radius) {
		return vec3(0.0);
	}
	return distance_px >= radius - ring_width ? composite(input_color, gradient_tile(ring_color, 1.0, pixel)) : input_color;
}

vec2 mirror_uv(vec2 uv) {
	return vec2(1.0) - abs(vec2(1.0) - mod(uv, vec2(2.0)));
}

vec3 scoped_pixel(vec2 uv, vec2 viewport, float radius) {
	return scope_color(textureLod(screen_texture, uv, 0.0).rgb, length((uv - vec2(0.5)) * viewport), radius, floor(uv * viewport));
}

// A half-resolution texel holds the 2x2 pixels around its centre.
vec3 scoped_box(vec2 center, vec2 viewport, float radius) {
	vec2 uv = mirror_uv(center / viewport);
	if (scoped) {
		float distance_px = length((uv - vec2(0.5)) * viewport);
		if (distance_px - 1.5 >= radius) {
			return vec3(0.0);
		}
		if (distance_px + 1.5 >= radius - ring_width) {
			vec3 sum = vec3(0.0);
			for (int y = 0; y < 2; y++) {
				for (int x = 0; x < 2; x++) {
					vec2 pixel = center + vec2(float(x), float(y)) - vec2(0.5);
					sum += scoped_pixel(mirror_uv(pixel / viewport), viewport, radius);
				}
			}
			return sum * 0.25;
		}
	}
	return textureLod(screen_texture, uv, 0.0).rgb;
}

// CSS backdrop blur sees the composited scope layer below it, with sigma in pixels.
// Above sigma 4 the browser's Skia filter runs at half resolution, then upscales.
vec3 backdrop_blur(vec2 uv, vec2 viewport, float radius) {
	vec3 sum = vec3(0.0);
	float total = 0.0;
	vec2 pixel = floor(uv * viewport);
	if (fire_blur <= 4.0) {
		int extent = int(ceil(3.0 * fire_blur));
		float falloff = 2.0 * fire_blur * fire_blur;
		for (int y = -extent; y <= extent; y++) {
			for (int x = -extent; x <= extent; x++) {
				vec2 offset = vec2(float(x), float(y));
				float weight = exp(-dot(offset, offset) / falloff);
				sum += weight * scoped_pixel(mirror_uv((pixel + vec2(0.5) + offset) / viewport), viewport, radius);
				total += weight;
			}
		}
		return sum / total;
	}
	float sigma = fire_blur * 0.5;
	int extent = int(ceil(3.0 * sigma));
	float falloff = 2.0 * sigma * sigma;
	for (int i = -extent; i <= extent; i++) {
		total += exp(-float(i * i) / falloff);
	}
	// Half-resolution coordinates of this pixel, split into a texel and its bilinear weight.
	vec2 scaled = (pixel + vec2(0.5)) * 0.5 - vec2(0.5);
	vec2 base = floor(scaled);
	vec2 blend = scaled - base;
	// The downsample, horizontal pass and vertical pass each store RGBA8 bytes, so the
	// four texels around this pixel are blurred separately, horizontal pass first.
	vec3 texel_00 = vec3(0.0);
	vec3 texel_10 = vec3(0.0);
	vec3 texel_01 = vec3(0.0);
	vec3 texel_11 = vec3(0.0);
	for (int y = -extent; y <= extent + 1; y++) {
		vec3 row_0 = vec3(0.0);
		vec3 row_1 = vec3(0.0);
		for (int x = -extent; x <= extent + 1; x++) {
			vec3 texel = unorm8(scoped_box((base + vec2(float(x), float(y))) * 2.0 + vec2(1.0), viewport, radius));
			row_0 += (x <= extent ? exp(-float(x * x) / falloff) : 0.0) * texel;
			row_1 += (x > -extent ? exp(-float((x - 1) * (x - 1)) / falloff) : 0.0) * texel;
		}
		row_0 = unorm8(row_0 / total);
		row_1 = unorm8(row_1 / total);
		float weight_0 = y <= extent ? exp(-float(y * y) / falloff) : 0.0;
		float weight_1 = y > -extent ? exp(-float((y - 1) * (y - 1)) / falloff) : 0.0;
		texel_00 += weight_0 * row_0;
		texel_10 += weight_0 * row_1;
		texel_01 += weight_1 * row_0;
		texel_11 += weight_1 * row_1;
	}
	// Bilinear weights here are quarters, so byte-scaled sums are exact; the browser's
	// upscale rounds their halves down.
	vec3 top = mix(round(unorm8(texel_00 / total) * 255.0), round(unorm8(texel_10 / total) * 255.0), blend.x);
	vec3 bottom = mix(round(unorm8(texel_01 / total) * 255.0), round(unorm8(texel_11 / total) * 255.0), blend.x);
	return ceil(mix(top, bottom, blend.y) - vec3(0.5)) / 255.0;
}

void fragment() {
	vec2 viewport = max(viewport_size, vec2(1.0));
	float vmin = min(viewport.x, viewport.y) / 100.0;
	float distance_px = length((UV - vec2(0.5)) * viewport);
	float radius = radius_vmin * vmin;
	vec2 pixel = floor(UV * viewport);
	vec3 rgb = scope_color(textureLod(screen_texture, SCREEN_UV, 0.0).rgb, distance_px, radius, pixel);
	// CSS ellipse gradients use the farthest corner as the final stop.
	float ellipse = length((UV - vec2(0.5)) * sqrt(2.0));
	vec4 fire = ellipse <= fire_stops.y
		? gradient_mix(fire_color_0, fire_color_1, (ellipse - fire_stops.x) / max(0.000001, fire_stops.y - fire_stops.x))
		: gradient_mix(fire_color_1, fire_color_2, (ellipse - fire_stops.y) / max(0.000001, fire_stops.z - fire_stops.y));
	// Blur and gradient belong to one element, so its opacity applies to the group.
	if (fire_opacity > 0.0) {
		if (fire_blur > 0.0) {
			// The filtered backdrop and the gradient form an RGBA8 render surface first.
			vec3 group = composite(unorm8(backdrop_blur(SCREEN_UV, viewport, radius)), gradient_tile(fire, 1.0, pixel));
			// The opacity-scaled group is stored as bytes before it blends over the page.
			rgb = unorm8(unorm8(group * fire_opacity) + rgb * (1.0 - fire_opacity));
		} else {
			rgb = composite(rgb, gradient_tile(fire, fire_opacity, pixel));
		}
	}
	float weather_position = scoped ? distance_px / vmin : ellipse;
	float weather_middle = scoped ? weather_inner_vmin : weather_stops.x;
	float weather_end = scoped ? radius_vmin : weather_stops.y;
	vec4 weather = weather_position <= weather_middle
		? gradient_mix(weather_color_0, weather_color_1, weather_position / max(0.000001, weather_middle))
		: gradient_mix(weather_color_1, weather_color_2, (weather_position - weather_middle) / max(0.000001, weather_end - weather_middle));
	rgb = composite(rgb, gradient_tile(weather, weather_opacity, pixel));
	COLOR = vec4(rgb, 1.0);
}
