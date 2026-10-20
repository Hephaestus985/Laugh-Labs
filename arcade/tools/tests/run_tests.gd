extends Node
# Lab Arcade test suite. Checks the menu and every version of every game in
# games.gd. Easiest: tools/test.sh (no window, no sound). By hand:
#   godot --headless --audio-driver Dummy --path . --fixed-fps 60 res://tools/tests/run_tests.tscn -- <report_dir> [menu|external]
# Exit code 0 = all passed, 1 = something failed. The report is written to
# <report_dir>/report.txt with one screenshot per game.
# Player high scores, saves and settings are backed up first and restored after.

const Games := preload("res://games.gd")
const USER_FILES := ["settings.cfg", "the_last_knight_save.json", "sock_escape_best.dat", "open_rpg_inventory.tres", "sokoban_level.dat"]

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		# Jolt (the 3D physics engine) warns when its job queue is briefly full under heavy load,
		# then waits and carries on. It's inside the engine, not a game bug, so it doesn't count.
		if file.contains("jolt_job_system"):
			return
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])

var log_counter := ErrorCounter.new()
var out_dir := "user://test_report"
var results: Array = []  # [game, test, ok, detail]
var backup := {}
var headless := false


func _ready() -> void:
	OS.add_logger(log_counter)
	AudioServer.set_bus_mute(0, true)  # tests are silent, also with a window
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	headless = DisplayServer.get_name() == "headless"
	if headless:
		# a phone-like window: bigger than the 1280x720 canvas, so taps get scaled
		# like on a real phone (a re-scaled tap once opened the wrong game)
		get_window().size = Vector2i(1920, 1080)
	await frames(1)  # the tree must finish setting up before games are added
	for g in Games.EXTERNAL:  # like the launcher: sleeping helpers of games by others
		if g.has("park"):
			load(g["park"]).park(get_tree())
	backup_user_files()
	await run_all()
	restore_user_files()
	write_report()
	var failed := results.filter(func(r): return not r[2]).size()
	get_tree().quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func check(game: String, test: String, ok: bool, detail := "") -> bool:
	results.append([game, test, ok, detail])
	print("%s  %-26s %-28s %s" % ["PASS" if ok else "FAIL", game, test, detail])
	return ok


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)


## Canvas position -> window position, the way a real touch screen reports it.
func to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_screen_transform() * p


func tap(pos: Vector2, index := 0) -> void:
	pos = to_window(pos)
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var r := InputEventScreenTouch.new()
	r.index = index
	r.position = pos
	r.pressed = false
	Input.parse_input_event(r)


func mouse(pos: Vector2, down: bool) -> void:
	pos = to_window(pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = down
	Input.parse_input_event(e)


## A finger swipe as the phone reports it (emulated mouse press, moves, release).
func swipe(from: Vector2, dy: float) -> void:
	mouse(from, true)
	await frames(1)
	for i in 12:
		var d := InputEventMouseMotion.new()
		d.position = to_window(from + Vector2(0, dy * (i + 1) / 12.0))
		d.global_position = d.position
		d.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(d)
		await frames(1)
	mouse(from + Vector2(0, dy), false)
	await frames(5)


## A one-finger drag as a touch screen sends it (touch, drags, lift).
func touch_swipe(from: Vector2, delta: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.position = to_window(from)
	e.pressed = true
	Input.parse_input_event(e)
	await frames(1)
	var last := from
	for i in 12:
		var d := InputEventScreenDrag.new()
		var p := from + delta * (i + 1) / 12.0
		d.position = to_window(p)
		d.relative = to_window(p) - to_window(last)
		last = p
		Input.parse_input_event(d)
		await frames(1)
	var r := InputEventScreenTouch.new()
	r.position = to_window(from + delta)
	r.pressed = false
	Input.parse_input_event(r)
	await frames(3)


func release_all_keys() -> void:
	for k in [KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_X, KEY_Z]:
		key(k, false)


## Standard deviation of the screen's brightness; ~0 means a blank screen.
func screen_detail(save_as := "") -> float:
	if headless:
		return 99.0
	var img := get_viewport().get_texture().get_image()
	if save_as != "":
		img.save_png("%s/%s.png" % [out_dir, save_as])
	img.resize(160, 90)
	var sum := 0.0
	var sq := 0.0
	for y in 90:
		for x in 160:
			var v := img.get_pixel(x, y).get_luminance()
			sum += v
			sq += v * v
	var n := 160.0 * 90.0
	return sqrt(maxf(0.0, sq / n - (sum / n) * (sum / n))) * 255.0


func new_errors(since: int) -> Array:
	return log_counter.errors.slice(since)


func backup_user_files() -> void:
	var d := DirAccess.open("user://")
	if d == null:
		return
	for f in d.get_files():
		if f in USER_FILES or f.begins_with("best_"):
			backup[f] = FileAccess.get_file_as_bytes("user://" + f)
			d.remove(f)


func restore_user_files() -> void:
	var d := DirAccess.open("user://")
	for f in d.get_files():
		if f in USER_FILES or f.begins_with("best_"):
			d.remove(f)
	for f in backup:
		var fa := FileAccess.open("user://" + f, FileAccess.WRITE)
		fa.store_buffer(backup[f])


## Runs a scene as the tree's current scene (next to this runner), so games
## that reload or change scenes don't take the test runner with them.
func spawn_current(scene_path: String) -> Node:
	var ps = load(scene_path)
	if ps == null:
		return null
	var n: Node = ps.instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	return n


func end_current() -> void:
	var cur := get_tree().current_scene
	if cur != self and is_instance_valid(cur):
		cur.queue_free()
	get_tree().current_scene = self
	await frames(2)


func has_code(n: Node) -> bool:
	return n != null and (n.get_script() != null or n.find_children("*", "TouchOverlay", true, false).size() > 0 or n.find_children("*", "", true, false).any(func(c): return c.get_script() != null))


func spawn(scene_path: String) -> Node:
	var ps = load(scene_path)
	if ps == null:
		return null
	var n: Node = ps.instantiate()
	add_child(n)
	return n


# ---------------------------------------------------------------- the tests

func run_all() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):  # quick run of some games: only=sudoku,minesweeper
			var ids: PackedStringArray = arg.substr(5).split(",")
			for g in Games.LIST + Games.EXTERNAL:
				if g["id"] in ids:
					if Games.EXTERNAL.has(g):
						await test_external(g)
					else:
						for v in g["versions"]:
							await test_game(g, v)
							await puzzle_checks(g, v)
			return
	if "external" in OS.get_cmdline_user_args():
		for g in Games.EXTERNAL:
			await test_external(g)
		return  # quick run: games by others only
	await test_menu()
	if "menu" in OS.get_cmdline_user_args():
		return  # quick run: launcher only
	for g in Games.LIST:
		for v in g["versions"]:
			await test_game(g, v)
			await puzzle_checks(g, v)
	await test_knight_flows()
	for g in Games.EXTERNAL:
		await test_external(g)


func test_menu() -> void:
	var errs := log_counter.errors.size()
	var ids := {}
	var ok_meta := true
	for g in Games.LIST:
		for field in ["id", "name", "tagline", "color", "versions", "length", "effort", "godot_time"]:
			if not g.has(field):
				ok_meta = false
				check("menu", "games.gd fields", false, "%s is missing %s" % [g.get("id", "?"), field])
		if ids.has(g["id"]):
			ok_meta = false
			check("menu", "unique game ids", false, g["id"])
		ids[g["id"]] = true
		var last := 0
		for v in g["versions"]:
			if v["v"] <= last:
				ok_meta = false
				check("menu", "versions in order", false, g["id"])
			last = v["v"]
			if not ResourceLoader.exists(v["scene"]):
				ok_meta = false
				check("menu", "version scene exists", false, v["scene"])
	check("menu", "games.gd is complete", ok_meta, "%d games" % Games.LIST.size())
	var m := spawn("res://menu.tscn")
	await frames(5)
	var all_n := Games.LIST.size() + Games.EXTERNAL.size()
	check("menu", "opens on the Library without picks", m.tab == 1)
	var cards: Node = m.find_child("Cards", true, false)
	check("menu", "Library has a card per game", cards != null and cards.get_child_count() == all_n, "%d cards" % (cards.get_child_count() if cards else 0))
	var plays_ok := cards != null
	if cards:
		for c in cards.get_children():
			plays_ok = plays_ok and c.find_child("Play", true, false) != null and c.find_child("Info", true, false) != null and c.find_child("HomeToggle", true, false) != null
	check("menu", "every card has Play, Info, + Home", plays_ok)
	check("menu", "renders", screen_detail("menu_landscape") > 3.0, "not checked: running headless" if headless else "")
	var db: Button = null
	for c in cards.get_children():
		db = c.find_child("Difficulty", true, false)
		if db:
			break
	if check("menu", "has difficulty buttons", db != null):
		var before := db.text
		db.emit_signal("pressed")
		await frames(1)
		check("menu", "difficulty button cycles", db.text != before, "%s -> %s" % [before, db.text])
		for g in Games.LIST:
			ArcadeGame.set_difficulty(g["id"], 1)
	# tapping Play on a card launches exactly that card's game (scaled like a phone)
	var launched := []
	m.launch_hook = func(id, _scene, _mode): launched.append(id)
	var right_game := true
	var picks := [0, 3, cards.get_child_count() - 1]
	for i in picks:
		var sc0: ScrollContainer = m.find_child("Scroll", true, false)
		var card: Control = cards.get_child(i)
		sc0.ensure_control_visible(card)
		await frames(3)
		launched.clear()
		var pc: Vector2 = card.find_child("Play", true, false).get_global_rect().get_center()
		mouse(pc, true)
		await frames(1)
		mouse(pc, false)
		await frames(3)
		var want := String(card.name).trim_prefix("Card_")
		right_game = right_game and launched.size() == 1 and launched[0] == want
		if launched.size() != 1 or launched[0] != want:
			print("  tap on card ", i, " (", want, ") launched ", launched)
	check("menu", "tap on Play opens that card's game", right_game)
	m.launch_hook = Callable()
	(m.find_child("Scroll", true, false) as ScrollContainer).scroll_vertical = 0
	await frames(2)
	# swiping scrolls the list, wherever the finger starts
	var sc: ScrollContainer = m.find_child("Scroll", true, false)
	var swipe_ok := sc != null
	if sc:
		var first_card: Control = cards.get_child(0)
		var r := first_card.get_global_rect()
		var spots := [r.position + Vector2(r.size.x * 0.5, 20), first_card.find_child("Play", true, false).get_global_rect().get_center(), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.45)]
		var got := []
		for spot in spots:
			m.fling = 0.0
			sc.scroll_vertical = 0
			await frames(3)
			await swipe(spot, -200)
			got.append(sc.scroll_vertical)
			swipe_ok = swipe_ok and sc.scroll_vertical > 100
		m.fling = 0.0
		print("  swipe results ", got)
		sc.scroll_vertical = 0
		await frames(2)
	check("menu", "swipe scrolls from card, label or button", swipe_ok)
	var info_btn: Button = cards.get_child(1).find_child("Info", true, false)
	var ic := info_btn.get_global_rect().get_center()
	mouse(ic, true)
	await frames(1)
	mouse(ic, false)
	await frames(4)
	check("menu", "tap on Info opens that card's page", m.page == "info" and m.page_game.get("id", "") == String(cards.get_child(1).name).trim_prefix("Card_") if is_instance_valid(cards) else m.page == "info", "page %s" % m.page_game.get("id", ""))
	var isc: ScrollContainer = m.find_child("Scroll", true, false)
	if isc:
		await swipe(isc.get_global_rect().get_center(), -200)
	check("menu", "info page scrolls by swipe", isc != null and isc.scroll_vertical > 50)
	m.go_back()
	await frames(3)
	# Home tab: the games you pick
	m.tab = 0
	m.show_list()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	check("menu", "Home is empty until you pick games", cards != null and cards.get_child_count() == 0)
	m.toggle_favorite("the_last_knight")
	m.toggle_favorite("outpost_assault")
	m.show_list()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	check("menu", "Home shows your picks", cards != null and cards.get_child_count() == 2)
	var ht: Button = cards.get_child(0).find_child("HomeToggle", true, false)
	var hc := ht.get_global_rect().get_center()
	mouse(hc, true)
	await frames(1)
	mouse(hc, false)
	await frames(3)
	cards = m.find_child("Cards", true, false)
	check("menu", "- Home removes a pick", cards != null and cards.get_child_count() == 1 and m.favorites().size() == 1)
	m.set_setting("ui", "favorites", [])
	# Library: search and filters
	m.tab = 1
	m.show_list()
	await frames(2)
	var se: LineEdit = m.find_child("Search", true, false)
	check("menu", "Library has a search bar", se != null)
	m.search = "knight"
	m.fill_cards()
	cards = m.find_child("Cards", true, false)
	check("menu", "search finds a game by name", cards.get_child_count() == 1 and String(cards.get_child(0).name) == "Card_the_last_knight")
	m.search = "tower defense"
	m.fill_cards()
	check("menu", "search matches descriptions", cards.get_child_count() == 1 and String(cards.get_child(0).name) == "Card_outpost_assault")
	m.search = "zzzz"
	m.fill_cards()
	check("menu", "search with no match shows no cards", cards.get_child_count() == 0)
	m.search = ""
	# drop-down filters: publisher, length, genre
	for id in ["PublisherFilter", "LengthFilter", "GenreFilter"]:
		var ob: OptionButton = m.find_child(id, true, false)
		check("menu", "Library has a %s drop-down" % id.trim_suffix("Filter").to_lower(), ob != null and ob.item_count > 2, "%d choices" % (ob.item_count if ob else 0))
	m.f_publisher = m.BY_OTHERS
	m.show_list()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	check("menu", "More games (by others) filter", cards.get_child_count() == Games.EXTERNAL.size())
	m.f_publisher = "Lab Arcade"
	m.fill_cards()
	check("menu", "Lab Arcade publisher filter", cards.get_child_count() == Games.LIST.size())
	m.f_publisher = "Kenney"
	m.fill_cards()
	check("menu", "publisher filter (Kenney)", cards.get_child_count() == 2)
	m.f_publisher = ""
	m.f_genre = "RPG"
	m.fill_cards()
	check("menu", "genre filter (RPG)", cards.get_child_count() == 1 and String(cards.get_child(0).name) == "Card_open_rpg")
	m.f_genre = ""
	var classes_ok := true
	var total := 0
	for li in range(1, m.LENGTHS.size()):
		m.f_length = li
		m.fill_cards()
		total += cards.get_child_count()
		for c in cards.get_children():
			for g in m.all_games():
				if "Card_" + g["id"] == String(c.name):
					classes_ok = classes_ok and m.length_class(g) == li
	check("menu", "length filters split the games", classes_ok and total == m.all_games().size(), "%d of %d" % [total, m.all_games().size()])
	# picking from the drop-down filters the list (as a tap on the phone would)
	m.f_length = 0
	m.show_list()
	await frames(2)
	var gob: OptionButton = m.find_child("GenreFilter", true, false)
	var gi := -1
	for i in gob.item_count:
		if gob.get_item_text(i) == "Racing":
			gi = i
	gob.select(gi)
	gob.item_selected.emit(gi)
	await frames(2)
	cards = m.find_child("Cards", true, false)
	check("menu", "choosing a genre in the drop-down filters", m.f_genre == "Racing" and cards.get_child_count() == 1)
	# coming back from a game builds a new menu: the filter must still be there
	var m2: Node = load("res://menu.tscn").instantiate()
	add_child(m2)
	await frames(3)
	var cards2: Node = m2.find_child("Cards", true, false)
	check("menu", "filters are kept after playing a game", m2.f_genre == "Racing" and cards2 != null and cards2.get_child_count() == 1, "genre '%s'" % m2.f_genre)
	m2.f_genre = ""
	m2.fill_cards()
	m2.queue_free()
	await frames(1)
	m.f_genre = ""
	m.f_length = 0
	m.show_list()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	# every sort order still lists every game
	var sorts_ok := true
	for i in m.SORTS.size():
		m.set_setting("ui", "sort", i)
		var sids = m.sorted_games().map(func(g): return g["id"])
		sorts_ok = sorts_ok and sids.size() == all_n
	m.set_setting("ui", "sort", 0)
	var az: Array = m.sorted_games().map(func(g): return g["name"])
	var az_sorted := az.duplicate()
	az_sorted.sort()
	check("menu", "all sort orders work", sorts_ok and az == az_sorted)
	m.set_setting("ui", "sort", 3)
	var short: Array = m.sorted_games()
	check("menu", "shortest first sorts by length", m.minutes(short[0]) <= m.minutes(short[short.size() - 1]), "%s .. %s" % [short[0]["id"], short[short.size() - 1]["id"]])
	m.set_setting("ui", "sort", 0)
	# play statistics
	var p0: int = m.plays("sock_escape")
	m.record_play("sock_escape")
	check("menu", "play count is recorded", m.plays("sock_escape") == p0 + 1 and m.last_played("sock_escape") > 0)
	# info page for every game
	var info_ok := true
	for g in m.all_games():
		m.show_info(g)
		await frames(1)
		info_ok = info_ok and m.body.get_child_count() >= 2
	check("menu", "info page for every game", info_ok)
	m.show_info(Games.LIST[Games.LIST.size() - 1])
	await frames(3)
	screen_detail("menu_info")
	m.show_settings()
	await frames(3)
	check("menu", "settings page builds", m.page == "settings" and m.body.get_child_count() >= 2)
	screen_detail("menu_settings")
	m.go_back()
	await frames(2)
	check("menu", "back returns to the list", m.page == "list")
	# portrait layout: turning the screen gives one column of cards
	if headless:
		check("menu", "portrait layout = 1 column", true, "skipped without a window")
	else:
		var old: Vector2i = DisplayServer.window_get_size()
		DisplayServer.window_set_size(Vector2i(540, 960))
		await frames(10)
		cards = m.find_child("Cards", true, false)
		check("menu", "portrait layout = 1 column", cards != null and cards.columns == 1)
		screen_detail("menu_portrait")
		DisplayServer.window_set_size(old)
		for i in 60:
			await frames(1)
			cards = m.find_child("Cards", true, false)
			if cards != null and cards.columns == 2:
				break
	cards = m.find_child("Cards", true, false)
	check("menu", "landscape layout = 2 columns", cards != null and cards.columns == 2)
	m.queue_free()
	await frames(2)
	check("menu", "no errors", new_errors(errs).is_empty(), ", ".join(new_errors(errs).slice(0, 3)))


func test_game(g: Dictionary, v: Dictionary) -> void:
	var name := "%s v%d" % [g["id"], v["v"]]
	var errs := log_counter.errors.size()
	release_all_keys()
	var n := spawn(v["scene"])
	if not check(name, "scene loads", n != null):
		return
	if not check(name, "has its game code", n.get_script() != null, "script missing from scene"):
		n.queue_free()
		return
	await frames(10)
	check(name, "uses the landscape game screen", get_window().content_scale_size == Vector2i(1280, 720))
	check(name, "title screen renders", screen_detail() > 3.0, "not checked: running headless" if headless else "")
	check(name, "starts on the title", int(n.get("state")) == 0)
	# a tap in the middle of the screen must start the game
	await tap(Vector2(640, 360))
	await frames(6)
	check(name, "tap starts the game", int(n.get("state")) != 0, "state %s" % n.get("state"))
	# play for 20 seconds with random keys and taps
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var keys := [KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_X]
	var held := {}
	for f in 1200:
		if f % 5 == 0:
			var k: int = keys[rng.randi() % keys.size()]
			held[k] = not held.get(k, false)
			key(k, held[k])
		if f % 90 == 45:
			await tap(Vector2(rng.randf_range(200, 1200), rng.randf_range(150, 650)), 1)
		if int(n.get("state")) != 0 and f % 200 == 199:
			pass
		await get_tree().process_frame
		if not is_instance_valid(n):
			break
	release_all_keys()
	if not check(name, "survives 20 s of play", is_instance_valid(n)):
		return
	check(name, "screen still renders", screen_detail(g["id"] + "_v%d" % v["v"]) > 3.0, "not checked: running headless" if headless else "")
	# high score saving
	if n.has_method("submit_score"):
		n.set("best", 0)
		n.call("submit_score", 4242)
		n.call("load_best")
		check(name, "high score is saved", int(n.get("best")) == 4242)
	# difficulty from the menu reaches the game
	ArcadeGame.set_difficulty(g["id"], 2)
	n.queue_free()
	await frames(2)
	var n2 := spawn(v["scene"])
	await frames(3)
	var hard := false
	if n2.get("diff") != null:
		hard = int(n2.get("diff")) == 2
	else:
		await tap(Vector2(640, 360))
		await frames(4)
		hard = is_equal_approx(float(n2.get("mult")), 1.25)
	check(name, "difficulty setting is used", hard)
	ArcadeGame.set_difficulty(g["id"], 1)
	# Esc must lead back to the menu (checked without leaving the test scene)
	check(name, "has a way back to the menu", n2.has_method("back_to_menu"))
	n2.queue_free()
	await frames(2)
	var e := new_errors(errs)
	check(name, "no errors", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])


## The calm board games (PuzzleGame): touch play, save and Continue, winning.
func puzzle_checks(g: Dictionary, v: Dictionary) -> void:
	var probe: Node = load(v["scene"]).instantiate()
	var is_puzzle := probe is PuzzleGame
	probe.free()
	if not is_puzzle:
		return
	var name := "%s v%d" % [g["id"], v["v"]]
	var errs := log_counter.errors.size()
	ArcadeGame.set_difficulty(g["id"], 1)
	var n: PuzzleGame = spawn(v["scene"])
	await frames(3)
	n.clear_save()
	await tap(Vector2(640, 360))
	await frames(4)
	if not check(name, "tap starts a round", n.state == 1):
		n.queue_free()
		return
	var before := JSON.stringify(n.to_save())
	await call("play_" + g["id"], n, name)
	await frames(3)
	var after := JSON.stringify(n.to_save())
	if n.state == 1:
		check(name, "touch play changes the board (phone)", before != after)
		# leave and come back: Continue restores the same board
		n.save_game()
		n.queue_free()
		await frames(2)
		Engine.set_meta("launch_mode", "continue")
		var n2: PuzzleGame = spawn(v["scene"])
		await frames(3)
		check(name, "Continue restores the board", n2.state == 1 and JSON.stringify(n2.to_save()) == after)
		n2.queue_free()
		await frames(2)
	else:
		n.queue_free()
		await frames(2)
	# turn the phone: a tall screen gets a portrait layout that still plays by touch
	var win_size := get_window().size
	get_window().size = Vector2i(1080, 1920)
	await frames(2)
	Engine.set_meta("launch_mode", "new")
	var np: PuzzleGame = spawn(v["scene"])
	await frames(4)
	var fits := np.portrait and get_window().content_scale_size == Vector2i(720, 1280)
	for b in np.buttons:
		fits = fits and Rect2(0, 0, 720, 1280).encloses(b[0]) and not (b[0] as Rect2).intersects(np.board_rect)
	check(name, "portrait: turns with the phone, buttons fit (phone)", fits, "portrait %s, %d buttons" % [np.portrait, np.buttons.size()])
	var pb := JSON.stringify(np.to_save())
	await call("play_" + g["id"], np, name + " portrait")
	await frames(3)
	check(name, "portrait: touch play works (phone)", np.state != 1 or JSON.stringify(np.to_save()) != pb)
	np.queue_free()
	await frames(2)
	get_window().size = win_size
	await frames(2)
	DirAccess.remove_absolute("user://best_%s.dat" % g["id"])
	# a fresh round on every difficulty
	for d in 3:
		ArcadeGame.set_difficulty(g["id"], d)
		Engine.set_meta("launch_mode", "new")
		var nd: PuzzleGame = spawn(v["scene"])
		await frames(2)
		check(name, "new %s round starts" % ArcadeGame.DIFF_NAMES[d], nd.state == 1 and nd.diff == d)
		if d == 1:
			await call("win_" + g["id"], nd)
			await frames(2)
			check(name, "solving it wins and saves the best score", nd.state == 2 and nd.won and nd.best > 0 and nd.best == nd.score and not FileAccess.file_exists(nd.save_path()), "state %d won %s best %d" % [nd.state, nd.won, nd.best])
		nd.queue_free()
		await frames(2)
	ArcadeGame.set_difficulty(g["id"], 1)
	DirAccess.remove_absolute("user://best_%s.dat" % g["id"])
	DirAccess.remove_absolute("user://%s_save.json" % g["id"])
	var e := new_errors(errs)
	check(name, "no errors while solving", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])


# ---- per-game touch play and a way to win (used by puzzle_checks)

func play_game_2048(n: PuzzleGame, name: String) -> void:
	var moved_anim := false
	for d in [Vector2(-300, 0), Vector2(0, 300), Vector2(300, 0), Vector2(0, -300)]:
		var before := JSON.stringify(n.get("cells"))
		await touch_swipe(n.get("borigin") + Vector2(n.get("bsize"), n.get("bsize")) * 0.5 - d * 0.5, d)
		if JSON.stringify(n.get("cells")) != before and not n.get("slides").is_empty():
			moved_anim = true
	check(name, "tiles slide with an animation", moved_anim)


func win_game_2048(n: PuzzleGame) -> void:
	var c: Array = n.get("cells")
	c.fill(0)
	c[0] = 1024
	c[1] = 1024
	n.set("cells", c)
	n.call("move", Vector2i.LEFT)  # makes 2048; the round goes on
	await frames(1)
	# fill the board so no move is left, which ends the round with the 2048 reached
	var k := 0
	for i in c.size():
		c[i] = 2 << (k % 10) if i != 0 else 2048
		k += 3 if (i % n.get("n")) == 0 else 1
	var vals := [2, 4, 8, 16, 32, 64, 128, 256, 512]
	for i in c.size():
		var x: int = i % int(n.get("n"))
		var y: int = i / int(n.get("n"))
		c[i] = vals[(x + 2 * y) % vals.size()] if i != 0 else 2048
	c[c.size() - 1] = 0
	n.set("cells", c)
	n.call("move", Vector2i.RIGHT)


func play_sudoku(n: PuzzleGame, name: String) -> void:
	var grid: Array = n.get("grid")
	var empty := grid.find(0)
	var cell_pos: Vector2 = n.ORIGIN + Vector2(empty % 9 + 0.5, empty / 9 + 0.5) * n.CELL
	await tap(cell_pos)
	await frames(2)
	var want: int = n.get("solution")[empty]
	var pad: Vector2 = n.call("pad_rect", want).get_center()
	await tap(pad)
	await frames(2)
	check(name, "tap a cell, then a number, fills it (phone)", n.get("grid")[empty] == want)
	var copy: Array = n.get("solution").duplicate()
	var given: Array = n.get("given")
	var puzzle := []
	for i in 81:
		puzzle.append(copy[i] if given[i] else 0)
	check(name, "the puzzle has exactly one solution", n._solve(puzzle, 2, false) == 1)


func win_sudoku(n: PuzzleGame) -> void:
	var sol: Array = n.get("solution")
	var g: Array = sol.duplicate()
	var last := 0
	for i in 81:
		if not n.get("given")[i]:
			last = i
	g[last] = 0
	n.set("grid", g)
	n.set("sel", last)
	n.call("put", sol[last])


func play_minesweeper(n: PuzzleGame, name: String) -> void:
	var c: float = n.get("cell")
	var start_cell: int = 3 * int(n.get("cols")) + 3
	await tap(n.call("cell_pos", start_cell) + Vector2(c, c) * 0.5)
	await frames(2)
	check(name, "first tap opens safe cells (phone)", n.get("open").count(true) > 1 and n.state == 1)
	# long-press a closed cell to flag it
	var closed: int = n.get("open").find(false)
	var p: Vector2 = n.call("cell_pos", closed) + Vector2(c, c) * 0.5
	var e := InputEventScreenTouch.new()
	e.position = to_window(p)
	e.pressed = true
	Input.parse_input_event(e)
	await frames(45)
	var r := InputEventScreenTouch.new()
	r.position = e.position
	Input.parse_input_event(r)
	await frames(3)
	check(name, "long-press places a flag (phone)", n.get("flag")[closed])


func win_minesweeper(n: PuzzleGame) -> void:
	n.call("reveal", 0)  # places the mines
	var mine: Array = n.get("mine")
	var open: Array = n.get("open")
	for i in mine.size():
		if not mine[i] and not open[i]:
			n.call("reveal", i)
			if n.state != 1:
				return


func play_solitaire(n: PuzzleGame, name: String) -> void:
	var before: int = n.get("waste").size()
	await tap(n.call("stock_rect").get_center())
	await frames(2)
	check(name, "tap the deck draws a card (phone)", n.get("waste").size() == before + 1)
	# drag: find a pile top that fits on another pile, or at least drag one and see it come back
	var moved := false
	for p in 7:
		var pile: Array = n.get("piles")[p]
		var c: int = pile.back()
		for q in 7:
			if q != p and n.call("fits_pile", c, q):
				var from: Vector2 = n.call("card_pos", p, pile.size() - 1) + Vector2(50, 40)
				var to: Vector2 = n.call("card_pos", q, n.get("piles")[q].size() - 1) + Vector2(50, 90)
				await touch_swipe(from, to - from)
				moved = n.get("piles")[q].has(c)
				break
		if moved:
			break
	if moved:
		check(name, "dragging a card onto a pile moves it (phone)", true)


func win_solitaire(n: PuzzleGame) -> void:
	var found := [range(0, 13), range(13, 26), range(26, 39), range(39, 51)]
	n.set("found", found)
	n.set("piles", [[51], [], [], [], [], [], []])
	n.set("stock", [])
	n.set("waste", [])
	n.call("auto_move", "p0", 0)


func play_nonogram(n: PuzzleGame, name: String) -> void:
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	await tap(o + Vector2(0.5, 0.5) * c)
	await frames(2)
	check(name, "tap fills a cell (phone)", n.get("cells")[0] == 1)
	# drag along the second row paints it
	await touch_swipe(o + Vector2(0.5, 1.5) * c, Vector2(c * 3, 0))
	await frames(2)
	var nn: int = n.get("n")
	check(name, "drag paints a row (phone)", n.get("cells")[nn] == 1 and n.get("cells")[nn + 3] == 1)


func win_nonogram(n: PuzzleGame) -> void:
	var tgt: Array = n.get("target")
	var cells: Array = tgt.map(func(v): return 1 if v else 0)
	var last := tgt.rfind(true)
	cells[last] = 0
	n.set("cells", cells)
	n.call("_hint")


func play_lights_out(n: PuzzleGame, name: String) -> void:
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	var before: Array = n.get("lit").duplicate()
	await tap(o + Vector2(1.5, 1.5) * c)
	await frames(2)
	var nn: int = n.get("n")
	var i := nn + 1
	var after: Array = n.get("lit")
	check(name, "tap flips a light and its neighbours (phone)", after[i] != before[i] and after[i - 1] != before[i - 1] and after[i + nn] != before[i + nn] and after[i + 1] != before[i + 1] and after[i - nn] != before[i - nn])


func win_lights_out(n: PuzzleGame) -> void:
	var need: Array = n.get("need")
	for i in need.size():
		if need[i] and n.state == 1:
			n.call("tap_cell", i)


func play_sliding_puzzle(n: PuzzleGame, name: String) -> void:
	var tiles: Array = n.get("tiles")
	var nn: int = n.get("n")
	var g := tiles.find(0)
	var pick := g - 1 if g % nn > 0 else g + 1
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	await tap(o + Vector2(pick % nn + 0.5, pick / nn + 0.5) * c)
	await frames(2)
	check(name, "tap a tile next to the gap slides it (phone)", n.get("tiles")[pick] == 0)


func win_sliding_puzzle(n: PuzzleGame) -> void:
	var nn: int = n.get("n")
	var tiles := []
	for i in nn * nn - 1:
		tiles.append(i + 1)
	tiles.append(0)
	# one step away from solved: the gap one to the left
	tiles[nn * nn - 1] = nn * nn - 1
	tiles[nn * nn - 2] = 0
	n.set("tiles", tiles)
	n.call("slide", nn * nn - 1)


func play_mahjong(n: PuzzleGame, name: String) -> void:
	var pair: Array = n.call("_pairs")
	if pair.is_empty():
		n.call("_shuffle")
		pair = n.call("_pairs")
	var left: int = n.call("_alive").size()
	for i in pair:
		await tap(n.call("tile_rect", i).get_center())
		await frames(2)
	check(name, "tap two matching free tiles removes them (phone)", n.call("_alive").size() == left - 2)


func win_mahjong(n: PuzzleGame) -> void:
	# the deal is built to be clearable: keep taking pairs (shuffle if stuck)
	var guard := 0
	while n.state == 1 and guard < 300:
		guard += 1
		var pair: Array = n.call("_pairs")
		if pair.is_empty():
			n.call("_shuffle")
			continue
		n.call("pick", pair[0])
		n.call("pick", pair[1])


func play_sokoban(n: PuzzleGame, name: String) -> void:
	var p0: int = n.get("player")
	var w: int = n.get("w")
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	# swipe in every direction until one step works
	for d in [Vector2(200, 0), Vector2(-200, 0), Vector2(0, 200), Vector2(0, -200)]:
		await touch_swipe(Vector2(500, 380), d)
		await frames(2)
		if n.get("player") != p0:
			break
	check(name, "swipe walks the worker (phone)", n.get("player") != p0)


func win_sokoban(n: PuzzleGame) -> void:
	n.set("boxes", n.get("goals").duplicate())
	n.call("_check")


func play_flow(n: PuzzleGame, name: String) -> void:
	# drag along the first solution pipe
	var sol: Array = n.get("solution")[0]
	var nn: int = n.get("n")
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	var pts := sol.map(func(i): return o + Vector2(i % nn + 0.5, i / nn + 0.5) * c)
	var e := InputEventScreenTouch.new()
	e.position = to_window(pts[0])
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	for k in range(1, pts.size()):
		var d := InputEventScreenDrag.new()
		d.position = to_window(pts[k])
		Input.parse_input_event(d)
		await frames(2)
	var r := InputEventScreenTouch.new()
	r.position = to_window(pts.back())
	Input.parse_input_event(r)
	await frames(3)
	check(name, "dragging from a dot to its partner connects them (phone)", n.call("pipe_done", 0))


func win_flow(n: PuzzleGame) -> void:
	var sol: Array = n.get("solution")
	var paths := []
	for k in sol.size():
		paths.append(sol[k].duplicate() if k > 0 else [])
	n.set("paths", paths)
	n.call("_hint")


func play_block_stacker(n: PuzzleGame, name: String) -> void:
	var p0: Vector2i = n.get("pos")
	await touch_swipe(Vector2(500, 300), Vector2(-130, 0))
	await frames(2)
	check(name, "dragging sideways slides the piece (phone)", n.get("pos").x < p0.x)
	await touch_swipe(Vector2(500, 200), Vector2(0, 260))
	await frames(3)
	check(name, "swipe down drops the piece (phone)", n.get("grid").filter(func(v): return v != "").size() == 4)


func win_block_stacker(n: PuzzleGame) -> void:
	var g: Array = n.get("grid")
	g.fill("")
	for x in 9:
		g[19 * 10 + x] = "T"
	n.set("grid", g)
	n.set("lines", int(n.get("target")) - 1)
	n.set("cells", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	n.set("piece", "I")
	n.set("pos", Vector2i(9, 0))
	n.call("hard_drop")
	# the target is reached; the round goes on until the stack tops out
	for k in 300:
		if n.state != 1:
			break
		n.call("hard_drop")


func play_connect_four(n: PuzzleGame, name: String) -> void:
	var o: Vector2 = n.ORIGIN
	await tap(o + Vector2(3.5 * n.CELL, 3 * n.CELL))
	await frames(2)
	check(name, "tap a column drops a disc (phone)", n.get("board")[5 * 7 + 3] == 1)
	for k in 120:
		if n.get("turn") == 1:
			break
		await frames(1)
	check(name, "the computer answers", n.get("board").filter(func(v): return v == 2).size() == 1)


func win_connect_four(n: PuzzleGame) -> void:
	var b: Array = n.get("board")
	b.fill(0)
	for c in 3:
		b[5 * 7 + c] = 1
	b[4 * 7 + 0] = 2
	b[4 * 7 + 1] = 2
	n.set("board", b)
	n.set("turn", 1)
	n.call("play", 3, 1)


func test_knight_flows() -> void:
	var name := "the_last_knight"
	var scene := "res://games/the_last_knight/v2/game.tscn"
	if not ResourceLoader.exists(scene):
		return
	var errs := log_counter.errors.size()
	# every level loads and can be walked into
	var k := spawn(scene)
	await frames(2)
	k.call("begin_run")
	var all_ok := true
	for lvl in range(1, 6):
		k.call("load_level", lvl)
		for f in 60:
			k.p["inv"] = 99.0
			await get_tree().process_frame
		all_ok = all_ok and int(k.get("lv")) == lvl
	check(name, "all 5 levels load", all_ok)
	# reaching the arena starts the boss; beating it ends the game
	k.p["x"] = 80 * 32.0
	await frames(10)
	check(name, "boss fight starts", k.get("boss") != null and bool(k.get("boss_on")))
	if k.get("boss") != null:
		var b: Dictionary = k.get("boss")
		var phases := {}
		for i in 20:
			b["inv"] = 0.0
			b["st"] = "reload"
			k.call("boss_hit", "bolt", 0.0, 0.0)
			phases[b["ph"]] = true
			if b["st"] == "dead":
				break
		check(name, "boss has 3 phases", phases.size() == 3, str(phases.keys()))
		for f in 320:
			await get_tree().process_frame
		check(name, "beating the boss ends the game", int(k.get("state")) == 5, "state %s" % k.get("state"))
	k.queue_free()
	await frames(2)
	# saving and continuing from the menu
	var save := {"v": 1, "diff": 2, "lv": 3, "boss": false, "score": 1234, "lives": 2, "time": 10.0, "coins": 1, "kills": 1, "geese": 0, "parries": 0, "seen": {}}
	var fa := FileAccess.open("user://the_last_knight_save.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify(save))
	fa = null
	Engine.set_meta("launch_mode", "continue")
	k = spawn(scene)
	await frames(5)
	check(name, "Continue loads the save", int(k.get("lv")) == 3 and int(k.get("score")) == 1234 and int(k.get("state")) == 1, "level %s score %s" % [k.get("lv"), k.get("score")])
	check(name, "playing a level saves progress", FileAccess.file_exists("user://the_last_knight_save.json"))
	k.queue_free()
	await frames(2)
	Engine.set_meta("launch_mode", "new")
	k = spawn(scene)
	await frames(3)
	check(name, "New game clears the save", not FileAccess.file_exists("user://the_last_knight_save.json"))
	# losing all lives ends in game over
	k.call("begin_run")
	k.call("load_level", 1)
	k.set("lives", 1)
	k.p["hp"] = 1
	k.p["inv"] = 0.0
	k.call("damage", "a test")
	for f in 150:
		await get_tree().process_frame
	check(name, "losing all lives = game over", int(k.get("state")) == 6, "state %s" % k.get("state"))
	k.queue_free()
	await frames(2)
	var e := new_errors(errs)
	check(name, "flows: no errors", e.is_empty(), ", ".join(e.slice(0, 3)))


func test_external(g: Dictionary) -> void:
	var name: String = g["id"]
	var errs := log_counter.errors.size()
	var v: Dictionary = g["versions"][g["versions"].size() - 1]
	var lic := Array(DirAccess.get_files_at("res://external/%s" % name)).any(func(f): return f.begins_with("LICENSE"))
	check(name, "license file included", lic)
	var start := spawn_current(v["scene"])
	if not check(name, "start screen loads with its code", has_code(start)):
		await end_current()
		return
	await frames(10)
	check(name, "start screen renders", screen_detail(name + "_start") > 3.0, "not checked: running headless" if headless else "")
	var has_back := start.has_method("_on_quit_pressed") or start.find_children("*", "TouchOverlay", true, false).size() > 0
	check(name, "has a way back to the arcade", has_back)
	var same: bool = g.get("main", v["scene"]) == v["scene"]
	var map: Node = start
	if not same:
		await end_current()
		map = spawn_current(g["main"])
	if not check(name, "game scene loads with its code", has_code(map)):
		await end_current()
		return
	await frames(30)
	await phone_checks(name, map)
	# play for 20 s with random taps and keys
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for f in 1200:
		if f % 40 == 20:
			await tap(Vector2(rng.randf_range(250, 1000), rng.randf_range(150, 600)))
		if f % 10 == 0:
			var k: int = [KEY_W, KEY_A, KEY_D, KEY_SPACE, KEY_S][rng.randi() % 5]
			key(k, rng.randf() < 0.6)
		await get_tree().process_frame
	release_all_keys()
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		key(k, false)
	# (a game may legally restart its own scene, e.g. after falling off)
	check(name, "survives 20 s of play", is_instance_valid(get_tree().current_scene) and get_tree().current_scene != self)
	check(name, "screen still renders", screen_detail(name + "_play") > 3.0, "not checked: running headless" if headless else "")
	get_tree().paused = false
	await back_via_menu_button(name)
	var e := new_errors(errs)
	check(name, "no errors", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])


## Taps "< MENU" like a player would and checks the launcher comes back cleanly.
func back_via_menu_button(name: String) -> void:
	var cur := get_tree().current_scene
	var ovs := cur.find_children("*", "TouchOverlay", true, false) if is_instance_valid(cur) and cur != self else []
	if ovs.is_empty():
		await end_current()
		return
	var ov: TouchOverlay = ovs[0]
	var menu_rect: Rect2 = ov.buttons.filter(func(b): return b[1] is String and b[1] == "__menu")[0][0]
	await tap(menu_rect.get_center())
	await frames(20)
	var now := get_tree().current_scene
	check(name, "< MENU returns to the launcher (phone)", is_instance_valid(now) and now.scene_file_path == "res://menu.tscn", str(now.scene_file_path if is_instance_valid(now) else "none"))
	await end_current()


## Racing: holding the stick towards a screen direction drives the truck that way on screen
## (John found left and right swapped when the truck drove towards the camera).
func steer_checks(name: String, ov: TouchOverlay, body: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	var dirs := {"right": Vector2(1, 0), "down": Vector2(0, 1), "left": Vector2(-1, 0), "up": Vector2(0, -1)}
	for dname in dirs:
		var d: Vector2 = dirs[dname]
		var from := Vector2(260, ov.laid_out_for.y - 260)
		var e := InputEventScreenTouch.new()
		e.index = 5
		e.position = to_window(from)
		e.pressed = true
		Input.parse_input_event(e)
		await frames(2)
		var drag := InputEventScreenDrag.new()
		drag.index = 5
		drag.position = to_window(from + d * 100)
		Input.parse_input_event(drag)
		await frames(150)  # time to turn
		# which way the truck points (it may be sliding along a wall, so not its movement)
		var model: Node3D = body.get_parent().get("vehicle_model")
		var pos := model.global_position
		var ahead := model.global_basis.z
		ahead.y = 0
		var r := InputEventScreenTouch.new()
		r.index = 5
		r.position = drag.position
		Input.parse_input_event(r)
		await frames(30)
		var sp := cam.unproject_position(pos + ahead.normalized()) - cam.unproject_position(pos)
		check(name, "stick %s points the truck %s on screen (phone)" % [dname, dname], sp.length() > 5 and sp.normalized().dot(d) > 0.9, "screen heading %s" % sp.normalized())


## Touch-plays a game with the arcade's on-screen controls (TouchOverlay).
func overlay_checks(name: String, game: Node) -> void:
	var ov_list := game.find_children("*", "TouchOverlay", true, false)
	if not check(name, "has on-screen phone controls", ov_list.size() > 0):
		return
	var ov: TouchOverlay = ov_list[0]
	await frames(2)
	var mover: Node3D = null
	for n in game.find_children("*", "CharacterBody3D", true, false) + game.find_children("*", "RigidBody3D", true, false):
		mover = n
		break
	if mover == null:
		return
	var p0 := mover.global_position
	if ov.stick_actions.size() == 4:
		# hold the stick up-right for a second
		var from := Vector2(200, ov.laid_out_for.y - 180)
		var e := InputEventScreenTouch.new()
		e.index = 3
		e.position = to_window(from)
		e.pressed = true
		Input.parse_input_event(e)
		await frames(2)
		var d := InputEventScreenDrag.new()
		d.index = 3
		d.position = to_window(from + Vector2(60, -90))
		Input.parse_input_event(d)
		await frames(60)
		var r := InputEventScreenTouch.new()
		r.index = 3
		r.position = to_window(from + Vector2(60, -90))
		r.pressed = false
		Input.parse_input_event(r)
		await frames(3)
		check(name, "stick moves the player (phone)", mover.global_position.distance_to(p0) > 0.3, "moved %.2f" % mover.global_position.distance_to(p0))
		if mover.get_parent() is Vehicle:
			await steer_checks(name, ov, mover)
	for b in ov.buttons:
		if not b[1] is String or b[1] == "__menu" or b[3]:
			continue
		var y0 := mover.global_position
		var c: Vector2 = (b[0] as Rect2).get_center()
		var e2 := InputEventScreenTouch.new()
		e2.index = 4
		e2.position = to_window(c)
		e2.pressed = true
		Input.parse_input_event(e2)
		await frames(40)
		var held_ok := Input.is_action_pressed(b[1]) or mover.global_position.distance_to(y0) > 0.05
		var r2 := InputEventScreenTouch.new()
		r2.index = 4
		r2.position = to_window(c)
		r2.pressed = false
		Input.parse_input_event(r2)
		await frames(3)
		check(name, "button %s works (phone)" % b[2], held_ok and not Input.is_action_pressed(b[1]))


## Plays Open RPG with taps only: the opening conversation, walking, and a battle turn.
func rpg_checks(name: String, main: Node) -> void:
	var dlg: Node = get_tree().root.get_node("Dialogic")
	for i in 240:
		if dlg.get("current_timeline") != null:
			break
		await frames(1)
	if not check(name, "opening conversation starts", dlg.get("current_timeline") != null):
		return
	await frames(60)
	var idx0: int = dlg.get("current_event_idx")
	var mid := Vector2(640, 400)
	await tap(mid)
	await frames(30)
	check(name, "a tap moves the conversation on (phone)", dlg.get("current_event_idx") > idx0, "event %d -> %d" % [idx0, dlg.get("current_event_idx")])
	for i in 30:
		if dlg.get("current_timeline") == null:
			break
		await tap(mid)
		await frames(30)
	check(name, "tapping through ends the conversation", dlg.get("current_timeline") == null)
	await frames(200)  # fade in and music
	# walk: tap a free cell a few steps away
	var gp: Node2D = get_tree().root.get_node("Player").get("gamepiece")
	if not check(name, "the player has a character", gp != null):
		return
	var board: Node = get_tree().root.get_node("Gameboard")
	var reg: Node = get_tree().root.get_node("GamepieceRegistry")
	var start_cell: Vector2i = reg.call("get_cell", gp)
	var goal := Vector2i(-99, -99)
	for d in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, 2)]:
		var c: Vector2i = start_cell + d
		if not board.get("pathfinder").call("get_path_to_cell", start_cell, c).is_empty():
			goal = c
			break
	if not check(name, "there is somewhere to walk", goal != Vector2i(-99, -99)):
		return
	var screen: Vector2 = gp.get_parent().get_global_transform_with_canvas() * board.call("cell_to_pixel", goal)
	await tap(screen)
	await frames(240)
	check(name, "a tap on the ground walks there (phone)", reg.call("get_cell", gp) == goal, "%s -> %s (goal %s)" % [start_cell, reg.call("get_cell", gp), goal])
	# a battle: start one the way an encounter does, then play the first choice with taps
	var arena: PackedScene = null
	for n in main.find_children("*", "", true, false):
		if "combat_arena" in n and n.get("combat_arena") is PackedScene:
			arena = n.get("combat_arena")
			break
	if not check(name, "the map has a battle", arena != null):
		return
	get_tree().root.get_node("FieldEvents").emit_signal("combat_triggered", arena)
	var menu: Node = null
	for i in 300:
		var menus := main.find_children("*", "UIActionMenu", true, false)
		if menus.size() > 0 and menus[0].visible:
			menu = menus[0]
			break
		await frames(1)
	if not check(name, "battle shows the action menu", menu != null):
		return
	await frames(30)
	var btn: Control = null
	for b in menu.get_children():
		if b is BaseButton and not b.disabled and b.get("action") and b.get("action").get("targets_enemies"):
			btn = b
			break
	if not check(name, "an attack can be chosen", btn != null):
		return
	var acting: Node = btn.get("action").get("source")
	await tap(btn.get_global_transform_with_canvas() * (btn.size / 2))
	await frames(30)
	var cursors := main.find_children("*", "UIBattlerTargetingCursor", true, false)
	if not check(name, "tap on an attack asks for a target (phone)", cursors.size() > 0):
		return
	# BACK cancels the target choice (it was broken in 1.10)
	var ov: TouchOverlay = main.find_children("*", "TouchOverlay", true, false)[0]
	var back_rect: Rect2 = ov.buttons.filter(func(b): return b[2] == "BACK")[0][0]
	await tap(back_rect.get_center(), 2)
	await frames(20)
	check(name, "BACK cancels picking a target (phone)", not is_instance_valid(cursors[0]))
	menu = null
	for i in 120:
		var menus := main.find_children("*", "UIActionMenu", true, false)
		if menus.size() > 0 and menus[0].visible:
			menu = menus[0]
			break
		await frames(1)
	if not check(name, "BACK shows the actions again", menu != null):
		return
	await frames(30)
	for b in menu.get_children():
		if b is BaseButton and not b.disabled and b.get("action") and b.get("action").get("targets_enemies"):
			btn = b
			break
	acting = btn.get("action").get("source")
	await tap(btn.get_global_transform_with_canvas() * (btn.size / 2))
	await frames(30)
	cursors = main.find_children("*", "UIBattlerTargetingCursor", true, false)
	if not check(name, "the attack can be chosen again", cursors.size() > 0):
		return
	var target: Node2D = cursors[0].get("targets")[0]
	await tap(target.get_global_transform_with_canvas().origin)
	await frames(10)
	check(name, "tap on an enemy attacks it (phone)", acting.get("cached_action") != null)


## Plays a Tactical RPG turn with taps only: start, pick a unit, Move, pick a tile.
func tactics_checks(name: String, main: Node) -> void:
	var start: Button = main.get("demo_map")
	await tap(start.get_global_rect().get_center())
	await frames(60)
	var level: Node = main.get("level_instance")
	if not check(name, "tap on Start battle opens the map (phone)", is_instance_valid(level)):
		return
	for i in 120:
		if level.get("turn_stage") == 1:
			break
		await frames(1)
	var cam := get_viewport().get_camera_3d()
	var pres: Resource = level.get("participant").get("res")
	var pawn: Node3D = null
	for p in level.get("player").get_children():
		if p.call("can_act") and not cam.is_position_behind(p.global_position):
			pawn = p
			break
	if not check(name, "a unit is ready to act", pawn != null):
		return
	var pawn_tap := cam.unproject_position(pawn.global_position + Vector3(0, 0.5, 0))
	pawn_tap = get_viewport().get_canvas_transform().affine_inverse() * pawn_tap
	await tap(pawn_tap)
	await frames(10)
	if not check(name, "tap on a unit selects it (phone)", pres.get("stage") == 1, "stage %d" % pres.get("stage")):
		return
	var move_btn: Button = main.find_child("Move", true, false)
	await tap(move_btn.get_global_rect().get_center())
	await frames(10)
	if not check(name, "tap on Move shows where it can go (phone)", pres.get("stage") == 3, "stage %d" % pres.get("stage")):
		return
	# a reachable, free tile that a tap on screen actually hits (not hidden behind another)
	var target: Node3D = null
	var tile_tap := Vector2.ZERO
	var space := cam.get_world_3d().direct_space_state
	for t in level.get("arena").find_children("*", "TacticsTile", true, false):
		if not t.get("reachable") or t == pawn.call("get_tile") or t.call("is_taken"):
			continue
		var sp := cam.unproject_position(t.global_position + Vector3(0, 0.05, 0))
		var q := PhysicsRayQueryParameters3D.create(cam.project_ray_origin(sp), cam.project_ray_origin(sp) + cam.project_ray_normal(sp) * 1000.0, 1)
		if space.intersect_ray(q).get("collider") == t:
			target = t
			tile_tap = get_viewport().get_canvas_transform().affine_inverse() * sp
			break
	if not check(name, "the unit has tiles it can reach", target != null):
		return
	var p0 := pawn.global_position
	await tap(tile_tap)
	await frames(180)
	check(name, "tap on a tile moves the unit there (phone)", pawn.global_position.distance_to(p0) > 0.5, "moved %.2f" % pawn.global_position.distance_to(p0))
	# camera arrows
	var ov: TouchOverlay = main.find_children("*", "TouchOverlay", true, false)[0]
	var cam_node: Node3D = main.find_child("TacticsCamera", true, false)
	for b in ov.buttons:
		if b[2] == "^":
			var c0 := cam_node.global_position
			var e := InputEventScreenTouch.new()
			e.index = 2
			e.position = to_window((b[0] as Rect2).get_center())
			e.pressed = true
			Input.parse_input_event(e)
			await frames(40)
			var r := InputEventScreenTouch.new()
			r.index = 2
			r.position = e.position
			Input.parse_input_event(r)
			await frames(3)
			check(name, "arrow button moves the camera (phone)", cam_node.global_position.distance_to(c0) > 0.2, "moved %.2f" % cam_node.global_position.distance_to(c0))
	# camera turn button (a Callable button, broken in 1.10)
	for b in ov.buttons:
		if b[2] == ">>":
			var rot0: int = TacticsCameraResource.y_rot
			await tap((b[0] as Rect2).get_center(), 2)
			await frames(5)
			check(name, "turn button turns the camera (phone)", TacticsCameraResource.y_rot != rot0, "%d -> %d" % [rot0, TacticsCameraResource.y_rot])
	# the battle ends when one side has no units left
	for p in level.get("opponent").get_children():
		p.get("stats").set("curr_health", 0)
	await frames(10)
	var panel: Node = main.find_child("ResultPanel", true, false)
	check(name, "defeating every enemy shows Victory", panel != null and panel.get_child(0).text == "Victory!")


## Plays the tower defense map the way a phone does: taps, drags, buttons.
func phone_checks(name: String, map: Node) -> void:
	if map.has_method("_press"):
		await overlay_checks(name, map)
		await rpg_checks(name, map)
		return
	if map.has_method("_show_result"):
		await overlay_checks(name, map)
		await tactics_checks(name, map)
		return
	if not map.has_method("_add_touch_buttons"):
		await overlay_checks(name, map)
		return
	get_tree().paused = false
	map.set("process_mode", Node.PROCESS_MODE_INHERIT)
	var cam: Camera2D = map.get("camera")
	var slots: Array = map.find_children("*", "Area2D", true, false).filter(func(a): return a.has_method("_on_input_event"))
	if not check(name, "map has turret slots", slots.size() > 0):
		return
	var slot: Area2D = slots[0]
	var popup: CanvasLayer = slot.get("turret_popup")
	popup.hide()
	var spot: Vector2 = slot.get_global_transform_with_canvas().origin
	# a drag that starts on a slot moves the map and does not open the build menu
	var cam_before := cam.position
	await touch_swipe(spot, Vector2(-160, 0))
	await frames(3)
	check(name, "drag moves the map (phone)", cam.position.distance_to(cam_before) > 50, "moved %d" % cam.position.distance_to(cam_before))
	check(name, "a drag doesn't open the build menu", not popup.visible)
	cam.position = cam_before
	await frames(3)
	spot = slot.get_global_transform_with_canvas().origin
	# a tap on the slot opens the build menu
	await tap(spot)
	await frames(4)
	if not check(name, "tap on a turret slot opens the build menu (phone)", popup.visible):
		return
	# tap the cheapest turret
	var money_before: int = Global.money
	var gat: Button = popup.find_child("Gatling", true, false).find_child("Button", true, false)
	await tap(gat.get_global_rect().get_center())
	await frames(4)
	check(name, "tap on a turret in the menu builds it (phone)", is_instance_valid(slot.get("turret")) and Global.money < money_before, "money %d -> %d" % [money_before, Global.money])
	# tap the built turret: its repair / remove buttons appear at a usable size
	await tap(slot.get_global_transform_with_canvas().origin)
	await frames(4)
	var actions: Control = slot.get("turret_actions")
	check(name, "tap on a turret shows its actions (phone)", actions.visible)
	var rem: Control = actions.find_child("Remove", true, false)
	var real_h: float = (rem.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, rem.size)).size.y if rem else 0.0
	check(name, "turret buttons are finger-sized", real_h >= 48.0, "%d px tall" % real_h)
	actions.hide()
	# on-screen zoom and pause buttons
	var zin: Button = map.find_child("ZoomIn", true, false)
	var z0: float = cam.get("target_zoom")
	if check(name, "has on-screen zoom buttons", zin != null):
		await tap(zin.get_global_rect().get_center())
		await frames(4)
		check(name, "zoom button zooms in (phone)", float(cam.get("target_zoom")) > z0)
	var pb: Button = map.find_child("PauseButton", true, false)
	if check(name, "has an on-screen pause button", pb != null):
		await tap(pb.get_global_rect().get_center())
		await frames(4)
		check(name, "pause button pauses (phone)", get_tree().paused)
		var pause_menu: Node = cam.get("hud").find_child("Pause", true, false)
		pause_menu.call("_enable", false)
		await frames(2)
	get_tree().paused = false


func write_report() -> void:
	var failed := results.filter(func(r): return not r[2])
	var lines := ["Lab Arcade test report  %s" % Time.get_datetime_string_from_system(), "%d checks, %d failed" % [results.size(), failed.size()], ""]
	for r in results:
		lines.append("%s  %-26s %-30s %s" % ["PASS" if r[2] else "FAIL", r[0], r[1], r[3]])
	var f := FileAccess.open(out_dir + "/report.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("TESTS: %d checks, %d failed" % [results.size(), failed.size()])
