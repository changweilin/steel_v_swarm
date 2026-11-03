extends Control

var state: Dictionary = {}
var map_data: Dictionary = {}
var side := "STEEL"
var missile_points: Array = []
var near := false
var focus := Vector2.ZERO
var hero_kind := ""
var window := Rect2()
var canvas: Control
var markers := MinimapMarkerState.new()
var positions: Dictionary = {}
var own_id := 0
var heading := 0.0
var cadence := MinimapCadence.new()
var draw_enabled := false
var draw_frame: Dictionary = {}
var mode_font: SystemFont
var base_texture: Texture2D
var base_canvas: Control
var lane_view: MinimapLanes
var vision := MinimapVision.new()
var fog_view: MinimapFog
var view_peer := 0
var view_dead := true
var aiming := false
var weather_fog := 0.0

func _ready() -> void:
	base_canvas = Control.new()
	base_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(base_canvas)
	base_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base_canvas.draw.connect(_draw_base)
	fog_view = MinimapFog.new()
	base_canvas.add_child(fog_view)
	lane_view = MinimapLanes.new()
	base_canvas.add_child(lane_view)
	lane_view.hide()
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_map)

func configure(map: Dictionary, allegiance: String, base: Texture2D = null) -> void:
	clear()
	map_data = map
	base_texture = base
	side = allegiance
	if MinimapWindow.available():
		var dimensions: Array = Content.balance.minimap.canvas
		size = Vector2(dimensions[0], dimensions[1])
		cadence.configure(float(Time.get_ticks_msec()) / 1000.0)
		if not Session.dedicated:
			fog_view.configure(size)
	clip_contents = true
	queue_redraw()

func clear() -> void:
	map_data = {}
	base_texture = null
	side = ""
	near = false
	focus = Vector2.ZERO
	hero_kind = ""
	state = {}
	missile_points.clear()
	markers.bunkers.clear()
	vision.clear()
	positions.clear()
	own_id = 0
	heading = 0
	view_peer = 0
	view_dead = true
	aiming = false
	weather_fog = 0
	draw_enabled = false
	draw_frame.clear()
	cadence.invalidate()
	if fog_view != null:
		fog_view.clear()
	if lane_view != null:
		lane_view.clear()
		lane_view.hide()
	queue_redraw()
	if canvas != null:
		canvas.queue_redraw()
		base_canvas.queue_redraw()

func toggle_mode() -> String:
	near = not near
	cadence.invalidate()
	return Content.balance.minimap.notices["near" if near else "full"]

func advance(now: float) -> bool:
	if map_data.is_empty() or not MinimapWindow.available() or not cadence.advance(now):
		return false
	draw_enabled = true
	var terrain: Dictionary = map_data.bounds.duplicate()
	var precise := MinimapWindow.components(terrain, near, focus, hero_kind)
	window = MinimapWindow.rectangle(precise)
	var units: Array = []
	for unit: Dictionary in state.get("units", []):
		var captured := unit.duplicate()
		if captured.get("special") is Dictionary:
			captured.special = captured.special.duplicate()
		units.append(captured)
	# One source draw commits its window and inputs before later UI/snapshot events.
	draw_frame = {"window": window, "window_components": precise, "terrain": terrain,
		"size": size, "near": near, "focus": focus, "side": side,
		"heading": heading, "own_id": own_id, "kind": hero_kind, "peer": view_peer,
		"dead": view_dead, "aiming": aiming, "fog": weather_fog, "pulse_until": vision.pulse_until,
		"units": units, "positions": positions.duplicate(), "bunkers": markers.bunkers.values().duplicate(true),
		"missiles": missile_points.duplicate()}
	lane_view.update_window(window, size, precise)
	lane_view.show()
	base_canvas.queue_redraw()
	canvas.queue_redraw()
	return true

func update_fog(now: float, columns: Array, shared_blockers: SourceBlockerQuery = null) -> void:
	if draw_frame.is_empty():
		return
	# The caller updates interpolated model positions between advance and this call.
	draw_frame.positions = positions.duplicate()
	var rows: Array = []
	if not String(draw_frame.side).is_empty():
		for unit: Dictionary in draw_frame.units:
			var point: Vector3 = draw_frame.positions.get(int(unit.id), unit.position)
			rows.append({"kind": unit.kind, "side": unit.side, "hero": not String(unit.character).is_empty(),
				"self": int(unit.id) == int(draw_frame.own_id), "peer": unit.peer, "hp": unit.hp, "dead": bool(unit.get("dead", float(unit.hp) <= 0)),
				"decoy": unit.kind == "decoy", "lost": unit.get("special", {}).get("lost", false),
				"point": Vector2(point.x, point.z)})
	var view := {"side": draw_frame.side, "peer": draw_frame.peer, "kind": draw_frame.kind, "dead": draw_frame.dead,
		"aiming": draw_frame.aiming, "fog": draw_frame.fog, "point": draw_frame.focus}
	fog_view.update_view(MinimapVision.sources(rows, view) if not String(draw_frame.side).is_empty() else [],
		draw_frame.terrain, draw_frame.window, draw_frame.side, now < float(draw_frame.pulse_until), columns, shared_blockers, draw_frame.window_components)

func accept_snapshot(snapshot: Dictionary) -> void:
	state = snapshot
	side = snapshot.get("vision_side", side)
	markers.remember(snapshot.get("units", []))
	for event: Dictionary in snapshot.get("events", []):
		vision.observe(event, side, float(Time.get_ticks_msec()) / 1000.0)

func _draw() -> void:
	if map_data.is_empty() or not MinimapWindow.available():
		return
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))

func _draw_base() -> void:
	if not draw_enabled or map_data.is_empty() or not MinimapWindow.available():
		return
	if base_texture != null:
		base_canvas.draw_texture_rect_region(base_texture, Rect2(Vector2.ZERO, draw_frame.size),
			MinimapWindow.texture_region(draw_frame.terrain, draw_frame.window, base_texture.get_size(), draw_frame.window_components))

func _draw_map() -> void:
	if not draw_enabled or map_data.is_empty() or not MinimapWindow.available():
		return
	var commands := _commands_for(draw_frame, draw_frame.positions)
	# Source missiles precede the own-view arrow and follow the retained bunkers.
	var arrow: Dictionary = commands.pop_back() if not String(draw_frame.side).is_empty() else {}
	for command: Dictionary in commands:
		_draw_marker(command)
	if not draw_frame.missiles.is_empty():
		var marker: Dictionary = Content.balance.missile.presentation.minimap
		var extent := Vector2(marker.size[0], marker.size[1])
		var color := Color.hex((int(marker.color) << 8) | 0xff)
		for point: Vector3 in draw_frame.missiles:
			canvas.draw_rect(_missile_rect(point, draw_frame, extent), color)
	if not arrow.is_empty():
		_draw_marker(arrow)
	canvas.draw_set_transform(Vector2.ZERO)
	_draw_label()

func _draw_label() -> void:
	var rules: Dictionary = Content.balance.minimap.labels
	if mode_font == null:
		mode_font = SystemFont.new()
		mode_font.font_names = PackedStringArray([String(rules.fontFamily)])
	var font_size := int(rules.fontSize)
	var precise: Dictionary = draw_frame.window_components
	var text := MinimapWindow.label(draw_frame.near, float(precise.x1) - float(precise.x0))
	var measured := mode_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var box: Array = rules.box.rect
	var background: Array = rules.box.colour
	canvas.draw_rect(Rect2(box[0], draw_frame.size.y + float(box[1]), measured.x + float(box[2]), box[3]),
		Color(background[0], background[1], background[2], background[3]))
	var colour: Array = rules.colours["near" if draw_frame.near else "full"]
	canvas.draw_string(mode_font, Vector2(rules.position[0], draw_frame.size.y + float(rules.position[1]) - mode_font.get_descent(font_size)),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(colour[0], colour[1], colour[2], colour[3]))

func marker_commands() -> Array:
	if map_data.is_empty():
		return []
	var precise := MinimapWindow.components(map_data.bounds, near, focus, hero_kind)
	return _commands_for({"window": MinimapWindow.rectangle(precise), "window_components": precise,
		"size": size, "focus": focus, "side": side, "heading": heading, "own_id": own_id,
		"units": state.get("units", []), "bunkers": markers.bunkers.values()}, positions)

func _commands_for(frame: Dictionary, shown_positions: Dictionary) -> Array:
	var rows: Array = []
	var precise: Dictionary = frame.window_components
	for unit: Dictionary in frame.units:
		rows.append({"kind": unit.kind, "side": unit.side, "hero": not String(unit.character).is_empty(),
			"self": int(unit.id) == int(frame.own_id), "neutral": unit.get("special", {}).get("neutral", false),
			"point": _project(shown_positions.get(int(unit.id), unit.position), frame.window, frame.size, precise)})
	var known: Array = []
	for record: Dictionary in frame.bunkers:
		known.append({"side": record.side, "point": MinimapWindow.project_components_pair(
			float(record.get("x", record.point.x)), float(record.get("z", record.point.y)), precise, frame.size)})
	var own: Variant = MinimapWindow.project_components_pair(frame.focus.x, frame.focus.y, precise, frame.size) if not String(frame.side).is_empty() else null
	return MinimapMarkerState.commands(rows, frame.side, known, own, frame.heading)

func _draw_marker(command: Dictionary) -> void:
	canvas.draw_set_transform(Vector2(command.position[0], command.position[1]), float(command.rotation))
	var colour := Color(command.colour[0], command.colour[1], command.colour[2], command.colour[3])
	var width := float(command.width) if command.width != null else -1.0
	match command.shape:
		"rect":
			canvas.draw_rect(Rect2(command.rect[0], command.rect[1], command.rect[2], command.rect[3]), colour, command.fill, width, true)
		"circle":
			canvas.draw_circle(Vector2(command.center[0], command.center[1]), float(command.radius), colour, command.fill, width, true)
		"polygon":
			var points := PackedVector2Array()
			for point: Array in command.points:
				points.append(Vector2(point[0], point[1]))
			canvas.draw_colored_polygon(points, colour)

func _project(point: Vector3, frame_window: Rect2, frame_size: Vector2, precise: Dictionary = {}) -> Array:
	if not precise.is_empty():
		return MinimapWindow.project_components_pair(point.x, point.z, precise, frame_size)
	var projected := MinimapWindow.project(Vector2(point.x, point.z), frame_window, frame_size)
	return [projected.x, projected.y]

func _missile_rect(point: Vector3, frame: Dictionary, extent: Vector2) -> Rect2:
	var projected := _project(point, frame.window, frame.size, frame.window_components)
	return Rect2(float(projected[0]) - float(extent.x) * .5, float(projected[1]) - float(extent.y) * .5, extent.x, extent.y)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.08, 0.9)
	style.border_color = Color("477482")
	style.set_border_width_all(1)
	return style

