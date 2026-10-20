extends ArcadeGame
# Orbit Courier: deliver party invitations across the galaxy by slingshotting
# between moving planets. Tap to let go of your orbit at the right moment.

const NAMES := ["Mercury", "Venus", "Earth", "Mars", "Ceres", "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto (still invited)", "Kepler-22b", "Proxima b", "Tatooine", "Vulcan", "The Moon", "Europa", "Titan", "Phobos"]
const LEVEL_NAMES := ["The inner planets", "Wobbly orbits", "Black hole alley", "The Kuiper commute", "Deep space, no signal"]
const DIFFS := [{"name": "Easy", "f": 0.8}, {"name": "Normal", "f": 1.0}, {"name": "Hard", "f": 1.25}]

enum State { TITLE, PLAY, OVER }
var state: int = State.TITLE
var diff := 1
var DF := 1.0
var planets: Array = []
var holes: Array = []
var stars: Array = []
var parts: Array = []
var cam := 0.0
var level := 1
var delivered := 0
var streak := 0
var banner := ""
var banner_t := 0.0
var why := ""
var new_best := false
var gtime := 0.0

# ship
var mode := "orbit"
var sp_planet: Dictionary
var ang := PI
var spos := Vector2.ZERO
var svel := Vector2.ZERO
var sdir := 1.0
var from_p = null
var trail: Array = []


func _ready() -> void:
	game_id = "orbit_courier"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()
	diff = difficulty()
	for i in 90:
		stars.append({"x": randf() * 4000.0, "y": randf() * H, "s": randf_range(1.0, 3.5), "z": randf_range(0.2, 0.6)})
	reset()


func level_for(n: int) -> int:
	return 1 + n / 5


func make_planet(x: float, y: float, i: int) -> Dictionary:
	var r := randf_range(32, 52)
	return {"x": x, "y": y, "bx": x, "by": y, "r": r, "orbit": r + randf_range(52, 80), "name": NAMES[i % NAMES.size()],
		"hue": randf(), "amp": 0.0, "spd": 0.0, "ph": randf() * 6.0, "done": false, "ring": randf() < 0.33}


func add_planet() -> void:
	var last: Dictionary = planets[planets.size() - 1]
	var L := level_for(planets.size())
	var gap := randf_range(0.38, 0.5) * 880.0 + minf(120.0, L * 16.0)
	var p := make_planet(last["bx"] + gap, randf_range(H * 0.25, H * 0.75), planets.size())
	if L >= 2:
		p["amp"] = randf_range(40, 80 + L * 12)
		p["spd"] = (randf_range(0.6, 1.1) + L * 0.12) * DF
	if L >= 3 and randf() < 0.5:
		holes.append({"x": (last["bx"] + p["bx"]) / 2.0 + randf_range(-40, 40), "y": randf_range(40, H * 0.3) if randf() < 0.5 else randf_range(H * 0.7, H - 40), "r": randf_range(20, 30)})
	planets.append(p)


func reset() -> void:
	DF = DIFFS[diff]["f"]
	planets = [make_planet(220, H / 2, 2)]
	holes.clear()
	parts.clear()
	for i in 6:
		add_planet()
	sp_planet = planets[0]
	planets[0]["done"] = true
	mode = "orbit"
	ang = PI
	sdir = 1.0
	from_p = null
	trail.clear()
	cam = 0.0
	level = 1
	delivered = 0
	streak = 0
	gtime = 0.0
	banner = "Level 1: The inner planets"
	banner_t = 1.8
	new_best = false
	update_orbit_pos()


func update_orbit_pos() -> void:
	spos = Vector2(sp_planet["x"], sp_planet["y"]) + Vector2(cos(ang), sin(ang)) * sp_planet["orbit"]


func release() -> void:
	if mode != "orbit":
		return
	var sp := (380.0 + level * 24.0) * DF
	mode = "fly"
	update_orbit_pos()
	svel = Vector2(-sin(ang), cos(ang)) * sdir * sp
	from_p = sp_planet


func burst(p: Vector2, c: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := randf_range(60, 400)
		parts.append({"p": p, "v": Vector2(cos(a), sin(a)) * s, "life": randf_range(0.4, 0.9), "c": c})


func catch_by(p: Dictionary) -> void:
	mode = "orbit"
	sp_planet = p
	var c := Vector2(p["x"], p["y"])
	ang = (spos - c).angle()
	var tan := Vector2(-sin(ang), cos(ang))
	sdir = 1.0 if tan.dot(svel) >= 0.0 else -1.0
	if not p["done"]:
		p["done"] = true
		delivered += 1
		streak += 1
		burst(spos, Color(0.43, 0.64, 1.0), 18)
		var nl := level_for(delivered)
		if nl != level:
			level = nl
			banner = "Level %d: %s" % [level, LEVEL_NAMES[level - 1] if level <= LEVEL_NAMES.size() else "Faster, further, lonelier"]
			banner_t = 1.8
		while planets.size() < delivered + 7:
			add_planet()


func lose(reason: String) -> void:
	why = reason
	state = State.OVER
	t = 0.0
	shake(14.0)
	burst(spos, Color(1, 0.35, 0.5), 30)
	new_best = submit_score(delivered)


func on_input(event: InputEvent) -> void:
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
			set_difficulty(game_id, diff)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
			set_difficulty(game_id, diff)
	if state == State.PLAY and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_UP:
		release()


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
			if pressed_a():
				release()
			step(minf(delta, 0.04))
	for p in parts:
		p["p"] += p["v"] * delta
		p["life"] -= delta
	parts = parts.filter(func(p): return p["life"] > 0.0)
	queue_redraw()


func step(dt: float) -> void:
	gtime += dt
	for p in planets:
		if p["amp"] > 0.0:
			p["y"] = p["by"] + sin(gtime * p["spd"] + p["ph"]) * p["amp"]
	if mode == "orbit":
		ang += (2.6 + level * 0.18) * DF * sdir * dt
		update_orbit_pos()
	else:
		spos += svel * dt
		for h in holes:
			var hp := Vector2(h["x"], h["y"])
			var d := hp.distance_to(spos)
			if d < h["r"] + 8:
				lose("Eaten by a black hole")
				return
			if d < h["r"] * 7.0:
				svel += (hp - spos) / d * 1800.0 * dt / maxf(d * d / 1600.0, 1.0)
		for q in planets:
			if q == from_p:
				continue
			var dd := Vector2(q["x"], q["y"]).distance_to(spos)
			if dd < q["r"] + 6:
				lose("Crashed into " + q["name"])
				return
			if dd < q["orbit"] + 12 and dd > q["r"]:
				catch_by(q)
				break
		if spos.y < -60 or spos.y > H + 60 or spos.x < cam - 80 or spos.x > cam + W + 240:
			lose("Drifted into the void")
			return
	trail.append(spos)
	if trail.size() > 24:
		trail.pop_front()
	var target := spos.x - W * 0.32
	cam += (target - cam) * minf(1.0, dt * 4.0)


func verdict() -> String:
	if delivered >= 25:
		return "The whole galaxy came. Even Pluto, who is still bitter about the planet thing."
	if delivered >= 12:
		return "Decent turnout. Saturn brought a ring. Several, actually."
	if delivered >= 5:
		return "A small party. You have to planet better next time."
	return "Nobody came. The invitations are still orbiting."


func _draw() -> void:
	draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(0.04, 0.05, 0.1))
	for s in stars:
		var sx := fposmod(s["x"] - cam * s["z"], W)
		draw_rect(Rect2(sx, s["y"], s["s"], s["s"]), Color(0.8, 0.8, 0.9, 0.5))
	var off := Vector2(-cam, 0)
	for h in holes:
		var hp: Vector2 = Vector2(h["x"], h["y"]) + off
		for k in 6:
			draw_circle(hp, h["r"] * (4.0 - k * 0.5), Color(0.35, 0.0, 0.5, 0.08))
		draw_circle(hp, h["r"], Color(0, 0, 0))
	for p in planets:
		var pp: Vector2 = Vector2(p["x"], p["y"]) + off
		if pp.x < -200 or pp.x > W + 200:
			continue
		draw_arc(pp, p["orbit"], 0, TAU, 64, Color(0.4, 0.45, 0.6, 0.5) if p["done"] else Color(0.43, 0.64, 1.0, 0.6), 2.0)
		var col := Color.from_hsv(p["hue"], 0.5, 0.85)
		draw_circle(pp, p["r"], col)
		draw_circle(pp - Vector2(p["r"], p["r"]) * 0.35, p["r"] * 0.35, Color(1, 1, 1, 0.25))
		if p["ring"]:
			draw_set_transform(pp, -0.3, Vector2(1.0, 0.28))
			draw_arc(Vector2.ZERO, p["r"] * 1.6, 0, TAU, 40, Color.from_hsv(p["hue"], 0.4, 1.0, 0.8), 6.0)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		draw_string(font, pp + Vector2(-120, p["orbit"] + 28), p["name"] + (" (invited)" if p["done"] else ""), HORIZONTAL_ALIGNMENT_CENTER, 240, 18, Color(0.5, 0.85, 0.6) if p["done"] else Color(0.7, 0.72, 0.82))
	if trail.size() > 1:
		var pts := PackedVector2Array()
		for tr in trail:
			pts.append(tr + off)
		draw_polyline(pts, Color(1, 0.35, 0.5, 0.5), 3.0)
	if state != State.OVER:
		var a := ang + PI / 2 * sdir if mode == "orbit" else svel.angle()
		draw_set_transform(spos + off, a, Vector2(2, 2))
		draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(-6, -6), Vector2(-3, 0), Vector2(-6, 6)]), Color(1, 0.35, 0.5))
		draw_rect(Rect2(-3, -2, 5, 4), Color(1, 1, 1))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for q in parts:
		draw_rect(Rect2(q["p"] + off, Vector2(5, 5)), Color(q["c"], clampf(q["life"] / 0.9, 0, 1)))
	text(Vector2(150, 40), "Invites %d" % delivered, 30, Color(1, 1, 1))
	text(Vector2(150, 72), "Level %d   best %d" % [level, best], 22, Color(0.75, 0.75, 0.85))
	if banner_t > 0.0 and state == State.PLAY:
		text(Vector2(0, H / 2 - 120), banner, 40, Color(1, 0.4, 0.55, minf(1.0, banner_t * 2.0)), true)
	if state == State.TITLE:
		card("ORBIT COURIER", [
			"Deliver party invitations across the galaxy by slingshotting",
			"between moving planets. Let go of your orbit at the right moment",
			"to fly to the next planet. Watch out for black holes.",
			"Tap anywhere / SPACE to let go.",
			"Difficulty: %s   (change it on the start screen, or with left / right here)" % DIFFS[diff]["name"],
		], "Tap or press SPACE to start")
	elif state == State.OVER and t > 0.6:
		card(why.to_upper(), [
			"Delivered %d invitation%s (level %d)%s" % [delivered, "" if delivered == 1 else "s", level, "   NEW BEST!" if new_best else ""],
			verdict(),
		], "Tap or press SPACE to continue" if t > 0.9 else "")
	draw_overlay()


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(W / 2 - 540, 130, 1080, 450), Color(0.1, 0.11, 0.18, 0.96))
	text(Vector2(0, 210), title, 54, Color(1, 0.4, 0.55), true)
	var y := 280.0
	for l in lines:
		text(Vector2(0, y), l, 25, Color(1, 1, 1), true)
		y += 42.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 545), prompt, 30, Color(0.6, 1, 0.6), true)
