extends Node
# Lab Arcade test suite. Checks the menu and every version of every game in
# games.gd. Run in a window (screenshots need a real renderer):
#   godot --path . --fixed-fps 60 res://tools/tests/run_tests.tscn -- <report_dir>
# Exit code 0 = all passed, 1 = something failed. The report is written to
# <report_dir>/report.txt with one screenshot per game.
# Player high scores, saves and settings are backed up first and restored after.

const Games := preload("res://games.gd")
const USER_FILES := ["settings.cfg", "the_last_knight_save.json", "sock_escape_best.dat"]

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])

var log_counter := ErrorCounter.new()
var out_dir := "user://test_report"
var results: Array = []  # [game, test, ok, detail]
var backup := {}
var headless := false


func _ready() -> void:
	OS.add_logger(log_counter)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	headless = DisplayServer.get_name() == "headless"
	if headless:
		# a phone-like window: bigger than the 1280x720 canvas, so taps get scaled
		# like on a real phone (a re-scaled tap once opened the wrong game)
		get_window().size = Vector2i(1920, 1080)
		await frames(1)
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


func spawn(scene_path: String) -> Node:
	var ps = load(scene_path)
	if ps == null:
		return null
	var n: Node = ps.instantiate()
	add_child(n)
	return n


# ---------------------------------------------------------------- the tests

func run_all() -> void:
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
	m.f_source = 2
	m.show_list()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	check("menu", "More games filter", cards.get_child_count() == Games.EXTERNAL.size())
	m.f_source = 1
	m.fill_cards()
	check("menu", "Lab games filter", cards.get_child_count() == Games.LIST.size())
	m.f_source = 0
	m.f_length = 1
	m.fill_cards()
	var quick_ok := cards.get_child_count() > 0
	for c in cards.get_children():
		for g in m.all_games():
			if "Card_" + g["id"] == String(c.name):
				quick_ok = quick_ok and m.minutes(g) <= 3.0
	check("menu", "Quick filter only shows short games", quick_ok, "%d games" % cards.get_child_count())
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
	check(name, "license files included", FileAccess.file_exists("res://external/%s/LICENSE.txt" % name))
	var menu_scene := spawn(v["scene"])
	if not check(name, "start screen loads with its code", menu_scene != null and menu_scene.get_script() != null):
		return
	await frames(10)
	check(name, "start screen renders", screen_detail(name + "_menu") > 3.0, "not checked: running headless" if headless else "")
	check(name, "has a way back to the arcade", menu_scene.has_method("_on_quit_pressed"))
	menu_scene.queue_free()
	await frames(2)
	# play the map for 20 s with random taps and drags
	var map := spawn("res://external/%s/scenes/maps/map_template.tscn" % name)
	if not check(name, "map loads with its code", map != null and map.get_script() != null):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for f in 1200:
		if f % 40 == 20:
			await tap(Vector2(rng.randf_range(100, 1180), rng.randf_range(100, 620)))
		await get_tree().process_frame
	await phone_checks(name, map)
	var enemies: Node = map.find_child("EnemyContainer", true, false)
	check(name, "enemies arrive and the game runs", enemies != null and is_instance_valid(map), "")
	check(name, "screen still renders", screen_detail(name + "_map") > 3.0, "not checked: running headless" if headless else "")
	get_tree().paused = false
	map.queue_free()
	await frames(3)
	var e := new_errors(errs)
	check(name, "no errors", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])


## Plays the tower defense map the way a phone does: taps, drags, buttons.
func phone_checks(name: String, map: Node) -> void:
	if not map.has_method("_add_touch_buttons"):
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
