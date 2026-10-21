extends Node
# Lab Arcade test suite. Checks the menu and every version of every game in
# games.gd. Easiest: tools/test.sh (no window, no sound). By hand:
#   godot --headless --audio-driver Dummy --path . --fixed-fps 60 res://tools/tests/run_tests.tscn -- <report_dir> [menu|external]
# Exit code 0 = all passed, 1 = something failed. The report is written to
# <report_dir>/report.txt with one screenshot per game.
# Player high scores, saves and settings are backed up first and restored after.

const Games := preload("res://games.gd")
const USER_FILES := ["settings.cfg", "the_last_knight_save.json", "sock_escape_best.dat", "open_rpg_inventory.tres", "sokoban_level.dat",
	"city_builder.json", "deck_builder_save.tres", "open_rts_options.tres"]

class ErrorCounter extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		# Jolt (the 3D physics engine) warns when its job queue is briefly full under heavy load,
		# then waits and carries on. It's inside the engine, not a game bug, so it doesn't count.
		if file.contains("jolt_job_system"):
			return
		# Open RTS bakes its navigation from the map's meshes while loading; the engine notes
		# that this is slow. A performance note, not a game bug.
		if (rationale + code).contains("Source geometry parsing for navigation mesh baking"):
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


func mouse_move(pos: Vector2) -> void:
	var d := InputEventMouseMotion.new()
	d.position = to_window(pos)
	d.global_position = d.position
	d.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(d)


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
		if f in USER_FILES or f.begins_with("best_") or f.begins_with("scores_"):
			backup[f] = FileAccess.get_file_as_bytes("user://" + f)
			d.remove(f)


func restore_user_files() -> void:
	var d := DirAccess.open("user://")
	for f in d.get_files():
		if f in USER_FILES or f.begins_with("best_") or f.begins_with("scores_"):
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
	Engine.set_meta("no_update_check", true)
	Store.reset_to_builtin()  # a game list downloaded by an earlier run must not change the tests
	Packs.refresh()
	# help pages open by themselves the first time a game is played; tests open them on purpose
	var all_ids := (Games.LIST + Games.EXTERNAL).map(func(g): return g["id"])
	GameData.set_setting("help", "seen", all_ids)
	if "help" in OS.get_cmdline_user_args():
		await test_help()
		return
	if "stress" in OS.get_cmdline_user_args():
		# bug hunt: every game started from its start screen, long random play
		var pick := ""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("only="):
				pick = arg.substr(5)
		for g in Games.LIST + Games.EXTERNAL:
			if pick == "" or g["id"] in pick.split(","):
				await test_stress(g)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("only="):  # quick run of some games: only=sudoku,minesweeper
			if "menu" in OS.get_cmdline_user_args():
				await test_menu()
				await test_hubs()
			var ids: PackedStringArray = arg.substr(5).split(",")
			for g in Games.LIST + Games.EXTERNAL:
				if g["id"] in ids:
					if Games.EXTERNAL.has(g):
						await test_external(g)
					else:
						for v in g["versions"]:
							await test_game(g, v)
							await _guarded_puzzle_checks(g, v)
			return
	if "external" in OS.get_cmdline_user_args():
		for g in Games.EXTERNAL:
			await test_external(g)
		return  # quick run: games by others only
	await test_menu()
	await test_hubs()
	await test_launcher_extras()
	await test_store()
	await test_help()
	if "menu" in OS.get_cmdline_user_args():
		return  # quick run: launcher only
	for g in Games.LIST:
		for v in g["versions"]:
			await test_game(g, v)
			await _guarded_puzzle_checks(g, v)
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
	# game settings (difficulty, saves, scores) live on each game's own start screen
	var settings_free := true
	for c in cards.get_children():
		settings_free = settings_free and c.find_child("Difficulty", true, false) == null
	check("menu", "no game settings in the launcher", settings_free)
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
	# Home tab: a Steam-style front page with a hero banner and sideways rows
	m.tab = 0
	m.show_list()
	await frames(2)
	check("menu", "Home has a hero banner", m.find_child("Hero", true, false) != null and m.find_child("HeroPlay", true, false) != null)
	check("menu", "Home has no picks row until you pick games", m.find_child("Row_picks", true, false) == null)
	check("menu", "Home has a row per genre", m.get_tree().get_nodes_in_group("hrow").size() >= m.values_of("genre").size())
	m.toggle_favorite("the_last_knight")
	m.toggle_favorite("outpost_assault")
	m.show_list()
	await frames(3)
	var prow: ScrollContainer = m.find_child("Row_picks", true, false)
	check("menu", "Home shows your picks", prow != null and prow.get_child(0).get_child_count() == 2)
	# a sideways swipe on a long row scrolls that row, not the page
	var grow: ScrollContainer = null
	for r in m.get_tree().get_nodes_in_group("hrow"):
		if r.get_child(0).get_child_count() >= 5 and (grow == null or r.get_global_rect().position.y < grow.get_global_rect().position.y):
			grow = r
	if grow:
		var page: ScrollContainer = m.current_scroll()
		page.scroll_vertical = int(grow.position.y)
		await frames(2)
		var gr := grow.get_global_rect()
		var p0 := Vector2(gr.position.x + gr.size.x * 0.8, gr.position.y + 40)
		var v0 := page.scroll_vertical
		mouse(p0, true)
		await frames(1)
		for i in 6:
			mouse_move(p0 - Vector2(60 * (i + 1), 3))
			await frames(1)
		mouse(p0 - Vector2(360, 3), false)
		await frames(2)
		check("menu", "swiping a Home row scrolls it sideways", grow.scroll_horizontal > 100 and absi(page.scroll_vertical - v0) < 10, "h %d, v moved %d" % [grow.scroll_horizontal, page.scroll_vertical - v0])
	else:
		check("menu", "swiping a Home row scrolls it sideways", false, "no long row")
	# - on a Library card removes a pick
	m.tab = 1
	m.show_list()
	await frames(2)
	m.search = "knight"
	m.fill_cards()
	await frames(2)
	cards = m.find_child("Cards", true, false)
	var ht: Button = cards.get_child(0).find_child("HomeToggle", true, false)
	var hc := ht.get_global_rect().get_center()
	mouse(hc, true)
	await frames(1)
	mouse(hc, false)
	await frames(3)
	check("menu", "- removes a pick from Home", m.favorites().size() == 1 and not m.is_favorite("the_last_knight"), "favs %s, scroll %d, toggle at %s" % [m.favorites(), m.current_scroll().scroll_vertical, hc])
	m.search = ""
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
	var found := cards.get_children().map(func(c): return String(c.name))
	check("menu", "search matches descriptions", found.has("Card_outpost_assault") and found.has("Card_duel_defense") and found.size() == 2, str(found))
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
	check("menu", "publisher filter (Kenney)", cards.get_child_count() == Games.EXTERNAL.filter(func(g): return g["publisher"] == "Kenney").size(), "%d cards" % cards.get_child_count())
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
	check("menu", "landscape layout = 3 columns", cards != null and cards.columns == 3)
	m.queue_free()
	await frames(2)
	check("menu", "no errors", new_errors(errs).is_empty(), ", ".join(new_errors(errs).slice(0, 3)))


## Updates, What's new, NEW / UPDATED badges, playtime and the profile page.
func test_launcher_extras() -> void:
	var cv := GameData.compare_versions("1.9", "1.22") < 0 and GameData.compare_versions("1.22", "1.22") == 0 and GameData.compare_versions("2.0", "1.99") > 0
	check("launcher", "app versions compare by number (1.9 < 1.22)", cv)
	# a newer app on GitHub shows an Update banner; the same version doesn't
	GameData.set_setting("ui", "app_version", GameData.app_version())
	var m := spawn("res://menu.tscn")
	await frames(3)
	m.tab = 1
	m.handle_update_info({"version": "99.0", "apk": "https://example.invalid/x.apk", "size": 30000000})
	m.show_list()
	await frames(2)
	check("launcher", "a newer version shows an Update banner", m.find_child("UpdateBanner", true, false) != null)
	m.handle_update_info({"version": GameData.app_version()})
	m.show_list()
	await frames(2)
	check("launcher", "no banner when up to date", m.find_child("UpdateBanner", true, false) == null)
	# updates compare build numbers (they only go up) and show the label
	m.handle_update_info({"version": "1.29", "label": "1.1", "build": GameData.app_build() + 1})
	var shows_label: bool = m.update_info.get("version", "") == "1.1"
	m.handle_update_info({"version": "1.29", "label": GameData.app_version(), "build": GameData.app_build()})
	check("launcher", "updates compare build numbers", shows_label and m.update_info.is_empty())
	# every game starts at version 1.0 (John, 2026-10-20)
	var firsts := (Games.LIST + Games.EXTERNAL).filter(func(g): return int(g["versions"][0]["v"]) != 1 or GameData.version_name(g["versions"][0]) != "1.0")
	check("launcher", "every game starts at v1.0", firsts.is_empty(), str(firsts.map(func(g): return g["id"])))
	m.queue_free()
	await frames(2)
	# first start after an update shows What's new
	GameData.set_setting("ui", "app_version", "0.9")
	GameData.set_setting("ui", "app_build", GameData.app_build() - 1)  # an older build was installed
	m = spawn("res://menu.tscn")
	await frames(3)
	check("launcher", "after an update the app shows What's new", m.page == "whatsnew" and m.find_child("WhatsNewDone", true, false) != null)
	check("launcher", "What's new lists the changes", m.whats_new_list().size() > 0 and m.whats_new_list()[0]["version"] == GameData.app_version())
	m.queue_free()
	await frames(2)
	# NEW and UPDATED badges
	GameData.set_setting("seen", "versions", {"sudoku": 0})
	GameData.mark_all_seen([])
	m = spawn("res://menu.tscn")
	await frames(3)
	m.tab = 1
	m.search = ""
	m.show_list()
	await frames(2)
	var cards: Node = m.find_child("Cards", true, false)
	var su: Node = cards.find_child("Card_sudoku", false, false)
	var other: Node = cards.find_child("Card_minesweeper", false, false)
	var b1: Label = su.find_child("Badge", true, false) if su else null
	var b2: Label = other.find_child("Badge", true, false) if other else null
	check("launcher", "a game with a newer version shows UPDATED", b1 != null and b1.text.strip_edges() == "UPDATED")
	check("launcher", "a game you never saw shows NEW", b2 != null and b2.text.strip_edges() == "NEW")
	m.queue_free()
	await frames(2)
	GameData.set_setting("seen", "versions", {})
	# playtime: time between Play on a start screen and coming back
	var before := GameData.playtime("sudoku")
	Engine.set_meta("hub_game", "sudoku")
	Engine.set_meta("hub_scene", "")
	Engine.set_meta("play_started", int(Time.get_unix_time_from_system()) - 125)
	var h := spawn("res://common/game_hub.tscn")
	await frames(2)
	check("launcher", "time played is counted per game", GameData.playtime("sudoku") - before >= 125)
	h.queue_free()
	Engine.remove_meta("hub_game")
	Engine.remove_meta("hub_scene")
	await frames(1)
	m = spawn("res://menu.tscn")
	await frames(3)
	m.show_profile()
	await frames(2)
	var texts := m.find_children("*", "Label", true, false).map(func(l): return l.text)
	check("launcher", "the profile shows time played and most played", texts.has("Most played") and texts.has("Sudoku"), str(texts.slice(0, 6)))
	m.queue_free()
	await frames(2)
	# coming back from a game's page keeps the Library where it was (John: it jumped to the top)
	m = spawn("res://menu.tscn")
	await frames(3)
	m.tab = 1
	m.show_list()
	await frames(4)
	var lsc: ScrollContainer = m.current_scroll()
	lsc.scroll_vertical = 900
	await frames(2)
	var at: int = lsc.scroll_vertical
	var card: Node = m.find_child("Cards", true, false).get_child(6)
	(card.find_child("Info", true, false) as Button).emit_signal("pressed")
	await frames(3)
	m.go_back()
	await frames(6)
	check("launcher", "back from Info returns to the same spot in the Library", at > 100 and m.current_scroll().scroll_vertical == at, "%d -> %d" % [at, m.current_scroll().scroll_vertical])
	m.queue_free()
	await frames(2)
	# ratings, collections, the collection filter and the Feel toggles
	m = spawn("res://menu.tscn")
	await frames(3)
	var sg: Dictionary = m.all_games().filter(func(x): return x["id"] == "sudoku")[0]
	m.show_info(sg)
	await frames(2)
	var star: Button = m.find_child("Star4", true, false)
	check("launcher", "a game page has rating stars", star != null)
	if star:
		star.emit_signal("pressed")
		await frames(2)
	check("launcher", "tapping a star rates the game", GameData.rating("sudoku") == 4 and (m.find_child("Star4", true, false) as StarButton).filled and not (m.find_child("Star5", true, false) as StarButton).filled)
	var le: LineEdit = m.find_child("NewCollection", true, false)
	le.text = "Brain teasers"
	(m.find_child("AddCollection", true, false) as Button).emit_signal("pressed")
	await frames(2)
	check("launcher", "a new collection holds the game", GameData.collections().has("Brain teasers") and GameData.in_collection("Brain teasers", "sudoku") and m.find_child("Coll_Brain teasers", true, false) != null)
	m.tab = 0
	m.show_list()
	await frames(2)
	var crow: ScrollContainer = m.find_child("Row_coll_Brain teasers", true, false)
	check("launcher", "a collection gets its own Home row", crow != null and crow.get_child(0).get_child_count() == 1)
	m.tab = 1
	m.f_collection = "Brain teasers"
	m.show_list()
	await frames(2)
	var cc: GridContainer = m.find_child("Cards", true, false)
	check("launcher", "the Library filters by collection", cc.get_child_count() == 1 and String(cc.get_child(0).name) == "Card_sudoku")
	m.f_collection = ""
	m.set_setting("ui", "sort", 7)
	m.fill_cards()
	check("launcher", "sorting by your rating puts rated games first", String(cc.get_child(0).name) == "Card_sudoku")
	m.set_setting("ui", "sort", 0)
	m.show_settings()
	await frames(2)
	var ts: Button = m.find_child("TapSounds", true, false)
	var was := UiFx.sounds_on()
	ts.emit_signal("pressed")
	await frames(2)
	check("launcher", "tap sounds can be switched off", UiFx.sounds_on() != was)
	var vb: Button = m.find_child("Vibration", true, false)
	var vwas := UiFx.vibration_on()
	vb.emit_signal("pressed")
	await frames(2)
	check("launcher", "vibration can be switched off", UiFx.vibration_on() != vwas)
	# save backup: copy everything out, change something, restore it
	var bk := Backup.make()
	check("launcher", "a backup holds settings and scores", bk.contains("settings.cfg") and Backup.check(bk) == "")
	GameData.set_rating("sudoku", 1)
	GameData.delete_collection("Brain teasers")
	m.ask_restore(bk)
	await frames(2)
	var cr: Button = m.find_child("ConfirmRestore", true, false)
	check("launcher", "restoring asks once more first", cr != null and GameData.rating("sudoku") == 1)
	if cr:
		cr.emit_signal("pressed")
		await frames(2)
	check("launcher", "restoring a backup brings progress back", GameData.rating("sudoku") == 4 and GameData.in_collection("Brain teasers", "sudoku"))
	var bad := func(files: Dictionary): return Backup.check(JSON.stringify({"app": "Lab Arcade", "files": files})) != ""
	var b64 := Marshalls.utf8_to_base64("x=1")
	check("launcher", "backups can't write outside the app's data", bad.call({"../evil.cfg": b64}) and bad.call({"/etc/x.json": b64}) and bad.call({"packs/state.json": b64}))
	check("launcher", "backups can't carry code or resources", bad.call({"x.gd": b64}) and bad.call({"x.tres": b64}) and bad.call({"dialogic/saves/a/state.txt": b64}) and bad.call({"s.cfg": Marshalls.utf8_to_base64("[a]\nb=Object(GDScript,\"script\":null)")}))
	check("launcher", "other text is not taken as a backup", Backup.check("hello") != "" and Backup.check("{}") != "")
	# keyboard / controller: Escape (or B) goes back, shoulder buttons switch tabs
	m.show_info(sg)
	await frames(2)
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	check("launcher", "Escape or B goes back from a game page", m.page == "list")
	m.tab = 0
	m.show_list()
	await frames(1)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	jb.pressed = true
	Input.parse_input_event(jb)
	await frames(3)
	check("launcher", "controller shoulder buttons switch to the Library", m.tab == 1)
	var fo: Control = m.get_viewport().gui_get_focus_owner()
	check("launcher", "with a controller a button has focus", fo != null and fo is Control and m.is_ancestor_of(fo), str(fo))
	if fo:
		fo.release_focus()
	UiFx.keys = false
	GameData.delete_collection("Brain teasers")
	GameData.set_rating("sudoku", 0)
	check("launcher", "collections can be deleted", not GameData.collections().has("Brain teasers"))
	m.queue_free()
	await frames(2)


## Each game's own start screen: play buttons, difficulty, high scores, saved game,
## sound, back to the arcade; and that Play really starts the game.
## The signed game list: only a list signed with the right key and newer than the one
## in use is taken; packs that need a newer app fall back to the app's own copy.
func test_store() -> void:
	var errs := log_counter.errors.size()
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var pem := key.save_to_string(true)
	var own_serial := Store.serial
	var lab: Array = Store.catalog["lab"].duplicate(true)
	var packs: Dictionary = Store.packs.duplicate(true)
	# a list where sudoku v1's pack needs a far newer app, and a new game only it has
	var first: String = packs.keys()[0]
	packs["sudoku/v1"]["min_build"] = 999999
	packs["sudoku/v1"]["sha256"] = "changed"
	var newgame: Dictionary = lab[0].duplicate(true)
	newgame["id"] = "test_new_game"
	newgame["name"] = "Test New Game"
	lab.append(newgame)
	var nv: Dictionary = newgame["versions"][0]
	packs["test_new_game/v%d" % int(nv["v"])] = packs[first].duplicate(true)
	var later := {"format": 1, "serial": own_serial + 5, "catalog": {"lab": lab, "external": Store.catalog["external"]}, "packs": packs, "art": {}}
	var data := JSON.stringify(later).to_utf8_buffer()
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	var sig := crypto.sign(HashingContext.HASH_SHA256, h.finish(), key)
	check("store", "the app's public key reads", CryptoKey.new().load_from_string(Store.PUBLIC_KEY, true) == OK)
	check("store", "a list signed with another key is refused", Store.accept(data, sig) != "" and Store.serial == own_serial)
	var bad := data.duplicate()
	bad[10] = bad[10] ^ 1
	check("store", "a changed list is refused", Store.accept(bad, sig, pem) != "" and Store.serial == own_serial)
	check("store", "a signed, newer list is taken", Store.accept(data, sig, pem) == "" and Store.serial == own_serial + 5)
	Packs.refresh()
	check("store", "a new game in the list shows up", Games.LIST.any(func(g): return g["id"] == "test_new_game"))
	check("store", "a pack that needs a newer app falls back to the app's own copy", Packs.manifest.has("sudoku/v1") and Packs.manifest["sudoku/v1"]["sha256"] != "changed", "%d packs, store %d, sent %d, own %d, has %s" % [Packs.manifest.size(), Store.packs.size(), packs.size(), Store._builtin["packs"].size(), Store._builtin["packs"].has("sudoku/v1")])
	check("store", "the list is kept for the next start", FileAccess.file_exists("user://store/store.json"))
	check("store", "the same list again is not taken (no going back)", Store.accept(data, sig, pem) == "not newer")
	Store.reset_to_builtin()
	Packs.refresh()
	check("store", "back to the app's own list", Store.serial == own_serial and not Games.LIST.any(func(g): return g["id"] == "test_new_game"))
	# a game by others updated in place: only the newest version can be played, older ones
	# are listed (not tappable) under Archived versions
	var m: Node = spawn("res://menu.tscn")
	await frames(3)
	var racing: Dictionary = Games.EXTERNAL.filter(func(x): return x["id"] == "racing")[0]
	m.show_info(racing)
	await frames(3)
	var plays: Array = m.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Play v"))
	var arch: Button = m.find_child("ArchivedToggle", true, false)
	var box: Control = m.find_child("Archived", true, false)
	# v1.0 (free drive) has its own scene and stays playable; 2.0 was updated in place by 2.1
	check("versions", "Kenney Racing: free drive and the newest race are playable, 2.0 is archived", plays.size() == 2 and arch != null and box != null and not box.visible and box.get_child_count() == 1, "%d playable" % plays.size())
	if arch:
		arch.emit_signal("pressed")
		await frames(1)
		check("versions", "tapping Archived versions shows them", box.visible)
	m.queue_free()
	await frames(2)
	check("store", "no errors", new_errors(errs).is_empty(), ", ".join(new_errors(errs).slice(0, 3)))


func test_hubs() -> void:
	var all_ok := {"opens": true, "play": true, "back": true, "ach": true}
	for g in Games.LIST + Games.EXTERNAL:
		var id: String = g["id"]
		var vs: Array = g["versions"]
		Engine.set_meta("hub_game", id)
		Engine.set_meta("hub_scene", vs[vs.size() - 1]["scene"])
		var h: Control = spawn("res://common/game_hub.tscn")
		await frames(2)
		all_ok["opens"] = all_ok["opens"] and h.find_child("BackToArcade", true, false) != null
		var ach: Node = h.find_child("Achievements", true, false)
		all_ok["ach"] = all_ok["ach"] and ach != null and ach.get_child_count() >= 3 and ach.get_child_count() <= 5
		var started := []
		h.launch_hook = func(gid, _scene, mode): started.append([gid, mode])
		var p: Button = h.find_child("Play", true, false)
		if p == null:
			p = h.find_child("Continue", true, false)
		if p:
			p.emit_signal("pressed")
		all_ok["play"] = all_ok["play"] and started.size() == 1 and started[0][0] == id
		all_ok["back"] = all_ok["back"] and GameData.back_scene() == GameData.HUB
		h.queue_free()
		await frames(1)
	check("start screens", "every game has its own start screen", all_ok["opens"])
	check("start screens", "every game has 3 to 5 achievements", all_ok["ach"])
	check("start screens", "Play on the start screen starts that game", all_ok["play"])
	check("start screens", "< MENU in a game comes back to its start screen", all_ok["back"])
	# difficulty, high scores, saved game and sound on one game with all of them
	var knight: Dictionary = {}
	for g in Games.LIST:
		if g["id"] == "the_last_knight":
			knight = g
	Engine.set_meta("hub_game", "the_last_knight")
	Engine.set_meta("hub_scene", "")
	var h: Control = spawn("res://common/game_hub.tscn")
	await frames(2)
	check("start screens", "no difficulty or sound buttons on the start screen (they're in the game)", h.find_child("Diff2", true, false) == null and h.find_child("Sound", true, false) == null)
	# the game's own options (gear button): difficulty and sound, the game paused meanwhile
	var opt := GameOptions.open_for(h, "the_last_knight")
	await frames(2)
	check("game options", "the gear opens the game's options and pauses it", opt != null and get_tree().paused and HelpPage.is_open())
	(opt.find_child("Diff2", true, false) as Button).emit_signal("pressed")
	await frames(1)
	check("game options", "difficulty is set in the game's options", ArcadeGame.get_difficulty("the_last_knight") == 2)
	(opt.find_child("Sound", true, false) as Button).emit_signal("pressed")
	await frames(1)
	check("game options", "sound can be switched off per game", not GameData.sound_on("the_last_knight"))
	(opt.find_child("Done", true, false) as Button).emit_signal("pressed")
	await frames(2)
	check("game options", "Done closes them and the game goes on", not HelpPage.is_open() and not get_tree().paused)
	GameData.set_sound("the_last_knight", true)
	GameData.apply_sound("the_last_knight")
	ArcadeGame.set_difficulty("the_last_knight", 1)
	GameData.add_score("the_last_knight", 4321, 2)
	GameData.add_score("the_last_knight", 99, 0)
	h.build()
	await frames(1)
	var hs: Node = h.find_child("HighScores", true, false)
	var texts := hs.find_children("*", "Label", true, false).map(func(l): return l.text) if hs else []
	check("start screens", "high scores are listed, best first", texts.size() >= 8 and texts[1] == "4321" and texts.has("99") and texts.has("Hard"), str(texts.slice(0, 8)))
	var f := FileAccess.open(knight["save_file"], FileAccess.WRITE)
	f.store_string(JSON.stringify({"lv": 3}))
	f = null
	h.build()
	await frames(1)
	check("start screens", "a saved game shows Continue and New game", h.find_child("Continue", true, false) != null and h.find_child("NewGame", true, false) != null)
	(h.find_child("DeleteSave", true, false) as Button).emit_signal("pressed")
	await frames(1)
	check("start screens", "the saved game can be deleted", not FileAccess.file_exists(knight["save_file"]) and h.find_child("Play", true, false) != null)
	GameData.clear_scores(knight)
	h.queue_free()
	Engine.remove_meta("hub_game")
	Engine.remove_meta("hub_scene")
	await frames(1)
	# Play skips the game's own title screen
	var skip_ok := true
	for gid in ["sock_escape", "waveguide_snake", "the_last_knight"]:
		for g in Games.LIST:
			if g["id"] == gid:
				var vs: Array = g["versions"]
				Engine.set_meta("auto_start", true)
				var n := spawn(vs[vs.size() - 1]["scene"])
				await frames(4)
				skip_ok = skip_ok and int(n.get("state")) != 0
				n.queue_free()
				await frames(1)
	Engine.set_meta("auto_start", false)
	release_all_keys()
	check("start screens", "Play skips the game's own title", skip_ok)
	# achievements: a win on Hard unlocks two, celebrated once on the start screen
	ArcadeGame.set_difficulty("sudoku", 2)
	GameData.record_play("sudoku")
	GameData.add_win("sudoku")
	ArcadeGame.set_difficulty("sudoku", 1)
	Engine.set_meta("hub_game", "sudoku")
	Engine.set_meta("hub_scene", "")
	h = spawn("res://common/game_hub.tscn")
	await frames(2)
	var won := func(k): return (h.find_child("Ach_" + k, true, false) != null) and GameData.get_setting("achieved", "sudoku/" + k, 0) > 0
	check("start screens", "winning unlocks achievements", won.call("first") and won.call("win") and won.call("hard"))
	check("start screens", "new achievements get a banner", h.find_child("Unlocked", true, false) != null)
	h.queue_free()
	await frames(1)
	h = spawn("res://common/game_hub.tscn")
	await frames(2)
	check("start screens", "the banner shows only once", h.find_child("Unlocked", true, false) == null)
	# keyboard / controller: the start screen starts on Play
	UiFx.keys = true
	h.build()
	await frames(2)
	var fo := h.get_viewport().gui_get_focus_owner()
	check("start screens", "with keys or a controller, Play has focus", fo != null and String(fo.name) in ["Play", "Continue"], str(fo.name if fo else "none"))
	UiFx.keys = false
	if fo:
		fo.release_focus()
	h.queue_free()
	Engine.remove_meta("hub_game")
	Engine.remove_meta("hub_scene")
	await frames(1)


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


var _puzzle_done := false


## A script error inside the checks stops them without failing anything: catch that.
func _guarded_puzzle_checks(g: Dictionary, v: Dictionary) -> void:
	_puzzle_done = false
	var errs := log_counter.errors.size()
	await puzzle_checks(g, v)
	if not _puzzle_done:
		var e := new_errors(errs)
		check("%s v%d" % [g["id"], v["v"]], "board game checks ran to the end", false, ", ".join(e.slice(0, 2)))


## The calm board games (PuzzleGame): touch play, save and Continue, winning.
func puzzle_checks(g: Dictionary, v: Dictionary) -> void:
	var probe: Node = load(v["scene"]).instantiate()
	var is_puzzle := probe is PuzzleGame
	probe.free()
	if not is_puzzle:
		_puzzle_done = true
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
	var hooks = load(v["scene"].get_base_dir().get_base_dir() + "/arcade_tests.gd")
	await hooks.play(self, n, name)
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
	await hooks.play(self, np, name + " portrait")
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
			await hooks.win(self, nd)
			await frames(2)
			check(name, "solving it wins and saves the best score", nd.state == 2 and nd.won and nd.best > 0 and nd.best == nd.score and not FileAccess.file_exists(nd.save_path()), "state %d won %s best %d" % [nd.state, nd.won, nd.best])
		nd.queue_free()
		await frames(2)
	ArcadeGame.set_difficulty(g["id"], 1)
	DirAccess.remove_absolute("user://best_%s.dat" % g["id"])
	DirAccess.remove_absolute("user://%s_save.json" % g["id"])
	var e := new_errors(errs)
	check(name, "no errors while solving", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])
	_puzzle_done = true


func test_knight_flows() -> void:
	var name := "the_last_knight"
	var scene := "res://games/the_last_knight/v1/game.tscn"
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
	await help_button_check(name)
	await back_via_menu_button(name)
	var e := new_errors(errs)
	check(name, "no errors", e.is_empty(), "%d: %s" % [e.size(), ", ".join(e.slice(0, 3))])


## Stress test: start the game the way a player does (start screen, Play), play for
## 40 s with every kind of input (taps, swipes, long presses, two fingers, keys, the
## phone turned), then the back button, Continue, and back again. Any error counts.
func test_stress(g: Dictionary) -> void:
	var name: String = g["id"]
	var errs := log_counter.errors.size()
	var lab: bool = Games.LIST.has(g)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("diff="):  # stress at a set difficulty: diff=0 (Easy) .. diff=2 (Hard)
			ArcadeGame.set_difficulty(name, int(arg.substr(5)))
	Engine.set_meta("hub_game", name)
	Engine.set_meta("hub_scene", "")
	var hub: Node = spawn_current(GameData.HUB)
	await frames(6)
	hub.call("play", "new" if g.has("save_file") else "")
	var game: Node = null
	for i in 90:
		await frames(2)
		var cur := get_tree().current_scene
		if is_instance_valid(cur) and cur != self and cur.scene_file_path != GameData.HUB:
			game = cur
			break
	if not check(name, "stress: Play on the start screen starts the game", game != null):
		await end_current()
		return
	await frames(40)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var keys := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_X, KEY_Z, KEY_J, KEY_ENTER]
	var rotated := false
	for f in 2400:
		if HelpPage.is_open():
			HelpPage.close_current()
		var size: Vector2 = get_viewport().get_visible_rect().size
		var p := Vector2(rng.randf_range(0.05, 0.95) * size.x, rng.randf_range(0.12, 0.95) * size.y)
		if p.x < size.x * 0.18 and p.y < size.y * 0.22:
			p.x += size.x * 0.3  # keep away from "< MENU" (tested elsewhere)
		match f % 120:
			10, 50, 90:
				await tap(p)
			30:
				await touch_swipe(p, Vector2(rng.randf_range(-260, 260), rng.randf_range(-260, 260)))
			70:
				var e := InputEventScreenTouch.new()
				e.position = to_window(p)
				e.pressed = true
				Input.parse_input_event(e)
				await frames(40)
				var r := InputEventScreenTouch.new()
				r.position = e.position
				Input.parse_input_event(r)
			100:
				for idx in [0, 1]:
					var e2 := InputEventScreenTouch.new()
					e2.index = idx
					e2.position = to_window(p + Vector2(60 * idx, 0))
					e2.pressed = true
					Input.parse_input_event(e2)
				for s in 6:
					var d := InputEventScreenDrag.new()
					d.index = 1
					d.position = to_window(p + Vector2(60 + 15 * s, 10 * s))
					d.relative = Vector2(15, 10)
					Input.parse_input_event(d)
					await frames(1)
				for idx in [0, 1]:
					var e3 := InputEventScreenTouch.new()
					e3.index = idx
					e3.position = to_window(p)
					Input.parse_input_event(e3)
		if f % 16 == 5:
			key(keys[rng.randi() % keys.size()], rng.randf() < 0.6)
		if lab and f == 1000:
			get_window().size = Vector2i(1080, 1920)  # the phone turned upright
			rotated = true
		if lab and f == 1700:
			get_window().size = Vector2i(1920, 1080)
			rotated = false
		await get_tree().process_frame
	release_all_keys()
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_J, KEY_ENTER]:
		key(k, false)
	if rotated:
		get_window().size = Vector2i(1920, 1080)
	HelpPage.close_current()
	get_tree().paused = false
	var alive := get_tree().current_scene
	check(name, "stress: survives 40 s of mixed touch and keys", is_instance_valid(alive) and alive != self, str(alive.scene_file_path if is_instance_valid(alive) else "none"))
	# the back button leaves the game (to its start screen, or its own menu first)
	for tries in 3:
		var before := get_tree().current_scene
		if not is_instance_valid(before) or before.scene_file_path in [GameData.HUB, GameData.LAUNCHER]:
			break
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await frames(40)
	var now := get_tree().current_scene
	check(name, "stress: the back button leads out of the game", is_instance_valid(now) and now.scene_file_path in [GameData.HUB, GameData.LAUNCHER], str(now.scene_file_path if is_instance_valid(now) else "none"))
	# Continue from the start screen, when the game saved
	if is_instance_valid(now) and now.scene_file_path == GameData.HUB and now.find_child("Continue", true, false):
		now.call("play", "continue")
		await frames(80)
		var cont := get_tree().current_scene
		check(name, "stress: Continue loads the saved game", is_instance_valid(cont) and cont.scene_file_path != GameData.HUB)
	await end_current()
	get_tree().paused = false
	Engine.remove_meta("hub_game")
	Engine.remove_meta("hub_scene")
	if g.has("park"):
		load(g["park"]).park(get_tree())
	GameData.reset_window(get_window())
	var e := new_errors(errs)
	check(name, "stress: no errors", e.is_empty(), "%d: %s" % [e.size(), " | ".join(e.slice(0, 4))])


## Games by others with a help page: "?" opens it (game paused), "Got it" closes it.
func help_button_check(name: String) -> void:
	var cur := get_tree().current_scene
	if not is_instance_valid(cur) or cur == self:
		return
	var rect := Rect2()
	for ov in cur.find_children("*", "TouchOverlay", true, false):
		for b in (ov as TouchOverlay).buttons:
			if b[2] == "?":
				rect = b[0]
	var hb: Control = cur.find_child("HelpButton", true, false)
	if hb:
		rect = hb.get_global_rect()
	if rect.size == Vector2.ZERO:
		return
	await tap(rect.get_center())
	await frames(4)
	var ok := HelpPage.is_open() and get_tree().paused
	var page := HelpPage.current
	var got: Button = page.find_child("GotIt", true, false) if page else null
	if got:
		await tap(got.get_global_rect().get_center())
		await frames(4)
	check(name, "? opens the game's help, Got it closes it (phone)", ok and not HelpPage.is_open() and not get_tree().paused, "opened %s, still open %s, paused %s, rect %s" % [ok, HelpPage.is_open(), get_tree().paused, rect])
	HelpPage.close_current()
	get_tree().paused = false


## Help pages of the games made for the arcade: every page reads well, "?" opens it,
## the back button and "Got it" close it, and it opens by itself the first time.
func test_help() -> void:
	var with_help := 0
	for g in Games.LIST + Games.EXTERNAL:
		var vs: Array = g["versions"]
		var path: String = (str(vs[vs.size() - 1]["scene"]).get_base_dir() + "/help.json") if Games.LIST.has(g) else "res://external/%s/lab_arcade_help.json" % g["id"]
		if not FileAccess.file_exists(path):
			continue
		with_help += 1
		var d := HelpPage.read(path)
		check("help", "%s has a readable help page" % g["id"], d.get("sections", []).size() >= 3)
	check("help", "13 games have a help page", with_help == 13, "%d" % with_help)
	for gid in ["sudoku", "minesweeper", "nonogram", "mahjong", "solitaire", "sokoban", "the_last_knight"]:
		var g: Dictionary = Games.LIST.filter(func(x): return x["id"] == gid)[0]
		var vs: Array = g["versions"]
		var n: Node = spawn(vs[vs.size() - 1]["scene"])
		await frames(6)
		if n.get("state") == 0 and n.has_method("start_new"):
			n.start_new()
			await frames(4)
		var r: Rect2 = n.get("help_btn")
		await tap(r.get_center())
		await frames(4)
		var opened := HelpPage.is_open() and get_tree().paused
		get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await frames(4)
		check("help", "%s: ? opens its help, back closes it and stays in the game (phone)" % gid, opened and not HelpPage.is_open() and not get_tree().paused and is_instance_valid(n) and n.is_inside_tree())
		# the gear next to it: the game's own options (difficulty, sound)
		var orect: Rect2 = n.options_btn()
		await tap(orect.get_center())
		await frames(4)
		var oopen := HelpPage.current is GameOptions and get_tree().paused
		var done: Button = HelpPage.current.find_child("Done", true, false) if HelpPage.current else null
		if done:
			await tap(done.get_global_rect().get_center())
			await frames(4)
		check("help", "%s: the gear opens its options (difficulty, sound), Done closes them (phone)" % gid, oopen and not HelpPage.is_open() and not get_tree().paused and not orect.intersects(r), "gear %s, ? %s" % [orect, r])
		n.queue_free()
		await frames(2)
	# the first time a game is played its help opens by itself, once
	GameData.set_setting("help", "seen", [])
	var s: Dictionary = Games.LIST.filter(func(x): return x["id"] == "sudoku")[0]
	var first: Node = spawn(s["versions"][0]["scene"])
	await frames(6)
	var auto := HelpPage.is_open()
	var got: Button = HelpPage.current.find_child("GotIt", true, false) if HelpPage.current else null
	if got:
		await tap(got.get_global_rect().get_center())
		await frames(4)
	first.queue_free()
	await frames(2)
	first = spawn(s["versions"][0]["scene"])
	await frames(6)
	check("help", "a game's help opens by itself the first time, only once", auto and not HelpPage.is_open())
	HelpPage.close_current()
	first.queue_free()
	await frames(2)
	GameData.set_setting("help", "seen", (Games.LIST + Games.EXTERNAL).map(func(g): return g["id"]))
	get_tree().paused = false


## Taps "< MENU" like a player would and checks the launcher comes back cleanly.
func back_via_menu_button(name: String) -> void:
	await frames(90)  # let a scene change started by the random taps finish first
	var cur := get_tree().current_scene
	var ovs := cur.find_children("*", "TouchOverlay", true, false) if is_instance_valid(cur) and cur != self else []
	if ovs.is_empty():
		await end_current()
		return
	var ov: TouchOverlay = ovs[0]
	var menus: Array = ov.buttons.filter(func(b): return b[1] is String and b[1] == "__menu")
	if menus.is_empty():
		# screens without "< MENU" (their own menu leads back): the phone's back button,
		# which first closes a pop-up the random taps may have opened (as on a phone)
		for i in 3:
			get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			await frames(20)
			if get_tree().current_scene != cur:
				break
	else:
		await tap((menus[0][0] as Rect2).get_center())
	await frames(20)
	var now := get_tree().current_scene
	check(name, "< MENU (or the back button) returns to the launcher (phone)", is_instance_valid(now) and now.scene_file_path == "res://menu.tscn", str(now.scene_file_path if is_instance_valid(now) else "none"))
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
	if game.has_method("lab_test_drive"):  # a game that starts on its own menu (Kenney Racing 2)
		game.lab_test_drive()
		await frames(6)
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
	# games by others can carry their own phone tests (external/<id>/arcade_tests.gd)
	var hook_path := "res://external/%s/arcade_tests.gd" % name
	if ResourceLoader.exists(hook_path):
		await overlay_checks(name, map)
		await load(hook_path).phone(self, map, name)
		return
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
