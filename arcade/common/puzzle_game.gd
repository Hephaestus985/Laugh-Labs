class_name PuzzleGame
extends ArcadeGame
# Shared base for the calm board and puzzle games (2048, Sudoku, Minesweeper...).
# It adds what they all need on top of ArcadeGame:
#   - title screen, playing, finished (won / lost) states
#   - difficulty from the menu (diff: 0 easy, 1 normal, 2 hard)
#   - a save after every move, with Continue / New game (menu and title)
#   - finger-sized on-screen buttons (Undo, New, Hint...) and tap / drag / swipe input
#   - landscape and portrait: the screen turns with the phone. The game lays itself
#     out in board_rect (buttons go in panel_rect) from layout(), which runs again
#     whenever the phone turns. sw / sh are the screen size (1280x720 or 720x1280).
#   - a little animation clock: anim(key) gives 0..1 progress of a started effect
# A game overrides the hooks below and calls save_game() after each move and
# finish(won, score) when the round is over.

const BTN_H := 70.0
const BG := Color(0.10, 0.11, 0.17)
const INK := Color(0.95, 0.95, 1.0)
const DIM := Color(0.70, 0.72, 0.85)
const ACCENT := Color(1.0, 0.75, 0.30)

var state := 0  # 0 title, 1 playing, 2 finished
var diff := 1
var score := 0
var moves := 0
var elapsed := 0.0
var won := false
var has_save := false
var title := "Puzzle"
var help: Array[String] = []  # lines on the title screen
var buttons: Array = []  # [Rect2, label, Callable] rebuilt every frame by the game
var message := ""
var message_t := 0.0

var portrait := false
var sw := 1280.0
var sh := 720.0
var board_rect := Rect2(30, 76, 950, 630)
var panel_rect := Rect2(1000, 100, 256, 600)
var panel_slots := 0  # reserve room for this many buttons (if some come and go)
var _anims := {}  # key -> [start time, duration]

var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false


# ---------------------------------------------------------------- hooks for the games

## Set up a new round for the current difficulty.
func new_game() -> void:
	pass


## The board as plain data (numbers, strings, arrays, dictionaries) for the save file.
func to_save() -> Dictionary:
	return {}


func from_save(_d: Dictionary) -> void:
	pass


## A short text for the menu card, e.g. "score 512" or "12 of 81 filled".
func save_info() -> String:
	return "in progress"


func draw_game() -> void:
	pass


## The play buttons for the right-hand column: [[label, Callable], ...]
func play_buttons() -> Array:
	return []


func game_tap(_pos: Vector2) -> void:
	pass


func game_long_press(pos: Vector2) -> void:
	game_tap(pos)


## Pressed, moved and released: from / to in screen coordinates.
func game_press(_pos: Vector2) -> void:
	pass


func game_drag(_from: Vector2, _to: Vector2) -> void:
	pass


func game_release(_from: Vector2, _to: Vector2) -> void:
	pass


## A quick swipe: dir is one of Vector2i.LEFT / RIGHT / UP / DOWN.
func game_swipe(_dir: Vector2i) -> void:
	pass


func game_key(_k: int) -> void:
	pass


func game_update(_delta: float) -> void:
	pass


## Place the board inside board_rect. Runs at the start and whenever the phone turns.
func layout() -> void:
	pass


# ---------------------------------------------------------------- screen and animation

func _want_portrait() -> bool:
	var s := get_window().size
	return s.y > s.x


func apply_screen(force := false) -> void:
	var p := _want_portrait()
	if p == portrait and not force:
		return
	portrait = p
	var win := get_window()
	win.content_scale_size = Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	sw = 720.0 if portrait else 1280.0
	sh = 1280.0 if portrait else 720.0
	_place_areas()
	layout()


func _place_areas() -> void:
	var n := maxi(play_buttons().size(), panel_slots)
	if portrait:
		var rows := maxi(1, ceili(n / 2.0))
		var ph := rows * (BTN_H + 12.0)
		panel_rect = Rect2(20, sh - ph - 16, sw - 40, ph)
		board_rect = Rect2(20, 86, sw - 40, panel_rect.position.y - 86 - 14)
	else:
		panel_rect = Rect2(1000, 100, 256, sh - 110)
		board_rect = Rect2(30, 76, 950, sh - 86)


## Start (or restart) a named animation.
func start_anim(key: String, duration: float) -> void:
	_anims[key] = [t, duration]


## Progress of a named animation: 0 just started .. 1 done (also 1 if never started).
func anim(key: String) -> float:
	if not _anims.has(key):
		return 1.0
	var a: Array = _anims[key]
	return clampf((t - a[0]) / a[1], 0.0, 1.0)


func animating(key: String) -> bool:
	return anim(key) < 1.0


static func ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)


## A quick "pop": grows past full size and settles (for new or merged things).
static func pop(x: float) -> float:
	return 1.0 + 0.18 * sin(clampf(x, 0.0, 1.0) * PI)


## Text centred on the screen, wrapped to the screen width.
func ctext(y: float, s: String, size: int, c: Color) -> void:
	var w := sw - 40.0
	draw_multiline_string_outline(font, Vector2(20, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, 3, 6, Color(0.08, 0.08, 0.15, 0.9 * c.a))
	draw_multiline_string(font, Vector2(20, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, 3, c)


func text_lines(s: String, size: int) -> int:
	return maxi(1, int(font.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, sw - 40.0, size).y / (font.get_height(size) * 0.98)))


# ---------------------------------------------------------------- flow

func save_path() -> String:
	return "user://%s_save.json" % game_id


func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	apply_screen(true)
	use_stick = false
	use_b = false
	show_a = false
	custom_keys = true
	diff = difficulty()
	load_best()
	has_save = FileAccess.file_exists(save_path())
	var lm := launch_mode()
	if lm == "new":
		clear_save()
		start_new()
	elif lm == "continue" and has_save:
		continue_game()


func start_new() -> void:
	diff = difficulty()
	score = 0
	moves = 0
	elapsed = 0.0
	won = false
	message = ""
	new_game()
	state = 1
	_place_areas()
	layout()
	save_game()


func continue_game() -> void:
	var o = JSON.parse_string(FileAccess.get_file_as_string(save_path())) if FileAccess.file_exists(save_path()) else null
	if typeof(o) != TYPE_DICTIONARY or typeof(o.get("data")) != TYPE_DICTIONARY:
		start_new()
		return
	diff = int(o.get("diff", difficulty()))
	score = int(o.get("score", 0))
	moves = int(o.get("moves", 0))
	elapsed = float(o.get("elapsed", 0.0))
	won = false
	message = ""
	from_save(o["data"])
	state = 1
	_place_areas()
	layout()


func save_game() -> void:
	if state != 1:
		return
	var o := {"info": save_info(), "diff": diff, "score": score, "moves": moves, "elapsed": elapsed, "data": to_save()}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(o))
	has_save = true


func clear_save() -> void:
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(save_path())
	has_save = false


## The round is over. Saves the best score and removes the save.
func finish(did_win: bool, final_score: int) -> void:
	start_anim("finish", 0.45)
	won = did_win
	if did_win:
		GameData.add_win(game_id)
	score = final_score
	state = 2
	clear_save()
	if final_score > 0:
		submit_score(final_score)


func toast(s: String) -> void:
	message = s
	message_t = 2.0


func time_text(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


# ---------------------------------------------------------------- input

func on_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == 1:
			game_key(event.keycode)
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_title_tap(Vector2(sw / 2, sh / 2))
		return
	var p := Vector2.ZERO
	var down := false
	var is_press := false
	var is_move := false
	if is_mobile:
		if event is InputEventScreenTouch and event.index == 0:
			p = event.position
			is_press = true
			down = event.pressed
		elif event is InputEventScreenDrag and event.index == 0:
			p = event.position
			is_move = true
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			p = event.position
			is_press = true
			down = event.pressed
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and state == 1:
			game_long_press(event.position)
			return
		elif event is InputEventMouseMotion and _pressing:
			p = event.position
			is_move = true
	if is_press and down:
		if MENU_BTN.has_point(p):
			return
		_pressing = true
		_dragged = false
		_press_pos = p
		_press_time = t
		if state == 1 and not _on_button(p):
			game_press(p)
	elif is_move and _pressing:
		if p.distance_to(_press_pos) > 24.0:
			_dragged = true
		if state == 1 and not _on_button(_press_pos):
			game_drag(_press_pos, p)
	elif is_press and not down and _pressing:
		_pressing = false
		_release(_press_pos, p)


var _press_time := 0.0
var _long_done := false


func _on_button(p: Vector2) -> bool:
	for b in buttons:
		if (b[0] as Rect2).grow(6).has_point(p):
			return true
	return false


func _release(from: Vector2, to: Vector2) -> void:
	if _long_done:
		_long_done = false
		return
	if state != 1:
		if not _dragged:
			_title_tap(to)
		return
	for b in buttons:
		if (b[0] as Rect2).grow(6).has_point(from) and (b[0] as Rect2).grow(20).has_point(to):
			(b[2] as Callable).call()
			return
	if _on_button(from):
		return
	var d := to - from
	if _dragged and d.length() > 50.0:
		var dir := Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(d.y)))
		game_swipe(dir)
		game_release(from, to)
	elif _dragged:
		game_release(from, to)
	else:
		game_release(from, to)
		game_tap(to)


func _title_tap(p: Vector2) -> void:
	for b in buttons:
		if (b[0] as Rect2).grow(6).has_point(p):
			(b[2] as Callable).call()
			return
	if state == 0:
		if has_save:
			continue_game()
		else:
			start_new()
	elif state == 2:
		start_new()


func _process(delta: float) -> void:
	tick(delta)
	apply_screen()
	if state == 1:
		elapsed += delta
		# long press (for flags / notes) while the finger stays put
		if _pressing and not _dragged and not _long_done and t - _press_time > 0.5 and not _on_button(_press_pos):
			_long_done = true
			game_long_press(_press_pos)
		game_update(delta)
	if message_t > 0.0:
		message_t -= delta
	_layout_buttons()
	queue_redraw()


func _layout_buttons() -> void:
	buttons.clear()
	var mid := sh * 0.5
	if state == 0:
		if has_save:
			buttons.append([Rect2(sw / 2 - 170, sh * 0.78, 340, BTN_H), "New game", start_new])
		return
	if state == 2:
		if portrait:
			buttons.append([Rect2(sw / 2 - 170, mid + 120, 340, BTN_H), "Play again", start_new])
			buttons.append([Rect2(sw / 2 - 170, mid + 210, 340, BTN_H), "Menu", back_to_menu])
		else:
			buttons.append([Rect2(sw / 2 - 330, mid + 160, 300, BTN_H), "Play again", start_new])
			buttons.append([Rect2(sw / 2 + 30, mid + 160, 300, BTN_H), "Menu", back_to_menu])
		return
	var pbs := play_buttons()
	if portrait:
		var cols := 2
		var bw := (panel_rect.size.x - 12.0 * (cols - 1)) / cols
		for k in pbs.size():
			var r := Rect2(panel_rect.position + Vector2((k % cols) * (bw + 12), (k / cols) * (BTN_H + 12)), Vector2(bw, BTN_H))
			buttons.append([r, pbs[k][0], pbs[k][1]])
	else:
		var y := panel_rect.position.y + 10
		for pb in pbs:
			buttons.append([Rect2(panel_rect.position.x, y, panel_rect.size.x, BTN_H), pb[0], pb[1]])
			y += BTN_H + 14


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, sw, sh), BG)
	if state == 0:
		_draw_title()
	else:
		draw_game()
		if state == 2:
			var k := ease_out(anim("finish"))
			draw_rect(Rect2(0, 0, sw, sh), Color(0, 0, 0, 0.55 * k))
			var mid := sh * 0.5
			ctext(mid - 110 - 40 * (1.0 - k), ("You win!" if won else "Game over"), 72, Color(ACCENT, k))
			ctext(mid - 20, "Score %d   Best %d" % [score, best], 34, Color(INK, k))
			ctext(mid + 30, "Time %s   Moves %d" % [time_text(elapsed), moves], 26, Color(DIM, k))
	for b in buttons:
		draw_button(b[0], b[1])
	if message_t > 0.0 and message != "":
		var a := clampf(message_t, 0.0, 1.0)
		var y := (panel_rect.position.y - 70) if portrait else sh - 90
		draw_rect(Rect2(sw / 2 - minf(300, sw / 2 - 10), y, minf(600, sw - 20), 60), Color(0, 0, 0, 0.6 * a))
		ctext(y + 40, message, 26, Color(1, 1, 1, a))
	draw_overlay()


func _draw_title() -> void:
	var y := sh * 0.2
	ctext(y, title, 76, ACCENT)
	y += 52
	ctext(y, "%s   -   Best %d" % [DIFF_NAMES[diff], best], 26, DIM)
	y += 70
	for line in help:
		ctext(y, line, 26, INK)
		y += 40 * text_lines(line, 26)
	ctext(maxf(y + 40, sh * 0.7), "Tap to continue" if has_save else "Tap to play", 34, ACCENT if fmod(t, 1.2) < 0.8 else DIM)


func draw_button(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.22, 0.25, 0.38))
	draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.get_center().y + 10), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, INK)


## Two short stat lines: above the buttons (landscape) or next to MENU (portrait).
func draw_stats(lines: Array) -> void:
	var x := 150.0 if portrait else panel_rect.position.x
	var y := 36.0 if portrait else 50.0
	for line in lines:
		draw_string(font, Vector2(x, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, sw - x - 16, 24 if portrait else 26, DIM)
		y += 28
