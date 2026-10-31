extends RefCounted

# Compare exact RGBA8 bytes: normalized Float32 channel differences can exceed a
# whole-byte tolerance such as 2/255 even when the byte difference is within it.
static func compare(actual: Image, expected: Image, tolerance: float = 2.0 / 255) -> Dictionary:
	assert(actual.get_size() == expected.get_size(), "Raster comparison requires matching dimensions")
	var a_bytes := _bytes(actual)
	var b_bytes := _bytes(expected)
	var allowed := int(roundf(tolerance * 255.0))
	var maximum := 0
	var mismatched := 0
	for offset in range(0, mini(a_bytes.size(), b_bytes.size()), 4):
		var alpha := absi(a_bytes[offset + 3] - b_bytes[offset + 3])
		# Native offscreen buffers use premultiplied RGB; browser PNGs use straight RGB.
		# The straight channel is scaled by alpha/255, so differences are in 1/255 byte units.
		var colour := 0
		for channel in range(3):
			colour = maxi(colour, absi(a_bytes[offset + channel] * 255 - b_bytes[offset + channel] * b_bytes[offset + 3]))
		var error := maxi(alpha * 255, colour)
		maximum = maxi(maximum, error)
		if error > allowed * 255:
			mismatched += 1
	return {"pixels": mismatched, "maximum": float(maximum) / (255.0 * 255.0)}

static func _bytes(image: Image) -> PackedByteArray:
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
