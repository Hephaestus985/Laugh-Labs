extends Control
# Lab Arcade launcher: the game list (sortable, landscape or portrait), an
# info page per game (story, controls, facts, difficulty, versions) and a
# settings page. Play statistics live in user://settings.cfg next to the
# per-game difficulty that ArcadeGame reads.

const Games := preload("res://games.gd")
const SETTINGS := "user://settings.cfg"
const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)
const SORTS := ["A to Z", "Recently played", "Most played", "Shortest first", "Longest first", "Most effort first", "Newest first"]
const ORIENTS := ["Auto (turn the phone)", "Always landscape", "Always portrait"]
const BG := Color(0.11, 0.10, 0.17)
const PANEL := Color(0.17, 0.16, 0.25)
const GOLD := Color(1.0, 0.85, 0.35)
const MUTED := Color(0.75, 0.75, 0.85)

var body: VBoxContainer
var page := "list"
var page_game: Dictionary = {}
var confirm_reset := false
var portrait := false


var tab := 1  # 0 = Home (your picks), 1 = Library (everything)
var search := ""
var f_publisher := ""  # "" any, BY_OTHERS, or a publisher's name
var f_length := 0  # index in LENGTHS
var f_genre := ""  # "" any, or a genre
var f_unplayed := false
var launch_hook := Callable()  # tests replace launching with this
const BY_OTHERS := "More games (by others)"
const LENGTHS := ["Any length", "Short (under 5 min)", "Medium (5-15 min)", "Long (15 min or more)", "No end (free play)"]


func _ready() -> void:
	get_tree().paused = false  # in case a game was left while paused
	for g in Games.EXTERNAL:  # games whose always-loaded helpers must sleep in the launcher
		if g.has("park"):
			load(g["park"]).park(get_tree())
	tab = int(get_setting("ui", "tab", 0 if favorites().size() > 0 else 1))
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	apply_orientation()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	_on_resized()


func _process(delta: float) -> void:
	# follow phone rotation (checked every frame; cheap, and more reliable than signals)
	var ws := DisplayServer.window_get_size()
	if (ws.y > ws.x) != portrait:
		_on_resized()
	# keep gliding a little after a swipe
	if not drag_down and absf(fling) > 20.0 and is_instance_valid(drag_scroll):
		drag_scroll.scroll_vertical -= int(fling * delta)
		fling *= pow(0.04, delta)


# ---------------------------------------------------------------- swipe to scroll
# Swipes are handled here, before any card or button sees them, so a swipe
# that starts anywhere (card background, label, button) scrolls the list.
# A touch that doesn't move is passed on unchanged as a normal tap.

const DRAG_START := 14.0
var drag_down := false
var dragging := false
var drag_from := Vector2.ZERO
var drag_start_scroll := 0
var drag_scroll: ScrollContainer = null
var drag_press: InputEventMouseButton = null
var fling := 0.0
var last_drag_y := 0.0
var last_drag_t := 0


## The topmost visible, enabled button at a point (in screen-canvas coordinates).
func button_at(root: Node, pos: Vector2) -> BaseButton:
	var found: BaseButton = null
	for b in root.find_children("*", "BaseButton", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(pos):
			found = b  # later in the tree = drawn on top
	return found


func current_scroll() -> ScrollContainer:
	return body.find_child("Scroll", true, false) as ScrollContainer if body else null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var sc := current_scroll()
			if sc == null or not sc.get_global_rect().has_point(event.position):
				return
			drag_down = true
			dragging = false
			fling = 0.0
			drag_scroll = sc
			drag_from = event.position
			drag_start_scroll = sc.scroll_vertical
			drag_press = event.duplicate()
			last_drag_y = event.position.y
			last_drag_t = Time.get_ticks_msec()
			get_viewport().set_input_as_handled()
		elif drag_down:
			drag_down = false
			get_viewport().set_input_as_handled()
			if not dragging and is_instance_valid(drag_scroll):
				# it was a tap: press the button under the finger. (Re-sending the
				# touch would be scaled twice on phones and hit the wrong button.)
				var b := button_at(drag_scroll, drag_from)
				if b and b.get_global_rect().has_point(event.position):
					b.emit_signal("pressed")
			dragging = false
	elif event is InputEventMouseMotion and drag_down:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return  # a stray pointer move (e.g. a real mouse hovering), not the finger
		var dy: float = event.position.y - drag_from.y
		if not dragging and absf(dy) > DRAG_START:
			dragging = true
		if dragging and is_instance_valid(drag_scroll):
			drag_scroll.scroll_vertical = drag_start_scroll - int(dy)
			var now := Time.get_ticks_msec()
			var dt := maxf(1.0, now - last_drag_t) / 1000.0
			fling = lerpf(fling, (event.position.y - last_drag_y) / dt, 0.5)
			last_drag_y = event.position.y
			last_drag_t = now
		get_viewport().set_input_as_handled()
	elif (event is InputEventScreenTouch or event is InputEventScreenDrag) and drag_down:
		# the emulated mouse events above do the work on phones
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- settings + stats

func cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	return c


func get_setting(section: String, key: String, default):
	return cfg().get_value(section, key, default)


func set_setting(section: String, key: String, value) -> void:
	var c := cfg()
	c.set_value(section, key, value)
	c.save(SETTINGS)


func plays(id: String) -> int:
	return int(get_setting("stats", "plays_" + id, 0))


func last_played(id: String) -> int:
	return int(get_setting("stats", "last_" + id, 0))


func record_play(id: String) -> void:
	var c := cfg()
	c.set_value("stats", "plays_" + id, int(c.get_value("stats", "plays_" + id, 0)) + 1)
	c.set_value("stats", "last_" + id, int(Time.get_unix_time_from_system()))
	c.save(SETTINGS)


func best_path(g: Dictionary) -> String:
	return g.get("best_file", "user://best_%s.dat" % g["id"])


func read_best(g: Dictionary) -> int:
	var path := best_path(g)
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_32() if f else 0


func save_info(g: Dictionary) -> String:
	# "level 3" / "the boss" for a game with a save, "" otherwise
	if not g.has("save_file") or not FileAccess.file_exists(g["save_file"]):
		return ""
	var o = JSON.parse_string(FileAccess.get_file_as_string(g["save_file"]))
	if typeof(o) != TYPE_DICTIONARY:
		return "saved"
	if o.get("boss", false):
		return "at the boss"
	return "level %d" % int(o.get("lv", 1))


func newest(g: Dictionary) -> Dictionary:
	var vs: Array = g["versions"]
	return vs[vs.size() - 1]


## Which LENGTHS entry a game falls in (judged by its shortest stated run).
func length_class(g: Dictionary) -> int:
	var m := minutes(g)
	if m >= 99.0:
		return 4
	return 1 if m < 5.0 else (2 if m < 15.0 else 3)


## The distinct values of a games.gd field, in a stable order.
func values_of(field: String) -> Array:
	var out: Array = []
	for g in all_games():
		var v: String = g.get(field, "")
		if v != "" and not out.has(v):
			out.append(v)
	out.sort()
	return out


func minutes(g: Dictionary) -> float:
	var m := RegEx.create_from_string("(\\d+)\\s*(?:-\\s*\\d+)?\\s*(s|min)").search(g.get("length", ""))
	if m == null:
		return 99.0
	var n := float(m.get_string(1))
	return n / 60.0 if m.get_string(2) == "s" else n


func effort_level(g: Dictionary) -> int:
	var m := RegEx.create_from_string("(\\d) of 8").search(g.get("effort", ""))
	return int(m.get_string(1)) if m else 2


func short_effort(e: String) -> String:
	var m := RegEx.create_from_string("(\\d) of 8: ([A-Za-z]+)").search(e)
	if m:
		return "Effort %s/8 %s" % [m.get_string(1), m.get_string(2)]
	return e


func favorites() -> Array:
	return get_setting("ui", "favorites", [])


func is_favorite(id: String) -> bool:
	return favorites().has(id)


func toggle_favorite(id: String) -> void:
	var f: Array = favorites().duplicate()
	if f.has(id):
		f.erase(id)
	else:
		f.append(id)
	set_setting("ui", "favorites", f)


func is_external(g: Dictionary) -> bool:
	return Games.EXTERNAL.any(func(e): return e["id"] == g["id"])


func matches(g: Dictionary) -> bool:
	if f_publisher == BY_OTHERS and not is_external(g):
		return false
	if f_publisher != "" and f_publisher != BY_OTHERS and g.get("publisher", "") != f_publisher:
		return false
	if f_length != 0 and length_class(g) != f_length:
		return false
	if f_genre != "" and g.get("genre", "") != f_genre:
		return false
	if f_unplayed and plays(g["id"]) > 0:
		return false
	var q := search.strip_edges().to_lower()
	if q != "":
		var hay := ("%s %s %s %s %s %s" % [g["name"], g["tagline"], g.get("about", ""), g.get("effort", ""), g.get("publisher", ""), g.get("genre", "")]).to_lower()
		for word in q.split(" ", false):
			if not hay.contains(word):
				return false
	return true


func tab_list() -> Array:
	if tab == 0:
		return all_games().filter(func(g): return is_favorite(g["id"]))
	return all_games().filter(matches)


func all_games() -> Array:
	return Games.LIST + Games.EXTERNAL


func sorted_games() -> Array:
	var list: Array = []
	var src := tab_list()
	for i in src.size():
		var g: Dictionary = src[i].duplicate()
		g["_order"] = i
		list.append(g)
	match int(get_setting("ui", "sort", 0)):
		0:
			list.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
		1:
			list.sort_custom(func(a, b): return last_played(a["id"]) > last_played(b["id"]) or (last_played(a["id"]) == last_played(b["id"]) and a["_order"] < b["_order"]))
		2:
			list.sort_custom(func(a, b): return plays(a["id"]) > plays(b["id"]) or (plays(a["id"]) == plays(b["id"]) and a["_order"] < b["_order"]))
		3:
			list.sort_custom(func(a, b): return minutes(a) < minutes(b))
		4:
			list.sort_custom(func(a, b): return minutes(a) > minutes(b))
		5:
			list.sort_custom(func(a, b): return effort_level(a) > effort_level(b) or (effort_level(a) == effort_level(b) and a["_order"] > b["_order"]))
		6:
			list.sort_custom(func(a, b): return a["_order"] > b["_order"])
	return list


# ---------------------------------------------------------------- orientation

func apply_orientation() -> void:
	if not OS.has_feature("mobile"):
		return
	var o := int(get_setting("ui", "orientation", 0))
	DisplayServer.screen_set_orientation([DisplayServer.SCREEN_SENSOR, DisplayServer.SCREEN_SENSOR_LANDSCAPE, DisplayServer.SCREEN_SENSOR_PORTRAIT][o])


func _on_resized() -> void:
	var ws := DisplayServer.window_get_size()
	var want := ws.y > ws.x
	var target := PORTRAIT if want else LANDSCAPE
	if get_window().content_scale_size != target:
		get_window().content_scale_size = target
	if want != portrait or body.get_child_count() == 0:
		portrait = want
		refresh()


func refresh() -> void:
	match page:
		"info":
			show_info(page_game)
		"settings":
			show_settings()
		_:
			show_list()


# ---------------------------------------------------------------- widgets

func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


func label(s: String, size: int, color := Color(1, 1, 1), center := false) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func flat(c: Color, radius := 16, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func style_button(b: Button, c: Color, radius := 14) -> void:
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # let drags reach the scroll container on phones
	b.add_theme_stylebox_override("normal", flat(c, radius, 12))
	b.add_theme_stylebox_override("hover", flat(c.lightened(0.12), radius, 12))
	b.add_theme_stylebox_override("pressed", flat(c.darkened(0.2), radius, 12))
	var f := flat(Color(0, 0, 0, 0), radius, 12)
	f.draw_center = false
	f.border_color = Color(1, 1, 1)
	f.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", f)


func button(txt: String, c: Color, size := 22, expand := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 58)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(b, c)
	return b


func chip(txt: String, c := Color(0, 0, 0, 0.28)) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(c, 10, 7))
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 18)
	p.add_child(l)
	return p


func scroll_box() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 14)
	scroll.add_child(inner)
	return inner


func back_bar(title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := button("< Back", Color(0.25, 0.24, 0.36), 22, false)
	back.custom_minimum_size = Vector2(140, 58)
	back.pressed.connect(func():
		page = "list"
		refresh())
	row.add_child(back)
	var t := label(title, 34 if portrait else 40, GOLD)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	body.add_child(row)


func section(parent: Control, title: String) -> void:
	parent.add_child(label(title, 24, GOLD))


# ---------------------------------------------------------------- game list

func show_list() -> void:
	page = "list"
	clear_body()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var title := label("LAB ARCADE", 44 if portrait else 52, GOLD)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	var sb := button("Settings", Color(0.28, 0.26, 0.40), 22, false)
	sb.custom_minimum_size = Vector2(150, 58)
	sb.pressed.connect(show_settings)
	top.add_child(sb)
	body.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	for t in 2:
		var tb := button(("Home (%d)" % favorites().size()) if t == 0 else ("Library (%d)" % all_games().size()), Color(0.85, 0.55, 0.15) if tab == t else PANEL, 21, false)
		tb.name = "Tab%d" % t
		tb.custom_minimum_size = Vector2(150, 50)
		tb.pressed.connect(func():
			tab = t
			set_setting("ui", "tab", t)
			show_list())
		bar.add_child(tb)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var ob := OptionButton.new()
	ob.name = "SortOption"
	for srt in SORTS:
		ob.add_item("Sort: " + srt)
	ob.select(int(get_setting("ui", "sort", 0)))
	ob.add_theme_font_size_override("font_size", 19)
	ob.get_popup().add_theme_font_size_override("font_size", 26)
	ob.custom_minimum_size = Vector2(240, 50)
	ob.item_selected.connect(func(i):
		set_setting("ui", "sort", i)
		fill_cards())
	bar.add_child(ob)
	body.add_child(bar)
	if tab == 1:
		var se := LineEdit.new()
		se.name = "Search"
		se.placeholder_text = "Search games..."
		se.text = search
		se.clear_button_enabled = true
		se.add_theme_font_size_override("font_size", 22)
		se.custom_minimum_size = Vector2(0, 52)
		se.text_changed.connect(func(txt):
			search = txt
			fill_cards())
		body.add_child(se)
		var fl := HFlowContainer.new()
		fl.name = "Filters"
		fl.add_theme_constant_override("h_separation", 8)
		fl.add_theme_constant_override("v_separation", 8)
		body.add_child(fl)
		var pubs: Array = ["Lab Arcade", BY_OTHERS]
		for v in values_of("publisher"):
			if not pubs.has(v):
				pubs.append(v)
		fl.add_child(filter_menu("Publisher", "Any publisher", pubs, f_publisher, func(v): f_publisher = v))
		fl.add_child(filter_menu("Length", LENGTHS[0], LENGTHS.slice(1), "" if f_length == 0 else LENGTHS[f_length], func(v): f_length = maxi(0, LENGTHS.find(v))))
		fl.add_child(filter_menu("Genre", "Any genre", values_of("genre"), f_genre, func(v): f_genre = v))
		fl.add_child(filter_button("Unplayed", "Not played yet", f_unplayed, func(): f_unplayed = not f_unplayed))
	var inner := scroll_box()
	var count := label("", 19, MUTED)
	count.name = "Count"
	inner.add_child(count)
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 1 if portrait else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	inner.add_child(grid)
	fill_cards()


## A drop-down filter. The first entry means "no filter" (empty value).
func filter_menu(id: String, any_text: String, values: Array, current: String, action: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.name = id + "Filter"
	ob.add_item(any_text)
	for v in values:
		ob.add_item(v)
	ob.select(maxi(0, values.find(current) + 1))
	ob.add_theme_font_size_override("font_size", 18)
	ob.get_popup().add_theme_font_size_override("font_size", 26)
	ob.custom_minimum_size = Vector2(0, 46)
	if current != "":  # highlight a filter that is on
		ob.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	ob.item_selected.connect(func(i):
		action.call("" if i == 0 else values[i - 1])
		show_list())
	return ob


func filter_button(id: String, txt: String, on: bool, action: Callable) -> Button:
	var b := button(txt, Color(0.85, 0.55, 0.15) if on else PANEL, 18, false)
	b.name = id
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(func():
		action.call()
		show_list())
	return b


## Rebuild only the cards (keeps the search box and keyboard open while typing).
func fill_cards() -> void:
	var grid: GridContainer = body.find_child("Cards", true, false)
	var count: Label = body.find_child("Count", true, false)
	if grid == null:
		return
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var games := sorted_games()
	for g in games:
		grid.add_child(make_card(g))
	if tab == 0:
		count.text = "Your picks. Add games from the Library with \"+ Home\"." if games.size() > 0 else "Nothing here yet. Open the Library and tap \"+ Home\" on the games you like."
	else:
		count.text = "%d of %d games" % [games.size(), all_games().size()] + ("" if games.size() > 0 else ". Nothing matches: clear the search or a filter.")


func make_card(g: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_" + g["id"]
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", flat(Color(g["color"]).darkened(0.15), 18, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(label(g["name"], 30))
	v.add_child(label(g["tagline"], 20, Color(1, 1, 1, 0.85)))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	v.add_child(chips)
	chips.add_child(chip(g.get("genre", "")))
	chips.add_child(chip(g.get("length", "")))
	if not g.get("no_score", false):
		var best := read_best(g)
		chips.add_child(chip("Best %d" % best if best > 0 else "No score yet", Color(1, 0.85, 0.35, 0.28) if best > 0 else Color(0, 0, 0, 0.28)))
	var n := plays(g["id"])
	if n > 0:
		chips.add_child(chip("Played %dx" % n))
	chips.add_child(chip(short_effort(g.get("effort", ""))))
	var sv := save_info(g)
	if sv != "":
		chips.add_child(chip("Saved: " + sv, Color(0.2, 0.6, 0.35, 0.5)))
	if is_external(g):
		chips.add_child(chip("More games", Color(0.3, 0.5, 0.25, 0.5)))
	var hid: String = g["id"]
	var home := button("- Home" if is_favorite(hid) else "+ Home", Color(0.85, 0.55, 0.15, 0.85) if is_favorite(hid) else Color(0, 0, 0, 0.35), 18, false)
	home.name = "HomeToggle"
	home.custom_minimum_size = Vector2(110, 40)
	home.pressed.connect(func():
		toggle_favorite(hid)
		if tab == 0:
			show_list()
		else:
			home.text = "- Home" if is_favorite(hid) else "+ Home"
			style_button(home, Color(0.85, 0.55, 0.15, 0.85) if is_favorite(hid) else Color(0, 0, 0, 0.35))
			var t0: Button = body.find_child("Tab0", true, false)
			if t0:
				t0.text = "Home (%d)" % favorites().size())
	chips.add_child(home)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var scene: String = newest(g)["scene"]
	var play := button("Continue" if sv != "" else "Play", Color(0.16, 0.62, 0.38), 24)
	play.name = "Play"
	play.pressed.connect(func(): launch(g, scene, "continue" if sv != "" else ""))
	row.add_child(play)
	var gid: String = g["id"]
	if g.get("no_difficulty", false):
		var info0 := button("Info", Color(0, 0, 0, 0.3), 20)
		info0.name = "Info"
		info0.pressed.connect(func(): show_info(g))
		row.add_child(info0)
		return card
	var db := button("Difficulty: " + ArcadeGame.DIFF_NAMES[ArcadeGame.get_difficulty(gid)], Color(0, 0, 0, 0.3), 19)
	db.name = "Difficulty"
	db.tooltip_text = "Difficulty: tap to change"
	db.pressed.connect(func():
		var d := (ArcadeGame.get_difficulty(gid) + 1) % 3
		ArcadeGame.set_difficulty(gid, d)
		db.text = "Difficulty: " + ArcadeGame.DIFF_NAMES[d])
	row.add_child(db)
	var info := button("Info", Color(0, 0, 0, 0.3), 20)
	info.name = "Info"
	info.pressed.connect(func(): show_info(g))
	row.add_child(info)
	return card


func launch(g: Dictionary, scene: String, mode: String) -> void:
	if launch_hook.is_valid():
		launch_hook.call(g["id"], scene, mode)
		return
	record_play(g["id"])
	if g.get("aspect", "") == "expand":
		# games made by others: full landscape screen, their own layout
		get_window().content_scale_size = LANDSCAPE
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	Engine.set_meta("launch_mode", mode)
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- info page

func show_info(g: Dictionary) -> void:
	page = "info"
	page_game = g
	clear_body()
	back_bar(g["name"])
	var gid: String = g["id"]
	var inner := scroll_box()
	inner.add_child(label(g.get("about", g["tagline"]), 22))
	# play buttons
	var sv := save_info(g)
	var scene: String = newest(g)["scene"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	inner.add_child(row)
	var play := button("Continue (%s)" % sv if sv != "" else "Play", Color(0.16, 0.62, 0.38), 24)
	play.pressed.connect(func(): launch(g, scene, "continue" if sv != "" else ""))
	row.add_child(play)
	if sv != "":
		var ng := button("New game", Color(0.30, 0.28, 0.42), 22)
		ng.pressed.connect(func(): launch(g, scene, "new"))
		row.add_child(ng)
	var hb := button("Remove from Home" if is_favorite(gid) else "Add to Home", Color(0.30, 0.28, 0.42), 20)
	hb.name = "HomeToggle"
	hb.pressed.connect(func():
		toggle_favorite(gid)
		show_info(g))
	row.add_child(hb)
	if g.has("credit"):
		section(inner, "Made by")
		inner.add_child(label(g["credit"], 20, Color(0.9, 0.9, 1)))
	# difficulty
	if not g.get("no_difficulty", false):
		section(inner, "Difficulty")
		var drow := HBoxContainer.new()
		drow.add_theme_constant_override("separation", 8)
		inner.add_child(drow)
		for d in 3:
			var on := ArcadeGame.get_difficulty(gid) == d
			var b := button(ArcadeGame.DIFF_NAMES[d], Color(0.85, 0.55, 0.15) if on else PANEL, 22)
			b.pressed.connect(func():
				ArcadeGame.set_difficulty(gid, d)
				show_info(g))
			drow.add_child(b)
	section(inner, "Controls")
	inner.add_child(label(g.get("controls", ""), 21, Color(0.9, 0.9, 1)))
	section(inner, "Facts")
	var best := read_best(g)
	var lp := last_played(gid)
	var facts := [
		["Genre", g.get("genre", "?")],
		["Publisher", g.get("publisher", "?")],
		["One run", g.get("length", "?")],
		["Best score", "not tracked" if g.get("no_score", false) else (str(best) if best > 0 else "none yet")],
		["Played", "%d times" % plays(gid) + ("" if lp == 0 else ", last on " + Time.get_date_string_from_unix_time(lp))],
		["Effort", g.get("effort", "?")],
		["Godot version built in", g.get("godot_time", "?")],
		["Saved progress", sv if sv != "" else ("none" if g.has("save_file") else "not saved between sessions")],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(grid)
	for f in facts:
		var k := Label.new()
		k.text = f[0]
		k.add_theme_font_size_override("font_size", 20)
		k.add_theme_color_override("font_color", MUTED)
		grid.add_child(k)
		grid.add_child(label(f[1], 20))
	section(inner, "Versions")
	var vs: Array = g["versions"]
	for i in range(vs.size() - 1, -1, -1):
		var v: Dictionary = vs[i]
		var b := button("Play v%d%s  ·  %s\n%s" % [v["v"], "  (newest)" if i == vs.size() - 1 else "", v["date"], v["notes"]], Color(g["color"]).darkened(0.1 if i == vs.size() - 1 else 0.4), 20)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var vscene: String = v["scene"]
		b.pressed.connect(func(): launch(g, vscene, ""))
		inner.add_child(b)
	var web: Array = g.get("web", [])
	if web.size() > 0:
		inner.add_child(label("Earlier web versions in Laugh Lab (not playable here):", 19, MUTED))
		for w in web:
			inner.add_child(label("•  " + str(w), 19, MUTED))


# ---------------------------------------------------------------- settings page

func show_settings() -> void:
	page = "settings"
	clear_body()
	back_bar("Settings")
	var inner := scroll_box()
	section(inner, "Difficulty for all games")
	inner.add_child(label("Sets every game at once. You can still change single games on their card.", 19, MUTED))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	inner.add_child(drow)
	for d in 3:
		var b := button(ArcadeGame.DIFF_NAMES[d], PANEL, 22)
		b.pressed.connect(func():
			for g in Games.LIST:
				ArcadeGame.set_difficulty(g["id"], d)
			b.text = ArcadeGame.DIFF_NAMES[d] + " (set)")
		drow.add_child(b)
	section(inner, "Sort games by")
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 8)
	srow.add_theme_constant_override("v_separation", 8)
	inner.add_child(srow)
	for i in SORTS.size():
		var on := int(get_setting("ui", "sort", 0)) == i
		var b := button(SORTS[i], Color(0.85, 0.55, 0.15) if on else PANEL, 20, false)
		b.pressed.connect(func():
			set_setting("ui", "sort", i)
			show_settings())
		srow.add_child(b)
	section(inner, "Menu screen orientation")
	inner.add_child(label("Games always play in landscape. The menu can follow the phone.", 19, MUTED))
	var orow := HFlowContainer.new()
	orow.add_theme_constant_override("h_separation", 8)
	orow.add_theme_constant_override("v_separation", 8)
	inner.add_child(orow)
	for i in ORIENTS.size():
		var on := int(get_setting("ui", "orientation", 0)) == i
		var b := button(ORIENTS[i], Color(0.85, 0.55, 0.15) if on else PANEL, 20, false)
		b.pressed.connect(func():
			set_setting("ui", "orientation", i)
			apply_orientation()
			show_settings())
		orow.add_child(b)
	section(inner, "Data")
	var reset := button("Tap again to really reset all high scores" if confirm_reset else "Reset all high scores", Color(0.6, 0.2, 0.25) if confirm_reset else PANEL, 20)
	reset.pressed.connect(func():
		if confirm_reset:
			for g in Games.LIST:
				var p := best_path(g)
				if FileAccess.file_exists(p):
					DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			confirm_reset = false
			reset.text = "High scores reset"
		else:
			confirm_reset = true
			show_settings())
	inner.add_child(reset)
	section(inner, "About")
	inner.add_child(label("Lab Arcade %s  ·  %d + %d games  ·  made with Godot %s\ngithub.com/Hephaestus985/Laugh-Labs" % [ProjectSettings.get_setting("application/config/version", "?"), Games.LIST.size(), Games.EXTERNAL.size(), Engine.get_version_info()["string"]], 19, MUTED))


# ---------------------------------------------------------------- back button

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func go_back() -> void:
	if page == "list":
		get_tree().quit()
	else:
		page = "list"
		confirm_reset = false
		refresh()
