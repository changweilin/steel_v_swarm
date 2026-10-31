extends RefCounted

const BYTE_FORMATS := [Image.FORMAT_L8, Image.FORMAT_LA8, Image.FORMAT_R8, Image.FORMAT_RG8, Image.FORMAT_RGB8, Image.FORMAT_RGBA8]

## Compares in 8-bit channel units when both images are byte buffers, so a tolerance of two
## bytes is not decided by Float32 rounding of the normalized difference. Other formats keep
## the normalized comparison.
static func compare(actual: Image, expected: Image, tolerance: float = 2.0 / 255) -> Dictionary:
	assert(actual.get_size() == expected.get_size(), "Raster comparison requires matching dimensions")
	var bytes: bool = actual.get_format() in BYTE_FORMATS and expected.get_format() in BYTE_FORMATS
	var scale := 255.0 if bytes else 1.0
	var limit := snappedf(tolerance * scale, 0.000001)
	var maximum := 0.0
	var mismatched := 0
	for y in range(expected.get_height()):
		for x in range(expected.get_width()):
			var a := actual.get_pixel(x, y)
			var b := expected.get_pixel(x, y)
			var error := 0.0
			# Native offscreen buffers use premultiplied RGB; browser PNGs use straight RGB.
			if bytes:
				var alpha := float(b.a8)
				error = maxf(absf(a.a8 - alpha), maxf(absf(a.r8 - b.r8 * alpha / 255.0),
					maxf(absf(a.g8 - b.g8 * alpha / 255.0), absf(a.b8 - b.b8 * alpha / 255.0))))
			else:
				error = maxf(absf(a.a - b.a), maxf(absf(a.r - b.r * b.a),
					maxf(absf(a.g - b.g * b.a), absf(a.b - b.b * b.a))))
			maximum = maxf(maximum, error)
			if error > limit + 0.000001:
				mismatched += 1
	return {"pixels": mismatched, "maximum": maximum / scale}

static func diagnostic(actual: Image) -> Image:
	var result := actual.duplicate() as Image
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var value := result.get_pixel(x, y)
			if value.a > 0:
				result.set_pixel(x, y, Color(value.r / value.a, value.g / value.a, value.b / value.a, value.a))
	return result
