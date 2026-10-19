extends ArcadeGame
# Never Ask for Directions: steer a Viking longship through fjords, gusts,
# icebergs and a kraken, without once asking for directions.
# (The web version scrolled downwards; here the ship sails to the right.)

const TOP := 96.0
const BX := 190.0  # boat x on screen
const ZONES := [
	{"name": "The fjord", "tip": "Mind the walls"},
	{"name": "The North Sea", "tip": "Gusts push you sideways"},
	{"name": "Iceberg field", "tip": "The ice drifts"},
	{"name": "Kraken waters", "tip": "Watch for ripples"},
	{"name": "Off the map", "tip": "Still not asking"},
]
const TINTS := [Color(0.10, 0.22, 0.34), Color(0.09, 0.18, 0.30), Color(0.14, 0.26, 0.36), Color(0.12, 0.12, 0.26), Color(0.06, 0.07, 0.16)]
const DIFFS := [{"name": "Easy", "f": 0.8}, {"name": "Normal", "f": 1.0}, {"name": "Hard", "f": 1.25}]

enum State { TITLE, PLAY, OVER }
var state: int = State.TITLE
var diff := 1
var DF := 1.0
var by := 400.0
var bv := 0.0  # px per ms, across the lane
var things: Array = []
var loot: Array = []
var parts: Array = []
var waves: Array = []
var shields := 3
var dist := 0.0
var scroll := 0.0
var gold := 0
var level := 1
var inv := 0.0
var wind := 0.0
var wind_t := 0.0
var next_spawn := 120.0
var next_loot := 200.0
var banner := ""
var banner_t := 0.0
var why := ""
var new_best := false


func _ready() -> void:
	game_id = "never_ask_for_directions"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()
	diff = difficulty()
	reset()


func lane_h() -> float:
	return H - TOP


func mid() -> float:
	return TOP + lane_h() / 2.0


func zone_idx() -> int:
	return mini(level, ZONES.size()) - 1


func fjord_w(x: float) -> float:
	var base := lane_h() * 0.62 - mini(level, 4) * lane_h() * 0.03
	return maxf(lane_h() * 0.42, base + sin((scroll + x) / 280.0) * lane_h() * 0.05)


func fjord_c(x: float) -> float:
	return mid() + sin((scroll + x) / 460.0 + 1.3) * lane_h() * 0.14


func reset() -> void:
	DF = DIFFS[diff]["f"]
	by = mid()
	bv = 0.0
	things.clear()
	loot.clear()
	parts.clear()
	waves.clear()
	for i in 34:
		waves.append({"x": randf() * W, "y": TOP + randf() * lane_h(), "l": randf_range(16, 44)})
	shields = 3
	dist = 0.0
	scroll = 0.0
	gold = 0
	level = 1
	inv = 0.0
	wind = 0.0
	wind_t = 0.0
	next_spawn = 120.0
	next_loot = 200.0
	banner = "Level 1: The fjord"
	banner_t = 1.8
	new_best = false


func speed() -> float:
	return (0.11 + level * 0.018 + minf(0.05, dist / 60000.0)) * DF


func score() -> int:
	return int(dist / 10.0) + gold * 25


func hit(reason: String) -> void:
	if inv > 0.0:
		return
	shields -= 1
	inv = 1300.0
	shake(10.0)
	burst(Vector2(BX, by), Color(1, 0.35, 0.5), 14)
	if shields <= 0:
		why = reason
		state = State.OVER
		t = 0.0
		new_best = submit_score(score())


func burst(p: Vector2, c: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(100, 300), "life": 0.6, "c": c})


func spawn() -> void:
	var r := randf()
	if level >= 4 and r < 0.25:
		things.append({"k": "kraken", "x": randf_range(W * 0.4, W * 0.85), "y": randf_range(TOP + lane_h() * 0.15, TOP + lane_h() * 0.85), "t": 0.0, "r": 32.0})
		return
	if level >= 3 and r < 0.55:
		things.append({"k": "ice", "x": W + 60, "y": randf_range(TOP + 40, H - 40), "r": randf_range(28, 48), "vy": randf_range(-0.06, 0.06) * level})
		return
	var c := fjord_c(W + 40) if level == 1 else mid()
	var hw := fjord_w(W + 40) / 2.0 - 32.0 if level == 1 else lane_h() / 2.0 - 40.0
	things.append({"k": "rock", "x": W + 50, "y": c + randf_range(-hw, hw), "r": randf_range(20, 34)})


func on_input(event: InputEvent) -> void:
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
			set_difficulty(game_id, diff)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
			set_difficulty(game_id, diff)


func _process(delta: float) -> void:
	tick(delta)
	banner_t = maxf(0.0, banner_t - delta)
	match state:
		State.TITLE:
			if pressed_b():
				diff = (diff + 1) % 3
				set_difficulty(game_id, diff)
			if start_pressed():
				reset()
				state = State.PLAY
		State.OVER:
			if start_pressed() and t > 0.9:
				state = State.TITLE
		State.PLAY:
			clear_presses()
			step(minf(delta, 0.04) * 1000.0)
	for p in parts:
		p["p"] += p["v"] * delta
		p["life"] -= delta
	parts = parts.filter(func(p): return p["life"] > 0.0)
	queue_redraw()


func step(dt: float) -> void:
	var nl := 1 + int(dist / 9000.0)
	if nl != level:
		level = nl
		var z: Dictionary = ZONES[zone_idx()]
		banner = "Level %d: %s" % [level, (z["name"] + ". " + z["tip"]) if level <= ZONES.size() else "Faster. Still lost."]
		banner_t = 2.0
	var sp := speed()
	dist += sp * dt * 4.0
	var sx := sp * dt * 2.0  # screen px scrolled this frame
	scroll += sx
	var s := axis().y
	if pointer_down and (is_mobile or a_down):
		s = -1.0 if pointer.y < by - 12 else (1.0 if pointer.y > by + 12 else 0.0)
	if level >= 2:
		wind_t -= dt
		if wind_t <= 0.0:
			wind = 0.0 if randf() < 0.5 else randf_range(-1, 1) * (0.06 + level * 0.01)
			wind_t = randf_range(1500, 3200)
	else:
		wind = 0.0
	bv += (s * 0.0032 + wind * 0.02) * dt
	bv *= pow(0.9, dt / 16.0)
	by += bv * dt
	if level == 1:
		var c := fjord_c(BX)
		var hw := fjord_w(BX) / 2.0
		if by < c - hw + 24:
			by = c - hw + 24
			bv = 0.4
			hit("the fjord wall")
		if by > c + hw - 24:
			by = c + hw - 24
			bv = -0.4
			hit("the fjord wall")
	by = clampf(by, TOP + 28, H - 28)
	next_spawn -= sp * dt
	if next_spawn <= 0.0:
		spawn()
		next_spawn = (maxf(18.0, 85.0 - level * 11.0) + randf() * 45.0) / DF
	next_loot -= sp * dt
	if next_loot <= 0.0:
		var ly := fjord_c(W + 30) + randf_range(-fjord_w(W + 30) / 3.0, fjord_w(W + 30) / 3.0) if level == 1 else randf_range(TOP + 48, H - 48)
		loot.append(Vector2(W + 30, ly))
		next_loot = randf_range(110, 220)
	var boat := Vector2(BX, by)
	for i in range(things.size() - 1, -1, -1):
		var o: Dictionary = things[i]
		o["x"] -= sx
		if o["k"] == "kraken":
			o["t"] += dt
			if o["t"] > 1400 and o["t"] < 2600 and Vector2(o["x"], o["y"]).distance_to(boat) < o["r"] + 24:
				hit("the Kraken")
			if o["t"] > 3200 or o["x"] < -80:
				things.remove_at(i)
			continue
		if o.has("vy"):
			o["y"] = clampf(o["y"] + o["vy"] * dt, TOP + 20, H - 20)
		if Vector2(o["x"], o["y"]).distance_to(boat) < o["r"] + 20:
			hit("an iceberg" if o["k"] == "ice" else "a rock")
			things.remove_at(i)
			continue
		if o["x"] < -80:
			things.remove_at(i)
	for i in range(loot.size() - 1, -1, -1):
		loot[i].x -= sx
		if absf(loot[i].x - BX) < 44 and absf(loot[i].y - by) < 40:
			gold += 1
			burst(loot[i], Color(0.88, 0.66, 0.0), 8)
			loot.remove_at(i)
		elif loot[i].x < -40:
			loot.remove_at(i)
	for w in waves:
		w["x"] -= sx * 1.2
		if w["x"] < -50:
			w["x"] = W + 10
			w["y"] = TOP + randf() * lane_h()
	if inv > 0.0:
		inv -= dt


func verdict() -> String:
	var sc := score()
	if sc >= 1500:
		return "You discovered America by accident. Still didn't ask anyone."
	if sc >= 700:
		return "Legendary raid. The sagas will exaggerate it further."
	if sc >= 300:
		return "A decent raid. Your crew suspects you're lost, but nobody says it."
	return "You hit %s. Your crew quietly opens a map." % why


func _draw() -> void:
	draw_rect(Rect2(-40, -40, W + 80, H + 80), TINTS[zone_idx()])
	for w in waves:
		draw_arc(Vector2(w["x"], w["y"]), w["l"] / 2.0, PI + 0.4, TAU - 0.4, 8, Color(1, 1, 1, 0.15), 2.0)
	if level == 1:
		var x := -10.0
		while x < W + 10:
			var c := fjord_c(x)
			var hw := fjord_w(x) / 2.0
			draw_rect(Rect2(x, TOP, 12, c - hw - TOP), Color(0.48, 0.55, 0.43))
			draw_rect(Rect2(x, c + hw, 12, H - c - hw), Color(0.48, 0.55, 0.43))
			x += 10.0
	if wind != 0.0:
		text(Vector2(BX + 60, mid()), "gust ^" if wind < 0 else "gust v", 24, Color(0.85, 0.85, 0.95, 0.8))
	for g in loot:
		draw_circle(g, 16, Color(0.88, 0.66, 0.0))
		draw_circle(g - Vector2(4, 4), 6, Color(1, 0.95, 0.7))
	for o in things:
		var p := Vector2(o["x"], o["y"])
		var r: float = o["r"]
		match o["k"]:
			"rock":
				draw_circle(p, r, Color(0.42, 0.44, 0.47))
				draw_circle(p - Vector2(r, r) * 0.3, r * 0.45, Color(0.55, 0.57, 0.6))
			"ice":
				var pts := PackedVector2Array()
				for k in 6:
					var a := k / 6.0 * TAU
					pts.append(p + Vector2(cos(a), sin(a)) * r * (0.8 if k % 2 else 1.0))
				draw_colored_polygon(pts, Color(0.91, 0.96, 1.0))
				pts.append(pts[0])
				draw_polyline(pts, Color(0.61, 0.78, 0.9), 3.0)
			"kraken":
				var ph: float = o["t"]
				if ph < 1400:
					draw_arc(p, r + ph / 45.0, 0, TAU, 40, Color(1, 0.35, 0.5, 0.3 + 0.4 * absf(sin(ph / 120.0))), 3.0)
				elif ph < 2600:
					var kc := Color(0.56, 0.25, 0.66)
					draw_circle(p, r + 12, kc)
					for k in 4:
						var aa := k * 1.57 + ph / 400.0
						var pts2 := PackedVector2Array([p, p + Vector2(cos(aa), sin(aa)) * 60.0, p + Vector2(cos(aa + 0.6), sin(aa + 0.6)) * 88.0])
						draw_polyline(pts2, kc, 13.0)
					draw_rect(Rect2(p + Vector2(-12, -8), Vector2(8, 8)), Color(1, 1, 1))
					draw_rect(Rect2(p + Vector2(4, -8), Vector2(8, 8)), Color(1, 1, 1))
	if not (state == State.OVER) and not (inv > 0.0 and int(inv / 90.0) % 2 == 1):
		draw_boat()
	for q in parts:
		draw_rect(Rect2(q["p"], Vector2(6, 6)), Color(q["c"], clampf(q["life"] / 0.6, 0, 1)))
	draw_rect(Rect2(0, 0, W, TOP), Color(0.05, 0.06, 0.12, 0.9))
	text(Vector2(150, 40), "%d m   %d loot   score %d" % [int(dist / 10.0), gold, score()], 28, Color(1, 1, 1))
	text(Vector2(150, 76), "Level %d  ·  %s   best %d" % [level, ZONES[zone_idx()]["name"] if level <= ZONES.size() else "Off the map", best], 22, Color(0.75, 0.75, 0.85))
	for i in 3:
		draw_circle(Vector2(W - 120 + i * 36, 50), 14, Color(0.88, 0.66, 0.0) if i < shields else Color(0.3, 0.3, 0.4))
	if banner_t > 0.0 and state == State.PLAY:
		text(Vector2(0, mid() - 60), banner, 36, Color(1, 0.4, 0.55, minf(1.0, banner_t * 2.0)), true)
	if state == State.TITLE:
		card("NEVER ASK FOR DIRECTIONS", [
			"Steer a Viking longship through fjords, gusts, icebergs and a kraken,",
			"without once asking for directions. Grab loot. Three shields.",
			"Hold the screen above or below the ship to steer, or use up / down.",
			"Difficulty: %s   (change it in the menu, or with left / right here)" % DIFFS[diff]["name"],
		], "Tap or press SPACE to sail")
	elif state == State.OVER and t > 0.5:
		card("VALHALLA", [
			"Sailed %d m with %d loot: score %d, level %d%s" % [int(dist / 10.0), gold, score(), level, "   NEW BEST!" if new_best else ""],
			verdict(),
		], "Tap or press SPACE to continue" if t > 0.9 else "")
	draw_overlay()


func draw_boat() -> void:
	draw_set_transform(Vector2(BX, by), PI / 2 + bv * 0.6, Vector2(2, 2))
	var hull := PackedVector2Array([Vector2(0, -24), Vector2(7, -14), Vector2(10, -2), Vector2(10, 10), Vector2(8, 17), Vector2(-8, 17), Vector2(-10, 10), Vector2(-10, -2), Vector2(-7, -14)])
	draw_colored_polygon(hull, Color(0.54, 0.35, 0.17))
	draw_rect(Rect2(-11, -6, 22, 12), Color(1, 0.35, 0.5))
	draw_rect(Rect2(-11, -2, 22, 3), Color(1, 1, 1))
	for k in [-1, 0, 1]:
		draw_circle(Vector2(-10, k * 7 + 6), 3, Color(0.88, 0.66, 0.0))
		draw_circle(Vector2(10, k * 7 + 6), 3, Color(0.88, 0.66, 0.0))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(W / 2 - 540, 130, 1080, 450), Color(0.08, 0.1, 0.18, 0.96))
	text(Vector2(0, 210), title, 54, Color(1, 0.4, 0.55), true)
	var y := 280.0
	for l in lines:
		text(Vector2(0, y), l, 25, Color(1, 1, 1), true)
		y += 42.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 545), prompt, 30, Color(0.6, 1, 0.6), true)
