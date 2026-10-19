extends PuzzleGame
# Flow: connect each pair of same-coloured dots with a pipe. Pipes can't cross,
# and when you're done every square is filled. Puzzles are made by cutting the
# board into random snake-shaped paths, so a full solution always exists (yours
# may differ from it: any one that connects every pair and fills the board wins).
# Easy 5x5, Normal 7x7, Hard 9x9.

const AREA := Rect2(60, 70, 900, 630)
const PALETTE := [
	Color(0.92, 0.20, 0.20), Color(0.20, 0.45, 0.95), Color(0.15, 0.70, 0.25), Color(0.98, 0.85, 0.15),
	Color(0.95, 0.55, 0.10), Color(0.15, 0.80, 0.85), Color(0.85, 0.25, 0.85), Color(0.60, 0.35, 0.15),
	Color(0.95, 0.60, 0.70), Color(0.55, 0.85, 0.30), Color(0.50, 0.50, 0.95), Color(0.95, 0.95, 0.95),
]

var n := 5
var dots: Array = []  # per colour [cell_a, cell_b]
var solution: Array = []  # per colour: list of cells from a to b
var paths: Array = []  # per colour: the player's pipe, a list of cells starting at a dot
var cell := 100.0
var origin := Vector2.ZERO
var drawing := -1  # colour being drawn
var hints := 0
var undo_stack: Array = []


func _init() -> void:
	game_id = "flow"
	title = "Flow"
	help = ["Drag from a dot to draw a pipe to the other dot of the same colour.", "Pipes can't cross. Fill every square to finish.", "Drag back over a pipe to shorten it. Hint draws one pipe for you."]


func new_game() -> void:
	n = [5, 7, 9][diff]
	var want_min: int = [4, 6, 8][diff]
	var want_max: int = [6, 9, 12][diff]
	for attempt in 300:
		var sol := _carve()
		if sol.size() >= want_min and sol.size() <= want_max:
			solution = sol
			break
	dots = solution.map(func(p): return [p[0], p[p.size() - 1]])
	paths = []
	for k in solution.size():
		paths.append([])
	drawing = -1
	hints = 0
	undo_stack.clear()
	_fit()


func _fit() -> void:
	cell = floorf(minf(AREA.size.x, AREA.size.y) / n)
	origin = AREA.position + (AREA.size - Vector2(n, n) * cell) / 2.0


func _nb(i: int) -> Array:
	var out := []
	var x := i % n
	var y := i / n
	if x > 0: out.append(i - 1)
	if x < n - 1: out.append(i + 1)
	if y > 0: out.append(i - n)
	if y < n - 1: out.append(i + n)
	return out


## Cut the board into snake paths of 3+ cells that cover every square. [] on failure.
func _carve() -> Array:
	var owner := []
	owner.resize(n * n)
	owner.fill(-1)
	var result := []
	var max_len := n + 3
	while owner.has(-1):
		# start where it's tightest: an empty cell with the fewest empty neighbours
		var start := -1
		var fewest := 9
		var empties := []
		for i in n * n:
			if owner[i] == -1:
				empties.append(i)
		empties.shuffle()
		for i in empties:
			var c := _nb(i).filter(func(j): return owner[j] == -1).size()
			if c < fewest:
				fewest = c
				start = i
		var path := [start]
		owner[start] = result.size()
		var target_len := 3 + randi() % (max_len - 2)
		while path.size() < target_len:
			var opts := _nb(path.back()).filter(func(j): return owner[j] == -1)
			if opts.is_empty():
				break
			# prefer squares that would otherwise get cut off
			opts.sort_custom(func(a, b): return _nb(a).filter(func(j): return owner[j] == -1).size() < _nb(b).filter(func(j): return owner[j] == -1).size())
			var pick: int = opts[0] if randf() < 0.6 else opts[randi() % opts.size()]
			path.append(pick)
			owner[pick] = result.size()
		if path.size() < 3:
			# too short to be a pipe: glue it onto an end of a neighbouring path
			var glued := false
			for p_i in result.size():
				var other: Array = result[p_i]
				var piece := path.duplicate()
				if _nb(other.back()).has(piece.back()):
					piece.reverse()
				if _nb(other.back()).has(piece[0]):
					other.append_array(piece)
				else:
					piece = path.duplicate()
					if _nb(other[0]).has(piece[0]):
						piece.reverse()
					if not _nb(other[0]).has(piece.back()):
						continue
					piece.append_array(other)
					result[p_i] = piece
				for c in path:
					owner[c] = p_i
				glued = true
				break
			if not glued:
				return []
			continue
		result.append(path)
		if result.size() > PALETTE.size():
			return []
	return result


func to_save() -> Dictionary:
	return {"n": n, "solution": solution, "paths": paths, "hints": hints}


func _ints(a) -> Array:
	return (a as Array).map(func(v): return int(v))


func from_save(d: Dictionary) -> void:
	n = int(d.get("n", 5))
	solution = d.get("solution", []).map(func(a): return _ints(a))
	paths = d.get("paths", []).map(func(a): return _ints(a))
	hints = int(d.get("hints", 0))
	if solution.is_empty() or paths.size() != solution.size():
		new_game()
		return
	dots = solution.map(func(p): return [p[0], p[p.size() - 1]])
	drawing = -1
	undo_stack.clear()
	_fit()


func save_info() -> String:
	return "%d of %d pipes" % [_connected_count(), dots.size()]


func play_buttons() -> Array:
	return [["Undo", _undo], ["Hint", _hint], ["Restart", _restart], ["New game", start_new]]


func _dot_colour(i: int) -> int:
	for k in dots.size():
		if dots[k].has(i):
			return k
	return -1


func _owner(i: int) -> int:
	for k in paths.size():
		if paths[k].has(i):
			return k
	return -1


func pipe_done(k: int) -> bool:
	var p: Array = paths[k]
	return p.size() >= 2 and dots[k].has(p[0]) and dots[k].has(p.back()) and p[0] != p.back()


func _connected_count() -> int:
	var c := 0
	for k in paths.size():
		if pipe_done(k):
			c += 1
	return c


func _cell_at(p: Vector2) -> int:
	var r := (p - origin) / cell
	if r.x < 0 or r.y < 0 or r.x >= n or r.y >= n:
		return -1
	return int(r.y) * n + int(r.x)


func game_press(p: Vector2) -> void:
	drawing = -1
	var i := _cell_at(p)
	if i < 0:
		return
	undo_stack.append(JSON.stringify(paths))
	var dc := _dot_colour(i)
	if dc >= 0:
		drawing = dc
		paths[dc] = [i]
		return
	var oc := _owner(i)
	if oc >= 0:
		drawing = oc
		var path: Array = paths[oc]
		paths[oc] = path.slice(0, path.find(i) + 1)
	else:
		undo_stack.pop_back()


func game_drag(_from: Vector2, to: Vector2) -> void:
	if drawing < 0:
		return
	var target := _cell_at(to)
	if target < 0:
		return
	# walk there one square at a time (fast fingers skip squares)
	var guard := 0
	while guard < 30:
		guard += 1
		var path: Array = paths[drawing]
		var cur: int = path.back()
		if cur == target:
			break
		var dx := target % n - cur % n
		var dy := target / n - cur / n
		var nxt := cur + (signi(dx) if absi(dx) >= absi(dy) else signi(dy) * n)
		if not extend(drawing, nxt):
			break


## Add one square to colour k's pipe. Returns false if it can't go there.
func extend(k: int, nxt: int) -> bool:
	var path: Array = paths[k]
	if path.is_empty() or not _nb(path.back()).has(nxt):
		return false
	if pipe_done(k):
		# finished pipe: only allow going back
		if path.size() >= 2 and nxt == path[path.size() - 2]:
			path.pop_back()
			return true
		return false
	var at := path.find(nxt)
	if at >= 0:
		paths[k] = path.slice(0, at + 1)  # going back over its own pipe
		return true
	var dc := _dot_colour(nxt)
	if dc >= 0 and dc != k:
		return false
	if dc == k and nxt == path[0]:
		return false
	var oc := _owner(nxt)
	if oc >= 0 and oc != k:
		var other: Array = paths[oc]
		paths[oc] = other.slice(0, other.find(nxt))  # cut the other pipe
	path.append(nxt)
	return true


func game_release(_from: Vector2, _to: Vector2) -> void:
	if drawing < 0:
		return
	drawing = -1
	if undo_stack.size() > 0 and undo_stack.back() == JSON.stringify(paths):
		undo_stack.pop_back()
	else:
		moves += 1
	_check()


func _check() -> void:
	if _connected_count() == dots.size():
		var filled := 0
		for k in paths.size():
			filled += paths[k].size()
		if filled == n * n:
			finish(true, maxi(100, (diff + 1) * 600 + n * n * 4 - int(elapsed) - hints * 120))
			return
		toast("All connected! Now fill every square")
	save_game()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	paths = (JSON.parse_string(undo_stack.pop_back()) as Array).map(func(a): return _ints(a))
	save_game()


func _restart() -> void:
	undo_stack.append(JSON.stringify(paths))
	for k in paths.size():
		paths[k] = []
	save_game()


func _hint() -> void:
	for k in solution.size():
		if paths[k] != solution[k]:
			undo_stack.append(JSON.stringify(paths))
			# lay the solution pipe; it may cut through other pipes
			for j in paths.size():
				if j != k:
					for c in solution[k]:
						var at: int = paths[j].find(c)
						if at >= 0:
							paths[j] = paths[j].slice(0, at)
			paths[k] = solution[k].duplicate()
			hints += 1
			toast("Hint: one pipe drawn")
			_check()
			return


func draw_game() -> void:
	draw_rect(Rect2(origin, Vector2(n, n) * cell), Color(0.06, 0.06, 0.10))
	for k in paths.size():
		var path: Array = paths[k]
		if pipe_done(k):
			for c in path:
				var pc: Color = PALETTE[k]
				draw_rect(Rect2(origin + Vector2(c % n, c / n) * cell, Vector2(cell, cell)), Color(pc, 0.18))
	for i in n * n:
		draw_rect(Rect2(origin + Vector2(i % n, i / n) * cell, Vector2(cell, cell)), Color(1, 1, 1, 0.12), false, 1.0)
	for k in paths.size():
		var path: Array = paths[k]
		for j in range(1, path.size()):
			var a: Vector2 = origin + Vector2(path[j - 1] % n + 0.5, path[j - 1] / n + 0.5) * cell
			var b: Vector2 = origin + Vector2(path[j] % n + 0.5, path[j] / n + 0.5) * cell
			draw_line(a, b, PALETTE[k], cell * 0.32)
			draw_circle(b, cell * 0.16, PALETTE[k])
	for k in dots.size():
		for d in dots[k]:
			draw_circle(origin + Vector2(d % n + 0.5, d / n + 0.5) * cell, cell * 0.36, PALETTE[k])
	var filled := 0
	for k in paths.size():
		filled += paths[k].size()
	draw_stats(["Pipes %d of %d" % [_connected_count(), dots.size()], "Filled %d%%" % (filled * 100 / (n * n))])
