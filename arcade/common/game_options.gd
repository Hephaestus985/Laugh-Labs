class_name GameOptions
extends HelpPage
# A game's own options, opened with the gear button in the game: difficulty (when the
# game has it) and sound. They used to be on the game's start screen in the launcher.
# A new difficulty applies from the next round, so the game you're in isn't reset.
# Like a help page it pauses the game; "Done", the back button or Esc close it.

var _game_id := ""
var _host: Node


## The game in the game list (Store), for its name and whether it has difficulty.
static func game_info(game_id: String) -> Dictionary:
	for kind in ["lab", "external"]:
		for g in Store.catalog.get(kind, []):
			if g is Dictionary and g.get("id", "") == game_id:
				return g
	return {}


## Games made for the arcade, and games by others that add the gear themselves.
static func has_gear(game_id: String) -> bool:
	for g in Store.catalog.get("lab", []):
		if g is Dictionary and g.get("id", "") == game_id:
			return true
	return has_difficulty(game_id)


static func has_difficulty(game_id: String) -> bool:
	var g := game_info(game_id)
	return not g.is_empty() and not g.get("no_difficulty", false)


static func open_for(host: Node, game_id: String) -> GameOptions:
	if is_open():
		return null
	var page := GameOptions.new()
	page._game_id = game_id
	page._host = host
	page._build_options()
	return page


func _build_options() -> void:
	current = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "GameOptions"
	_host.get_tree().root.add_child(self)
	_was_paused = get_tree().paused
	get_tree().paused = true
	for o in get_tree().root.find_children("*", "TouchOverlay", true, false):
		if o.visible:
			_overlays.append(o)
			o.visible = false
			o.process_mode = Node.PROCESS_MODE_DISABLED
	_fill()


func _fill() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var size := get_viewport().get_visible_rect().size
	var k := clampf(minf(size.x, size.y) / 720.0, 0.2, 3.0)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(int(18 * k))
	sb.set_content_margin_all(int(28 * k))
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(minf(620 * k, size.x - 32 * k), 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(14 * k))
	panel.add_child(col)
	var g := game_info(_game_id)
	col.add_child(_label(str(g.get("name", "Options")), int(36 * k), GOLD))
	if has_difficulty(_game_id):
		col.add_child(_label("Difficulty", int(24 * k), INK))
		var row := HBoxContainer.new()
		row.name = "Difficulty"
		row.add_theme_constant_override("separation", int(8 * k))
		col.add_child(row)
		var cur := ArcadeGame.get_difficulty(_game_id)
		for d in 3:
			var b := _button(ArcadeGame.DIFF_NAMES[d], Color(0.85, 0.55, 0.15) if d == cur else PANEL, k)
			b.name = "Diff%d" % d
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func():
				ArcadeGame.set_difficulty(_game_id, d)
				_fill())
			row.add_child(b)
		col.add_child(_label("A new difficulty starts with your next round or game.", int(19 * k), Color(0.7, 0.75, 0.85)))
	var on := GameData.sound_on(_game_id)
	var snd := _button("Sound: on" if on else "Sound: off", PANEL, k)
	snd.name = "Sound"
	snd.pressed.connect(func():
		GameData.set_sound(_game_id, not GameData.sound_on(_game_id))
		GameData.apply_sound(_game_id)
		_fill())
	col.add_child(snd)
	var done := _button("Done", Color(0.33, 0.62, 0.10), k)
	done.name = "Done"
	done.pressed.connect(close)
	col.add_child(done)


func _button(s: String, c: Color, k: float) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(0, 66 * k)
	b.add_theme_font_size_override("font_size", int(26 * k))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c.lightened(0.1) if st == "pressed" else c
		sb.set_corner_radius_all(int(12 * k))
		b.add_theme_stylebox_override(st, sb)
	return b


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


## The gear drawn on a game's options button (fonts on phones have no gear symbol).
static func draw_gear(ci: CanvasItem, center: Vector2, r: float, c: Color) -> void:
	for i in 8:
		var a := i * TAU / 8.0
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var p := center + dir * r * 0.78
		ci.draw_colored_polygon(PackedVector2Array([p - side * r * 0.2, p + side * r * 0.2, p + dir * r * 0.32 + side * r * 0.14, p + dir * r * 0.32 - side * r * 0.14]), c)
	ci.draw_circle(center, r * 0.8, c)
	ci.draw_circle(center, r * 0.34, Color(0.1, 0.1, 0.12, 0.9))
