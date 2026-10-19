extends PuzzleGame
# 2048: swipe to slide every tile; equal tiles merge. Reach 2048 (and keep going).
# Easy: 5x5 board, unlimited undo. Normal: 4x4, 3 undos. Hard: 4x4, no undo, more 4s.

var n := 4
var cells: Array = []  # n*n ints, 0 = empty
var undo_stack: Array = []  # [cells, score]
var undos_left := 3
var reached := false


func _init() -> void:
	game_id = "game_2048"
	title = "2048"
	help = ["Swipe (or use the arrow keys) to slide all tiles.", "Two equal tiles merge into one: 2+2 = 4, 4+4 = 8...", "Make a 2048 tile, then keep going for a high score."]


func new_game() -> void:
	n = 5 if diff == 0 else 4
	undos_left = [9999, 3, 0][diff]
	cells = []
	cells.resize(n * n)
	cells.fill(0)
	undo_stack.clear()
	reached = false
	_spawn()
	_spawn()


func to_save() -> Dictionary:
	return {"n": n, "cells": cells, "undos": undos_left, "reached": reached}


func from_save(d: Dictionary) -> void:
	n = int(d.get("n", 4))
	cells = []
	for v in d.get("cells", []):
		cells.append(int(v))
	if cells.size() != n * n:
		new_game()
		return
	undos_left = int(d.get("undos", 0))
	reached = bool(d.get("reached", false))
	undo_stack.clear()


func save_info() -> String:
	return "score %d" % score


func play_buttons() -> Array:
	var b := []
	if undos_left > 0:
		b.append(["Undo" if undos_left > 99 else "Undo (%d)" % undos_left, _undo])
	b.append(["New game", start_new])
	return b


func _spawn() -> void:
	var empty := []
	for i in cells.size():
		if cells[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return
	var four_chance: float = [0.1, 0.1, 0.25][diff]
	cells[empty[randi() % empty.size()]] = 4 if randf() < four_chance else 2


func _idx(x: int, y: int) -> int:
	return y * n + x


## Slide one line towards its start. Returns [new_line, points].
func _slide(line: Array) -> Array:
	var vals := line.filter(func(v): return v != 0)
	var out := []
	var pts := 0
	var i := 0
	while i < vals.size():
		if i + 1 < vals.size() and vals[i] == vals[i + 1]:
			out.append(vals[i] * 2)
			pts += vals[i] * 2
			i += 2
		else:
			out.append(vals[i])
			i += 1
	while out.size() < n:
		out.append(0)
	return [out, pts]


func move(dir: Vector2i) -> bool:
	var before := cells.duplicate()
	var gained := 0
	for a in n:
		var idxs := []
		for b in n:
			# walk from the side the tiles slide towards
			var x: int
			var y: int
			if dir == Vector2i.LEFT:
				x = b; y = a
			elif dir == Vector2i.RIGHT:
				x = n - 1 - b; y = a
			elif dir == Vector2i.UP:
				x = a; y = b
			else:
				x = a; y = n - 1 - b
			idxs.append(_idx(x, y))
		var line := idxs.map(func(i): return cells[i])
		var r := _slide(line)
		for k in n:
			cells[idxs[k]] = r[0][k]
		gained += r[1]
	if cells == before:
		return false
	undo_stack.append([before, score])
	if undo_stack.size() > 20:
		undo_stack.pop_front()
	score += gained
	moves += 1
	_spawn()
	if not reached and cells.max() >= 2048:
		reached = true
		toast("2048! Keep going for a higher score")
	if not _can_move():
		finish(reached, score)
	else:
		save_game()
	return true


func _can_move() -> bool:
	for y in n:
		for x in n:
			var v: int = cells[_idx(x, y)]
			if v == 0:
				return true
			if x + 1 < n and cells[_idx(x + 1, y)] == v:
				return true
			if y + 1 < n and cells[_idx(x, y + 1)] == v:
				return true
	return false


func _undo() -> void:
	if undo_stack.is_empty() or undos_left <= 0:
		toast("Nothing to undo")
		return
	var last: Array = undo_stack.pop_back()
	cells = last[0]
	score = last[1]
	undos_left -= 1
	save_game()


func game_swipe(dir: Vector2i) -> void:
	move(dir)


func game_key(k: int) -> void:
	match k:
		KEY_LEFT, KEY_A: move(Vector2i.LEFT)
		KEY_RIGHT, KEY_D: move(Vector2i.RIGHT)
		KEY_UP, KEY_W: move(Vector2i.UP)
		KEY_DOWN, KEY_S: move(Vector2i.DOWN)
		KEY_U, KEY_Z: _undo()


func _tile_color(v: int) -> Color:
	if v == 0:
		return Color(0.20, 0.22, 0.32)
	var k := int(log(v) / log(2.0))
	var hues := [0.10, 0.08, 0.05, 0.02, 0.98, 0.93, 0.85, 0.75, 0.6, 0.5, 0.42, 0.33]
	return Color.from_hsv(hues[(k - 1) % hues.size()], 0.55 + 0.03 * mini(k, 10), 0.95 - 0.02 * mini(k, 10))


func draw_game() -> void:
	var size := 600.0
	var o := Vector2((PANEL_X - size) / 2.0 + 40, 80)
	var gap := 10.0
	var c := (size - gap * (n + 1)) / n
	draw_rect(Rect2(o, Vector2(size, size)), Color(0.14, 0.15, 0.23))
	for y in n:
		for x in n:
			var v: int = cells[_idx(x, y)]
			var r := Rect2(o + Vector2(gap + x * (c + gap), gap + y * (c + gap)), Vector2(c, c))
			draw_rect(r, _tile_color(v))
			if v > 0:
				var fs := int(c * (0.42 if v < 100 else (0.34 if v < 1000 else 0.27)))
				draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), str(v), HORIZONTAL_ALIGNMENT_CENTER, c, fs, Color(0.1, 0.1, 0.15) if v < 8 else Color.WHITE)
	draw_stats(["Score %d" % score, "Best %d" % maxi(best, score)])
	text(Vector2(o.x, H - 20), "Swipe to slide the tiles", 22, DIM)
