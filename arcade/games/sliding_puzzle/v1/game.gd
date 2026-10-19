extends PuzzleGame
# The 15 puzzle: slide the tiles into the gap until they read 1, 2, 3... in order.
# Shuffled by making random legal moves from the solved board, so it can always
# be solved. Easy 3x3, Normal 4x4, Hard 5x5.

const AREA := Rect2(170, 70, 640, 630)

var n := 4
var tiles: Array = []  # n*n ints, 0 = the gap
var cell := 150.0
var origin := Vector2.ZERO
var undo_stack: Array = []


func _init() -> void:
	game_id = "sliding_puzzle"
	title = "Sliding Puzzle"
	help = ["Slide the tiles back into order: 1, 2, 3... with the gap at the end.", "Tap a tile in the gap's row or column to slide it (and the ones between).", "Or swipe towards the gap."]


func new_game() -> void:
	n = [3, 4, 5][diff]
	_fit()
	tiles = []
	for i in n * n - 1:
		tiles.append(i + 1)
	tiles.append(0)
	var last := -1
	for k in n * n * 30:
		var g := tiles.find(0)
		var opts := _neighbours(g).filter(func(j): return j != last)
		var j: int = opts[randi() % opts.size()]
		tiles[g] = tiles[j]
		tiles[j] = 0
		last = g
	if _solved():
		new_game()
	undo_stack.clear()


func _fit() -> void:
	cell = floorf(minf(AREA.size.x, AREA.size.y) / n)
	origin = AREA.position + (AREA.size - Vector2(n, n) * cell) / 2.0


func _neighbours(i: int) -> Array:
	var out := []
	var x := i % n
	var y := i / n
	if x > 0: out.append(i - 1)
	if x < n - 1: out.append(i + 1)
	if y > 0: out.append(i - n)
	if y < n - 1: out.append(i + n)
	return out


func _solved() -> bool:
	for i in n * n - 1:
		if tiles[i] != i + 1:
			return false
	return true


func to_save() -> Dictionary:
	return {"n": n, "tiles": tiles}


func from_save(d: Dictionary) -> void:
	n = int(d.get("n", 4))
	tiles = d.get("tiles", []).map(func(v): return int(v))
	if tiles.size() != n * n or not tiles.has(0):
		new_game()
		return
	_fit()
	undo_stack.clear()


func save_info() -> String:
	var ok := 0
	for i in n * n - 1:
		if tiles[i] == i + 1:
			ok += 1
	return "%d of %d tiles in place" % [ok, n * n - 1]


func play_buttons() -> Array:
	return [["Undo", _undo], ["New game", start_new]]


## Slide the tile at i (and the tiles between it and the gap) into the gap.
func slide(i: int) -> bool:
	var g := tiles.find(0)
	if i < 0 or i == g:
		return false
	var gx := g % n
	var gy := g / n
	var x := i % n
	var y := i / n
	if x != gx and y != gy:
		return false
	undo_stack.append(tiles.duplicate())
	var step := (1 if x > gx else -1) if y == gy else (n if y > gy else -n)
	var cur := g
	while cur != i:
		tiles[cur] = tiles[cur + step]
		cur += step
	tiles[i] = 0
	moves += 1
	if _solved():
		finish(true, maxi(100, (diff + 1) * 900 - moves * 2 - int(elapsed)))
	else:
		save_game()
	return true


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	tiles = undo_stack.pop_back()
	save_game()


func game_tap(p: Vector2) -> void:
	var r := (p - origin) / cell
	if r.x < 0 or r.y < 0 or r.x >= n or r.y >= n:
		return
	slide(int(r.y) * n + int(r.x))


## A swipe moves the tile next to the gap in the swipe's direction into it.
func game_swipe(dir: Vector2i) -> void:
	var g := tiles.find(0)
	var x := g % n - dir.x
	var y := g / n - dir.y
	if x >= 0 and y >= 0 and x < n and y < n:
		slide(y * n + x)


func game_key(k: int) -> void:
	match k:
		KEY_LEFT, KEY_A: game_swipe(Vector2i.LEFT)
		KEY_RIGHT, KEY_D: game_swipe(Vector2i.RIGHT)
		KEY_UP, KEY_W: game_swipe(Vector2i.UP)
		KEY_DOWN, KEY_S: game_swipe(Vector2i.DOWN)
		KEY_U: _undo()


func draw_game() -> void:
	draw_rect(Rect2(origin, Vector2(n, n) * cell).grow(8), Color(0.14, 0.15, 0.23))
	for i in n * n:
		var v: int = tiles[i]
		if v == 0:
			continue
		var r := Rect2(origin + Vector2(i % n, i / n) * cell, Vector2(cell, cell)).grow(-5)
		var home := v == i + 1
		var hue := float((v - 1) / n) / n
		draw_rect(r, Color.from_hsv(0.58 + hue * 0.35, 0.45, 0.85 if home else 0.65))
		draw_rect(r, Color(1, 1, 1, 0.3), false, 2.0)
		draw_string(font, Vector2(r.position.x, r.get_center().y + cell * 0.15), str(v), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(cell * 0.42), Color.WHITE)
	draw_stats(["Moves %d   %s" % [moves, time_text(elapsed)], DIFF_NAMES[diff]])
