extends PuzzleGame
# Minesweeper: open every cell that has no mine. A number tells how many of the
# 8 neighbours hide a mine. Tap to open, long-press (or Flag mode) to flag.
# Tapping an opened number whose flags are all placed opens its other neighbours.
# The first tap is always safe.

const SIZES := [[10, 7, 10], [14, 9, 22], [16, 10, 35]]  # columns, rows, mines

var cols := 10
var rows := 7
var mines := 10
var cell := 64.0
var origin := Vector2.ZERO
var mine: Array = []  # bools
var open: Array = []  # bools
var flag: Array = []  # bools
var placed := false
var flag_mode := false
var boom := -1
var open_at := {}  # cell -> time it opens (cells open in a ripple from the tap)


func _init() -> void:
	game_id = "minesweeper"
	title = "Minesweeper"
	help = ["Open every cell without a mine. Numbers count the mines next to a cell.", "Tap to open. Long-press, or turn on Flag mode, to mark a mine.", "Tap a number whose mines are all flagged to open the rest around it."]


func new_game() -> void:
	cols = SIZES[diff][0]
	rows = SIZES[diff][1]
	mines = SIZES[diff][2]
	_fit()
	var n := cols * rows
	mine = []
	mine.resize(n)
	mine.fill(false)
	open = mine.duplicate()
	flag = mine.duplicate()
	placed = false
	flag_mode = false
	boom = -1
	open_at = {}


## In portrait the board is shown turned on its side (columns become rows), so it
## fills the tall screen. Only the drawing and the tap position change.
func _disp() -> Vector2:
	return Vector2(rows, cols) if portrait else Vector2(cols, rows)


func layout() -> void:
	_fit()


func _fit() -> void:
	var d := _disp()
	cell = floorf(minf(minf(board_rect.size.x / d.x, board_rect.size.y / d.y), 96.0))
	origin = board_rect.position + (board_rect.size - d * cell) / 2.0


func cell_pos(i: int) -> Vector2:
	var x := i % cols
	var y := i / cols
	return origin + (Vector2(y, x) if portrait else Vector2(x, y)) * cell


func to_save() -> Dictionary:
	return {"cols": cols, "rows": rows, "mines": mines, "mine": mine, "open": open, "flag": flag, "placed": placed}


func from_save(d: Dictionary) -> void:
	cols = int(d.get("cols", 10))
	rows = int(d.get("rows", 7))
	mines = int(d.get("mines", 10))
	mine = d.get("mine", []).map(func(v): return bool(v))
	open = d.get("open", []).map(func(v): return bool(v))
	flag = d.get("flag", []).map(func(v): return bool(v))
	placed = bool(d.get("placed", false))
	if mine.size() != cols * rows or open.size() != mine.size() or flag.size() != mine.size():
		new_game()
		return
	_fit()
	flag_mode = false
	boom = -1
	open_at = {}


func save_info() -> String:
	return "%d mines left" % (mines - flag.count(true))


func play_buttons() -> Array:
	return [
		["Flag mode: ON" if flag_mode else "Flag mode: off", func(): flag_mode = not flag_mode],
		["New game", start_new],
	]


func _neighbours(i: int) -> Array:
	var out := []
	var x := i % cols
	var y := i / cols
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows:
				out.append(ny * cols + nx)
	return out


func _count(i: int) -> int:
	return _neighbours(i).filter(func(j): return mine[j]).size()


func _place(safe: int) -> void:
	var keep_clear := _neighbours(safe)
	keep_clear.append(safe)
	var spots := []
	for i in mine.size():
		if not keep_clear.has(i):
			spots.append(i)
	spots.shuffle()
	for k in mini(mines, spots.size()):
		mine[spots[k]] = true
	placed = true


func _cell_at(p: Vector2) -> int:
	var r := (p - origin) / cell
	var d := _disp()
	if r.x < 0 or r.y < 0 or r.x >= d.x or r.y >= d.y:
		return -1
	if portrait:
		return int(r.x) * cols + int(r.y)
	return int(r.y) * cols + int(r.x)


func reveal(i: int) -> void:
	if i < 0 or flag[i]:
		return
	if not placed:
		_place(i)
	if open[i]:
		_chord(i)
		return
	moves += 1
	if mine[i]:
		boom = i
		start_anim("boom", 0.8)
		for j in mine.size():
			if mine[j]:
				open[j] = true
				open_at[j] = t + 0.15 + cell_pos(j).distance_to(cell_pos(i)) / cell * 0.04
		finish(false, 0)
		return
	_flood(i)
	_check_win()


func _flood(start: int) -> void:
	var todo := [start]
	var dist := {start: 0}
	var k := 0
	while k < todo.size():
		var i: int = todo[k]
		k += 1
		if open[i] or flag[i]:
			continue
		open[i] = true
		open_at[i] = t + dist[i] * 0.03
		if _count(i) == 0:
			for j in _neighbours(i):
				if not open[j] and not dist.has(j):
					dist[j] = dist[i] + 1
					todo.append(j)


func _chord(i: int) -> void:
	var nb := _neighbours(i)
	if nb.filter(func(j): return flag[j]).size() != _count(i):
		return
	for j in nb:
		if not open[j] and not flag[j]:
			if mine[j]:
				reveal(j)
				return
			_flood(j)
	_check_win()


func toggle_flag(i: int) -> void:
	if i < 0 or open[i]:
		return
	flag[i] = not flag[i]
	save_game()


func _check_win() -> void:
	for i in mine.size():
		if not mine[i] and not open[i]:
			save_game()
			return
	for i in mine.size():
		if mine[i]:
			flag[i] = true
	finish(true, maxi(100, (diff + 1) * 1000 + mines * 20 - int(elapsed) * 2))


func game_tap(p: Vector2) -> void:
	var i := _cell_at(p)
	if i < 0:
		return
	if flag_mode and not open[i]:
		toggle_flag(i)
	else:
		reveal(i)


func game_long_press(p: Vector2) -> void:
	toggle_flag(_cell_at(p))


func game_key(k: int) -> void:
	if k == KEY_F:
		flag_mode = not flag_mode


func draw_game() -> void:
	for i in mine.size():
		var r := Rect2(cell_pos(i), Vector2(cell, cell)).grow(-2)
		var opened_k := 1.0
		if open[i] and open_at.has(i):
			opened_k = clampf((t - float(open_at[i])) / 0.18, 0.0, 1.0)
		if open[i] and opened_k <= 0.0:
			draw_rect(r, Color(0.34, 0.40, 0.58))
		elif open[i]:
			if opened_k < 1.0:
				draw_rect(r, Color(0.34, 0.40, 0.58))
				r = Rect2(r.get_center() - r.size * opened_k / 2.0, r.size * opened_k)
			draw_rect(r, Color(0.85, 0.86, 0.92) if i != boom else Color(0.95, 0.3, 0.3))
			if mine[i]:
				draw_circle(r.get_center(), cell * 0.25, Color(0.1, 0.1, 0.12))
			else:
				var c := _count(i)
				if c > 0:
					var cols_by_n := [Color.BLACK, Color(0.15, 0.35, 0.9), Color(0.1, 0.55, 0.2), Color(0.85, 0.15, 0.15), Color(0.3, 0.1, 0.6), Color(0.55, 0.1, 0.1), Color(0.1, 0.5, 0.55), Color.BLACK, Color(0.4, 0.4, 0.4)]
					draw_string(font, Vector2(r.position.x, r.get_center().y + cell * 0.2), str(c), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(cell * 0.55), cols_by_n[c])
		else:
			draw_rect(r, Color(0.34, 0.40, 0.58))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 1, 1, 0.18))
			if flag[i]:
				var c := r.get_center()
				draw_line(c + Vector2(-cell * 0.1, cell * 0.28), c + Vector2(-cell * 0.1, -cell * 0.28), Color.WHITE, 3.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-cell * 0.1, -cell * 0.28), c + Vector2(cell * 0.25, -cell * 0.15), c + Vector2(-cell * 0.1, -cell * 0.02)]), Color(0.95, 0.25, 0.2))
	draw_stats(["Mines left %d" % (mines - flag.count(true)), "%s   %s" % [DIFF_NAMES[diff], time_text(elapsed)]])
	if boom >= 0 and animating("boom"):
		var k := anim("boom")
		draw_circle(cell_pos(boom) + Vector2(cell, cell) / 2.0, cell * (0.5 + 4.0 * k), Color(1.0, 0.5, 0.2, 0.5 * (1.0 - k)))
	if flag_mode:
		text(Vector2(origin.x, origin.y - 8), "Flag mode: taps place flags", 20, ACCENT)
