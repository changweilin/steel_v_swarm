class_name ScopeState
extends RefCounted

var fire_dwell := 0.0
var fire_fog := 0.0
var weather_fog := 0.0

func advance(delta: float, in_fire: bool, weather: float, alive: bool = true) -> void:
	if not alive:
		clear()
		return
	var rules: Dictionary = Content.balance.view
	var terrain: Dictionary = Content.constants.TERRAIN_FX
	fire_dwell = maxf(0, fire_dwell + delta * (1.0 if in_fire else -float(rules.fogRecovery)))
	fire_fog = clampf((fire_dwell - float(terrain.FIRE_FOG_S)) / (float(terrain.FIRE_FOG_MAX_S) - float(terrain.FIRE_FOG_S)), 0, 1)
	weather_fog = clampf(weather, 0, 1)

func clear() -> void:
	fire_dwell = 0
	fire_fog = 0
	weather_fog = 0

static func radius_vmin(fire: float, weather: float) -> float:
	var scope: Dictionary = Content.constants.SCOPE
	var multiplier := 1 - (1 - float(Content.constants.FOG_SIGHT.MIN_MULT)) * normalized_density(weather)
	return (float(scope.R_VMIN) - normalized_density(fire) * (float(scope.R_VMIN) - float(scope.FOG_R_VMIN))) * multiplier

func radius(viewport: Vector2) -> float:
	return radius_vmin(fire_fog, weather_fog) / 100.0 * minf(viewport.x, viewport.y)

static func weather_stops(density: float) -> Vector2:
	var stops := weather_stop_components(density)
	return Vector2(stops[0], stops[1])

static func weather_stop_components(density: float) -> Array:
	var config: Dictionary = Content.constants.WEATHER_FOG_MASK
	var multiplier := 1 - (1 - float(Content.constants.FOG_SIGHT.MIN_MULT)) * normalized_density(density)
	var start: float = config.R0_CLEAR + config.R0_SPAN * multiplier
	return [start, minf(1, start + float(config.R1_PAD))]

static func normalized_density(value: float) -> float:
	# Source formulas use `value || 0` before clamping.
	return clampf(0.0 if is_nan(value) else value, 0.0, 1.0)

static func fov_step(current: float, wanted: float, delta: float) -> float:
	var rules: Dictionary = Content.balance.view
	return current + (wanted - current) * (1 - exp(-maxf(0.0, float(rules.fovSpeed)) * maxf(0.0, delta))) if absf(current - wanted) > rules.fovSnap else wanted

static func aim_blend(fov: float, base_fov: float, zoom_fov: float) -> float:
	var span := base_fov - zoom_fov
	return clampf((base_fov - fov) / span, 0, 1) if span > 0 else 0.0
