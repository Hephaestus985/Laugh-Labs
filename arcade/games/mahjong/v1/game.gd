extends PuzzleGame
# Mahjong solitaire: remove matching pairs of free tiles. A tile is free when no
# tile lies on top of it and its left or right side is open.
# Deals are built backwards (pairs are taken off free spots of the full stack), so
# every deal can be cleared. Shuffle re-deals the tiles left, again solvably.

const AREA := Rect2(30, 70, 960, 640)
# layers as [columns, rows] centred on each other
const LAYOUTS := [
	[[8, 4], [4, 2]],
	[[10, 5], [6, 3], [2, 1]],
	[[12, 6], [8, 4], [4, 2], [2, 1]],
]
const SUIT_COLORS := [Color(0.15, 0.55, 0.30), Color(0.20, 0.40, 0.80), Color(0.80, 0.20, 0.20)]
const HONORS := ["N", "E", "S", "W", "R", "G", "Wh"]

var tiles: Array = []  # [x, y, z, face] with face -1 = removed (x, y in tile units)
var cols := 8
var rows := 4
var tw := 80.0
var th := 100.0
var origin := Vector2.ZERO
var sel := -1
var hint_pair: Array = []
var undo_stack: Array = []
var shuffles := 0


func _init() -> void:
	game_id = "mahjong"
	title = "Mahjong Solitaire"
	help = ["Tap two matching tiles to remove them.", "Only free tiles can be picked: nothing on top, and an open left or right side.", "Clear the whole stack. Hint shows a pair; Shuffle mixes the tiles left."]


func new_game() -> void:
	var layout: Array = LAYOUTS[diff]
	cols = layout[0][0]
	rows = layout[0][1]
	var spots := []
	for z in layout.size():
		var w: int = layout[z][0]
		var h: int = layout[z][1]
		var ox := (cols - w) / 2
		var oy := (rows - h) / 2
		for y in h:
			for x in w:
				spots.append([ox + x, oy + y, z])
	tiles = []
	for s in spots:
		tiles.append([s[0], s[1], s[2], -1])
	_deal(range(tiles.size()))
	_fit()
	sel = -1
	hint_pair = []
	undo_stack.clear()
	shuffles = 0


func _fit() -> void:
	tw = floorf(minf(AREA.size.x / (cols + 0.6), AREA.size.y / (rows + 0.6) * 0.8))
	th = floorf(tw * 1.25)
	origin = AREA.position + (AREA.size - Vector2(cols * tw, rows * th)) / 2.0 + Vector2(10, 10)


## Give faces to the tiles at these indices so they can all be removed in pairs.
func _deal(idxs: Array) -> void:
	for attempt in 50:
		var left := idxs.duplicate()
		var order := []
		var ok := true
		while not left.is_empty():
			var free := left.filter(func(i): return _free_in(i, left))
			if free.size() < 2:
				ok = false
				break
			free.shuffle()
			order.append([free[0], free[1]])
			left.erase(free[0])
			left.erase(free[1])
		if not ok:
			continue
		var kinds := 34
		var faces := []
		for k in order.size():
			faces.append(k % kinds)
		faces.shuffle()
		for k in order.size():
			tiles[order[k][0]][3] = faces[k]
			tiles[order[k][1]][3] = faces[k]
		return
	# could not build a solvable deal (very unlikely): deal randomly in pairs
	var shuffled := idxs.duplicate()
	shuffled.shuffle()
	for k in range(0, shuffled.size() - 1, 2):
		tiles[shuffled[k]][3] = (k / 2) % 34
		tiles[shuffled[k + 1]][3] = (k / 2) % 34


## Free among a set of tile indices (used while dealing).
func _free_in(i: int, among: Array) -> bool:
	var t0: Array = tiles[i]
	var left_open := true
	var right_open := true
	for j in among:
		if j == i:
			continue
		var t1: Array = tiles[j]
		if t1[0] == t0[0] and t1[1] == t0[1] and t1[2] == t0[2] + 1:
			return false
		if t1[2] == t0[2] and t1[1] == t0[1]:
			if t1[0] == t0[0] - 1:
				left_open = false
			elif t1[0] == t0[0] + 1:
				right_open = false
	return left_open or right_open


func _alive() -> Array:
	var out := []
	for i in tiles.size():
		if tiles[i][3] >= 0:
			out.append(i)
	return out


func is_free(i: int) -> bool:
	return tiles[i][3] >= 0 and _free_in(i, _alive())


func to_save() -> Dictionary:
	return {"tiles": tiles, "cols": cols, "rows": rows, "shuffles": shuffles}


func from_save(d: Dictionary) -> void:
	tiles = d.get("tiles", []).map(func(a): return (a as Array).map(func(v): return int(v)))
	cols = int(d.get("cols", 8))
	rows = int(d.get("rows", 4))
	shuffles = int(d.get("shuffles", 0))
	if tiles.is_empty():
		new_game()
		return
	_fit()
	sel = -1
	hint_pair = []
	undo_stack.clear()


func save_info() -> String:
	return "%d tiles left" % _alive().size()


func play_buttons() -> Array:
	return [["Hint", _hint], ["Shuffle", _shuffle], ["Undo", _undo], ["New game", start_new]]


func _pairs() -> Array:
	var free := _alive().filter(func(i): return is_free(i))
	for a in free.size():
		for b in range(a + 1, free.size()):
			if tiles[free[a]][3] == tiles[free[b]][3]:
				return [free[a], free[b]]
	return []


func _hint() -> void:
	hint_pair = _pairs()
	if hint_pair.is_empty():
		toast("No pairs left: tap Shuffle")


func _shuffle() -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	undo_stack.append(JSON.stringify(tiles))
	_deal(alive)
	shuffles += 1
	sel = -1
	hint_pair = []
	toast("Shuffled")
	save_game()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	tiles = (JSON.parse_string(undo_stack.pop_back()) as Array).map(func(a): return (a as Array).map(func(v): return int(v)))
	sel = -1
	hint_pair = []
	save_game()


func pick(i: int) -> void:
	if i < 0:
		return
	if not is_free(i):
		toast("That tile is blocked")
		return
	if sel == -1 or sel == i:
		sel = -1 if sel == i else i
		return
	if tiles[sel][3] == tiles[i][3]:
		undo_stack.append(JSON.stringify(tiles))
		tiles[sel][3] = -1
		tiles[i][3] = -1
		sel = -1
		hint_pair = []
		moves += 1
		if _alive().is_empty():
			finish(true, maxi(100, (diff + 1) * 1000 + tiles.size() * 5 - int(elapsed) - shuffles * 150))
			return
		if _pairs().is_empty():
			toast("No pairs left: tap Shuffle")
		save_game()
	else:
		sel = i


func tile_rect(i: int) -> Rect2:
	var t0: Array = tiles[i]
	var lift: Vector2 = Vector2(-7, -7) * t0[2]
	return Rect2(origin + Vector2(t0[0] * tw, t0[1] * th) + lift, Vector2(tw - 4, th - 4))


func game_tap(p: Vector2) -> void:
	# topmost tile under the finger
	var best := -1
	for i in tiles.size():
		if tiles[i][3] >= 0 and tile_rect(i).has_point(p):
			if best == -1 or tiles[i][2] > tiles[best][2]:
				best = i
	pick(best)


func draw_face(r: Rect2, face: int) -> void:
	if face < 27:
		var s := face / 9
		var v := face % 9 + 1
		draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 10)), SUIT_COLORS[s])
		draw_string(font, Vector2(r.position.x, r.get_center().y + r.size.y * 0.16), str(v), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.45), SUIT_COLORS[s])
		for k in s + 1:
			draw_circle(Vector2(r.position.x + 12 + k * 12, r.end.y - 12), 4, SUIT_COLORS[s])
	else:
		var h: String = HONORS[face - 27]
		var col := Color(0.15, 0.15, 0.2)
		if face >= 31:
			col = [Color(0.8, 0.15, 0.15), Color(0.1, 0.55, 0.25), Color(0.3, 0.4, 0.8)][face - 31]
		draw_string(font, Vector2(r.position.x, r.get_center().y + r.size.y * 0.14), h, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.38), col)


func draw_game() -> void:
	var order := _alive()
	order.sort_custom(func(a, b): return tiles[a][2] < tiles[b][2] or (tiles[a][2] == tiles[b][2] and (tiles[a][1] < tiles[b][1] or (tiles[a][1] == tiles[b][1] and tiles[a][0] > tiles[b][0]))))
	for i in order:
		var r := tile_rect(i)
		draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Color(0.35, 0.30, 0.22))
		var free := is_free(i)
		var bg := Color(0.98, 0.96, 0.88) if free else Color(0.84, 0.82, 0.74)
		if i == sel:
			bg = Color(1.0, 0.85, 0.45)
		elif hint_pair.has(i):
			bg = Color(0.7, 0.92, 1.0)
		draw_rect(r, bg)
		draw_rect(r, Color(0.3, 0.25, 0.2), false, 2.0)
		draw_face(r, tiles[i][3])
	draw_stats(["Tiles left %d" % _alive().size(), "%s   %s" % [DIFF_NAMES[diff], time_text(elapsed)]])
