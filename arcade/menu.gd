extends Control
# Lab Arcade launcher: the game list (sortable, landscape or portrait), an
# info page per game (story, controls, facts, difficulty, versions) and a
# settings page. Play statistics live in user://settings.cfg next to the
# per-game difficulty that ArcadeGame reads.

const Games := preload("res://games.gd")
const SETTINGS := "user://settings.cfg"
const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)
const SORTS := ["A to Z", "Recently played", "Most played", "Shortest first", "Longest first", "Most effort first", "Newest first", "Your rating"]
const ORIENTS := ["Auto (turn the phone)", "Always landscape", "Always portrait"]
const BG := Color(0.11, 0.10, 0.17)
const PANEL := Color(0.17, 0.16, 0.25)
const GOLD := Color(1.0, 0.85, 0.35)
const MUTED := Color(0.75, 0.75, 0.85)

var body: VBoxContainer
var page := "list"
var page_game: Dictionary = {}
var confirm_reset := false
var confirm_delete := false
var portrait := false


var tab := 1  # 0 = Home (your picks), 1 = Library (everything)
var search := ""
var f_publisher := ""  # "" any, BY_OTHERS, or a publisher's name
var f_length := 0  # index in LENGTHS
var f_genre := ""  # "" any, or a genre
var f_unplayed := false
var f_collection := ""  # "" any, or one of your collections
var launch_hook := Callable()  # tests replace launching with this
const BY_OTHERS := "More games (by others)"
const LENGTHS := ["Any length", "Short (under 5 min)", "Medium (5-15 min)", "Long (15 min or more)", "No end (free play)"]


func _ready() -> void:
	get_tree().paused = false  # in case a game was left while paused
	Packs.setup()  # load the games downloaded earlier
	for g in Games.EXTERNAL:  # games whose always-loaded helpers must sleep in the launcher
		if g.has("park"):
			load(g["park"]).park(get_tree())
	tab = int(get_setting("ui", "tab", 0 if favorites().size() > 0 else 1))
	load_filters()
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
	_after_update_check()
	check_for_update()


func _process(delta: float) -> void:
	# follow phone rotation (checked every frame; cheap, and more reliable than signals)
	var ws := DisplayServer.window_get_size()
	if (ws.y > ws.x) != portrait:
		_on_resized()
	if is_instance_valid(dl):
		_update_download_ui()
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


var drag_row: ScrollContainer = null  # a Home row under the finger (scrolls sideways)
var drag_row_start := 0
var drag_horizontal := false


func row_at(p: Vector2) -> ScrollContainer:
	for r in get_tree().get_nodes_in_group("hrow"):
		if r is ScrollContainer and r.is_visible_in_tree() and r.get_global_rect().has_point(p):
			return r
	return null


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
			drag_row = row_at(event.position)
			drag_row_start = drag_row.scroll_horizontal if drag_row else 0
			drag_horizontal = false
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
		var dx: float = event.position.x - drag_from.x
		if not dragging and maxf(absf(dx), absf(dy)) > DRAG_START:
			dragging = true
			# sideways on a Home row scrolls that row; otherwise the page
			drag_horizontal = is_instance_valid(drag_row) and absf(dx) > absf(dy)
		if dragging and drag_horizontal and is_instance_valid(drag_row):
			drag_row.scroll_horizontal = drag_row_start - int(dx)
		elif dragging and is_instance_valid(drag_scroll):
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
	if o.has("info"):
		return str(o["info"])
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
	if f_collection != "" and not GameData.in_collection(f_collection, g["id"]):
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
		7:
			list.sort_custom(func(a, b): return GameData.rating(a["id"]) > GameData.rating(b["id"]) or (GameData.rating(a["id"]) == GameData.rating(b["id"]) and String(a["name"]) < String(b["name"])))
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
		"profile":
			show_profile()
		"whatsnew":
			show_whats_new("")
		_:
			show_list()


# ---------------------------------------------------------------- widgets

func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	UiFx.fade_in(body, 0.16)


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
	if not b.pressed.is_connected(UiFx.tap):
		b.pressed.connect(UiFx.tap.bind(b))


func button(txt: String, c: Color, size := 22, expand := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 58)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_button(b, c)
	return b


## A game's cover art (Steam-style header, 920x430), optionally tappable.
## Its height follows its width, so it keeps its shape on any screen.
func cover_art(g: Dictionary, on_tap := Callable()) -> Control:
	var path: String = g.get("cover", "")
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	return picture(tex, on_tap, Color(g["color"]).darkened(0.3))


func picture(tex: Texture2D, on_tap := Callable(), fallback := Color(0.1, 0.12, 0.18)) -> Control:
	var tr := TextureRect.new()
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.mouse_filter = Control.MOUSE_FILTER_PASS
	if tex:
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		tr.custom_minimum_size = Vector2(0, 160)
		var cr := ColorRect.new()
		cr.color = fallback
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.add_child(cr)
	if tex:
		tr.modulate.a = 0.0
		tr.ready.connect(func(): UiFx.fade_in(tr, 0.3))
	if on_tap.is_valid():
		var b := Button.new()
		b.name = "Cover"
		b.flat = true
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.06), 0, 0))
		b.add_theme_stylebox_override("pressed", flat(Color(0, 0, 0, 0.15), 0, 0))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(on_tap)
		tr.add_child(b)
	return tr


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
	var pb := button("Profile", Color(0.28, 0.26, 0.40), 22, false)
	pb.name = "ProfileButton"
	pb.custom_minimum_size = Vector2(130 if portrait else 150, 58)
	pb.pressed.connect(show_profile)
	top.add_child(pb)
	var sb := button("Settings", Color(0.28, 0.26, 0.40), 22, false)
	sb.custom_minimum_size = Vector2(130 if portrait else 150, 58)
	sb.pressed.connect(show_settings)
	top.add_child(sb)
	body.add_child(top)
	update_banner(body)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	for t in 2:
		var tb := button("Home" if t == 0 else ("Library (%d)" % all_games().size()), Color(0.85, 0.55, 0.15) if tab == t else PANEL, 21, false)
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
	if tab == 1:
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
		if not GameData.collections().is_empty():
			fl.add_child(filter_menu("Collection", "Any collection", GameData.collections().keys(), f_collection, func(v): f_collection = v))
		fl.add_child(filter_button("Unplayed", "Not played yet", f_unplayed, func(): f_unplayed = not f_unplayed))
	var inner := scroll_box()
	if tab == 0:
		build_home(inner)
		return
	var count := label("", 19, MUTED)
	count.name = "Count"
	inner.add_child(count)
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.columns = 1 if portrait else 3
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
## The Library's search and filters are kept between visits (playing a game reloads the menu).
const FILTER_KEYS := ["search", "f_publisher", "f_length", "f_genre", "f_unplayed", "f_collection"]


func load_filters() -> void:
	var saved: Dictionary = get_setting("ui", "filters", {})
	for k in FILTER_KEYS:
		if saved.has(k) and typeof(saved[k]) == typeof(get(k)):
			set(k, saved[k])
	if f_length < 0 or f_length >= LENGTHS.size():
		f_length = 0
	if f_genre != "" and not values_of("genre").has(f_genre):
		f_genre = ""
	if f_publisher not in ["", BY_OTHERS] and not values_of("publisher").has(f_publisher):
		f_publisher = ""
	if f_collection != "" and not GameData.collections().has(f_collection):
		f_collection = ""


func save_filters() -> void:
	var now := {}
	for k in FILTER_KEYS:
		now[k] = get(k)
	if now != get_setting("ui", "filters", {}):
		set_setting("ui", "filters", now)


func fill_cards() -> void:
	save_filters()
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


## A Steam-library style tile: the cover (tap for the game's page), its name, one line
## of facts, and Play / difficulty / Info / Home.
func make_card(g: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_" + g["id"]
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := flat(Color(0.11, 0.16, 0.22), 12, 0)
	sb.set_content_margin(SIDE_BOTTOM, 12)
	card.add_theme_stylebox_override("panel", sb)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	card.add_child(outer)
	var art := cover_art(g, func(): show_info(g))
	outer.add_child(art)
	var bdg := GameData.badge(g)
	if bdg != "":
		var bl := Label.new()
		bl.name = "Badge"
		bl.text = " " + bdg + " "
		bl.add_theme_font_size_override("font_size", 18)
		bl.add_theme_color_override("font_color", Color.WHITE)
		var bs := flat(Color(0.85, 0.25, 0.25) if bdg == "NEW" else Color(0.15, 0.45, 0.75), 8, 4)
		bl.add_theme_stylebox_override("normal", bs)
		bl.position = Vector2(10, 10)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(bl)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	outer.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pad.add_child(v)
	var title_l := label(g["name"], 23)
	title_l.name = "Title"
	title_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(title_l)
	var pt := GameData.playtime(g["id"])
	var stars := GameData.rating(g["id"])
	var meta := label("%s  ·  %s%s%s" % [g.get("genre", ""), g.get("length", "").get_slice(" (", 0), ("  ·  " + GameData.time_text(pt) + " played") if pt > 0 else "", ("  ·  rated %d/5" % stars) if stars > 0 else ""], 17, MUTED)
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(meta)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var scene: String = newest(g)["scene"]
	var pk := Packs.key_for(g, scene)
	var pst := Packs.status(pk)
	var ptxt := "Play"
	if pst == "download":
		ptxt = "Get " + Packs.size_text(Packs.size_of(pk))
	elif pst == "update":
		ptxt = "Update"
	var play := button(ptxt, Color(0.33, 0.62, 0.10) if pst == "ready" else Color(0.15, 0.45, 0.75), 21)
	play.name = "Play"
	play.size_flags_stretch_ratio = 1.6
	play.pressed.connect(func(): launch(g, scene))
	row.add_child(play)
	var gid: String = g["id"]
	var info := button("Info", Color(0.20, 0.27, 0.36), 17)
	info.name = "Info"
	info.pressed.connect(func(): show_info(g))
	row.add_child(info)
	var home := button("-" if is_favorite(gid) else "+", Color(0.85, 0.55, 0.15, 0.9) if is_favorite(gid) else Color(0.20, 0.27, 0.36), 20, false)
	home.name = "HomeToggle"
	home.tooltip_text = "Home: tap to add or remove"
	home.custom_minimum_size = Vector2(52, 0)
	home.pressed.connect(func():
		toggle_favorite(gid)
		if tab == 0:
			show_list()
		else:
			home.text = "-" if is_favorite(gid) else "+"
			style_button(home, Color(0.85, 0.55, 0.15, 0.9) if is_favorite(gid) else Color(0.20, 0.27, 0.36))
			var t0: Button = body.find_child("Tab0", true, false)
			if t0:
				t0.text = "Home (%d)" % favorites().size())
	row.add_child(home)
	return card


## Open a game: download it if needed, then show its own start screen (where you
## pick Continue / New game, difficulty and so on).
func launch(g: Dictionary, scene: String, mode: String = "") -> void:
	if launch_hook.is_valid():
		launch_hook.call(g["id"], scene, mode)
		return
	var pk := Packs.key_for(g, scene)
	if Packs.status(pk) != "ready":
		download(pk, func(): launch(g, scene, mode))
		return
	Engine.set_meta("hub_game", g["id"])
	Engine.set_meta("hub_scene", scene)
	get_tree().change_scene_to_file(GameData.HUB)


# ---------------------------------------------------------------- home: a Steam-style front page

## A big banner for the game you played last (or one to start with), then rows of
## covers you swipe sideways: your picks, your collections, recently played, new and
## updated, and one row per genre.
func build_home(inner: VBoxContainer) -> void:
	var games := all_games()
	var last := games.filter(func(g): return last_played(g["id"]) > 0)
	last.sort_custom(func(a, b): return last_played(a["id"]) > last_played(b["id"]))
	var hero_game: Dictionary = last[0] if not last.is_empty() else {}
	var hero_title := "Continue playing"
	if hero_game.is_empty():
		# never played anything: suggest the newest game
		var by_new := games.duplicate()
		by_new.sort_custom(func(a, b): return String(newest(a)["date"]) > String(newest(b)["date"]) or (newest(a)["date"] == newest(b)["date"] and int(a.get("order", 0)) > int(b.get("order", 0))))
		hero_game = by_new[0]
		hero_title = "Start here"
	_hero(inner, hero_game, hero_title)
	var picks := games.filter(func(g): return is_favorite(g["id"]))
	_row(inner, "picks", "Your picks", picks, "Tap + on a game in the Library to pin it here.")
	var cols := GameData.collections()
	for cname in cols:
		var ids: Array = cols[cname]
		_row(inner, "coll_" + cname.validate_node_name(), cname, games.filter(func(g): return ids.has(g["id"])), "Empty: add games to it on their page.")
	_row(inner, "recent", "Recently played", last.slice(0, 12), "")
	var fresh := games.filter(func(g): return GameData.badge(g) != "")
	_row(inner, "new", "New and updated", fresh, "")
	for genre in values_of("genre"):
		_row(inner, "genre_" + genre.validate_node_name(), genre, games.filter(func(g): return g.get("genre", "") == genre), "")


func _hero(parent: Control, g: Dictionary, title: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "Hero"
	panel.add_theme_stylebox_override("panel", flat(Color(0.11, 0.16, 0.22), 16, 0))
	parent.add_child(panel)
	var box: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var art := cover_art(g, func(): show_info(g))
	# a wide banner of fixed height, so the rows below stay in view
	if art is TextureRect and (art as TextureRect).texture:
		(art as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size = Vector2(0, 300 if portrait else 380)
	art.size_flags_stretch_ratio = 1.4
	box.add_child(art)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	box.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(v)
	v.add_child(label(title.to_upper(), 17, MUTED))
	v.add_child(label(g["name"], 32))
	var facts := []
	if last_played(g["id"]) > 0:
		facts.append("Last played " + Time.get_date_string_from_unix_time(last_played(g["id"])))
	if GameData.playtime(g["id"]) > 0:
		facts.append(GameData.time_text(GameData.playtime(g["id"])) + " played")
	v.add_child(label("  ·  ".join(facts) if not facts.is_empty() else g["tagline"], 19, Color(0.55, 0.75, 0.95)))
	var scene: String = newest(g)["scene"]
	var pk := Packs.key_for(g, scene)
	var pst := Packs.status(pk)
	var play := button("Resume" if title == "Continue playing" and pst == "ready" else ("Get  " + Packs.size_text(Packs.size_of(pk)) if pst != "ready" else "Play"), Color(0.33, 0.62, 0.10) if pst == "ready" else Color(0.15, 0.45, 0.75), 26, false)
	play.name = "HeroPlay"
	play.custom_minimum_size = Vector2(220, 66)
	play.pressed.connect(func(): launch(g, scene))
	v.add_child(play)


## A titled row of small covers that scrolls sideways.
func _row(parent: Control, id: String, title: String, games: Array, empty_text: String) -> void:
	if games.is_empty() and empty_text == "":
		return
	parent.add_child(label(title, 24, GOLD))
	if games.is_empty():
		parent.add_child(label(empty_text, 18, MUTED))
		return
	var sc := ScrollContainer.new()
	sc.name = "Row_" + id
	sc.add_to_group("hrow")
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(sc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	sc.add_child(h)
	var w := 250.0 if portrait else 290.0
	for g in games:
		var tile := VBoxContainer.new()
		tile.name = "Tile_" + str(g["id"])
		tile.custom_minimum_size = Vector2(w, 0)
		tile.add_theme_constant_override("separation", 4)
		tile.add_child(cover_art(g, func(): show_info(g)))
		var nl := label(g["name"], 18)
		nl.autowrap_mode = TextServer.AUTOWRAP_OFF
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tile.add_child(nl)
		h.add_child(tile)


# ---------------------------------------------------------------- app updates and what's new

const UPDATE_URL := "https://raw.githubusercontent.com/Hephaestus985/Laugh-Labs/downloads/version.json"
static var update_info := {}  # the newer app on GitHub, if there is one
static var update_checked := false
var update_status := ""


## Ask GitHub (once per app start) whether a newer Lab Arcade exists.
func check_for_update(force := false) -> void:
	if update_checked and not force:
		return
	update_checked = true
	update_status = "Checking..."
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, data: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			update_status = "Couldn't check (no internet?)"
		else:
			handle_update_info(JSON.parse_string(data.get_string_from_utf8()))
		if page == "settings":
			show_settings())
	if req.request(UPDATE_URL) != OK:
		update_status = "Couldn't check"


func handle_update_info(d) -> void:
	if typeof(d) != TYPE_DICTIONARY or not d.has("version"):
		update_status = "Couldn't read the update information"
		return
	if GameData.compare_versions(str(d["version"]), GameData.app_version()) > 0:
		update_info = d
		update_status = "Lab Arcade %s is available" % d["version"]
		if page == "list":
			show_list()
	else:
		update_info = {}
		update_status = "You have the newest version (%s)" % GameData.app_version()


func update_banner(parent: Control) -> void:
	if update_info.is_empty():
		return
	var p := PanelContainer.new()
	p.name = "UpdateBanner"
	p.add_theme_stylebox_override("panel", flat(Color(0.15, 0.45, 0.75), 14, 12))
	parent.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var size_txt := "" if int(update_info.get("size", 0)) <= 0 else " (%s)" % Packs.size_text(int(update_info["size"]))
	var l := label("Lab Arcade %s is available%s. Your games, saves and scores stay." % [update_info["version"], size_txt], 20)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var b := button("Update", Color(0.33, 0.62, 0.10), 22, false)
	b.name = "UpdateNow"
	b.custom_minimum_size = Vector2(150, 54)
	b.pressed.connect(func(): OS.shell_open(str(update_info.get("apk", ""))))
	row.add_child(b)


## First start after an app update: show what changed. Very first start: nothing is new.
func _after_update_check() -> void:
	var last: String = get_setting("ui", "app_version", "")
	var now := GameData.app_version()
	if last == "":
		GameData.mark_all_seen(all_games())
	elif GameData.compare_versions(last, now) < 0:
		show_whats_new(last)
	set_setting("ui", "app_version", now)


func whats_new_list() -> Array:
	if not FileAccess.file_exists("res://whats_new.json"):
		return []
	var a = JSON.parse_string(FileAccess.get_file_as_string("res://whats_new.json"))
	return a if typeof(a) == TYPE_ARRAY else []


## What changed since `since` (or the last few versions when it's "").
func show_whats_new(since := "") -> void:
	page = "whatsnew"
	clear_body()
	back_bar("What's new")
	var inner := scroll_box()
	var shown := 0
	for sec in whats_new_list():
		if since != "" and GameData.compare_versions(str(sec["version"]), since) <= 0:
			continue
		if since == "" and shown >= 4:
			break
		shown += 1
		section(inner, "Lab Arcade %s  ·  %s" % [sec["version"], sec["date"]])
		for n in sec["notes"]:
			var sub_item := str(n).begins_with("  - ")
			inner.add_child(label(("      ◦ " + str(n).substr(4)) if sub_item else ("•  " + str(n)), 19 if sub_item else 20, MUTED if sub_item else Color(1, 1, 1)))
	if shown == 0:
		inner.add_child(label("Nothing new to show.", 20, MUTED))
	var ok := button("Let's play", Color(0.33, 0.62, 0.10), 24, false)
	ok.name = "WhatsNewDone"
	ok.custom_minimum_size = Vector2(240, 60)
	ok.pressed.connect(show_list)
	inner.add_child(ok)


# ---------------------------------------------------------------- profile

func show_profile() -> void:
	page = "profile"
	clear_body()
	back_bar("Your profile")
	var inner := scroll_box()
	var games := all_games()
	var ids := games.map(func(g): return g["id"])
	var total := GameData.total_playtime(ids)
	var tried := games.filter(func(g): return plays(g["id"]) > 0)
	var total_plays := 0
	var total_wins := 0
	for g in games:
		total_plays += plays(g["id"])
		total_wins += GameData.wins(g["id"])
	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", 12)
	tiles.add_theme_constant_override("v_separation", 12)
	inner.add_child(tiles)
	for st in [["Time played", GameData.time_text(total)], ["Games tried", "%d of %d" % [tried.size(), games.size()]], ["Times played", str(total_plays)], ["Rounds won", str(total_wins)]]:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(250, 0)
		p.add_theme_stylebox_override("panel", flat(Color(0.11, 0.16, 0.22), 14, 16))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(label(st[1], 34, GOLD))
		v.add_child(label(st[0], 18, MUTED))
		tiles.add_child(p)
	section(inner, "Most played")
	var by_time := games.filter(func(g): return GameData.playtime(g["id"]) > 0 or plays(g["id"]) > 0)
	by_time.sort_custom(func(a, b): return GameData.playtime(a["id"]) * 1000 + plays(a["id"]) > GameData.playtime(b["id"]) * 1000 + plays(b["id"]))
	if by_time.is_empty():
		inner.add_child(label("Play a game and it shows up here.", 20, MUTED))
	var top := maxi(1, GameData.playtime(by_time[0]["id"])) if not by_time.is_empty() else 1
	for g in by_time.slice(0, 8):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		inner.add_child(row)
		var name_l := label(g["name"], 20)
		name_l.custom_minimum_size = Vector2(230, 0)
		name_l.size_flags_horizontal = Control.SIZE_FILL
		row.add_child(name_l)
		var barbox := PanelContainer.new()
		barbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barbox.add_theme_stylebox_override("panel", flat(Color(0.11, 0.16, 0.22), 8, 0))
		row.add_child(barbox)
		var fill := ColorRect.new()
		fill.color = Color(g["color"])
		fill.custom_minimum_size = Vector2(0, 26)
		fill.size_flags_horizontal = Control.SIZE_FILL
		fill.size_flags_stretch_ratio = float(GameData.playtime(g["id"])) / top
		var holder := HBoxContainer.new()
		holder.add_child(fill)
		var rest := Control.new()
		rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rest.size_flags_stretch_ratio = maxf(0.001, 1.0 - fill.size_flags_stretch_ratio)
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(rest)
		barbox.add_child(holder)
		row.add_child(label("%s  ·  %dx" % [GameData.time_text(GameData.playtime(g["id"])), plays(g["id"])], 18, MUTED))


# ---------------------------------------------------------------- downloads

var dl: PackDownload = null
var dl_queue: Array = []  # [key, then (Callable)]
var dl_layer: CanvasLayer = null
var dl_label: Label = null
var dl_bar: ProgressBar = null


## Download a game pack (with a progress screen), then run `then`.
func download(key: String, then := Callable()) -> void:
	dl_queue.append([key, then])
	if not is_instance_valid(dl):
		_next_download()


func _next_download() -> void:
	if dl_queue.is_empty():
		_close_download_ui()
		_refresh_page()
		return
	var job: Array = dl_queue.pop_front()
	if Packs.status(job[0]) == "ready":
		if (job[1] as Callable).is_valid():
			dl_queue.clear()
			_close_download_ui()
			(job[1] as Callable).call()
		else:
			_next_download()
		return
	_open_download_ui()
	dl = PackDownload.start(self, job[0])
	dl.finished.connect(func(err: String):
		dl = null
		if err != "":
			dl_queue.clear()
			_show_download_error(err)
		elif (job[1] as Callable).is_valid() and dl_queue.is_empty():
			_close_download_ui()
			(job[1] as Callable).call()
		else:
			_next_download())


func _refresh_page() -> void:
	refresh()


func _game_name(key: String) -> String:
	var id := key.get_slice("/", 0)
	for g in all_games():
		if g["id"] == id:
			return g["name"]
	return id


func _open_download_ui() -> void:
	if is_instance_valid(dl_layer):
		return
	dl_layer = CanvasLayer.new()
	dl_layer.layer = 10
	add_child(dl_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	dl_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = get_viewport().get_visible_rect().size / 2 - Vector2(280, 110)
	box.add_theme_constant_override("separation", 16)
	dl_layer.add_child(box)
	dl_label = label("", 26, Color(1, 1, 1), true)
	dl_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dl_label)
	dl_bar = ProgressBar.new()
	dl_bar.custom_minimum_size = Vector2(0, 34)
	dl_bar.max_value = 1.0
	dl_bar.show_percentage = false
	box.add_child(dl_bar)
	var cancel := button("Cancel", PANEL, 22)
	cancel.name = "CancelDownload"
	cancel.pressed.connect(func():
		dl_queue.clear()
		if is_instance_valid(dl):
			dl.cancel()
		_close_download_ui())
	box.add_child(cancel)


func _update_download_ui() -> void:
	if not is_instance_valid(dl_label):
		return
	var p := dl.progress()
	dl_bar.value = p
	var more := "" if dl_queue.is_empty() else "  (%d more)" % dl_queue.size()
	dl_label.text = "Downloading %s%s\n%s of %s" % [_game_name(dl.key), more, Packs.size_text(int(p * Packs.size_of(dl.key))), Packs.size_text(Packs.size_of(dl.key))]


func _show_download_error(err: String) -> void:
	_open_download_ui()
	dl_bar.visible = false
	dl_label.text = "Download failed: %s." % err
	var b: Button = dl_layer.find_child("CancelDownload", true, false)
	b.text = "OK"


func _close_download_ui() -> void:
	if is_instance_valid(dl_layer):
		dl_layer.queue_free()
	dl_layer = null


# ---------------------------------------------------------------- info page

func show_info(g: Dictionary) -> void:
	page = "info"
	page_game = g
	clear_body()
	back_bar(g["name"])
	var gid: String = g["id"]
	var inner := scroll_box()
	inner.add_theme_constant_override("separation", 14)
	# hero, like a store page: the cover, and beside it (below it in portrait) the
	# name, the short description and the key facts
	var hero: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	inner.add_child(hero)
	var art := cover_art(g)
	art.size_flags_stretch_ratio = 1.25
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero.add_child(art)
	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 8)
	hero.add_child(head)
	head.add_child(label(g["name"], 34))
	head.add_child(label(g["tagline"], 20, Color(1, 1, 1, 0.85)))
	var vs: Array = g["versions"]
	var first: Dictionary = vs[0]
	var kv := GridContainer.new()
	kv.columns = 2
	kv.add_theme_constant_override("h_separation", 14)
	kv.add_theme_constant_override("v_separation", 2)
	head.add_child(kv)
	for pair in [["MADE BY", g.get("publisher", "?")], ["GENRE", g.get("genre", "?")], ["RELEASED", first["date"]], ["ONE RUN", g.get("length", "?").get_slice(" (", 0)]]:
		kv.add_child(label(pair[0], 15, MUTED))
		var vl := label(pair[1], 17, Color(0.55, 0.75, 0.95))
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kv.add_child(vl)
	# the action bar: play / get, new game, difficulty, home
	var scene: String = newest(g)["scene"]
	var pk := Packs.key_for(g, scene)
	var pst := Packs.status(pk)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", flat(Color(0.11, 0.16, 0.22), 12, 12))
	inner.add_child(bar)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	bar.add_child(row)
	var ptxt := "Play"
	if pst == "download":
		ptxt = "Get  ·  %s" % Packs.size_text(Packs.size_of(pk))
	elif pst == "update":
		ptxt = "Update  ·  %s" % Packs.size_text(Packs.size_of(pk))
	var play := button(ptxt, Color(0.33, 0.62, 0.10) if pst == "ready" else Color(0.15, 0.45, 0.75), 26, false)
	play.name = "Play"
	play.custom_minimum_size = Vector2(260, 64)
	play.pressed.connect(func(): launch(g, scene))
	row.add_child(play)
	var hb := button("- Home" if is_favorite(gid) else "+ Home", Color(0.22, 0.30, 0.40), 20, false)
	hb.name = "HomeToggle"
	hb.custom_minimum_size = Vector2(0, 64)
	hb.pressed.connect(func():
		toggle_favorite(gid)
		show_info(g))
	row.add_child(hb)
	# tags
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 8)
	tags.add_theme_constant_override("v_separation", 8)
	inner.add_child(tags)
	for tg in [g.get("genre", ""), g.get("length", ""), "Open source" if is_external(g) else "Lab Arcade original", "Saves progress" if g.has("save_file") else "", "Difficulty levels" if not g.get("no_difficulty", false) else ""]:
		if tg != "":
			tags.add_child(chip(tg, Color(0.40, 0.60, 0.80, 0.25)))
	# your rating and collections
	var you := HFlowContainer.new()
	you.add_theme_constant_override("h_separation", 6)
	you.add_theme_constant_override("v_separation", 8)
	inner.add_child(you)
	you.add_child(label("Your rating", 19, MUTED))
	var stars_row := HBoxContainer.new()
	stars_row.name = "Rating"
	you.add_child(stars_row)
	var cur := GameData.rating(gid)
	for s in range(1, 6):
		var sbtn := StarButton.new()
		sbtn.name = "Star%d" % s
		sbtn.filled = s <= cur
		sbtn.pressed.connect(func():
			GameData.set_rating(gid, 0 if GameData.rating(gid) == s else s)
			UiFx.tap(self)
			show_info(g))
		stars_row.add_child(sbtn)
	_collections_editor(inner, g)
	# screenshots
	var shots: Array = g.get("shots", [])
	if not shots.is_empty():
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 10)
		inner.add_child(strip)
		for path in shots:
			if not ResourceLoader.exists(path):
				continue
			var tex: Texture2D = load(path)
			var shot := picture(tex, func(): show_picture(tex))
			shot.get_node("Cover").name = "Shot"
			strip.add_child(shot)
	section(inner, "About this game")
	inner.add_child(label(g.get("about", g["tagline"]), 21))
	section(inner, "How to play")
	inner.add_child(label(g.get("controls", ""), 20, Color(0.9, 0.9, 1)))
	section(inner, "Details")
	var last: Dictionary = newest(g)
	var facts := [
		["Made by", g.get("publisher", "?")],
		["Genre", g.get("genre", "?")],
		["First version", first["date"]],
		["Latest version", "v%d, %s" % [last["v"], last["date"]]],
		["One run", g.get("length", "?")],
		["Download", Packs.size_text(Packs.size_of(pk)) + ("" if pst != "ready" or Packs.builtin.has(pk) else " (on this phone)")],
		["Effort", g.get("effort", "?")],
		["Built in Godot in", g.get("godot_time", "?")],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(grid)
	for f in facts:
		var k := Label.new()
		k.text = f[0]
		k.add_theme_font_size_override("font_size", 19)
		k.add_theme_color_override("font_color", MUTED)
		grid.add_child(k)
		var val := label(f[1], 19)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
	if g.has("credit"):
		section(inner, "Credits")
		inner.add_child(label(g["credit"], 19, Color(0.9, 0.9, 1)))
	section(inner, "Versions")
	for i in range(vs.size() - 1, -1, -1):
		var v: Dictionary = vs[i]
		var vk := Packs.key_for(g, v["scene"])
		var get_txt := "" if Packs.status(vk) == "ready" else "  ·  download %s" % Packs.size_text(Packs.size_of(vk))
		var b := button("Play v%d%s  ·  %s%s\n%s" % [v["v"], "  (newest)" if i == vs.size() - 1 else "", v["date"], get_txt, v["notes"]], Color(0.15, 0.21, 0.29) if i == vs.size() - 1 else Color(0.12, 0.16, 0.22), 19)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var vscene: String = v["scene"]
		b.pressed.connect(func(): launch(g, vscene))
		inner.add_child(b)
	var downloaded := []
	for v in vs:
		var vk := Packs.key_for(g, v["scene"])
		if Packs.state().has(vk):
			downloaded.append(vk)
	if not downloaded.is_empty():
		var total := 0
		for vk in downloaded:
			total += Packs.size_of(vk)
		var del := button("Delete download (frees %s)" % Packs.size_text(total), PANEL, 20)
		del.name = "DeleteDownload"
		del.pressed.connect(func():
			for vk in downloaded:
				Packs.remove(vk)
			show_info(g))
		inner.add_child(del)
	var web: Array = g.get("web", [])
	if web.size() > 0:
		inner.add_child(label("Earlier web versions in Laugh Lab (not playable here):", 19, MUTED))
		for w in web:
			inner.add_child(label("•  " + str(w), 19, MUTED))


## Put a game in (or out of) your collections, or start a new one.
func _collections_editor(parent: Control, g: Dictionary) -> void:
	var gid: String = g["id"]
	var row := HFlowContainer.new()
	row.name = "Collections"
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	row.add_child(label("Collections", 19, MUTED))
	for cname in GameData.collections():
		var inside := GameData.in_collection(cname, gid)
		var cb := button(("In: " if inside else "+ ") + cname, Color(0.85, 0.55, 0.15) if inside else Color(0.20, 0.27, 0.36), 18, false)
		cb.name = "Coll_" + cname.validate_node_name()
		cb.pressed.connect(func():
			GameData.toggle_in_collection(cname, gid)
			show_info(g))
		row.add_child(cb)
	var le := LineEdit.new()
	le.name = "NewCollection"
	le.placeholder_text = "New collection..."
	le.custom_minimum_size = Vector2(220, 52)
	le.add_theme_font_size_override("font_size", 19)
	row.add_child(le)
	var add := button("Add", Color(0.20, 0.27, 0.36), 18, false)
	add.name = "AddCollection"
	add.pressed.connect(func():
		var n := le.text.strip_edges()
		if n != "":
			GameData.add_collection(n)
			if not GameData.in_collection(n, gid):
				GameData.toggle_in_collection(n, gid)
			show_info(g))
	row.add_child(add)


## A screenshot full screen; tap anywhere to close.
func show_picture(tex: Texture2D) -> void:
	var layer := CanvasLayer.new()
	layer.name = "Picture"
	layer.layer = 9
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(tr)
	var close := Button.new()
	close.name = "ClosePicture"
	close.flat = true
	close.set_anchors_preset(Control.PRESET_FULL_RECT)
	close.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): layer.queue_free())
	layer.add_child(close)


# ---------------------------------------------------------------- settings page

func show_settings() -> void:
	page = "settings"
	clear_body()
	back_bar("Settings")
	var inner := scroll_box()
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
	section(inner, "Feel")
	var frow := HFlowContainer.new()
	frow.add_theme_constant_override("h_separation", 8)
	frow.add_theme_constant_override("v_separation", 8)
	inner.add_child(frow)
	var so := button("Tap sounds: on" if UiFx.sounds_on() else "Tap sounds: off", PANEL, 20, false)
	so.name = "TapSounds"
	so.pressed.connect(func():
		set_setting("ui", "sounds", not UiFx.sounds_on())
		show_settings())
	frow.add_child(so)
	var vi := button("Vibration: on" if UiFx.vibration_on() else "Vibration: off", PANEL, 20, false)
	vi.name = "Vibration"
	vi.pressed.connect(func():
		set_setting("ui", "vibration", not UiFx.vibration_on())
		show_settings())
	frow.add_child(vi)
	if not GameData.collections().is_empty():
		section(inner, "Your collections")
		for cname in GameData.collections():
			var crow := HBoxContainer.new()
			crow.add_theme_constant_override("separation", 10)
			inner.add_child(crow)
			crow.add_child(label("%s  (%d games)" % [cname, (GameData.collections()[cname] as Array).size()], 20))
			var del := button("Delete", Color(0.45, 0.18, 0.22), 18, false)
			del.pressed.connect(func():
				GameData.delete_collection(cname)
				show_settings())
			crow.add_child(del)
	section(inner, "App updates")
	inner.add_child(label("Lab Arcade %s. %s" % [GameData.app_version(), update_status], 19, MUTED))
	var urow := HFlowContainer.new()
	urow.add_theme_constant_override("h_separation", 8)
	urow.add_theme_constant_override("v_separation", 8)
	inner.add_child(urow)
	var cu := button("Check for updates", PANEL, 20, false)
	cu.name = "CheckUpdates"
	cu.pressed.connect(func():
		check_for_update(true)
		show_settings())
	urow.add_child(cu)
	var wn := button("What's new", PANEL, 20, false)
	wn.name = "WhatsNew"
	wn.pressed.connect(func(): show_whats_new(""))
	urow.add_child(wn)
	if not update_info.is_empty():
		var up := button("Update to %s" % update_info["version"], Color(0.33, 0.62, 0.10), 20, false)
		up.pressed.connect(func(): OS.shell_open(str(update_info.get("apk", ""))))
		urow.add_child(up)
	section(inner, "Downloads")
	var missing := []
	var missing_size := 0
	for g in all_games():
		var k := Packs.key_for(g, newest(g)["scene"])
		if Packs.status(k) != "ready":
			missing.append(k)
			missing_size += Packs.size_of(k)
	var have := Packs.state().size()
	inner.add_child(label("Games are downloaded the first time you play them, then work offline. An app update only downloads a game again if that game changed.\nOn this phone: %d downloads, %s." % [have, Packs.size_text(Packs.used_bytes())], 19, MUTED))
	if not missing.is_empty():
		var all := button("Download all %d games (%s)" % [missing.size(), Packs.size_text(missing_size)], Color(0.15, 0.45, 0.75), 20)
		all.name = "DownloadAll"
		all.pressed.connect(func():
			for k in missing:
				download(k))
		inner.add_child(all)
	if have > 0:
		var delall := button("Tap again to delete all downloads" if confirm_delete else "Delete all downloads", Color(0.6, 0.2, 0.25) if confirm_delete else PANEL, 20)
		delall.pressed.connect(func():
			if confirm_delete:
				for k in Packs.state().keys():
					Packs.remove(k)
				confirm_delete = false
			else:
				confirm_delete = true
			show_settings())
		inner.add_child(delall)
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
