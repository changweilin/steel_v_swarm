class_name CarrierRules
extends RefCounted

# Scalar source coordinates avoid float32 drift before the native scene boundary.
static func parts(kind: String, effect: String) -> int:
	if effect not in ["strike", "heal", "summon"]:
		return 1
	return int(Content.constants.SQUAD.KAMI.N) if kind == "drone" else int(Content.constants.DECOY.BOMB_MAX) if kind == "morph" else 1

static func integer_part(total: float, count: int, index: int) -> int:
	return int(floorf(total * (index + 1) / count + 0.5) - floorf(total * index / count + 0.5))

static func side(index: int) -> float:
	var count: int = maxi(1, int(Content.constants.SQUAD.KAMI.N))
	return 0.0 if count == 1 else (index - (count - 1) / 2.0) / ((count - 1) / 2.0)

static func turn_delta(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

static func hypot2(x: float, z: float) -> float:
	# Preserve the captured V8 two-argument Math.hypot rounding at the dive apex.
	return SourceNumeric.hypot(x, z)

static func destination(origin: Dictionary, x: float, z: float, yaw: float) -> Dictionary:
	var dx: float = x - origin.x
	var dz: float = z - origin.z
	var distance := hypot2(dx, dz)
	var minimum: float = Content.constants.ATK_CARRIER.MIN_LEG
	if distance < minimum:
		var ux := dx / distance if distance > 1 else -sin(yaw)
		var uz := dz / distance if distance > 1 else cos(yaw)
		x = origin.x + ux * minimum
		z = origin.z + uz * minimum
	return {"x": x, "z": z, "distance": distance, "yaw": atan2(-(x - origin.x), z - origin.z)}

static func advance(state: Dictionary, delta: float, now: float, target: Dictionary = {}) -> Dictionary:
	var outcome := {"arrivals": [], "remove": false}
	match state.kind:
		"kami":
			var rule: Dictionary = Content.constants.SQUAD.KAMI
			var dx: float = state.tx - state.x
			var dz: float = state.tz - state.z
			if now >= state.die_at or sqrt(dx * dx + dz * dz + state.y * state.y) <= rule.BOOM_M:
				outcome.arrivals.append({"x": state.x, "z": state.z, "fraction": state.fraction, "count": state.count})
				outcome.remove = true
				return outcome
			var speed: float = Content.constants.UNITS.drone.speed * rule.SPEED_MUL
			state.yaw += clampf(turn_delta(atan2(-dx, dz) - state.yaw), -rule.TURN * delta, rule.TURN * delta)
			state.y += clampf(-state.y, -speed * delta, speed * delta)
			state.x += -sin(state.yaw) * speed * delta
			state.z += cos(state.yaw) * speed * delta
			state.y = maxf(0, state.y)
		"decoy":
			var rule: Dictionary = Content.constants.DECOY
			if now >= state.die_at:
				outcome.remove = true
				return outcome
			var dx: float = state.tx - state.x
			var dz: float = state.tz - state.z
			if not state.drops.is_empty() and now >= state.next_bomb and sqrt(dx * dx + dz * dz) <= rule.BOMB_R:
				var part: Dictionary = state.drops.pop_front()
				outcome.arrivals.append({"x": state.tx, "z": state.tz, "fraction": part.fraction, "count": part.count})
				state.next_bomb = now + rule.BOMB_GAP
				if state.drops.is_empty():
					state.die_at = minf(state.die_at, now + 1.5)
			state.yaw += clampf(turn_delta(atan2(-dx, dz) - state.yaw), -rule.TURN * delta, rule.TURN * delta)
			state.x += -sin(state.yaw) * rule.SPEED * delta
			state.z += cos(state.yaw) * rule.SPEED * delta
		"hyper":
			if now < state.get("launch_at", 0):
				return outcome
			if target.is_empty():
				state.target = 0
			if state.chase and not target.is_empty():
				state.tx = target.x
				state.tz = target.z
			var rule: Dictionary = Content.constants.HYPER
			if state.phase == "climb":
				state.travel = minf(state.distance, state.travel + rule.CLIMB_SPD * cos(deg_to_rad(rule.LAUNCH_DEG)) * delta)
				var fraction: float = state.travel / state.distance
				state.x = state.x0 + state.ux * state.travel
				state.z = state.z0 + state.uz * state.travel
				state.y = state.y0 + state.distance * tan(deg_to_rad(rule.LAUNCH_DEG)) / 2 * fraction * (2 - fraction)
				if fraction >= 1:
					state.phase = "dive"
					state.dive = {"x": state.x, "y": state.y, "z": state.z}
					state.travel = 0.0
					var radius: float = Content.constants.UNITS.tower.range * rule.TRACK_R_F
					state.chase = not target.is_empty() and sqrt(pow(target.x - state.tx, 2) + pow(target.z - state.tz, 2)) <= radius
					if not state.chase:
						state.target = 0
				return outcome
			var ty: float = target.get("height", 0)
			var dx: float = state.tx - state.dive.x
			var dz: float = state.tz - state.dive.z
			var dy: float = ty - state.dive.y
			var length := sqrt(dx * dx + dz * dz + dy * dy)
			if not length:
				length = 1.0
			state.travel += rule.CLIMB_SPD * rule.DIVE_F * delta
			var fraction: float = minf(1, state.travel / length)
			state.spin += rule.SPIN_RPS * TAU * delta
			var radius: float = rule.SPIRAL_R * (1 - fraction)
			var cosine := cos(state.spin) * radius
			var sine := sin(state.spin) * radius
			state.x = state.dive.x + dx * fraction + state.uz * cosine + state.ux * sine
			state.z = state.dive.z + dz * fraction - state.ux * cosine + state.uz * sine
			state.y = maxf(0, state.dive.y + dy * fraction)
			state.yaw = atan2(-dx, dz)
			if fraction >= 1:
				outcome.arrivals.append({"x": state.x, "z": state.z, "fraction": state.fraction, "count": state.count})
				outcome.remove = true
	return outcome
