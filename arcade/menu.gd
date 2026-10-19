extends Control
# Laugh Lab Arcade: the start screen that lists every game.

const Games := preload("res://games.gd")


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var title := Label.new()
	title.text = "LAUGH LAB ARCADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Pick a game. Laughing is mandatory."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	col.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)

	var first: Button = null
	for g in Games.LIST:
		var b := make_card(g)
		grid.add_child(b)
		if first == null:
			first = b
	if first:
		first.grab_focus()


func make_card(g: Dictionary) -> Button:
	var b := Button.new()
	var best := read_best(g["best_file"])
	b.text = "%s\n%s%s" % [g["name"], g["tagline"], ("\nBest: %d" % best) if best > 0 else ""]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(580, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	var c: Color = g["color"]
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if state == "normal" else (c.lightened(0.15) if state != "pressed" else c.darkened(0.2))
		if state == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1)
			sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		sb.set_content_margin_all(18)
		b.add_theme_stylebox_override(state, sb)
	var scene: String = g["scene"]
	b.pressed.connect(func(): get_tree().change_scene_to_file(scene))
	return b


func read_best(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_32() if f else 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button closes the app from the menu
		get_tree().quit()
