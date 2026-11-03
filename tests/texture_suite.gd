extends RefCounted

static func run(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("textureCases") or not fixtures.has("textureImageCapture"):
		h._check(false, "Regenerate original texture UV/wrapping/pixel references")
		return
	var images := SourceTextureImages.new()
	h._check(images.configure([fixtures.textureImageCapture]), "Decode original RGBA bytes without losing transparent RGB")
	await _manual_mips(h, fixtures)
	await _cel_samplers(h, fixtures)
	if not fixtures.get("textureRasters") is Dictionary:
		h._check(false, "Regenerate original WebGL sampler raster references separately from CPU transformUv")
		return
	var raster: Dictionary = fixtures.textureRasters
	var width := int(raster.get("width", 0))
	var height := int(raster.get("height", 0))
	var rows: Array = raster.get("rows", [])
	var raw: Dictionary = raster.get("rawSampling", {})
	var pixels: Array = raw.get("pixels", [])
	if width <= 0 or height != fixtures.textureCases.size() or rows.size() != height or pixels.size() != width * height * 4 or raw.get("colorSpaceOverride") != "none":
		h._check(false, "Original WebGL raw sampler atlas has complete rows/pixels and an explicit colour-space isolation pass")
		return
	for row_index in range(height):
		var fixture: Dictionary = fixtures.textureCases[row_index]
		var row: Dictionary = rows[row_index]
		if row.get("spec") != fixture.spec or row.get("points", []).size() != width or fixture.probes.size() != width:
			h._check(false, "Original sampler raster row matches the source texture declaration and probe count")
			continue
		var spec := SourceTextureImages.prepare(fixture.spec, fixture.rawUV)
		h._check(not spec.is_empty(), "Prepare original affine UV domain")
		if spec.is_empty():
			continue
		var texture := images.resolve(spec)
		h._check(texture != null, "Build native original texture image variant")
		if texture == null:
			continue
		h._check(images.resolve(spec) == texture, "Reuse original image/sampler variants across material surfaces")
		var material := StandardMaterial3D.new()
		h._check(SourceTextureImages.apply_sampling(material, spec), "Bind native nearest/clamp/repeat/mirror sampling")
		var image := texture.get_image()
		h._check(image != null and not image.is_empty(), "Native texture retains imported pixels")
		if image == null or image.is_empty():
			continue
		for probe_index in range(width):
			var probe: Dictionary = fixture.probes[probe_index]
			h._check(row.points[probe_index] == probe.point, "Original WebGL sampler atlas preserves probe order")
			var uv := SourceTextureImages.coordinates(Vector2(probe.point[0], probe.point[1]), spec)
			if material.texture_repeat:
				uv = Vector2(fposmod(uv.x, 1), fposmod(uv.y, 1))
			var x := clampi(floori(uv.x * image.get_width()), 0, image.get_width() - 1)
			var y := clampi(floori(uv.y * image.get_height()), 0, image.get_height() - 1)
			var pixel := image.get_pixel(x, y)
			for channel in range(4):
				var actual := float(pixel[channel])
				# CPU transformUv and the original GPU differ at nearest-filter ties.
				# Compare the adapter to actual source-renderer sampling, retaining the
				# independent CPU values only as diagnostics.
				var expected := float(pixels[(row_index * width + probe_index) * 4 + channel]) / 255.0
				var ok := absf(actual - expected) < .00001
				var description := "Original WebGL nearest sampler texels"
				if not ok:
					description = "Original WebGL sampler: spec=%s point=%s uv=%s xy=(%d,%d) ch=%d actual=%f gpu=%f cpu=%f" % [
						JSON.stringify(spec), str(probe.point), str(uv), x, y, channel, actual, expected, float(probe.rgba[channel])
					]
				h._check(ok, description)

static func _manual_mips(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.get("textureMipCases") is Array or fixtures.textureMipCases.is_empty():
		h._check(false, "Regenerate source Canvas2D authored mip references")
		return
	for fixture: Dictionary in fixtures.textureMipCases:
		var images := SourceTextureImages.new()
		if not images.configure([fixture.capture]):
			h._check(false, "Decode source authored mip chain: " + fixture.label)
			continue
		var original := images.images[0]
		h._check(original.get_mipmap_count() + 1 == fixture.levels.size(), "Preserve complete source authored mip chain")
		var cel := SourceCelData.new()
		h._check(cel.configure({"celSamplers": [{"kind": "image", "texture": fixture.spec}]}, images), "Cel sampler accepts captured authored levels")
		var cel_texture := cel.texture(0)
		h._check(cel_texture != null and cel_texture.get_image().get_mipmap_count() == original.get_mipmap_count(), "Cel sampler retains every authored level")
		if cel_texture != null:
			for level in range(original.get_mipmap_count() + 1):
				var raw := SourceTextureImages._source_level(original, level)
				var actual := await _gpu_level(h, cel_texture, level, raw.get_size())
				h._check(actual.get_data() == raw.get_data(), "Cel sampler retains raw authored mips without native regeneration")
		var texture := images.resolve(fixture.spec)
		h._check(texture != null, "Upload source authored mip chain: " + fixture.label)
		if texture == null:
			continue
		var uploaded := texture.get_image()
		h._check(uploaded != null and uploaded.get_mipmap_count() == original.get_mipmap_count(), "Native texture retains every authored level")
		if uploaded == null:
			continue
		for level in range(fixture.levels.size()):
			var expected: Dictionary = fixture.levels[level]
			var raw := SourceTextureImages._source_level(original, level)
			h._check(raw.get_data() == PackedByteArray(expected.bytes), "Original Canvas2D mip pixels remain byte exact")
			var actual := await _gpu_level(h, texture, level, raw.get_size())
			if fixture.spec.flipY:
				raw.flip_y()
			h._check(actual.get_data() == raw.get_data(), "Native upload flips each authored mip without downsampling")
		h._check(images.resolve(fixture.spec) == texture, "Reuse authored mip texture variants")
		h._check(fixture.get("nativeVariants") is Array and not fixture.nativeVariants.is_empty(), "Authored mip fixture requires original GPU sampling evidence")
		for variant: Dictionary in fixture.get("nativeVariants", []):
			var native := images.resolve(variant.spec)
			h._check(native != null, "Build authored mip mirror/repeat variant")
			if native == null:
				continue
			var image := native.get_image()
			h._check(image != null and image.get_mipmap_count() + 1 == variant.levels.size(), "Source GPU and native variant contain the same mip levels")
			if image == null or image.get_mipmap_count() + 1 != variant.levels.size():
				continue
			for level in range(variant.levels.size()):
				var expected: Dictionary = variant.levels[level]
				var size := Vector2i(maxi(image.get_width() >> level, 1), maxi(image.get_height() >> level, 1))
				var actual := await _gpu_level(h, native, level, size)
				h._check(actual.get_size() == Vector2i(expected.width, expected.height) and actual.get_data() == PackedByteArray(expected.bytes),
					"Native authored mip matches original GPU textureLod: %s level %d sampler %s" % [fixture.label, level, JSON.stringify(variant.spec)])

# GLES readback (ANGLE, WebGL) regenerates mips from level 0, so fetch each uploaded level on the GPU.
static func _gpu_level(h: Node, texture: Texture2D, level: int, size: Vector2i) -> Image:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type canvas_item;\nrender_mode unshaded, blend_disabled;\nuniform sampler2D source : filter_nearest_mipmap;\nuniform int level;\nvoid fragment() { COLOR = texelFetch(source, ivec2(FRAGCOORD.xy), level); }\n"
	material.set_shader_parameter("source", texture)
	material.set_shader_parameter("level", level)
	rect.material = material
	viewport.add_child(rect)
	h.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.free()
	image.convert(Image.FORMAT_RGBA8)
	# Viewports below a minimum size are padded; keep only the fetched level.
	return image.get_region(Rect2i(Vector2i.ZERO, size))

# Writes the float32 bits each texel channel samples as, four output pixels per texel.
static func _gpu_bits(h: Node, texture: Texture2D, size: Vector2i) -> PackedByteArray:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size.x * 4, size.y)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type canvas_item;\nrender_mode unshaded, blend_disabled;\nuniform sampler2D source : filter_nearest;\nvoid fragment() {\n\tivec2 pixel = ivec2(FRAGCOORD.xy);\n\tuint bits = floatBitsToUint(texelFetch(source, ivec2(pixel.x / 4, pixel.y), 0)[pixel.x % 4]);\n\tCOLOR = vec4(uvec4(bits, bits >> 8u, bits >> 16u, bits >> 24u) & uvec4(255u)) / 255.0;\n}\n"
	material.set_shader_parameter("source", texture)
	rect.material = material
	viewport.add_child(rect)
	h.add_child(viewport)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.free()
	image.convert(Image.FORMAT_RGBA8)
	return image.get_region(Rect2i(Vector2i.ZERO, Vector2i(size.x * 4, size.y))).get_data()

static func _cel_samplers(h: Node, fixtures: Dictionary) -> void:
	if not fixtures.has("celSamplerCases") or not fixtures.has("celSamplerBundle"):
		h._check(false, "Regenerate original cel ramp and Three typed data sampler references")
		return
	var bundle := SourceCelData.new()
	if not bundle.configure(fixtures.celSamplerBundle, SourceTextureImages.new()):
		h._check(false, "Decode original native cel sampler formats")
		return
	for fixture: Dictionary in fixtures.celSamplerCases:
		var index := int(fixture.index)
		var image: Image = bundle.sampler_images[index]
		h._check(image.get_width() == int(fixture.width) and image.get_height() == int(fixture.height), "Original cel sampler dimensions: " + fixture.label)
		h._check(image.get_data() == PackedByteArray(fixture.bytes), "Cel sampler storage retains every byte, including float signed zero and half subnormals")
		h._check(bundle.sampling(index) == fixture.sampling, "Original cel sampler keeps its own colour space, filtering, wrap and UV declarations")
		for pixel in range(fixture.rgba.size()):
			var actual := image.get_pixel(pixel % int(fixture.width), pixel / int(fixture.width))
			for channel in range(4):
				var expected := float(fixture.rgba[pixel][channel])
				h._check(absf(actual[channel] - expected) <= maxf(absf(expected) * .000001, .000000000001),
					"Native byte/half/float channels match original Three decoding without byte quantization")
		var texture := bundle.texture(index)
		h._check(texture != null and texture == bundle.texture(index), "Original cel sampler texture is shared within its immutable bundle")
		if texture != null:
			var expected := PackedFloat32Array()
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var color := image.get_pixel(x, y)
					expected.append_array([color.r, color.g, color.b, color.a])
			var fetched := await _gpu_bits(h, texture, image.get_size())
			h._check(fetched == expected.to_byte_array(), "Native cel texture retains the captured channel precision")
