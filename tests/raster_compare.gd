extends RefCounted

static func compare(actual: Image, expected: Image, tolerance: float = 2.0 / 255) -> Dictionary:
	assert(actual.get_size() == expected.get_size(), "Raster comparison requires matching dimensions")
	# Compare exact stored bytes. Color's Float32 channels would turn a two-byte
	# difference into 0.00784316... which exceeds the double 2/255 tolerance.
	var limit := roundi(tolerance * 255.0)
	var maximum := 0
	var mismatched := 0
	var a_bytes := _rgba8(actual)
	var b_bytes := _rgba8(expected)
	for offset in range(0, b_bytes.size(), 4):
		# Native offscreen buffers use premultiplied RGB; browser PNGs use straight RGB.
		var alpha := b_bytes[offset + 3]
		var error := absi(a_bytes[offset + 3] - alpha)
		for channel in range(3):
			# Integer round-half-up of straight * alpha / 255 (the premultiplied byte).
			var premultiplied := (b_bytes[offset + channel] * alpha * 2 + 255) / 510
			error = maxi(error, absi(a_bytes[offset + channel] - premultiplied))
		maximum = maxi(maximum, error)
		if error > limit:
			mismatched += 1
	return {"pixels": mismatched, "maximum": float(maximum) / 255.0}

static func _rgba8(image: Image) -> PackedByteArray:
	var copy := image.duplicate() as Image
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	return copy.get_data()

static func diagnostic(actual: Image) -> Image:
	var result := actual.duplicate() as Image
	for y in range(result.get_height()):
		for x in range(result.get_width()):
			var value := result.get_pixel(x, y)
			if value.a > 0:
				result.set_pixel(x, y, Color(value.r / value.a, value.g / value.a, value.b / value.a, value.a))
	return result
