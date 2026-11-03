class_name BattleFeed
extends VBoxContainer

func push_message(message: String) -> void:
	if not Content.balance.has("hud_feed"):
		push_error("Missing original HUD feed metadata; regenerate source content")
		return
	var cfg: Dictionary = Content.balance.hud_feed
	var row := Label.new()
	row.text = message
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override("font_size", 16)
	add_child(row)
	move_child(row, 0)
	while get_child_count() > int(cfg.maximum):
		get_child(get_child_count() - 1).free()
	# Bound to the row so a cleared row drops the connection instead of a freed lambda capture.
	get_tree().create_timer(float(cfg.lifetime)).timeout.connect(row.queue_free)

func clear() -> void:
	for row in get_children():
		row.free()
