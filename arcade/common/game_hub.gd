extends Control
# A game's own start screen: Play / Continue / New game, difficulty, high scores,
# the saved game, settings (sound) and how to play. The launcher only opens it
# (Engine meta "hub_game" = game id, "hub_scene" = version to play); "< MENU" in the
# game comes back here, and "< Arcade" here goes back to the launcher.

const Games := preload("res://games.gd")
const BG := Color(0.08, 0.10, 0.14)
const PANEL := Color(0.12, 0.17, 0.23)
const MUTED := Color(0.65, 0.70, 0.80)
const GOLD := Color(1.0, 0.85, 0.35)

var g: Dictionary = {}
var scene := ""
var external := false
var portrait := false
var body: VBoxContainer
var confirm_reset := false
var launch_hook := Callable()  # tests replace starting the game with this
var unlocked: Array = []  # achievements reached in the last session, shown once


func _ready() -> void:
	get_tree().paused = false
	var id: String = Engine.get_meta("hub_game", "")
	scene = Engine.get_meta("hub_scene", "")
	for gg in Games.LIST + Games.EXTERNAL:
		if gg["id"] == id:
			g = gg
	if g.is_empty():
		get_tree().change_scene_to_file.call_deferred(GameData.LAUNCHER)
		return
	if scene == "":
		var vs: Array = g["versions"]
		scene = vs[vs.size() - 1]["scene"]
	external = Games.EXTERNAL.has(g)
	GameData.mark_seen(g)
	# back from a game: count the time played
	if Engine.has_meta("play_started"):
		GameData.add_playtime(g["id"], int(Time.get_unix_time_from_system()) - int(Engine.get_meta("play_started")))
		Engine.remove_meta("play_started")
	unlocked = GameData.check_achievements(g)
	for gg in Games.EXTERNAL:  # helpers of games by others sleep outside their game
		if gg.has("park"):
			load(gg["park"]).park(get_tree())
	AudioServer.set_bus_mute(0, false)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	_fit_screen()
	build()


func _want_portrait() -> bool:
	var s := DisplayServer.window_get_size()
	return s.y > s.x


func _fit_screen() -> void:
	portrait = _want_portrait()
	var win := get_window()
	GameData.reset_window(win)
	win.content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _process(_delta: float) -> void:
	if _want_portrait() != portrait:
		_fit_screen()
		build()


func _input(event: InputEvent) -> void:
	UiFx.note_input(event)


func _unhandled_input(event: InputEvent) -> void:
	# Escape, or B on a controller
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_to_arcade()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_to_arcade()


func back_to_arcade() -> void:
	Engine.remove_meta("hub_game")
	Engine.remove_meta("hub_scene")
	get_tree().change_scene_to_file.call_deferred(GameData.LAUNCHER)


## Start the game: mode "" (fresh), "new" or "continue".
func play(mode: String) -> void:
	if launch_hook.is_valid():
		launch_hook.call(g["id"], scene, mode)
		return
	GameData.record_play(g["id"])
	GameData.apply_sound(g["id"])
	if external:
		# games made by others: full landscape screen, their own layout
		get_window().content_scale_size = Vector2i(1280, 720)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		if OS.has_feature("mobile"):
			DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	Engine.set_meta("launch_mode", mode)
	Engine.set_meta("auto_start", mode != "continue")
	Engine.set_meta("play_started", int(Time.get_unix_time_from_system()))
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- building the screen

func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var tint := ColorRect.new()
	tint.color = Color(Color(g["color"]).darkened(0.55), 0.55)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tint)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	if not unlocked.is_empty():
		_unlock_banner()
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	# top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	outer.add_child(top)
	var back := button("< Arcade", PANEL, 22, false)
	back.name = "BackToArcade"
	back.custom_minimum_size = Vector2(150, 56)
	back.pressed.connect(back_to_arcade)
	top.add_child(back)
	var title := label(g["name"], 34 if portrait else 38, GOLD)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	# everything else scrolls
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 18
	scroll.follow_focus = true
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	# hero: cover, and the play buttons beside it (below it in portrait)
	var hero: BoxContainer = VBoxContainer.new() if portrait else HBoxContainer.new()
	hero.add_theme_constant_override("separation", 18)
	body.add_child(hero)
	var art := cover()
	art.size_flags_stretch_ratio = 1.2
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero.add_child(art)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	hero.add_child(side)
	_play_buttons(side)
	if not g.get("no_difficulty", false):
		_difficulty(side)
	_scores()
	_achievements()
	_saved_game()
	_settings()
	section("How to play")
	body.add_child(label(g.get("controls", ""), 20, Color(0.9, 0.92, 1)))
	section("About")
	body.add_child(label(g.get("about", g["tagline"]), 20))
	var vs: Array = g["versions"]
	if vs.size() > 1 or scene != vs[vs.size() - 1]["scene"]:
		for v in vs:
			if v["scene"] == scene:
				body.add_child(label("You are playing version %d (%s)." % [v["v"], v["date"]], 18, MUTED))
	if g.has("credit"):
		section("Credits")
		body.add_child(label(g["credit"], 18, MUTED))
	# keyboard / controller: start on Play (or Continue)
	var first: Control = find_child("Continue", true, false)
	if first == null:
		first = find_child("Play", true, false)
	UiFx.focus_first.call_deferred(self, first)


func _play_buttons(side: Container) -> void:
	var sv := GameData.save_info(g)
	if sv != "":
		var cont := button("Continue  ·  %s" % sv, Color(0.33, 0.62, 0.10), 28)
		cont.name = "Continue"
		cont.custom_minimum_size = Vector2(0, 76)
		cont.pressed.connect(func(): play("continue"))
		side.add_child(cont)
		var ng := button("New game", Color(0.22, 0.30, 0.40), 24)
		ng.name = "NewGame"
		ng.custom_minimum_size = Vector2(0, 62)
		ng.pressed.connect(func(): play("new"))
		side.add_child(ng)
	else:
		var p := button("Play", Color(0.33, 0.62, 0.10), 32)
		p.name = "Play"
		p.custom_minimum_size = Vector2(0, 84)
		p.pressed.connect(func(): play("new" if g.has("save_file") else ""))
		side.add_child(p)
	var best := GameData.read_best(g)
	var facts := []
	if not g.get("no_score", false):
		facts.append("Best %d" % best if best > 0 else "No score yet")
	var n := GameData.plays(g["id"])
	facts.append("Played %d times" % n if n != 1 else "Played once")
	if GameData.playtime(g["id"]) > 0:
		facts.append(GameData.time_text(GameData.playtime(g["id"])))
	side.add_child(label("  ·  ".join(facts), 20, MUTED))


func _difficulty(side: Container) -> void:
	side.add_child(label("Difficulty", 20, MUTED))
	var row := HBoxContainer.new()
	row.name = "Difficulty"
	row.add_theme_constant_override("separation", 8)
	side.add_child(row)
	var cur := ArcadeGame.get_difficulty(g["id"])
	for d in 3:
		var b := button(ArcadeGame.DIFF_NAMES[d], Color(0.85, 0.55, 0.15) if d == cur else PANEL, 22)
		b.name = "Diff%d" % d
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(func():
			ArcadeGame.set_difficulty(g["id"], d)
			build())
		row.add_child(b)


func _scores() -> void:
	if g.get("no_score", false):
		return
	section("High scores")
	var list := GameData.scores(g["id"])
	var box := PanelContainer.new()
	box.name = "HighScores"
	box.add_theme_stylebox_override("panel", flat(PANEL, 12, 14))
	body.add_child(box)
	if list.is_empty():
		var best := GameData.read_best(g)
		box.add_child(label("Best so far: %d. Finish a run to fill this list." % best if best > 0 else "No scores yet. Finish a run to get on the list.", 20, MUTED))
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for k in list.size():
		var e: Dictionary = list[k]
		var top := k == 0
		grid.add_child(label("#%d" % (k + 1), 20, GOLD if top else MUTED))
		grid.add_child(label(str(int(e["score"])), 22 if top else 20, GOLD if top else Color.WHITE))
		grid.add_child(label(ArcadeGame.DIFF_NAMES[clampi(int(e.get("difficulty", 1)), 0, 2)], 18, MUTED))
		grid.add_child(label(str(e.get("date", "")), 18, MUTED))


func _achievements() -> void:
	var list := GameData.achievements(g)
	var got := list.filter(func(a): return a["done"]).size()
	section("Achievements  %d / %d" % [got, list.size()])
	var flow := HFlowContainer.new()
	flow.name = "Achievements"
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	body.add_child(flow)
	for a in list:
		var p := PanelContainer.new()
		p.name = "Ach_" + a["key"]
		p.custom_minimum_size = Vector2(300 if portrait else 290, 0)
		p.add_theme_stylebox_override("panel", flat(Color(0.30, 0.24, 0.08) if a["done"] else PANEL, 12, 12))
		var v := VBoxContainer.new()
		p.add_child(v)
		v.add_child(label(a["name"], 21, GOLD if a["done"] else MUTED))
		v.add_child(label(a["text"], 18, Color.WHITE if a["done"] else MUTED))
		if a["done"] and a["when"] > 0:
			v.add_child(label(Time.get_date_string_from_unix_time(a["when"]), 16, MUTED))
		flow.add_child(p)


## "Achievement unlocked" slides down at the top and fades out.
func _unlock_banner() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Unlocked"
	layer.layer = 5
	add_child(layer)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(Color(0.30, 0.24, 0.08, 0.96), 14, 16))
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 16
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	var names: Array = unlocked.map(func(a): return a["name"])
	var l := label("Achievement unlocked: " + ", ".join(names), 22, GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	unlocked = []
	var tw := p.create_tween()
	p.modulate.a = 0.0
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)


func _saved_game() -> void:
	if not g.has("save_file"):
		return
	section("Saved game")
	var sv := GameData.save_info(g)
	if sv == "":
		body.add_child(label("No saved game. The game saves as you play; come back any time with Continue.", 19, MUTED))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	row.add_child(label("Saved: " + sv, 20))
	var del := button("Delete saved game", Color(0.45, 0.18, 0.22), 18, false)
	del.name = "DeleteSave"
	del.pressed.connect(func():
		GameData.delete_save(g)
		build())
	row.add_child(del)


func _settings() -> void:
	section("Settings")
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	body.add_child(row)
	var on := GameData.sound_on(g["id"])
	var snd := button("Sound: on" if on else "Sound: off", PANEL, 20, false)
	snd.name = "Sound"
	snd.custom_minimum_size = Vector2(170, 52)
	snd.pressed.connect(func():
		GameData.set_sound(g["id"], not GameData.sound_on(g["id"]))
		build())
	row.add_child(snd)
	if not g.get("no_score", false):
		var rs := button("Tap again to clear the high scores" if confirm_reset else "Clear high scores", Color(0.45, 0.18, 0.22) if confirm_reset else PANEL, 20, false)
		rs.name = "ClearScores"
		rs.custom_minimum_size = Vector2(0, 52)
		rs.pressed.connect(func():
			if confirm_reset:
				GameData.clear_scores(g)
				confirm_reset = false
			else:
				confirm_reset = true
			build())
		row.add_child(rs)


# ---------------------------------------------------------------- small helpers

func cover() -> Control:
	var tr := TextureRect.new()
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var path: String = g.get("cover", "")
	if path != "" and ResourceLoader.exists(path):
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		tr.custom_minimum_size = Vector2(0, 200)
	return tr


func section(title: String) -> void:
	var l := label(title, 24, GOLD)
	body.add_child(l)


func label(s: String, size: int, color := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func flat(c: Color, radius := 14, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


func button(txt: String, c: Color, size := 22, expand := true) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	b.mouse_filter = Control.MOUSE_FILTER_PASS  # let finger drags scroll the page
	b.add_theme_stylebox_override("normal", flat(c))
	b.add_theme_stylebox_override("hover", flat(c.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", flat(c.darkened(0.2)))
	var fo := flat(c.lightened(0.05))
	fo.border_color = Color(1, 1, 1)
	fo.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", fo)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b
