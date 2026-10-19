extends PuzzleGame
# Lights Out: every tap flips a light and its four neighbours. Turn all lights off.
# Boards are made by pressing random cells on a dark board, so they can always be
# solved; the hint shows one of the presses that is still needed.
# Easy 4x4, Normal 5x5, Hard 6x6.

const AREA := Rect2(60, 70, 900, 620)

var n := 5
var lit: Array = []  # bools
var need: Array = []  # bools: pressing this cell is part of a solution
var start: Array = []  # the board as dealt, for Restart
var start_need: Array = []
var undo_stack: Array = []
var hint_cell := -1
var cell := 100.0
var origin := Vector2.ZERO


func _init() -> void:
	game_id = "lights_out"
	title = "Lights Out"
	help = ["Tap a light: it flips, and so do the four lights next to it.", "Turn every light off in as few moves as you can.", "Every board can be solved. Stuck? Hint shows a light to tap."]


func new_game() -> void:
	n = [4, 5, 6][diff]
	_fit()
	lit = []
	lit.resize(n * n)
	lit.fill(false)
	need = lit.duplicate()
	var presses := n * n / 2 + randi() % 3
	for k in presses:
		_press(randi() % (n * n))
	if lit.count(true) == 0:
		_press(randi() % (n * n))
	start = lit.duplicate()
	start_need = need.duplicate()
	undo_stack.clear()
	hint_cell = -1


func _fit() -> void:
	cell = floorf(minf(AREA.size.x, AREA.size.y) / n)
	origin = AREA.position + (AREA.size - Vector2(n, n) * cell) / 2.0


func _press(i: int) -> void:
	var x := i % n
	var y := i / n
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx >= 0 and ny >= 0 and nx < n and ny < n:
			lit[ny * n + nx] = not lit[ny * n + nx]
	need[i] = not need[i]


func to_save() -> Dictionary:
	return {"n": n, "lit": lit, "need": need, "start": start, "start_need": start_need}


func from_save(d: Dictionary) -> void:
	n = int(d.get("n", 5))
	lit = d.get("lit", []).map(func(v): return bool(v))
	need = d.get("need", []).map(func(v): return bool(v))
	start = d.get("start", []).map(func(v): return bool(v))
	start_need = d.get("start_need", []).map(func(v): return bool(v))
	if lit.size() != n * n or need.size() != n * n or start.size() != n * n:
		new_game()
		return
	_fit()
	undo_stack.clear()
	hint_cell = -1


func save_info() -> String:
	return "%d lights on" % lit.count(true)


func play_buttons() -> Array:
	return [["Undo", _undo], ["Hint", _hint], ["Restart", _restart], ["New game", start_new]]


func tap_cell(i: int) -> void:
	if i < 0:
		return
	undo_stack.append([lit.duplicate(), need.duplicate()])
	_press(i)
	moves += 1
	hint_cell = -1
	if lit.count(true) == 0:
		var par := start_need.count(true)
		finish(true, maxi(100, (diff + 1) * 600 + par * 40 - maxi(0, moves - par) * 30))
	else:
		save_game()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	var u: Array = undo_stack.pop_back()
	lit = u[0]
	need = u[1]
	hint_cell = -1
	save_game()


func _hint() -> void:
	var opts := []
	for i in need.size():
		if need[i]:
			opts.append(i)
	if opts.is_empty():
		return
	hint_cell = opts[randi() % opts.size()]
	toast("Try the glowing ring")


func _restart() -> void:
	lit = start.duplicate()
	need = start_need.duplicate()
	undo_stack.clear()
	hint_cell = -1
	save_game()


func game_tap(p: Vector2) -> void:
	var r := (p - origin) / cell
	if r.x < 0 or r.y < 0 or r.x >= n or r.y >= n:
		return
	tap_cell(int(r.y) * n + int(r.x))


func draw_game() -> void:
	for i in lit.size():
		var r := Rect2(origin + Vector2(i % n, i / n) * cell, Vector2(cell, cell)).grow(-6)
		if lit[i]:
			draw_rect(r.grow(4), Color(1.0, 0.85, 0.35, 0.25))
			draw_rect(r, Color(1.0, 0.86, 0.40))
		else:
			draw_rect(r, Color(0.20, 0.22, 0.32))
		if i == hint_cell:
			draw_arc(r.get_center(), r.size.x * 0.3, 0, TAU, 40, Color(0.3, 0.9, 1.0), 5.0)
	var par := start_need.count(true)
	draw_stats(["Moves %d  (par %d)" % [moves, par], "Lights on %d" % lit.count(true)])
