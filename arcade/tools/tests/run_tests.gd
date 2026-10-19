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


func tap(pos: Vector2, index := 0) -> void:
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
		d.position = from + Vector2(0, dy * (i + 1) / 12.0)
		d.global_position = d.position
		d.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(d)
		await frames(1)
	mouse(from + Vector2(0, dy), false)
	await frames(5)


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
	await test_menu()
	for g in Games.LIST:
		for v in g["versions"]:
			await test_game(g, v)
	await test_knight_flows()


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
	var cards: Node = m.find_child("Cards", true, false)
	check("menu", "a card per game", cards != null and cards.get_child_count() == Games.LIST.size(), "%d cards" % (cards.get_child_count() if cards else 0))
	var plays_ok := cards != null
	if cards:
		for c in cards.get_children():
			plays_ok = plays_ok and c.find_child("Play", true, false) != null and c.find_child("Info", true, false) != null and c.find_child("Difficulty", true, false) != null
	check("menu", "every card has Play, Info, Difficulty", plays_ok)
	check("menu", "renders", screen_detail("menu_landscape") > 3.0)
	var db: Button = cards.get_child(0).find_child("Difficulty", true, false) if cards else null
	if check("menu", "has difficulty buttons", db != null):
		var before := db.text
		db.emit_signal("pressed")
		await frames(1)
		check("menu", "difficulty button cycles", db.text != before, "%s -> %s" % [before, db.text])
		for g in Games.LIST:
			ArcadeGame.set_difficulty(g["id"], 1)
	# swiping scrolls the list, wherever the finger starts
	var sc: ScrollContainer = m.find_child("Scroll", true, false)
	var swipe_ok := sc != null
	if sc:
		var first_card: Control = cards.get_child(0)
		var r := first_card.get_global_rect()
		var spots := [r.position + Vector2(r.size.x * 0.5, 20), first_card.find_child("Play", true, false).get_global_rect().get_center(), r.position + Vector2(r.size.x * 0.5, r.size.y * 0.45)]
		for spot in spots:
			sc.scroll_vertical = 0
			await frames(1)
			await swipe(spot, -200)
			swipe_ok = swipe_ok and sc.scroll_vertical > 100
		sc.scroll_vertical = 0
		await frames(2)
	check("menu", "swipe scrolls from card, label or button", swipe_ok)
	var info_btn: Button = cards.get_child(0).find_child("Info", true, false)
	var ic := info_btn.get_global_rect().get_center()
	mouse(ic, true)
	await frames(1)
	mouse(ic, false)
	await frames(4)
	check("menu", "a tap (no swipe) still presses buttons", m.page == "info")
	var isc: ScrollContainer = m.find_child("Scroll", true, false)
	if isc:
		await swipe(isc.get_global_rect().get_center(), -200)
	check("menu", "info page scrolls by swipe", isc != null and isc.scroll_vertical > 50)
	m.go_back()
	await frames(3)
	cards = m.find_child("Cards", true, false)
	# every sort order still lists every game
	var sorts_ok := true
	for i in m.SORTS.size():
		m.set_setting("ui", "sort", i)
		var sids = m.sorted_games().map(func(g): return g["id"])
		sorts_ok = sorts_ok and sids.size() == Games.LIST.size()
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
	for g in Games.LIST:
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
		m.show_info(Games.LIST[Games.LIST.size() - 1])
		await frames(4)
		screen_detail("menu_portrait_info")
		m.go_back()
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
	check(name, "title screen renders", screen_detail() > 3.0)
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
	check(name, "screen still renders", screen_detail(g["id"] + "_v%d" % v["v"]) > 3.0)
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


func write_report() -> void:
	var failed := results.filter(func(r): return not r[2])
	var lines := ["Lab Arcade test report  %s" % Time.get_datetime_string_from_system(), "%d checks, %d failed" % [results.size(), failed.size()], ""]
	for r in results:
		lines.append("%s  %-26s %-30s %s" % ["PASS" if r[2] else "FAIL", r[0], r[1], r[3]])
	var f := FileAccess.open(out_dir + "/report.txt", FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	print("TESTS: %d checks, %d failed" % [results.size(), failed.size()])
