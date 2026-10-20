extends PuzzleGame
# 2048: swipe to slide every tile; equal tiles merge. Reach 2048 (and keep going).
# Easy: 5x5 board, unlimited undo. Normal: 4x4, 3 undos. Hard: 4x4, no undo, more 4s.

var n := 4
var cells: Array = []  # n*n ints, 0 = empty
var undo_stack: Array = []  # [cells, score]
var undos_left := 3
var reached := false
# animation of the last move: tiles sliding [value, from, to], merged and new cells
var slides: Array = []
var merged: Array = []
var spawned := -1
var bsize := 600.0
var borigin := Vector2.ZERO


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
	slides = []
	merged = []


func layout() -> void:
	bsize = minf(minf(board_rect.size.x, board_rect.size.y), 640.0)
	borigin = board_rect.position + (board_rect.size - Vector2(bsize, bsize)) / 2.0


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
	spawned = empty[randi() % empty.size()]
	cells[spawned] = 4 if randf() < four_chance else 2


func _idx(x: int, y: int) -> int:
	return y * n + x


## Slide one line towards its start. Returns [new_line, points, sources] where
## sources[k] lists the line positions whose tiles ended up at position k.
func _slide(line: Array) -> Array:
	var vals := []
	var where := []
	for k in line.size():
		if line[k] != 0:
			vals.append(line[k])
			where.append(k)
	var out := []
	var src := []
	var pts := 0
	var i := 0
	while i < vals.size():
		if i + 1 < vals.size() and vals[i] == vals[i + 1]:
			out.append(vals[i] * 2)
			src.append([where[i], where[i + 1]])
			pts += vals[i] * 2
			i += 2
		else:
			out.append(vals[i])
			src.append([where[i]])
			i += 1
	while out.size() < n:
		out.append(0)
		src.append([])
	return [out, pts, src]


func move(dir: Vector2i) -> bool:
	var before := cells.duplicate()
	var gained := 0
	var new_slides := []
	var new_merged := []
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
			for s in r[2][k]:
				new_slides.append([line[s], idxs[s], idxs[k]])
			if r[2][k].size() == 2:
				new_merged.append(idxs[k])
		gained += r[1]
	if cells == before:
		return false
	slides = new_slides
	merged = new_merged
	start_anim("move", 0.24)
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
	slides = []
	merged = []
	spawned = -1
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


func _cell_rect(i: int, gap: float, c: float) -> Rect2:
	return Rect2(borigin + Vector2(gap + (i % n) * (c + gap), gap + (i / n) * (c + gap)), Vector2(c, c))


func _draw_tile(r: Rect2, v: int, scale := 1.0) -> void:
	if scale != 1.0:
		r = Rect2(r.get_center() - r.size * scale / 2.0, r.size * scale)
	draw_rect(r, _tile_color(v))
	var c := r.size.x
	var fs := int(c * (0.42 if v < 100 else (0.34 if v < 1000 else 0.27)))
	draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), str(v), HORIZONTAL_ALIGNMENT_CENTER, c, fs, Color(0.1, 0.1, 0.15) if v < 8 else Color.WHITE)


func draw_game() -> void:
	var gap := 10.0
	var c := (bsize - gap * (n + 1)) / n
	draw_rect(Rect2(borigin, Vector2(bsize, bsize)), Color(0.14, 0.15, 0.23))
	for i in n * n:
		draw_rect(_cell_rect(i, gap, c), _tile_color(0))
	var a := anim("move")
	var slide_part := 0.45
	if a < slide_part and not slides.is_empty():
		# phase 1: tiles glide to where they are going
		var k := ease_out(a / slide_part)
		for s in slides:
			var r0 := _cell_rect(s[1], gap, c)
			var r1 := _cell_rect(s[2], gap, c)
			_draw_tile(Rect2(r0.position.lerp(r1.position, k), r0.size), s[0])
	else:
		# phase 2: merged tiles pop, the new tile grows in
		var k := (a - slide_part) / (1.0 - slide_part) if a < 1.0 else 1.0
		for i in n * n:
			var v: int = cells[i]
			if v == 0:
				continue
			var sc := 1.0
			if i == spawned and a < 1.0:
				sc = ease_out(k)
			elif merged.has(i):
				sc = pop(k)
			if sc > 0.01:
				_draw_tile(_cell_rect(i, gap, c), v, sc)
	draw_stats(["Score %d" % score, "Best %d" % maxi(best, score)])
	if not portrait:
		text(Vector2(borigin.x, sh - 6), "Swipe to slide the tiles", 22, DIM)
