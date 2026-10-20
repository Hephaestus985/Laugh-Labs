class_name HelpPage
extends CanvasLayer
# A game's own help page: its goal, controls and rules, opened with the game's "?"
# button and shown once by itself the first time the game is played. The text lives in
# the game's folder (help.json: {"title": "...", "sections": [["Heading", "Text"], ...]}).
# The game is paused while the page is open; "Got it", the back button or Esc close it.

const BG := Color(0.07, 0.08, 0.12, 0.96)
const PANEL := Color(0.13, 0.15, 0.22)
const GOLD := Color(1.0, 0.85, 0.35)
const INK := Color(0.92, 0.94, 1.0)

static var current: HelpPage = null

var _was_paused := false
var _scroll: ScrollContainer
var _drag_from := -1.0
var _overlays: Array = []


## Opens the page described by a help.json file. Returns null when there is no such file.
static func open(host: Node, path: String) -> HelpPage:
	if is_open():
		return current
	var data := read(path)
	if data.is_empty():
		return null
	var page := HelpPage.new()
	page._build(host, data)
	return page


## The first time a game is played its help opens by itself (remembered in settings).
static func open_first_time(host: Node, game_id: String, path: String) -> void:
	var seen: Array = GameData.get_setting("help", "seen", [])
	if seen.has(game_id) or not FileAccess.file_exists(path):
		return
	seen.append(game_id)
	GameData.set_setting("help", "seen", seen)
	open.call_deferred(host, path)


static func is_open() -> bool:
	return is_instance_valid(current) and current.is_inside_tree()


static func close_current() -> void:
	if is_open():
		current.close()


static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or not d.get("sections") is Array:
		return {}
	return d


func _build(host: Node, data: Dictionary) -> void:
	current = self
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "HelpPage"
	host.get_tree().root.add_child(self)
	_was_paused = get_tree().paused
	get_tree().paused = true
	# the phone buttons of games by others would still react while the game is paused
	for o in get_tree().root.find_children("*", "TouchOverlay", true, false):
		if o.visible:
			_overlays.append(o)
			o.visible = false
			o.process_mode = Node.PROCESS_MODE_DISABLED
	var size := get_viewport().get_visible_rect().size
	var k := clampf(size.y / 720.0, 0.2, 3.0) if size.y < size.x else clampf(size.x / 720.0, 0.2, 3.0)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := maxf(16.0 * k, (size.x - 980.0 * k) / 2.0)
	margin.add_theme_constant_override("margin_left", int(side))
	margin.add_theme_constant_override("margin_right", int(side))
	margin.add_theme_constant_override("margin_top", int(18 * k))
	margin.add_theme_constant_override("margin_bottom", int(18 * k))
	bg.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(12 * k))
	margin.add_child(col)
	col.add_child(_label(str(data.get("title", "How to play")), int(40 * k), GOLD))
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(6 * k))
	_scroll.add_child(body)
	for s in data["sections"]:
		if not s is Array or s.size() < 2:
			continue
		var head := _label(str(s[0]), int(28 * k), GOLD)
		body.add_child(head)
		body.add_child(_label(str(s[1]), int(23 * k), INK))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 10 * k)
		body.add_child(gap)
	var ok := Button.new()
	ok.name = "GotIt"
	ok.text = "Got it"
	ok.custom_minimum_size = Vector2(260 * k, 70 * k)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", int(30 * k))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.33, 0.62, 0.10)
	sb.set_corner_radius_all(int(12 * k))
	ok.add_theme_stylebox_override("normal", sb)
	ok.add_theme_stylebox_override("hover", sb)
	ok.add_theme_stylebox_override("pressed", sb)
	ok.pressed.connect(close)
	col.add_child(ok)


func _label(s: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func close() -> void:
	if current == self:
		current = null
	for o in _overlays:
		if is_instance_valid(o):
			o.visible = true
			o.process_mode = Node.PROCESS_MODE_ALWAYS
	if is_inside_tree():
		get_tree().paused = _was_paused
	queue_free()


func _input(event: InputEvent) -> void:
	# a finger drag scrolls the text (also without a touch-scrolling ScrollContainer)
	if event is InputEventScreenTouch:
		_drag_from = event.position.y if event.pressed else -1.0
	elif event is InputEventScreenDrag and _drag_from >= 0.0 and is_instance_valid(_scroll):
		_scroll.scroll_vertical -= int(event.relative.y)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close.call_deferred()
