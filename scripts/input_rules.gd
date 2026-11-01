class_name InputRules
extends RefCounted

static func hold_slot(defending: bool) -> String:
	return Content.balance.controls.holdSlots[1 if defending else 0]

static func movement_basis(yaw: float, pitch: float, flight: bool, level_move: bool) -> Basis:
	var basis := Basis(Vector3.UP, yaw)
	if flight and not level_move:
		basis *= Basis(Vector3.RIGHT, pitch)
	return basis

static func moving(command: Dictionary) -> bool:
	return float(command.get("move_mag", command.get("move", Vector2.ZERO).length())) > 0.02 or command.get("jump_held", false) or absf(float(command.get("vertical", 0))) > 0

static func numpad(keys: Dictionary) -> Vector2:
	var yaw := int(keys.get("Numpad4", false)) - int(keys.get("Numpad6", false)) + int(keys.get("Numpad7", false)) - int(keys.get("Numpad9", false)) + int(keys.get("Numpad1", false)) - int(keys.get("Numpad3", false))
	var pitch := int(keys.get("Numpad8", false)) - int(keys.get("Numpad2", false)) + int(keys.get("Numpad7", false)) - int(keys.get("Numpad1", false)) + int(keys.get("Numpad9", false)) - int(keys.get("Numpad3", false))
	return Vector2(yaw, pitch)

static func look(yaw: float, pitch: float, change: Vector2, frozen: bool, invert_x: bool = false, invert_y: bool = false, system: bool = false) -> Vector2:
	if frozen:
		return Vector2(yaw, pitch)
	var limit: float = Content.balance.controls.pitchLimit
	return Vector2(yaw + change.x * (-1 if invert_x and not system else 1),
		clampf(pitch + change.y * (-1 if invert_y and not system else 1), -limit, limit))
