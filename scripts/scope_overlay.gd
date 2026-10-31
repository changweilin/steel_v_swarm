class_name ScopeOverlay
extends ColorRect

var fire_opacity := 0.0:
	set(value):
		fire_opacity = value
		if shader_material != null:
			shader_material.set_shader_parameter("fire_opacity", value)
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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/scope_mask.gdshader")
	material = shader_material
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
	shader_material.set_shader_parameter("radius_vmin", CssDecimal.fixed(radius, 1))
	if weather > 0:
		var inner := maxf(float(rules.weatherInnerMinimum), radius - float(rules.weatherInnerInset))
		var stops := ScopeState.weather_stop_components(weather)
		# The source keeps the last gradient while its opacity fades to zero.
		shader_material.set_shader_parameter("weather_inner_vmin", CssDecimal.fixed(inner, 1))
		shader_material.set_shader_parameter("weather_stops", Vector2(CssDecimal.fixed(stops[0] * 100, 1) / 100,
			CssDecimal.fixed(stops[1] * 100, 1) / 100))
	shader_material.set_shader_parameter("viewport_size", size)
	shader_material.set_shader_parameter("scoped", scoped)
	shader_material.set_shader_parameter("fire_opacity", fire_opacity)
	shader_material.set_shader_parameter("weather_opacity", weather_opacity)
	shader_material.set_shader_parameter("fire_blur", CssDecimal.fixed(fire * float(rules.blurPixels), 2))
	visible = scoped or fire_opacity > 0 or weather_opacity > 0 or fire_target > 0 or weather_target > 0

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
	visible = scope_active or fire_target > 0 or weather_target > 0
