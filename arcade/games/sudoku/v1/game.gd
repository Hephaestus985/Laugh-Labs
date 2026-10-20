extends PuzzleGame
# Sudoku: fill the 9x9 grid so every row, column and 3x3 box has 1 to 9 once.
# Puzzles are generated on the spot and always have exactly one solution.
# Easy: 44 givens, Normal: 34, Hard: 27. Tap a cell, then a number. Notes mode
# writes small pencil marks.

const N := 9
const GIVENS := [44, 34, 27]

var CELL := 64.0
var ORIGIN := Vector2(70, 72)
var PAD_O := Vector2(690, 160)
var PAD_C := 96.0
var last_put := -1
var flash_cells: Array = []  # a row, column or box that was just completed

var solution: Array = []  # 81 ints
var given: Array = []  # 81 bools
var grid: Array = []  # 81 ints, 0 empty
var notes: Array = []  # 81 ints, bit k = note k
var sel := -1
var notes_mode := false
var hints := 0
var undo_stack: Array = []


func _init() -> void:
	game_id = "sudoku"
	title = "Sudoku"
	help = ["Fill the grid: every row, column and 3x3 box holds 1 to 9 once.", "Tap a cell, then a number. Notes writes small pencil marks.", "Red numbers clash with another one. Hints fill in a cell."]


# ---------------------------------------------------------------- puzzle generation

static func _row(i: int) -> int: return i / N
static func _col(i: int) -> int: return i % N
static func _box(i: int) -> int: return (_row(i) / 3) * 3 + _col(i) / 3


## Bitmask of the numbers 1-9 that can still go at cell i.
static func _allowed(g: Array, i: int) -> int:
	var used := 0
	var r := _row(i)
	var c := _col(i)
	for k in N:
		used |= 1 << g[r * N + k]
		used |= 1 << g[k * N + c]
	var br := (r / 3) * 3
	var bc := (c / 3) * 3
	for y in 3:
		for x in 3:
			used |= 1 << g[(br + y) * N + bc + x]
	return ~used & 0x3FE


## Fill the grid (backtracking, most constrained cell first). Counts solutions up to limit.
static func _solve(g: Array, limit: int, rand: bool) -> int:
	var best_i := -1
	var best_mask := 0
	var best_n := 10
	for i in 81:
		if g[i] == 0:
			var m := _allowed(g, i)
			var cnt := 0
			var mm := m
			while mm:
				mm &= mm - 1
				cnt += 1
			if cnt < best_n:
				best_n = cnt
				best_i = i
				best_mask = m
				if cnt <= 1:
					break
	if best_i == -1:
		return 1
	if best_n == 0:
		return 0
	var digits := []
	for d in range(1, 10):
		if best_mask & (1 << d):
			digits.append(d)
	if rand:
		digits.shuffle()
	var found := 0
	for d in digits:
		g[best_i] = d
		found += _solve(g, limit - found, rand)
		if found >= limit:
			if not rand:
				g[best_i] = 0
			return found
	g[best_i] = 0
	return found


func new_game() -> void:
	var full := []
	full.resize(81)
	full.fill(0)
	_solve(full, 1, true)
	solution = full.duplicate()
	var puzzle := full.duplicate()
	var order := range(81)
	order.shuffle()
	var target: int = GIVENS[diff]
	var filled := 81
	var started := Time.get_ticks_msec()
	for i in order:
		if filled <= target or Time.get_ticks_msec() - started > 2500:
			break
		var keep: int = puzzle[i]
		puzzle[i] = 0
		var test := puzzle.duplicate()
		if _solve(test, 2, false) != 1:
			puzzle[i] = keep
		else:
			filled -= 1
	grid = puzzle
	given = puzzle.map(func(v): return v != 0)
	notes = []
	notes.resize(81)
	notes.fill(0)
	sel = -1
	notes_mode = false
	hints = 0
	undo_stack.clear()


func to_save() -> Dictionary:
	return {"solution": solution, "grid": grid, "given": given, "notes": notes, "hints": hints}


func from_save(d: Dictionary) -> void:
	solution = d.get("solution", []).map(func(v): return int(v))
	grid = d.get("grid", []).map(func(v): return int(v))
	given = d.get("given", []).map(func(v): return bool(v))
	notes = d.get("notes", []).map(func(v): return int(v))
	hints = int(d.get("hints", 0))
	if solution.size() != 81 or grid.size() != 81 or given.size() != 81 or notes.size() != 81:
		new_game()
	sel = -1
	undo_stack.clear()


func save_info() -> String:
	return "%d of 81 filled" % grid.filter(func(v): return v != 0).size()


func play_buttons() -> Array:
	return [
		["Notes: ON" if notes_mode else "Notes: off", func(): notes_mode = not notes_mode],
		["Erase", _erase],
		["Hint", _hint],
		["Undo", _undo],
		["New game", start_new],
	]


# ---------------------------------------------------------------- layout

func layout() -> void:
	if portrait:
		CELL = floorf(minf(board_rect.size.x / 9.0, (board_rect.size.y - 20) / 10.2))
		ORIGIN = Vector2(board_rect.position.x + (board_rect.size.x - 9 * CELL) / 2.0, board_rect.position.y)
		PAD_C = CELL
		PAD_O = ORIGIN + Vector2(0, 9 * CELL + 16)
	else:
		CELL = 64.0
		ORIGIN = Vector2(70, 72)
		PAD_C = 96.0
		PAD_O = Vector2(690, 160)


## The number pad: 3x3 beside the board, or one row of 9 under it in portrait.
func pad_rect(d: int) -> Rect2:
	if portrait:
		return Rect2(PAD_O + Vector2((d - 1) * PAD_C, 0), Vector2(PAD_C - 6, PAD_C - 6))
	return Rect2(PAD_O + Vector2(((d - 1) % 3) * PAD_C, ((d - 1) / 3) * PAD_C), Vector2(PAD_C - 8, PAD_C - 8))


# ---------------------------------------------------------------- playing

func _push_undo() -> void:
	undo_stack.append([grid.duplicate(), notes.duplicate()])
	if undo_stack.size() > 200:
		undo_stack.pop_front()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	var u: Array = undo_stack.pop_back()
	grid = u[0]
	notes = u[1]
	save_game()


func put(d: int) -> void:
	if sel < 0 or given[sel]:
		toast("Tap an empty cell first" if sel < 0 else "That number is part of the puzzle")
		return
	_push_undo()
	if notes_mode:
		if grid[sel] == 0:
			notes[sel] ^= 1 << d
	else:
		grid[sel] = 0 if grid[sel] == d else d
		notes[sel] = 0
		if grid[sel] != 0:
			_clear_notes_around(sel, d)
			last_put = sel
			start_anim("put", 0.25)
			_flash_done_units(sel)
		moves += 1
	_check_done()


func _clear_notes_around(i: int, d: int) -> void:
	for j in 81:
		if _row(j) == _row(i) or _col(j) == _col(i) or _box(j) == _box(i):
			notes[j] &= ~(1 << d)


## Light up a row, column or box that this number just completed (correctly).
func _flash_done_units(i: int) -> void:
	flash_cells = []
	for unit in [range(81).filter(func(j): return _row(j) == _row(i)), range(81).filter(func(j): return _col(j) == _col(i)), range(81).filter(func(j): return _box(j) == _box(i))]:
		var ok := true
		for j in unit:
			if grid[j] == 0 or _clashes(j):
				ok = false
				break
		if ok:
			flash_cells.append_array(unit)
	if not flash_cells.is_empty():
		start_anim("flash", 0.7)


func _erase() -> void:
	if sel < 0 or given[sel]:
		return
	_push_undo()
	grid[sel] = 0
	notes[sel] = 0
	save_game()


func _hint() -> void:
	var target := sel
	if target < 0 or given[target] or grid[target] == solution[target]:
		target = -1
		for i in 81:
			if grid[i] != solution[i]:
				target = i
				break
	if target < 0:
		return
	_push_undo()
	grid[target] = solution[target]
	notes[target] = 0
	_clear_notes_around(target, solution[target])
	sel = target
	last_put = target
	start_anim("put", 0.25)
	_flash_done_units(target)
	hints += 1
	toast("Hint: a %d goes here" % solution[target])
	_check_done()


func _check_done() -> void:
	if grid == solution:
		var pts := maxi(100, (diff + 1) * 1500 - int(elapsed) - hints * 150)
		finish(true, pts)
	else:
		save_game()


func _clashes(i: int) -> bool:
	var v: int = grid[i]
	if v == 0:
		return false
	for j in 81:
		if j != i and grid[j] == v and (_row(j) == _row(i) or _col(j) == _col(i) or _box(j) == _box(i)):
			return true
	return false


func game_tap(p: Vector2) -> void:
	var rel := (p - ORIGIN) / CELL
	if rel.x >= 0 and rel.y >= 0 and rel.x < 9 and rel.y < 9:
		sel = int(rel.y) * N + int(rel.x)
		return
	for d in range(1, 10):
		if pad_rect(d).grow(4).has_point(p):
			put(d)
			return


func game_key(k: int) -> void:
	if k >= KEY_1 and k <= KEY_9:
		put(k - KEY_0)
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		put(k - KEY_KP_0)
	elif k in [KEY_BACKSPACE, KEY_DELETE, KEY_0]:
		_erase()
	elif k == KEY_N:
		notes_mode = not notes_mode
	elif k == KEY_H:
		_hint()
	elif k == KEY_U:
		_undo()
	elif k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if sel < 0:
			sel = 40
		else:
			var r := _row(sel)
			var c := _col(sel)
			if k == KEY_LEFT: c = (c + 8) % 9
			elif k == KEY_RIGHT: c = (c + 1) % 9
			elif k == KEY_UP: r = (r + 8) % 9
			else: r = (r + 1) % 9
			sel = r * N + c


# ---------------------------------------------------------------- drawing

func draw_game() -> void:
	var sel_v: int = grid[sel] if sel >= 0 else 0
	for i in 81:
		var r := Rect2(ORIGIN + Vector2(_col(i), _row(i)) * CELL, Vector2(CELL, CELL))
		var bg := Color(0.93, 0.93, 0.97)
		if sel >= 0 and (_row(i) == _row(sel) or _col(i) == _col(sel) or _box(i) == _box(sel)):
			bg = Color(0.84, 0.87, 0.96)
		if sel_v != 0 and grid[i] == sel_v:
			bg = Color(0.75, 0.82, 0.98)
		if i == sel:
			bg = Color(1.0, 0.85, 0.5)
		if flash_cells.has(i) and animating("flash"):
			bg = bg.lerp(Color(0.55, 0.95, 0.6), 1.0 - anim("flash"))
		draw_rect(r, bg)
		draw_rect(r, Color(0.6, 0.6, 0.7), false, 1.0)
		var v: int = grid[i]
		if v != 0:
			var col := Color(0.12, 0.12, 0.2) if given[i] else Color(0.15, 0.35, 0.85)
			if _clashes(i):
				col = Color(0.85, 0.15, 0.2)
			var fs := int(CELL * 0.62 * (pop(anim("put")) if i == last_put and animating("put") else 1.0))
			draw_string(font, Vector2(r.position.x, r.position.y + CELL * 0.5 + fs * 0.36), str(v), HORIZONTAL_ALIGNMENT_CENTER, CELL, fs, col)
		elif notes[i]:
			for d in range(1, 10):
				if notes[i] & (1 << d):
					var np := r.position + Vector2(((d - 1) % 3) * CELL / 3.0, ((d - 1) / 3) * CELL / 3.0 + CELL * 0.28)
					draw_string(font, np, str(d), HORIZONTAL_ALIGNMENT_CENTER, CELL / 3.0, int(CELL * 0.25), Color(0.35, 0.35, 0.45))
	for k in 4:
		draw_line(ORIGIN + Vector2(k * 3 * CELL, 0), ORIGIN + Vector2(k * 3 * CELL, 9 * CELL), Color(0.1, 0.1, 0.15), 3.0)
		draw_line(ORIGIN + Vector2(0, k * 3 * CELL), ORIGIN + Vector2(9 * CELL, k * 3 * CELL), Color(0.1, 0.1, 0.15), 3.0)
	# number pad
	for d in range(1, 10):
		var pr := pad_rect(d)
		var left := 9 - grid.filter(func(v): return v == d).size()
		draw_rect(pr, Color(0.22, 0.25, 0.38) if left > 0 else Color(0.16, 0.17, 0.24))
		draw_rect(pr, Color(1, 1, 1, 0.3), false, 2.0)
		draw_string(font, Vector2(pr.position.x, pr.get_center().y + pr.size.y * 0.2), str(d), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(pr.size.y * 0.55), ACCENT if notes_mode else INK)
	var hint_y := (PAD_O.y + PAD_C + 26) if portrait else (PAD_O.y + 3 * PAD_C + 30)
	draw_string(font, Vector2(PAD_O.x, hint_y), "Notes mode" if notes_mode else "Tap a cell, then a number", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, DIM)
	draw_stats(["%s   %s" % [DIFF_NAMES[diff], time_text(elapsed)], "Hints %d" % hints])
