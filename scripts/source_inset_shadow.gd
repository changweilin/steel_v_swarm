class_name SourceInsetShadow
extends Node

# Chromium's coverage for `box-shadow: inset 0 0 <blur> <spread>` on an unrounded box
# that fills the viewport. Blink fills the box outset by the blur minus its spread hole
# with a blur mask filter (sigma = blur / 2), clipped to the box. The compositor rasters
# that per GPU tile, and Skia's Ganesh blurs each tile's mask separately:
#   - the mask covers the shape and the tile clip, both outset by 3 sigma, in an
#     approx-fit A8 target;
#   - above sigma 4 it rescales by halves to floor(size * 4 / sigma), with one border
#     texel downscaled straight from the mask's outer rows and columns;
#   - horizontal then vertical Gaussians store bytes, and a bilinear draw re-expands them.
# `texture` holds the resulting coverage byte per viewport pixel in every channel.

const SHADER := preload("res://shaders/source_mask_blur.gdshader")
const MAX_LINEAR_SIGMA := 4.0
const BORDER_TEXELS := 1
const GPU_TILE_ROUND_UP := 32
const MIN_GPU_TILE_HEIGHT := 256
const MAX_TARGET_SIZE := 8192

var texture: ViewportTexture
var _viewports: Array[SubViewport] = []

# Builds the pass chain for one viewport size. Returns false and leaves no texture when
# the source path is not the GPU mask blur this helper reproduces.
func build(size: Vector2i, blur: float, spread: float) -> bool:
	release()
	var result := plan(size, blur, spread)
	if not result.ok:
		push_error("Unsupported source inset shadow: " + String(result.error))
		return false
	for item: Dictionary in result.passes:
		var viewport := SubViewport.new()
		viewport.size = item.size
		viewport.disable_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var rects: Array = item.get("rects", [{"position": Vector2i.ZERO, "size": item.size, "uniforms": item.uniforms}])
		for rect: Dictionary in rects:
			var canvas := ColorRect.new()
			canvas.position = Vector2(rect.position)
			canvas.size = Vector2(rect.size)
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("target_size", Vector2(rect.size))
			for key: String in rect.uniforms:
				var value: Variant = rect.uniforms[key]
				if key == "source" or key == "edge_source":
					value = _viewports[int(value)].get_texture()
				material.set_shader_parameter(key, value)
			canvas.material = material
			viewport.add_child(canvas)
		_viewports.append(viewport)
	texture = _viewports[-1].get_texture()
	return true

func release() -> void:
	for viewport in _viewports:
		viewport.free()
	_viewports.clear()
	texture = null

# cc TilingData rows for a full-viewport GPU-rastered layer: tiles span the width, are
# max(round_up(ceil(height / 4) + 2, 32), 256) tall and overlap by one border texel.
# Each entry is the display rows [x, y) and the raster clip rows [z, w).
static func tiles(size: Vector2i) -> Array[Vector4i]:
	var height := ceili(size.y / 4.0) + 2 * BORDER_TEXELS
	height = maxi(ceili(height / float(GPU_TILE_ROUND_UP)) * GPU_TILE_ROUND_UP, MIN_GPU_TILE_HEIGHT)
	var result: Array[Vector4i] = []
	if size.y <= height:
		result.append(Vector4i(0, size.y, 0, size.y))
		return result
	var inner := height - 2 * BORDER_TEXELS
	var low := 0
	var index := 0
	while low < size.y:
		var high := mini((index + 1) * inner + BORDER_TEXELS, size.y)
		result.append(Vector4i(low, high, maxi(low - BORDER_TEXELS, 0), mini(high + BORDER_TEXELS, size.y)))
		low = high
		index += 1
	return result

# Skia's approx-fit texture dimension (GrResourceProvider::MakeApprox).
static func approx_size(value: int) -> int:
	value = maxi(16, value)
	var ceil_pow2 := 1
	while ceil_pow2 < value:
		ceil_pow2 <<= 1
	if ceil_pow2 == value or value <= 1024:
		return ceil_pow2
	var floor_pow2 := ceil_pow2 >> 1
	var middle := floor_pow2 + (floor_pow2 >> 1)
	return middle if value <= middle else ceil_pow2

static func _f32(value: float) -> float:
	var packed := PackedFloat32Array([value])
	return packed[0]

static func _radius(sigma: float) -> int:
	return ceili(_f32(3.0 * sigma))

static func _rect(left: float, top: float, right: float, bottom: float) -> Vector4:
	return Vector4(left, top, right, bottom)

static func plan(size: Vector2i, blur: float, spread: float) -> Dictionary:
	if size.x <= 0 or size.y <= 0 or blur <= 0.0 or spread < 0.0:
		return {"ok": false, "error": "empty box, zero blur or negative spread"}
	var sigma := _f32(blur * 0.5)
	var sigma3 := ceili(_f32(3.0 * sigma))
	var outer := Rect2i(-ceili(blur), -ceili(blur), size.x + 2 * ceili(blur), size.y + 2 * ceili(blur))
	if float(ceili(blur)) != blur or float(ceili(spread)) != spread:
		return {"ok": false, "error": "fractional blur or spread"}
	var hole := _rect(spread, spread, size.x - spread, size.y - spread)
	if hole.z <= hole.x or hole.w <= hole.y:
		return {"ok": false, "error": "spread fills the box"}
	# Paths no larger than 64 px with sigma <= 32 are blurred on the CPU instead.
	if outer.size.x <= 64 and outer.size.y <= 64 and sigma <= 32.0:
		return {"ok": false, "error": "CPU mask blur"}
	var passes: Array[Dictionary] = []
	var copies: Array[Dictionary] = []
	for tile in tiles(size):
		var clip := Rect2i(0, tile.z, size.x, tile.w - tile.z)
		var left := maxi(outer.position.x, clip.position.x) - sigma3
		var top := maxi(outer.position.y, clip.position.y) - sigma3
		var right := mini(outer.end.x, clip.end.x) + sigma3
		var bottom := mini(outer.end.y, clip.end.y) + sigma3
		var mask_size := Vector2i(right - left, bottom - top)
		var texture_size := Vector2i(approx_size(mask_size.x), approx_size(mask_size.y))
		if texture_size.x > MAX_TARGET_SIZE or texture_size.y > MAX_TARGET_SIZE:
			return {"ok": false, "error": "mask exceeds the render target limit"}
		var offset := Vector4(left, top, left, top)
		passes.append({"size": texture_size, "uniforms": {"mode": 0, "content_size": Vector2(mask_size),
			"outer_rect": Vector4(outer.position.x, outer.position.y, outer.end.x, outer.end.y) - offset,
			"hole_rect": hole - offset}})
		var blurred := _blur(passes, passes.size() - 1, texture_size, Vector4i(0, 0, mask_size.x, mask_size.y),
			Vector4i(0, 0, texture_size.x, texture_size.y), Vector2(sigma, sigma))
		if not blurred.ok:
			return blurred
		copies.append({"position": Vector2i(0, tile.x), "size": Vector2i(size.x, tile.y - tile.x),
			"uniforms": {"mode": 4, "source": int(blurred.index), "mask_origin": Vector2i(-left, tile.x - top)}})
	passes.append({"size": size, "uniforms": {}, "rects": copies})
	return {"ok": true, "passes": passes}

# GrBlurUtils::GaussianBlur in clamp mode. `dst` and `src` are left, top, right, bottom
# in the source target's texels; appends passes and returns the index of the result.
static func _blur(passes: Array[Dictionary], source: int, source_size: Vector2i, dst: Vector4i, src: Vector4i, sigma: Vector2) -> Dictionary:
	var radius := Vector2i(_radius(sigma.x), _radius(sigma.y))
	var reach := Vector4i(dst.x - radius.x, dst.y - radius.y, dst.z + radius.x, dst.w + radius.y)
	src = Vector4i(maxi(reach.x, src.x), maxi(reach.y, src.y), mini(reach.z, src.z), mini(reach.w, src.w))
	if src.z <= src.x or src.w <= src.y or src.z - src.x == 1 or src.w - src.y == 1:
		return {"ok": false, "error": "degenerate blur source"}
	if sigma.x <= MAX_LINEAR_SIGMA and sigma.y <= MAX_LINEAR_SIGMA:
		# 25 x 25 texels exceed the 28-sample 2D kernel, so these always take two passes.
		if (2 * radius.x + 1) * (2 * radius.y + 1) <= 28:
			return {"ok": false, "error": "single-pass 2D blur kernel"}
		return _two_pass(passes, source, dst, src, sigma, radius)
	var width := src.z - src.x
	var height := src.w - src.y
	var scale := Vector2(_f32(MAX_LINEAR_SIGMA / sigma.x) if sigma.x > MAX_LINEAR_SIGMA else 1.0,
		_f32(MAX_LINEAR_SIGMA / sigma.y) if sigma.y > MAX_LINEAR_SIGMA else 1.0)
	var rescaled := Vector2i(maxi(floori(_f32(width * scale.x)), 1), maxi(floori(_f32(height * scale.y)), 1))
	scale = Vector2(_f32(float(rescaled.x) / width), _f32(float(rescaled.y) / height))
	var scaled_sigma := Vector2(_f32(sigma.x * scale.x), _f32(sigma.y * scale.y))
	# Repeated linear rescale: each step at most halves a dimension (rounding up).
	var current := source
	var current_rect := Vector4(src.x, src.y, src.z, src.w)
	var current_size := Vector2i(width, height)
	while true:
		var next := rescaled
		if current_size.x > rescaled.x:
			next.x = maxi((current_size.x + 1) / 2, rescaled.x)
		if current_size.y > rescaled.y:
			next.y = maxi((current_size.y + 1) / 2, rescaled.y)
		if next == rescaled:
			passes.append({"size": rescaled + Vector2i(2, 2), "uniforms": {"mode": 2, "source": current,
				"edge_source": source, "src_rect": current_rect, "subset_rect": current_rect,
				"dst_rect": Vector4(1, 1, 1 + rescaled.x, 1 + rescaled.y),
				"edge_bounds": Vector4(src.x, src.y, src.z, src.w)}})
			break
		passes.append({"size": next, "uniforms": {"mode": 1, "source": current, "src_rect": current_rect,
			"subset_rect": current_rect, "dst_rect": Vector4(0, 0, next.x, next.y)}})
		current = passes.size() - 1
		current_rect = Vector4(0, 0, next.x, next.y)
		current_size = next
	var padded := passes.size() - 1
	var bounds := Vector4(_f32(_f32((dst.x - src.x) * scale.x) + 1.0), _f32(_f32((dst.y - src.y) * scale.y) + 1.0),
		_f32(_f32((dst.z - src.x) * scale.x) + 1.0), _f32(_f32((dst.w - src.y) * scale.y) + 1.0))
	var bounds_i := Vector4i(floori(bounds.x), floori(bounds.y), ceili(bounds.z), ceili(bounds.w))
	var inner := _blur(passes, padded, rescaled + Vector2i(2, 2), bounds_i,
		Vector4i(0, 0, rescaled.x + 2, rescaled.y + 2), scaled_sigma)
	if not inner.ok:
		return inner
	var from := bounds - Vector4(bounds_i.x, bounds_i.y, bounds_i.x, bounds_i.y)
	passes.append({"size": Vector2i(dst.z - dst.x, dst.w - dst.y), "uniforms": {"mode": 1, "source": int(inner.index),
		"src_rect": from, "subset_rect": from, "dst_rect": Vector4(0, 0, dst.z - dst.x, dst.w - dst.y)}})
	return {"ok": true, "index": passes.size() - 1}

static func _two_pass(passes: Array[Dictionary], source: int, dst: Vector4i, src: Vector4i, sigma: Vector2, radius: Vector2i) -> Dictionary:
	# The horizontal pass covers the rows the vertical pass reaches, clamped to the source.
	var x_dst := Vector4i(maxi(dst.x, src.x - radius.x + 1), maxi(dst.y - radius.y, src.y),
		mini(dst.z, src.z + radius.x - 1), mini(dst.w + radius.y, src.w))
	if x_dst.z <= x_dst.x or x_dst.w <= x_dst.y:
		return {"ok": false, "error": "degenerate horizontal blur"}
	passes.append({"size": Vector2i(x_dst.z - x_dst.x, x_dst.w - x_dst.y), "uniforms": {"mode": 3, "source": source,
		"src_offset": Vector2i(x_dst.x, x_dst.y), "direction": Vector2i(1, 0), "radius": radius.x, "sigma": sigma.x,
		"clamp_bounds": src}})
	var x_pass := passes.size() - 1
	passes.append({"size": Vector2i(dst.z - dst.x, dst.w - dst.y), "uniforms": {"mode": 3, "source": x_pass,
		"src_offset": Vector2i(dst.x - x_dst.x, dst.y - x_dst.y), "direction": Vector2i(0, 1), "radius": radius.y,
		"sigma": sigma.y, "clamp_bounds": Vector4i(0, 0, x_dst.z - x_dst.x, x_dst.w - x_dst.y)}})
	return {"ok": true, "index": passes.size() - 1}
