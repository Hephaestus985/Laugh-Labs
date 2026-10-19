extends Control
# Lab Arcade: the start screen that lists every game, plus a version
# history page per game where older versions can still be played.

const Games := preload("res://games.gd")

var body: VBoxContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)
	show_list()


func clear_body() -> void:
	for c in body.get_children():
		c.queue_free()


func label(s: String, size: int, color := Color(1, 1, 1), center := true) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func style_button(b: Button, c: Color, radius := 18) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # let drags reach the scroll container on phones
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if state == "normal" else (c.lightened(0.15) if state != "pressed" else c.darkened(0.2))
		if state == "focus":
			sb.draw_center = false
			sb.border_color = Color(1, 1, 1)
			sb.set_border_width_all(4)
		sb.set_corner_radius_all(radius)
		sb.set_content_margin_all(14)
		b.add_theme_stylebox_override(state, sb)


func scroll_box() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 14)
	scroll.add_child(inner)
	return inner


# ---------------------------------------------------------------- game list

func show_list() -> void:
	clear_body()
	body.add_child(label("LAB ARCADE", 58, Color(1.0, 0.85, 0.35)))
	body.add_child(label("%d games. Pick one." % Games.LIST.size(), 24))
	var inner := scroll_box()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	inner.add_child(grid)
	var first: Button = null
	for g in Games.LIST:
		var card := make_card(g)
		grid.add_child(card)
		if first == null:
			first = card.get_child(0)
	if first:
		first.grab_focus()


func newest(g: Dictionary) -> Dictionary:
	var vs: Array = g["versions"]
	return vs[vs.size() - 1]


func best_path(g: Dictionary) -> String:
	return g.get("best_file", "user://best_%s.dat" % g["id"])


func make_card(g: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var b := Button.new()
	var best := read_best(best_path(g))
	var nv := newest(g)
	b.text = "%s\n%s\n%s  ·  %s%s" % [g["name"], g["tagline"], g.get("length", ""), short_effort(g.get("effort", "")), ("  ·  Best: %d" % best) if best > 0 else ""]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(560, 170)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 25)
	style_button(b, g["color"])
	var scene: String = nv["scene"]
	var has_save: bool = g.has("save_file") and FileAccess.file_exists(g["save_file"])
	b.pressed.connect(func(): launch(scene, "continue" if has_save else ""))
	box.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	if has_save:
		var cb := small_button("Continue", Color(0.20, 0.45, 0.30))
		cb.pressed.connect(func(): launch(scene, "continue"))
		row.add_child(cb)
		var nb := small_button("New game", Color(0.22, 0.21, 0.32))
		nb.pressed.connect(func(): launch(scene, "new"))
		row.add_child(nb)
	var gid: String = g["id"]
	var db := small_button("Difficulty: " + ArcadeGame.DIFF_NAMES[ArcadeGame.get_difficulty(gid)], Color(0.30, 0.25, 0.40))
	db.pressed.connect(func():
		var d := (ArcadeGame.get_difficulty(gid) + 1) % 3
		ArcadeGame.set_difficulty(gid, d)
		db.text = "Difficulty: " + ArcadeGame.DIFF_NAMES[d])
	row.add_child(db)
	var vb := small_button("v%d · Versions" % nv["v"], Color(0.22, 0.21, 0.32))
	vb.pressed.connect(func(): show_versions(g))
	row.add_child(vb)
	return box


func short_effort(e: String) -> String:
	# "Web effort 7 of 8: Studio (built and playtested)" -> "effort 7/8 Studio"
	var m := RegEx.create_from_string("(\\d) of 8: ([A-Za-z]+)").search(e)
	if m:
		return "effort %s/8 %s" % [m.get_string(1), m.get_string(2)]
	return e


func small_button(txt: String, c: Color) -> Button:
	var sb := Button.new()
	sb.text = txt
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.add_theme_font_size_override("font_size", 19)
	style_button(sb, c, 12)
	return sb


func launch(scene: String, mode: String) -> void:
	Engine.set_meta("launch_mode", mode)
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- versions page

func show_versions(g: Dictionary) -> void:
	clear_body()
	var back := Button.new()
	back.text = "< Back to all games"
	back.add_theme_font_size_override("font_size", 22)
	style_button(back, Color(0.25, 0.24, 0.36), 12)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(show_list)
	body.add_child(back)
	body.add_child(label(g["name"] + ": versions", 44, Color(1.0, 0.85, 0.35)))
	var inner := scroll_box()
	inner.add_child(label("One run: %s\n%s\nGodot version built in %s" % [g.get("length", "?"), g.get("effort", "?"), g.get("godot_time", "?")], 21, Color(0.85, 0.85, 0.95), false))
	var vs: Array = g["versions"]
	for i in range(vs.size() - 1, -1, -1):
		var v: Dictionary = vs[i]
		var b := Button.new()
		var tag := "  (newest)" if i == vs.size() - 1 else ""
		b.text = "Play v%d%s   ·   %s\n%s" % [v["v"], tag, v["date"], v["notes"]]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		style_button(b, g["color"] if i == vs.size() - 1 else Color(g["color"]).darkened(0.35), 14)
		var scene: String = v["scene"]
		b.pressed.connect(func(): launch(scene, ""))
		inner.add_child(b)
		if i == vs.size() - 1:
			b.grab_focus.call_deferred()
	var web: Array = g.get("web", [])
	if web.size() > 0:
		inner.add_child(label("Earlier web versions in Laugh Lab (not playable here)", 22, Color(0.75, 0.75, 0.85), false))
		for w in web:
			inner.add_child(label("•  " + str(w), 20, Color(0.75, 0.75, 0.85), false))


func read_best(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_32() if f else 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
