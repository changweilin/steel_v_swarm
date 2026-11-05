class_name ScopeOverlay
extends ColorRect

var fire_opacity := 0.0:
	set(value):
		fire_opacity = value
		if shader_material != null:
			shader_material.set_shader_parameter("fire_opacity", value)
			for pass_material: ShaderMaterial in _pass_materials:
				pass_material.set_shader_parameter("fire_opacity", value)
			_sync_blur()
var weather_opacity := 0.0:
	set(value):
		weather_opacity = value
		if shader_material != null:
			shader_material.set_shader_parameter("weather_opacity", value)
var fire_target := 0.0
var weather_target := 0.0
var scope_active := false
var fire_tween: Tween
var weather_tween: Tween
var shader_material: ShaderMaterial
var fire_transition: Dictionary = {}
var weather_transition: Dictionary = {}
## Unscoped page behind the overlay, the same size as it. The blur passes cannot read the
## viewport that contains them, so without it the single-pass blur is used.
var page_texture: Texture2D:
	set(value):
		page_texture = value
		_sync_blur()
var _fire_blur := 0.0
## The chained targets read each other's previous draw, so the final pass keeps the
## single-pass blur until they have had this many frames to settle.
const BLUR_WARMUP_FRAMES := 3
var _blur_age := 0
var _blur_viewports: Array[SubViewport] = []
var _pass_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/scope_mask.gdshader")
	material = shader_material
	resized.connect(_sync_blur)
	set_process(false)
	var rules: Dictionary = Content.balance.view.mask
	shader_material.set_shader_parameter("ring_width", rules.ringWidth)
	shader_material.set_shader_parameter("ring_color", color_value(rules.ringColor))
	shader_material.set_shader_parameter("fire_stops", Vector3(rules.fireStops[0], rules.fireStops[1], rules.fireStops[2]))
	for index: int in range(3):
		shader_material.set_shader_parameter("fire_color_" + str(index), color_value(rules.fireColors[index]))
		shader_material.set_shader_parameter("weather_color_" + str(index), color_value(rules.weatherColors[index]))
	hide()

static func color_value(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3])

func update_view(state: ScopeState, scoped: bool) -> void:
	scope_active = scoped
	var rules: Dictionary = Content.balance.view.mask
	var fire := ScopeState.normalized_density(state.fire_fog)
	var weather := ScopeState.normalized_density(state.weather_fog)
	if fire_target != fire:
		fire_target = fire
		fire_tween = _start_fade("fire_opacity", fire_target, rules.fireTransition, fire_tween, fire_transition)
	if weather_target != weather:
		weather_target = weather
		weather_tween = _start_fade("weather_opacity", weather_target, rules.weatherTransition, weather_tween, weather_transition)
	var radius := ScopeState.radius_vmin(fire, weather)
	var radius_css := CssDecimal.fixed(radius, 1)
	_param("radius_vmin", radius_css)
	if weather > 0:
		var inner := maxf(float(rules.weatherInnerMinimum), radius - float(rules.weatherInnerInset))
		var stops := ScopeState.weather_stop_components(weather)
		# The source keeps the last gradient, including its mode and outer stop,
		# while its opacity fades to zero.
		_param("weather_retained", true)
		_param("weather_scoped", scoped)
		_param("weather_outer_vmin", radius_css)
		_param("weather_inner_vmin", CssDecimal.fixed(inner, 1))
		_param("weather_stops", Vector2(CssDecimal.fixed(stops[0] * 100, 1) / 100,
			CssDecimal.fixed(stops[1] * 100, 1) / 100))
	_param("viewport_size", size)
	_param("scoped", scoped)
	_param("fire_opacity", fire_opacity)
	_param("weather_opacity", weather_opacity)
	_param("fire_blur", CssDecimal.fixed(fire * float(rules.blurPixels), 2))
	_fire_blur = CssDecimal.fixed(fire * float(rules.blurPixels), 2)
	visible = scoped or fire_opacity > 0 or weather_opacity > 0 or fire_target > 0 or weather_target > 0
	_sync_blur()

func _param(parameter: String, value: Variant) -> void:
	shader_material.set_shader_parameter(parameter, value)
	for pass_material: ShaderMaterial in _pass_materials:
		pass_material.set_shader_parameter(parameter, value)

## Above sigma 4 the source blur runs as RGBA8 down, horizontal and vertical targets of the
## overlay's size; every pass keeps the overlay's pixel phase. Smaller overlays and the
## single-pass range keep the in-shader blur.
func split_wanted() -> bool:
	if page_texture == null or not is_inside_tree() or fire_opacity <= 0.0 or _fire_blur <= 4.0:
		return false
	var extent := ceili(1.5 * _fire_blur)
	var target := Vector2i(roundi(size.x), roundi(size.y))
	return target.x >= ceili(target.x / 2.0) + 2 * extent + 2 and target.y >= ceili(target.y / 2.0) + 2 * extent + 2

func _sync_blur() -> void:
	if shader_material == null:
		return
	if not split_wanted():
		_release_blur()
		return
	var target := Vector2i(roundi(size.x), roundi(size.y))
	var created := _blur_viewports.is_empty()
	if created:
		for pass_index: int in range(1, 4):
			var viewport := SubViewport.new()
			viewport.disable_3d = true
			viewport.transparent_bg = false
			viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
			viewport.name = ["scope_blur_down", "scope_blur_h", "scope_blur_v"][pass_index - 1]
			var pass_material := shader_material.duplicate() as ShaderMaterial
			pass_material.set_shader_parameter("pass", pass_index)
			pass_material.set_shader_parameter("blur_split", false)
			pass_material.set_shader_parameter("blur_source", page_texture if pass_index == 1 else _blur_viewports[pass_index - 2].get_texture())
			var rect := ColorRect.new()
			rect.material = pass_material
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			viewport.add_child(rect)
			add_child(viewport)
			_blur_viewports.append(viewport)
			_pass_materials.append(pass_material)
	var resized_targets := _blur_viewports[0].size != target
	for index: int in range(_blur_viewports.size()):
		_blur_viewports[index].size = target
		(_blur_viewports[index].get_child(0) as ColorRect).size = Vector2(target)
	_pass_materials[0].set_shader_parameter("blur_source", page_texture)
	shader_material.set_shader_parameter("blur_source", _blur_viewports[2].get_texture())
	if created or resized_targets:
		_blur_age = 0
		shader_material.set_shader_parameter("blur_split", false)
		set_process(true)

func _process(_delta: float) -> void:
	_blur_age += 1
	if _blur_age >= BLUR_WARMUP_FRAMES:
		shader_material.set_shader_parameter("blur_split", not _blur_viewports.is_empty())
		set_process(false)

func _release_blur() -> void:
	set_process(false)
	shader_material.set_shader_parameter("blur_split", false)
	shader_material.set_shader_parameter("blur_source", null)
	for viewport: SubViewport in _blur_viewports:
		remove_child(viewport)
		viewport.free()
	_blur_viewports.clear()
	_pass_materials.clear()

func _start_fade(property: String, target: float, seconds: float, previous: Tween, transition: Dictionary) -> Tween:
	var tween := preload("res://scripts/css_transition.gd").start(self, property, target, seconds, previous, transition, HurtFlashState._ease_out)
	if tween != null:
		tween.set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween

func clear() -> void:
	if fire_tween != null:
		fire_tween.kill()
	if weather_tween != null:
		weather_tween.kill()
	fire_opacity = 0
	weather_opacity = 0
	fire_target = 0
	weather_target = 0
	scope_active = false
	fire_transition.clear()
	weather_transition.clear()
	_release_blur()
	hide()

func _exit_tree() -> void:
	if fire_tween != null and fire_tween.is_valid():
		fire_tween.kill()
	if weather_tween != null and weather_tween.is_valid():
		weather_tween.kill()
	fire_tween = null
	weather_tween = null
	fire_transition.clear()
	weather_transition.clear()
	fire_opacity = fire_target
	weather_opacity = weather_target
	_release_blur()
	visible = scope_active or fire_target > 0 or weather_target > 0
