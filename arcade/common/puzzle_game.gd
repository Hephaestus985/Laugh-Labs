class_name PuzzleGame
extends ArcadeGame
# Shared base for the calm board and puzzle games (2048, Sudoku, Minesweeper...).
# It adds what they all need on top of ArcadeGame:
#   - title screen, playing, finished (won / lost) states
#   - difficulty from the menu (diff: 0 easy, 1 normal, 2 hard)
#   - a save after every move, with Continue / New game (menu and title)
#   - finger-sized on-screen buttons (Undo, New, Hint...) and tap / drag / swipe input
# A game overrides the hooks below and calls save_game() after each move and
# finish(won, score) when the round is over.

const PANEL_X := 1000.0  # buttons live in the right-hand column
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


# ---------------------------------------------------------------- flow

func save_path() -> String:
	return "user://%s_save.json" % game_id


func _ready() -> void:
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
	won = did_win
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
			_title_tap(Vector2(W / 2, H / 2))
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
	if state == 0:
		if has_save:
			buttons.append([Rect2(W / 2 - 170, 560, 340, BTN_H), "New game", start_new])
		return
	if state == 2:
		buttons.append([Rect2(W / 2 - 330, 520, 300, BTN_H), "Play again", start_new])
		buttons.append([Rect2(W / 2 + 30, 520, 300, BTN_H), "Menu", back_to_menu])
		return
	var y := 110.0
	for pb in play_buttons():
		buttons.append([Rect2(PANEL_X, y, W - PANEL_X - 24, BTN_H), pb[0], pb[1]])
		y += BTN_H + 14


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), BG)
	if state == 0:
		_draw_title()
	else:
		draw_game()
		if state == 2:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
			text(Vector2(0, 250), ("You win!" if won else "Game over"), 72, ACCENT, true)
			text(Vector2(0, 330), "Score %d   Best %d" % [score, best], 34, INK, true)
			text(Vector2(0, 380), "Time %s   Moves %d" % [time_text(elapsed), moves], 26, DIM, true)
	for b in buttons:
		draw_button(b[0], b[1])
	if message_t > 0.0 and message != "":
		var a := clampf(message_t, 0.0, 1.0)
		draw_rect(Rect2(W / 2 - 300, H - 90, 600, 60), Color(0, 0, 0, 0.6 * a))
		text(Vector2(0, H - 50), message, 26, Color(1, 1, 1, a), true)
	draw_overlay()


func _draw_title() -> void:
	text(Vector2(0, 150), title, 76, ACCENT, true)
	text(Vector2(0, 200), "%s   -   Best %d" % [DIFF_NAMES[diff], best], 26, DIM, true)
	var y := 270.0
	for line in help:
		text(Vector2(0, y), line, 26, INK, true)
		y += 40
	text(Vector2(0, 520), "Tap to continue" if has_save else "Tap to play", 34, ACCENT if fmod(t, 1.2) < 0.8 else DIM, true)


func draw_button(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.22, 0.25, 0.38))
	draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)
	draw_string(font, Vector2(r.position.x, r.get_center().y + 10), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, INK)


## A stat line in the right-hand column (above the buttons).
func draw_stats(lines: Array) -> void:
	var y := 50.0
	for line in lines:
		draw_string(font, Vector2(PANEL_X, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, W - PANEL_X - 20, 26, DIM)
		y += 30
