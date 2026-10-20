extends PuzzleGame
# Block Stacker: falling blocks. Slide and turn each piece so it completes whole
# rows; full rows disappear. Every 10 rows the pieces fall faster.
# Clear the target number of rows to win (Easy 20, Normal 40, Hard 60) and keep
# going for a higher score. Phone: drag sideways to slide, tap to turn, swipe
# down to drop. Buttons on the right do the same.

const COLS := 10
const ROWS := 20
var CELL := 32.0
var ORIGIN := Vector2(330, 40)
var cleared_rows: Array = []  # rows that just vanished, for the flash
var trail: Array = []  # hard drop: [x columns, from y, to y]
const SHAPES := {
	"I": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
	"O": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"T": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"S": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
	"Z": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	"J": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
	"L": [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}
const COLORS := {
	"I": Color(0.2, 0.85, 0.9), "O": Color(0.95, 0.85, 0.2), "T": Color(0.7, 0.3, 0.9),
	"S": Color(0.3, 0.85, 0.3), "Z": Color(0.9, 0.25, 0.25), "J": Color(0.25, 0.4, 0.95), "L": Color(0.95, 0.55, 0.15),
}

var grid: Array = []  # COLS*ROWS strings ("" = empty, else the shape letter)
var piece := "T"
var cells: Array = []  # the falling piece's blocks, relative to pos
var pos := Vector2i(3, 0)
var next_piece := "I"
var bag: Array = []
var lines := 0
var level := 1
var target := 40
var fall_t := 0.0
var flash := 0.0
var _drag_cols := 0
var _dropped_this_drag := false


func _init() -> void:
	game_id = "block_stacker"
	title = "Block Stacker"
	help = ["Slide and turn the falling blocks to fill whole rows; full rows vanish.", "Phone: drag sideways to slide, tap to turn, swipe down to drop.", "Clear the target rows to win, then keep going for a high score."]


func new_game() -> void:
	grid = []
	grid.resize(COLS * ROWS)
	grid.fill("")
	bag = []
	lines = 0
	level = 1
	target = [20, 40, 60][diff]
	next_piece = _take()
	_spawn()


func _take() -> String:
	if bag.is_empty():
		bag = SHAPES.keys()
		bag.shuffle()
	return bag.pop_back()


func _spawn() -> void:
	piece = next_piece
	next_piece = _take()
	cells = SHAPES[piece].duplicate()
	pos = Vector2i(3, 0)
	fall_t = 0.0
	if not _fits(cells, pos):
		finish(lines >= target, score)


func _fits(cs: Array, p: Vector2i) -> bool:
	for c in cs:
		var x: int = c.x + p.x
		var y: int = c.y + p.y
		if x < 0 or x >= COLS or y >= ROWS:
			return false
		if y >= 0 and grid[y * COLS + x] != "":
			return false
	return true


func layout() -> void:
	if portrait:
		CELL = floorf(minf(board_rect.size.x * 0.7 / COLS, board_rect.size.y / ROWS))
		ORIGIN = Vector2(board_rect.position.x, board_rect.position.y + (board_rect.size.y - ROWS * CELL) / 2.0)
	else:
		CELL = 32.0
		ORIGIN = Vector2(330, 40)


func fall_interval() -> float:
	var base: float = [0.85, 0.65, 0.45][diff]
	return maxf(0.06, base * pow(0.85, level - 1))


func shift(dx: int) -> bool:
	if _fits(cells, pos + Vector2i(dx, 0)):
		pos.x += dx
		return true
	return false


func rotate_piece() -> void:
	if piece == "O":
		return
	var size := 4 if piece == "I" else 3
	var turned := cells.map(func(c): return Vector2i(size - 1 - c.y, c.x))
	for kick in [0, -1, 1, -2, 2]:
		if _fits(turned, pos + Vector2i(kick, 0)):
			cells = turned
			pos.x += kick
			return


func soft_drop() -> bool:
	if _fits(cells, pos + Vector2i(0, 1)):
		pos.y += 1
		return true
	_lock()
	return false


func hard_drop() -> void:
	var dropped := 0
	var from_y := pos.y
	while _fits(cells, pos + Vector2i(0, 1)):
		pos.y += 1
		dropped += 1
	if dropped > 0:
		trail = [cells.map(func(c): return c.x + pos.x), from_y, pos.y, cells.duplicate()]
		start_anim("trail", 0.2)
	score += dropped * 2
	_lock()


func _lock() -> void:
	for c in cells:
		var y: int = c.y + pos.y
		if y < 0:
			finish(lines >= target, score)
			return
		grid[y * COLS + c.x + pos.x] = piece
	var cleared := 0
	var gone := []
	var y := ROWS - 1
	while y >= 0:
		var full := true
		for x in COLS:
			if grid[y * COLS + x] == "":
				full = false
				break
		if full:
			gone.append(y + cleared)  # where it was before the rows above it moved
			cleared += 1
			for yy in range(y, 0, -1):
				for x in COLS:
					grid[yy * COLS + x] = grid[(yy - 1) * COLS + x]
			for x in COLS:
				grid[x] = ""
		else:
			y -= 1
	if cleared > 0:
		score += [0, 100, 300, 500, 800][cleared] * level
		var was := lines
		lines += cleared
		level = 1 + lines / 10
		flash = 0.25
		cleared_rows = gone
		start_anim("clear", 0.35)
		if was < target and lines >= target:
			toast("Target reached! Keep going for a high score")
	moves += 1
	_spawn()
	if state == 1:
		save_game()


func to_save() -> Dictionary:
	return {"grid": grid, "piece": piece, "next": next_piece, "lines": lines, "level": level, "target": target}


func from_save(d: Dictionary) -> void:
	grid = d.get("grid", []).map(func(v): return str(v))
	lines = int(d.get("lines", 0))
	level = int(d.get("level", 1))
	target = int(d.get("target", 40))
	next_piece = str(d.get("next", "I"))
	if grid.size() != COLS * ROWS or not SHAPES.has(next_piece):
		new_game()
		return
	bag = []
	var p := str(d.get("piece", "T"))
	piece = p if SHAPES.has(p) else "T"
	cells = SHAPES[piece].duplicate()
	pos = Vector2i(3, 0)
	if not _fits(cells, pos):
		new_game()


func save_info() -> String:
	return "%d rows, score %d" % [lines, score]


func play_buttons() -> Array:
	return [["< Left", func(): shift(-1)], ["Right >", func(): shift(1)], ["Turn", rotate_piece], ["Drop", hard_drop]]


func game_update(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	fall_t += delta
	if fall_t >= fall_interval():
		fall_t = 0.0
		soft_drop()


func game_press(_p: Vector2) -> void:
	_drag_cols = 0
	_dropped_this_drag = false


func game_drag(from: Vector2, to: Vector2) -> void:
	if _dropped_this_drag or state != 1:
		return
	var d := to - from
	if d.y > 110 and absf(d.y) > absf(d.x) * 1.5:
		_dropped_this_drag = true
		hard_drop()
		return
	var want := int(d.x / 42.0)
	while _drag_cols < want:
		_drag_cols += 1
		shift(1)
	while _drag_cols > want:
		_drag_cols -= 1
		shift(-1)


func game_tap(_p: Vector2) -> void:
	rotate_piece()


func game_key(k: int) -> void:
	match k:
		KEY_LEFT, KEY_A: shift(-1)
		KEY_RIGHT, KEY_D: shift(1)
		KEY_UP, KEY_W, KEY_X: rotate_piece()
		KEY_DOWN, KEY_S: soft_drop()
		KEY_SPACE: hard_drop()


func _draw_block(p: Vector2, col: Color, size := -1.0) -> void:
	if size < 0.0:
		size = CELL
	var r := Rect2(p, Vector2(size, size)).grow(-1)
	draw_rect(r, col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(1, 1, 1, 0.3))
	draw_rect(r, Color(0, 0, 0, 0.35), false, 1.0)


func draw_game() -> void:
	var well := Rect2(ORIGIN, Vector2(COLS, ROWS) * CELL)
	draw_rect(well.grow(4), Color(0.4, 0.42, 0.55))
	draw_rect(well, Color(0.04, 0.05, 0.09) if flash <= 0.0 else Color(0.25, 0.25, 0.35))
	for i in grid.size():
		if grid[i] != "":
			_draw_block(ORIGIN + Vector2(i % COLS, i / COLS) * CELL, COLORS[grid[i]])
	if animating("clear"):
		var k := anim("clear")
		for row in cleared_rows:
			draw_rect(Rect2(ORIGIN + Vector2(0, row * CELL), Vector2(COLS * CELL, CELL)), Color(1, 1, 1, 0.8 * (1.0 - k)))
	if animating("trail") and trail.size() == 4:
		var k := anim("trail")
		var cs: Array = trail[3]
		for c in cs:
			var x: float = ORIGIN.x + (c.x + trail[0][0] - cs[0].x) * CELL
			var y0: float = ORIGIN.y + (c.y + trail[1]) * CELL
			var y1: float = ORIGIN.y + (c.y + trail[2]) * CELL
			draw_rect(Rect2(x + 4, y0, CELL - 8, y1 - y0), Color(1, 1, 1, 0.18 * (1.0 - k)))
	if state == 1:
		# where it would land
		var ghost := pos
		while _fits(cells, ghost + Vector2i(0, 1)):
			ghost.y += 1
		for c in cells:
			if c.y + ghost.y >= 0:
				draw_rect(Rect2(ORIGIN + Vector2(c.x + ghost.x, c.y + ghost.y) * CELL, Vector2(CELL, CELL)).grow(-3), Color(1, 1, 1, 0.15), false, 2.0)
		for c in cells:
			if c.y + pos.y >= 0:
				_draw_block(ORIGIN + Vector2(c.x + pos.x, c.y + pos.y) * CELL, COLORS[piece])
	# next piece
	var side := ORIGIN + Vector2(COLS * CELL + (24 if portrait else 70), 50)
	draw_string(font, side, "Next", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, DIM)
	var ns := 26.0 if portrait else 28.0
	for c in SHAPES[next_piece]:
		_draw_block(side + Vector2(10, 20) + Vector2(c.x, c.y) * ns, COLORS[next_piece], ns)
	draw_string(font, side + Vector2(0, 150), "Rows %d/%d" % [lines, target], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	draw_string(font, side + Vector2(0, 185), "Level %d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	draw_stats(["Score %d" % score, "Best %d" % maxi(best, score)])
	if not portrait:
		text(Vector2(40, sh - 20), "drag: slide   tap: turn   swipe down: drop", 18, DIM)
