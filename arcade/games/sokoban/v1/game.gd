extends PuzzleGame
# Sokoban: push every crate onto a target. Crates can be pushed, never pulled.
# Levels are built backwards: crates start on their targets and the warehouse
# worker pulls them away, so playing those moves forwards always solves the
# level. Easy 2 crates, Normal 3, Hard 4. Each solved level unlocks the next.

const AREA := Rect2(40, 70, 930, 630)
const LEVEL_FILE := "user://sokoban_level.dat"

var w := 9
var h := 8
var walls: Array = []  # bools
var goals: Array = []  # cell indices
var boxes: Array = []  # cell indices
var player := 0
var start_boxes: Array = []
var start_player := 0
var level := 1
var undo_stack: Array = []
var cell := 64.0
var origin := Vector2.ZERO
var walk_path: Array = []
var walk_t := 0.0


func _init() -> void:
	game_id = "sokoban"
	title = "Sokoban"
	help = ["Push every crate onto a target spot. You can push, but never pull.", "Swipe to walk one step (and push), or tap a square to walk there.", "Stuck? Undo or Restart. Every level can be solved."]


func _read_level() -> int:
	if FileAccess.file_exists(LEVEL_FILE):
		var f := FileAccess.open(LEVEL_FILE, FileAccess.READ)
		if f:
			return maxi(1, f.get_32())
	return 1


func new_game() -> void:
	level = _read_level()
	var nb: int = [2, 3, 4][diff] + (1 if level > 10 else 0)
	w = 8 + mini(level / 5, 2) + diff
	h = 7 + mini(level / 8, 1)
	var best_score := -1.0
	var best := {}
	for attempt in 40:
		var cand := _generate(nb)
		if cand.is_empty():
			continue
		if cand["score"] > best_score:
			best_score = cand["score"]
			best = cand
	if best.is_empty():
		# tiny fallback: one crate in an open room
		w = 7
		h = 6
		walls = _room()
		goals = [_i(2, 2)]
		boxes = [_i(3, 3)]
		player = _i(4, 4)
	else:
		walls = best["walls"]
		goals = best["goals"]
		boxes = best["boxes"]
		player = best["player"]
	start_boxes = boxes.duplicate()
	start_player = player
	undo_stack.clear()
	walk_path = []
	_fit()


func _i(x: int, y: int) -> int:
	return y * w + x


func _room() -> Array:
	var wl := []
	for y in h:
		for x in w:
			wl.append(x == 0 or y == 0 or x == w - 1 or y == h - 1)
	return wl


func _floor_cells(wl: Array) -> Array:
	var out := []
	for i in wl.size():
		if not wl[i]:
			out.append(i)
	return out


func _connected(wl: Array) -> bool:
	var fl := _floor_cells(wl)
	if fl.is_empty():
		return false
	var seen := {fl[0]: true}
	var todo := [fl[0]]
	while not todo.is_empty():
		var c: int = todo.pop_back()
		for d in [1, -1, w, -w]:
			var n: int = c + d
			if n >= 0 and n < wl.size() and not wl[n] and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen.size() == fl.size()


## One candidate level, or {} if it failed.
func _generate(nb: int) -> Dictionary:
	var wl := _room()
	# a few inner walls, keeping the floor connected
	var inner := int((w - 2) * (h - 2) * 0.16)
	for k in inner:
		var x := 1 + randi() % (w - 2)
		var y := 1 + randi() % (h - 2)
		var i := _i(x, y)
		if wl[i]:
			continue
		wl[i] = true
		if not _connected(wl):
			wl[i] = false
	var fl := _floor_cells(wl)
	# targets away from the walls' corners so crates can leave them
	var spots := fl.filter(func(c): return _open_sides(wl, c) >= 3)
	if spots.size() < nb + 2:
		return {}
	spots.shuffle()
	var gl: Array = spots.slice(0, nb)
	var bx: Array = gl.duplicate()
	var free_spots := fl.filter(func(c): return not bx.has(c))
	var pl: int = free_spots[randi() % free_spots.size()]
	# walk backwards: move around, sometimes pulling a crate behind you
	var dirs := [1, -1, w, -w]
	for step in 160 + nb * 40:
		var d: int = dirs[randi() % 4]
		var to: int = pl + d
		if wl[to] or bx.has(to):
			continue
		var behind: int = pl - d
		if bx.has(behind) and randf() < 0.65:
			bx[bx.find(behind)] = pl
		pl = to
	var off := 0
	var dist := 0.0
	for k in bx.size():
		if not gl.has(bx[k]):
			off += 1
		var bxy := Vector2(bx[k] % w, bx[k] / w)
		var best := 99.0
		for g in gl:
			best = minf(best, bxy.distance_to(Vector2(g % w, g / w)))
		dist += best
	if off < nb:
		return {}
	return {"walls": wl, "goals": gl, "boxes": bx, "player": pl, "score": dist + randf()}


func _open_sides(wl: Array, c: int) -> int:
	var n := 0
	for d in [1, -1, w, -w]:
		if not wl[c + d]:
			n += 1
	return n


func _fit() -> void:
	cell = floorf(minf(minf(AREA.size.x / w, AREA.size.y / h), 96.0))
	origin = AREA.position + (AREA.size - Vector2(w, h) * cell) / 2.0


func to_save() -> Dictionary:
	return {"w": w, "h": h, "walls": walls, "goals": goals, "boxes": boxes, "player": player, "start_boxes": start_boxes, "start_player": start_player, "level": level}


func from_save(d: Dictionary) -> void:
	w = int(d.get("w", 9))
	h = int(d.get("h", 8))
	walls = d.get("walls", []).map(func(v): return bool(v))
	goals = d.get("goals", []).map(func(v): return int(v))
	boxes = d.get("boxes", []).map(func(v): return int(v))
	player = int(d.get("player", 0))
	start_boxes = d.get("start_boxes", []).map(func(v): return int(v))
	start_player = int(d.get("start_player", 0))
	level = int(d.get("level", 1))
	if walls.size() != w * h or boxes.size() != goals.size() or boxes.is_empty():
		new_game()
		return
	undo_stack.clear()
	walk_path = []
	_fit()


func save_info() -> String:
	return "level %d" % level


func play_buttons() -> Array:
	return [["Undo", _undo], ["Restart", _restart], ["Skip level", _skip]]


## Move one step in a direction, pushing a crate if there is one.
func step(d: Vector2i) -> bool:
	var dd := d.x + d.y * w
	var to := player + dd
	if walls[to]:
		return false
	var bi := boxes.find(to)
	if bi >= 0:
		var beyond := to + dd
		if walls[beyond] or boxes.has(beyond):
			return false
		undo_stack.append([player, boxes.duplicate()])
		boxes[bi] = beyond
	else:
		undo_stack.append([player, boxes.duplicate()])
	player = to
	moves += 1
	_check()
	return true


func _check() -> void:
	for b in boxes:
		if not goals.has(b):
			save_game()
			return
	walk_path = []
	var f := FileAccess.open(LEVEL_FILE, FileAccess.WRITE)
	if f:
		f.store_32(level + 1)
	finish(true, level * 100 + maxi(0, 300 - moves))


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	var u: Array = undo_stack.pop_back()
	player = u[0]
	boxes = u[1]
	walk_path = []
	save_game()


func _restart() -> void:
	boxes = start_boxes.duplicate()
	player = start_player
	undo_stack.clear()
	walk_path = []
	save_game()


func _skip() -> void:
	toast("New level")
	new_game()
	save_game()


## Shortest walk to a square without pushing anything.
func _path_to(goal: int) -> Array:
	if walls[goal] or boxes.has(goal):
		return []
	var prev := {player: -1}
	var todo := [player]
	var k := 0
	while k < todo.size():
		var c: int = todo[k]
		k += 1
		if c == goal:
			break
		for d in [1, -1, w, -w]:
			var n: int = c + d
			if not walls[n] and not boxes.has(n) and not prev.has(n):
				prev[n] = c
				todo.append(n)
	if not prev.has(goal):
		return []
	var path := []
	var c := goal
	while c != player:
		path.push_front(c)
		c = prev[c]
	return path


func game_tap(p: Vector2) -> void:
	var r := (p - origin) / cell
	if r.x < 0 or r.y < 0 or r.x >= w or r.y >= h:
		return
	var target := int(r.y) * w + int(r.x)
	var dx := target % w - player % w
	var dy := target / w - player / w
	if absi(dx) + absi(dy) == 1:
		step(Vector2i(dx, dy))
		return
	walk_path = _path_to(target)


func game_swipe(dir: Vector2i) -> void:
	walk_path = []
	step(dir)


func game_key(k: int) -> void:
	walk_path = []
	match k:
		KEY_LEFT, KEY_A: step(Vector2i.LEFT)
		KEY_RIGHT, KEY_D: step(Vector2i.RIGHT)
		KEY_UP, KEY_W: step(Vector2i.UP)
		KEY_DOWN, KEY_S: step(Vector2i.DOWN)
		KEY_U, KEY_Z: _undo()
		KEY_R: _restart()


func game_update(delta: float) -> void:
	if walk_path.is_empty():
		return
	walk_t += delta
	if walk_t >= 0.08:
		walk_t = 0.0
		var nxt: int = walk_path.pop_front()
		step(Vector2i(nxt % w - player % w, nxt / w - player / w))


func draw_game() -> void:
	for i in w * h:
		var r := Rect2(origin + Vector2(i % w, i / w) * cell, Vector2(cell, cell))
		if walls[i]:
			draw_rect(r, Color(0.32, 0.26, 0.22))
			draw_rect(r.grow(-3), Color(0.42, 0.34, 0.28))
		else:
			draw_rect(r, Color(0.78, 0.74, 0.66))
			draw_rect(r, Color(0, 0, 0, 0.08), false, 1.0)
	for g in goals:
		var c := origin + Vector2(g % w + 0.5, g / w + 0.5) * cell
		draw_arc(c, cell * 0.28, 0, TAU, 32, Color(0.85, 0.2, 0.2), 4.0)
	for b in boxes:
		var r := Rect2(origin + Vector2(b % w, b / w) * cell, Vector2(cell, cell)).grow(-cell * 0.1)
		var on := goals.has(b)
		draw_rect(r, Color(0.35, 0.65, 0.30) if on else Color(0.80, 0.55, 0.25))
		draw_rect(r, Color(0.2, 0.12, 0.05), false, 3.0)
		draw_line(r.position, r.end, Color(0.2, 0.12, 0.05, 0.5), 2.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.2, 0.12, 0.05, 0.5), 2.0)
	var pc := origin + Vector2(player % w + 0.5, player / w + 0.5) * cell
	draw_circle(pc, cell * 0.32, Color(0.2, 0.4, 0.85))
	draw_circle(pc + Vector2(0, -cell * 0.06), cell * 0.14, Color(0.98, 0.85, 0.7))
	var on_goal := boxes.filter(func(b): return goals.has(b)).size()
	draw_stats(["Level %d   Moves %d" % [level, moves], "Crates home %d of %d" % [on_goal, boxes.size()]])
