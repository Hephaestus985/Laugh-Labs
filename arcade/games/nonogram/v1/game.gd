extends PuzzleGame
# Nonogram (Picross): the numbers beside each row and above each column give the
# lengths of the filled runs in that line, in order. Fill the grid to match.
# Any grid that matches every clue counts as solved.
# Easy 5x5, Normal 8x8, Hard 10x10. Tap to fill, long-press or Cross mode to mark
# a cell as empty, drag to paint along a row or column.

const SIZES := [5, 8, 10]

var n := 5
var target: Array = []  # bools: the hidden picture
var cells: Array = []  # 0 empty, 1 filled, 2 crossed
var row_clues: Array = []
var col_clues: Array = []
var cross_mode := false
var undo_stack: Array = []
var hints := 0
var cell := 50.0
var origin := Vector2.ZERO
var clue_w := 100.0
var clue_h := 100.0

var changed_at := {}  # cell -> time it was last filled or crossed (for the pop)
var line_flash := {}  # "r3" / "c5" -> time that row / column became right

var _paint_value := -1  # what a drag paints
var _paint_start := -1
var _paint_before: Array = []


func _init() -> void:
	game_id = "nonogram"
	title = "Nonogram"
	help = ["The numbers by each row and column are the lengths of its filled runs, in order.", "Tap to fill a cell, long-press or Cross mode to mark it empty.", "Drag to paint a row or column. Complete the hidden picture."]


static func clues_of(line: Array) -> Array:
	var out := []
	var run := 0
	for v in line:
		if v:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out if not out.is_empty() else [0]


func new_game() -> void:
	n = SIZES[diff]
	target = []
	# a picture with some structure: random blobs, not pure noise
	var density: float = [0.6, 0.55, 0.55][diff]
	while true:
		target = []
		for i in n * n:
			target.append(randf() < density)
		for pass_i in 2:
			var smooth := target.duplicate()
			for i in n * n:
				var x := i % n
				var y := i / n
				var cnt := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < n and ny < n and target[ny * n + nx]:
						cnt += 1
				if cnt >= 3:
					smooth[i] = true
				elif cnt <= 0:
					smooth[i] = false
			target = smooth
		var fill := target.count(true)
		if fill > n * n * 0.3 and fill < n * n * 0.8:
			break
	_make_clues()
	cells = []
	cells.resize(n * n)
	cells.fill(0)
	undo_stack.clear()
	hints = 0
	cross_mode = false
	changed_at = {}
	line_flash = {}


func _make_clues() -> void:
	row_clues = []
	col_clues = []
	for y in n:
		row_clues.append(clues_of(range(n).map(func(x): return target[y * n + x])))
	for x in n:
		col_clues.append(clues_of(range(n).map(func(y): return target[y * n + x])))
	var max_r := 1
	var max_c := 1
	for c in row_clues:
		max_r = maxi(max_r, c.size())
	for c in col_clues:
		max_c = maxi(max_c, c.size())
	_clue_counts = Vector2i(max_r, max_c)
	layout()


var _clue_counts := Vector2i(1, 1)


func layout() -> void:
	# cell size from the space left after the clues (clue numbers need ~28 px each)
	var a := board_rect
	var max_r := _clue_counts.x
	var max_c := _clue_counts.y
	cell = floorf(minf((a.size.x - max_r * 28) / n, (a.size.y - max_c * 28) / n))
	cell = minf(cell, 90.0)
	clue_w = max_r * 28.0 + 8
	clue_h = max_c * 28.0 + 8
	origin = a.position + Vector2(clue_w, clue_h) + (a.size - Vector2(clue_w, clue_h) - Vector2(n, n) * cell) / 2.0


func to_save() -> Dictionary:
	return {"n": n, "target": target, "cells": cells, "hints": hints}


func from_save(d: Dictionary) -> void:
	n = int(d.get("n", 5))
	target = d.get("target", []).map(func(v): return bool(v))
	cells = d.get("cells", []).map(func(v): return int(v))
	hints = int(d.get("hints", 0))
	if target.size() != n * n or cells.size() != n * n:
		new_game()
		return
	_make_clues()
	undo_stack.clear()
	cross_mode = false
	changed_at = {}
	line_flash = {}


func save_info() -> String:
	return "%d of %d filled" % [cells.count(1), target.count(true)]


func play_buttons() -> Array:
	return [
		["Cross mode: ON" if cross_mode else "Cross mode: off", func(): cross_mode = not cross_mode],
		["Undo", _undo],
		["Hint", _hint],
		["New game", start_new],
	]


func _cell_at(p: Vector2) -> int:
	var r := (p - origin) / cell
	if r.x < 0 or r.y < 0 or r.x >= n or r.y >= n:
		return -1
	return int(r.y) * n + int(r.x)


func game_press(p: Vector2) -> void:
	var i := _cell_at(p)
	_paint_start = i
	if i < 0:
		return
	_paint_before = cells.duplicate()
	if cross_mode:
		_paint_value = 0 if cells[i] == 2 else 2
	else:
		_paint_value = 0 if cells[i] == 1 else 1
	cells[i] = _paint_value
	changed_at[i] = t


func game_drag(from: Vector2, to: Vector2) -> void:
	if _paint_start < 0:
		return
	var i := _cell_at(to)
	if i < 0:
		return
	# paint along the row or the column of the starting cell
	var sx := _paint_start % n
	var sy := _paint_start / n
	var x := i % n
	var y := i / n
	if absi(x - sx) >= absi(y - sy):
		y = sy
	else:
		x = sx
	var lo := Vector2i(mini(sx, x), mini(sy, y))
	var hi := Vector2i(maxi(sx, x), maxi(sy, y))
	var was := cells.duplicate()
	cells = _paint_before.duplicate()
	for yy in range(lo.y, hi.y + 1):
		for xx in range(lo.x, hi.x + 1):
			cells[yy * n + xx] = _paint_value
	for k in cells.size():
		if cells[k] != was[k]:
			changed_at[k] = t


## Note which cells just changed, so they can pop.
func _mark_changes(before: Array) -> void:
	if before.size() != cells.size():
		return
	for i in cells.size():
		if cells[i] != before[i]:
			changed_at[i] = t


func game_release(_from: Vector2, _to: Vector2) -> void:
	if _paint_start < 0:
		return
	_paint_start = -1
	if cells != _paint_before:
		undo_stack.append(_paint_before)
		moves += 1
		_check()


func game_long_press(p: Vector2) -> void:
	var i := _cell_at(p)
	if i < 0:
		return
	# the press already filled it: mark it as empty instead
	cells = _paint_before.duplicate() if not _paint_before.is_empty() else cells
	cells[i] = 0 if cells[i] == 2 else 2
	changed_at[i] = t
	if cells != _paint_before:
		undo_stack.append(_paint_before)
		moves += 1
	_paint_start = -1
	_check()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	cells = undo_stack.pop_back()
	save_game()


func _hint() -> void:
	var wrong := []
	for i in n * n:
		if (cells[i] == 1) != target[i]:
			wrong.append(i)
	if wrong.is_empty():
		return
	undo_stack.append(cells.duplicate())
	var i: int = wrong[randi() % wrong.size()]
	cells[i] = 1 if target[i] else 2
	changed_at[i] = t
	hints += 1
	toast("Hint: one cell fixed")
	_check()


func line_done(clue: Array, line: Array) -> bool:
	return clues_of(line.map(func(v): return v == 1)) == clue


func _check() -> void:
	# rows and columns that just became right glow for a moment
	for y in n:
		var key := "r%d" % y
		var ok := line_done(row_clues[y], range(n).map(func(x): return cells[y * n + x]))
		if ok and not line_flash.has(key):
			line_flash[key] = t
		elif not ok:
			line_flash.erase(key)
	for x in n:
		var key := "c%d" % x
		var ok := line_done(col_clues[x], range(n).map(func(y): return cells[y * n + x]))
		if ok and not line_flash.has(key):
			line_flash[key] = t
		elif not ok:
			line_flash.erase(key)
	for y in n:
		if not line_done(row_clues[y], range(n).map(func(x): return cells[y * n + x])):
			save_game()
			return
	for x in n:
		if not line_done(col_clues[x], range(n).map(func(y): return cells[y * n + x])):
			save_game()
			return
	finish(true, maxi(100, (diff + 1) * 800 + n * n * 5 - int(elapsed) - hints * 100))


func game_key(k: int) -> void:
	if k == KEY_X:
		cross_mode = not cross_mode
	elif k == KEY_U:
		_undo()


func draw_game() -> void:
	var board := Rect2(origin, Vector2(n, n) * cell)
	draw_rect(board, Color(0.93, 0.93, 0.97))
	for key in line_flash:
		var k: float = clampf((t - float(line_flash[key])) / 0.6, 0.0, 1.0)
		if k < 1.0:
			var idx := int(key.substr(1))
			var band := Rect2(origin + Vector2(0, idx * cell), Vector2(n * cell, cell)) if key.begins_with("r") else Rect2(origin + Vector2(idx * cell, 0), Vector2(cell, n * cell))
			draw_rect(band, Color(0.5, 0.95, 0.55, 0.6 * (1.0 - k)))
	for i in n * n:
		var r := Rect2(origin + Vector2(i % n, i / n) * cell, Vector2(cell, cell))
		var pk := 1.0
		if changed_at.has(i):
			pk = clampf((t - float(changed_at[i])) / 0.18, 0.0, 1.0)
		if cells[i] == 1:
			var g := r.grow(-2)
			var s := 0.6 + 0.4 * ease_out(pk)
			draw_rect(Rect2(g.get_center() - g.size * s / 2.0, g.size * s), Color(0.18, 0.20, 0.32))
		elif cells[i] == 2:
			var c := r.grow(-cell * (0.3 + 0.15 * (1.0 - pk)))
			draw_line(c.position, c.end, Color(0.75, 0.35, 0.35), 3.0)
			draw_line(Vector2(c.end.x, c.position.y), Vector2(c.position.x, c.end.y), Color(0.75, 0.35, 0.35), 3.0)
	for k in n + 1:
		var w := 3.0 if k % 5 == 0 else 1.0
		draw_line(origin + Vector2(k * cell, 0), origin + Vector2(k * cell, n * cell), Color(0.3, 0.3, 0.4), w)
		draw_line(origin + Vector2(0, k * cell), origin + Vector2(n * cell, k * cell), Color(0.3, 0.3, 0.4), w)
	var fs := 24
	for y in n:
		var done := line_done(row_clues[y], range(n).map(func(x): return cells[y * n + x]))
		var s := " ".join(row_clues[y].map(func(v): return str(v)))
		draw_string(font, Vector2(origin.x - clue_w, origin.y + (y + 0.5) * cell + 9), s, HORIZONTAL_ALIGNMENT_RIGHT, clue_w - 10, fs, DIM if done else INK)
	for x in n:
		var done := line_done(col_clues[x], range(n).map(func(y): return cells[y * n + x]))
		var clue: Array = col_clues[x]
		for k in clue.size():
			var yy := origin.y - (clue.size() - k) * 28.0 + 6
			draw_string(font, Vector2(origin.x + x * cell, yy), str(clue[k]), HORIZONTAL_ALIGNMENT_CENTER, cell, fs, DIM if done else INK)
	draw_stats(["%s   %s" % [DIFF_NAMES[diff], time_text(elapsed)], "Hints %d" % hints])
	if cross_mode:
		text(Vector2(board_rect.position.x, board_rect.end.y + 4), "Cross mode: taps mark empty cells", 20, ACCENT)
