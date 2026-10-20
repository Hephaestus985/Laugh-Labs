extends ArcadeGame
# Escape Velocity: Enschede to the Moon. Bounce from a Twente rooftop to the
# Moon, dodging honking geese, space junk and meteoroids. Stroopwafels give
# a syrup-powered boost. The playfield is a 440-wide column (like the web
# version), scaled up and centred on the screen.

const K := 720.0 / 440.0
const CW := 440.0
const VH := 440.0
const OXS := (1280.0 - 440.0 * K) / 2.0
const ZL := 4000.0
const TOPY := ZL * 5.0
const ZONES := [
	{"n": "Roofs of Enschede", "tip": "Windmill sails are moving platforms. Hold on to your klompen.", "tint": Color("#79c2ff"), "k": .30, "a1": 300.0},
	{"n": "Partly Cloudy", "tip": "Clouds go POOF after one bounce. Just like your motivation.", "tint": Color("#9fb8ff"), "k": .36, "a1": 6000.0},
	{"n": "Goose Airspace", "tip": "Geese cross sideways. Stomp them from above or get HONKED.", "tint": Color("#ffb070"), "k": .36, "a1": 12000.0},
	{"n": "Stratosphere", "tip": "Space junk falls from above. Satellites drift. Look up!", "tint": Color("#1d2366"), "k": .66, "a1": 100000.0},
	{"n": "Low Earth Orbit", "tip": "Low gravity, drifting asteroids, hot meteoroids. Floaty but rude.", "tint": Color("#05071a"), "k": .84, "a1": 384400000.0},
]
const DIFFS := [
	{"name": "Easy", "gap": .84, "spd": .75, "rate": .72, "lives": 4, "pw": 1.14, "waf": 1.3},
	{"name": "Normal", "gap": 1.0, "spd": 1.0, "rate": 1.0, "lives": 3, "pw": 1.0, "waf": 1.0},
	{"name": "Hard", "gap": 1.1, "spd": 1.3, "rate": 1.32, "lives": 2, "pw": .86, "waf": .8},
]
const JUNK := ["a lost wrench", "a rejected manuscript", "an astronaut's glove", "Reviewer 2's comments", "a frozen sock", "a retired VCSEL", "someone's toaster", "a LaTeX error"]
const BG := Color("#10141b")
const LASER := Color("#ff5a82")
const BEAM := Color("#6ea4ff")
const INK := Color("#e8edf4")

enum State { TITLE, PLAY, DEAD, LANDED, OVER }
var state: int = State.TITLE
var diff := 1
var D: Dictionary
var gt := 0.0
var cam_y := -VH * 0.42
var gen_y := 0.0
var plats: Array = []
var mills: Array = []
var geese: Array = []
var junk: Array = []
var rocks: Array = []
var wafs: Array = []
var parts: Array = []
var texts: Array = []
var stars: Array = []
var lives := 3
var wafels := 0
var zone := 0
var max_y := 0.0
var banner = null
var g_t := 4.0
var j_t := 2.5
var r_t := 2.0
var flipped := false
var flip_a := 0.0
var end_t := 0.0
var dead_t := 0.0
var stomps := 0
var honks := 0
var bonks := 0
var iss_made := false
var last_mill := 300.0
var last_pl = null
var rep := 0
var result_reason := ""
var new_best := false
var p := {}
var touch_dir := 0
var touch_idx := -1


func _ready() -> void:
	game_id = "escape_velocity"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()
	diff = difficulty()
	D = DIFFS[diff]
	for i in 90:
		stars.append({"x": randf(), "y": randf() * 2000.0, "r": 1.6 if randf() < .15 else 1.0, "tw": randf() * 6.0})


# ---------------------------------------------------------------- world helpers

func zone_at(y: float) -> int:
	return clampi(int(floor(y / ZL)), 0, 4)


func alt_m(y: float) -> float:
	y = clampf(y, 0, TOPY)
	var z := zone_at(y)
	var f := clampf((y - z * ZL) / ZL, 0, 1)
	if z == 0:
		return 12.0 + (ZONES[0]["a1"] - 12.0) * f
	var a0: float = ZONES[z - 1]["a1"]
	var a1: float = ZONES[z]["a1"]
	return a0 * pow(a1 / a0, f)


func fmt_alt(m: float) -> String:
	if m < 1000:
		return "%d m" % roundi(m)
	var km := m / 1000.0
	if km < 10:
		return "%.2f km" % km
	if km < 100:
		return "%.1f km" % km
	var s := str(roundi(km))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out + " km"


func GR(z: int) -> float:
	return 760.0 if z >= 4 else 1500.0


func V0(z: int) -> float:
	return 640.0 if z >= 4 else 760.0


func max_j(z: int) -> float:
	return V0(z) * V0(z) / (2.0 * GR(z))


func Y(y: float) -> float:
	return VH - (y - cam_y)


# ---------------------------------------------------------------- setup

func new_game() -> void:
	D = DIFFS[diff]
	gt = 0.0
	cam_y = -VH * 0.42
	gen_y = 0.0
	plats.clear()
	mills.clear()
	geese.clear()
	junk.clear()
	rocks.clear()
	wafs.clear()
	parts.clear()
	texts.clear()
	lives = D["lives"]
	wafels = 0
	zone = 0
	max_y = 0.0
	g_t = 4.0
	j_t = 2.5
	r_t = 2.0
	flipped = false
	flip_a = 0.0
	end_t = 0.0
	dead_t = 0.0
	stomps = 0
	honks = 0
	bonks = 0
	iss_made = false
	last_mill = 300.0
	last_pl = null
	rep = 0
	new_best = false
	p = {"x": CW / 2, "y": 0.0, "vx": 0.0, "vy": V0(0), "face": 1.0, "sq": 0.0, "stun": 0.0, "inv": 0.0, "boost": 0.0}
	plats.append({"type": "floor", "x": 0.0, "y": 0.0, "py": 0.0, "w": CW, "vx": 0.0, "dead": false, "seed": 0.0})
	gen()
	set_banner(0)
	state = State.PLAY


func add_plat(type: String, x: float, y: float, w: float, vx := 0.0) -> Dictionary:
	var q := {"type": type, "x": x, "y": y, "py": y, "w": w, "vx": vx, "dead": false, "seed": randf()}
	plats.append(q)
	return q


func rsign() -> float:
	return -1.0 if randf() < .5 else 1.0


func gen() -> void:
	while gen_y < cam_y + VH + 260:
		var y0 := gen_y
		var z := zone_at(y0 + 60)
		if y0 > TOPY - 330:
			gen_y = 1e12
			break
		var mj := max_j(z)
		var gmin: float = [64, 74, 80, 86, 110][z]
		var gmax: float = [112, 128, 134, 142, 200][z]
		var gap := minf(randf_range(gmin, gmax) * D["gap"], mj * .8)
		if z == 0 and y0 - last_mill > 650 and y0 > 380 and y0 < ZL - 400 and randf() < .55:
			make_mill(y0)
			continue
		var y := y0 + gap
		var w := roundf([66, 70, 66, 70, 74][z] * D["pw"] * randf_range(.92, 1.08))
		var x := randf_range(0, CW - w)
		var type := "roof"
		var vx := 0.0
		var r := randf()
		if z == 0:
			if y > 1600 and r < .18:
				type = "bike"
				vx = randf_range(40, 70) * rsign() * D["spd"]
		elif z == 1:
			type = "cloud" if r < .58 else "balloon"
		elif z == 2:
			type = "cloud" if r < .35 else ("bike" if r < .55 else "balloon")
			if type == "bike":
				vx = randf_range(45, 80) * rsign() * D["spd"]
		elif z == 3:
			type = "sat" if r < .5 else "wball"
			if type == "sat":
				vx = randf_range(35, 75) * rsign() * D["spd"]
		else:
			type = "rock"
			vx = randf_range(20, 60) * rsign() * D["spd"] if r < .75 else 0.0
			if not iss_made and y > ZL * 4 + ZL * .45:
				iss_made = true
				type = "iss"
				w = minf(CW - 20, 150)
				x = (CW - w) / 2
				vx = 0.0
		var pl := add_plat(type, x, y, w, vx)
		if y > 500 and type != "cloud" and randf() < .032 * D["waf"]:
			wafs.append({"x": x + w / 2, "y": y + 26, "pl": pl, "t": randf() * 6.0, "taken": false})
		gen_y = y


func make_mill(y0: float) -> void:
	var R := 80.0
	var cy := y0 + R + 68
	var cx := randf_range(R + 30, CW - R - 30)
	var m := {"cx": cx, "cy": cy, "R": R, "a": randf() * TAU, "w": rsign() * randf_range(.75, 1.05) * D["spd"], "tips": []}
	for i in 4:
		var tp := add_plat("tip", 0, cy, 48)
		tp["mill"] = m
		tp["i"] = i
		m["tips"].append(tp)
	place_tips(m, true)
	mills.append(m)
	gen_y = cy + R + 52
	last_mill = gen_y


func place_tips(m: Dictionary, init: bool) -> void:
	for i in 4:
		var tp: Dictionary = m["tips"][i]
		var a: float = m["a"] + i * PI / 2
		tp["py"] = m["cy"] + sin(a) * m["R"] if init else tp["y"]
		tp["x"] = m["cx"] + cos(a) * m["R"] - tp["w"] / 2
		tp["y"] = m["cy"] + sin(a) * m["R"]


func say(x: float, y: float, s: String, c: Color, big := false) -> void:
	texts.append({"x": x, "y": y, "s": s, "t": 0.0, "c": c, "big": big})


func burst(x: float, y: float, n: int, c: Color, sp: float, life: float, g := 0.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := randf_range(.3, 1) * sp
		parts.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v, "t": 0.0, "life": life * randf_range(.6, 1.2), "c": c, "r": randf_range(1.5, 3.5), "g": g})


func set_banner(z: int) -> void:
	banner = {"z": z, "t": 0.0}
	if z > 0:
		shake(4.0)


# ---------------------------------------------------------------- input

func on_input(event: InputEvent) -> void:
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
			set_difficulty(game_id, diff)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
			set_difficulty(game_id, diff)
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_idx = event.index
			touch_dir = -1 if event.position.x < W / 2 else 1
		elif event.index == touch_idx:
			touch_idx = -1
			touch_dir = 0
	elif event is InputEventScreenDrag and event.index == touch_idx:
		touch_dir = -1 if event.position.x < W / 2 else 1
	elif event is InputEventMouseButton and not is_mobile and event.button_index == MOUSE_BUTTON_LEFT:
		touch_dir = (-1 if event.position.x < W / 2 else 1) if event.pressed else 0


func input_dir() -> float:
	var d := axis().x
	if absf(d) > 0.2:
		return signf(d)
	return float(touch_dir)


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	tick(delta)
	match state:
		State.TITLE:
			gt += delta
			if pressed_b():
				diff = (diff + 1) % 3
				set_difficulty(game_id, diff)
			if start_pressed():
				new_game()
				clear_presses()
		State.OVER:
			gt += delta
			if start_pressed() and t > 1.0:
				state = State.TITLE
				cam_y = -VH * 0.42
		_:
			clear_presses()
			update(minf(delta, 0.04))
	queue_redraw()


func hurt(kind: String, dir: float, obj: Dictionary) -> bool:
	if p["inv"] > 0.0 or p["boost"] > 0.0:
		return false
	p["stun"] = .5
	p["inv"] = .9
	shake(8.0)
	if kind == "goose":
		p["vx"] = dir * 430.0
		p["vy"] = minf(p["vy"], -140.0)
		honks += 1
		say(p["x"], p["y"] + 44, ["HONK!", "HONK HONK!", "Honked!", "*hostile honk*"][randi() % 4], LASER, true)
	else:
		p["vx"] = obj.get("vx", 0.0) + (-220.0 if p["x"] < obj["x"] else 220.0)
		p["vy"] = minf(p["vy"], -260.0)
		bonks += 1
		say(p["x"], p["y"] + 44, "Meteoroid'd!" if kind == "rock" else "Bonk! (%s)" % obj["label"], LASER)
	burst(p["x"], p["y"] + 20, 10, Color(1, 1, 1), 160, .5)
	return true


func overlaps_x(cx: float, hw: float, x: float, w: float) -> bool:
	for k in [-1, 0, 1]:
		var q: float = cx + k * CW
		if q + hw > x and q - hw < x + w:
			return true
	return false


func wdx(a: float, b: float) -> float:
	var d := a - b
	if d > CW / 2:
		d -= CW
	if d < -CW / 2:
		d += CW
	return d


func update(dt: float) -> void:
	gt += dt
	var z_now := zone_at(p["y"])
	var G := GR(z_now)
	var V := V0(z_now)
	if state == State.PLAY:
		var dir := 0.0 if p["stun"] > 0.0 else input_dir()
		if dir != 0.0:
			p["vx"] += dir * 2400.0 * dt
			p["face"] = dir
		else:
			p["vx"] *= pow(.0009, dt)
		if p["stun"] <= 0.0:
			p["vx"] = clampf(p["vx"], -340, 340)
		else:
			p["vx"] *= pow(.2, dt)
		p["x"] += p["vx"] * dt
		if p["x"] < 0:
			p["x"] += CW
		if p["x"] >= CW:
			p["x"] -= CW
		var prev_y: float = p["y"]
		if flipped:
			p["vy"] = minf(p["vy"] + 700.0 * dt, 620.0)
			p["y"] += p["vy"] * dt
			flip_a = minf(PI, flip_a + dt * 4.0)
			if p["y"] + 36 >= TOPY:
				p["y"] = TOPY - 36
				state = State.LANDED
				if banner != null:
					banner["t"] = maxf(banner["t"], 3.0)
				end_t = 0.0
				burst(p["x"], TOPY, 30, Color("#cfd2d8"), 160, 1, -60)
				shake(10.0)
				say(p["x"], TOPY - 80, "TOUCHDOWN!", LASER, true)
		elif p["boost"] > 0.0:
			p["boost"] -= dt
			p["vy"] = 980.0
			p["y"] += p["vy"] * dt
			if randf() < .9:
				parts.append({"x": p["x"] + randf_range(-5, 5), "y": p["y"] + 4, "vx": randf_range(-30, 30), "vy": -randf_range(80, 180), "t": 0.0, "life": .6, "c": Color("#c47a22") if randf() < .5 else Color("#f2c46d"), "r": randf_range(2, 4), "g": 0.0})
		else:
			p["vy"] -= G * dt
			p["y"] += p["vy"] * dt
			if p["vy"] <= 0.0:
				var best_pl: Variant = null
				for pl in plats:
					if pl["dead"]:
						continue
					if prev_y >= pl["py"] - .5 and p["y"] <= pl["y"] + .5 and overlaps_x(p["x"], 11, pl["x"], pl["w"]) and (best_pl == null or pl["y"] > best_pl["y"]):
						best_pl = pl
				if best_pl != null:
					land_on(best_pl, V)
		if not flipped and p["y"] > TOPY - 270 and state == State.PLAY:
			flipped = true
			p["boost"] = 0.0
			banner = {"z": 5, "t": 0.0}
			say(p["x"], p["y"] + 60, "Lunar gravity! Fall UP!", BEAM, true)
	elif state == State.DEAD:
		p["vy"] -= G * dt
		p["y"] += p["vy"] * dt
		dead_t += dt
		if dead_t > 1.0:
			finish("fall")
	elif state == State.LANDED:
		end_t += dt
		flip_a = minf(PI, flip_a + dt * 5.0)
		if end_t > 3.6:
			finish("moon")
	p["sq"] = maxf(0.0, p["sq"] - dt * 5.0)
	p["stun"] -= dt
	p["inv"] -= dt
	if state == State.PLAY:
		max_y = maxf(max_y, minf(p["y"], TOPY))
	var nz := zone_at(max_y)
	if nz > zone:
		zone = nz
		set_banner(nz)
	if flipped:
		cam_y = lerpf(cam_y, TOPY - VH + 130, minf(1.0, dt * 2.5))
	elif state != State.DEAD:
		cam_y = maxf(cam_y, p["y"] - VH * .42)
	if state == State.PLAY and not flipped and p["y"] < cam_y - 40:
		lives -= 1
		shake(8.0)
		if lives > 0:
			var rp := add_plat("rescue", CW / 2 - 45, cam_y + VH * .22, 90)
			rp["life"] = 6.0
			p["x"] = CW / 2
			p["y"] = rp["y"]
			p["vy"] = V * 1.05
			p["vx"] = 0.0
			p["inv"] = 2.2
			p["stun"] = 0.0
			say(CW / 2, rp["y"] + 70, "Rescue blimp! %d %s left" % [lives, "life" if lives == 1 else "lives"], LASER, true)
		else:
			state = State.DEAD
			dead_t = 0.0
			p["vy"] = 0.0
	for m in mills:
		m["a"] += m["w"] * dt
		place_tips(m, false)
	for q in plats:
		if q["type"] != "tip":
			q["py"] = q["y"]
		if q["vx"] != 0.0:
			q["x"] += q["vx"] * dt
			if q["x"] < 0:
				q["x"] = 0.0
				q["vx"] = -q["vx"]
			if q["x"] + q["w"] > CW:
				q["x"] = CW - q["w"]
				q["vx"] = -q["vx"]
		if q["type"] == "rescue":
			q["life"] -= dt
			if q["life"] < 0:
				q["dead"] = true
	plats = plats.filter(func(q): return not q["dead"] and q["y"] > cam_y - 160)
	mills = mills.filter(func(m): return m["cy"] + m["R"] > cam_y - 160)
	if gen_y < 1e11:
		gen()
	for w in wafs:
		w["t"] += dt
		if w["pl"] != null and not w["pl"]["dead"]:
			w["x"] = w["pl"]["x"] + w["pl"]["w"] / 2
			w["y"] = w["pl"]["y"] + 26
		if state == State.PLAY and not flipped and absf(wdx(w["x"], p["x"])) < 22 and absf(w["y"] - (p["y"] + 16)) < 26:
			w["taken"] = true
			wafels += 1
			p["boost"] = .85
			p["stun"] = 0.0
			p["inv"] = maxf(p["inv"], 1.1)
			say(p["x"], p["y"] + 50, ["SYRUP DRIVE!", "Stroopwafel-powered!", "Caramel thrust!", "Sticky ascent!"][randi() % 4], LASER, true)
			burst(w["x"], w["y"], 14, Color("#d79a3c"), 150, .6)
	wafs = wafs.filter(func(w): return not w["taken"] and w["y"] > cam_y - 100)
	var hz := zone_at(cam_y + VH * .6)
	var near_top := cam_y + VH > TOPY - 450
	if state == State.PLAY and not near_top:
		var grate: float = [0, 0, 1, .22, .16][hz]
		if grate > 0:
			g_t -= dt * grate * D["rate"]
			if g_t <= 0:
				g_t = randf_range(1.8, 3.2)
				spawn_goose(hz >= 4)
		var jr: float = [0, 0, 0, 1, .45][hz]
		if jr > 0:
			j_t -= dt * jr * D["rate"]
			if j_t <= 0:
				j_t = randf_range(1.3, 2.3)
				spawn_junk()
		if hz == 4:
			r_t -= dt * D["rate"]
			if r_t <= 0:
				r_t = randf_range(1.6, 2.6)
				spawn_rock()
	update_hazards(dt, V)
	for q in parts:
		q["t"] += dt
		q["vy"] += q["g"] * dt
		q["x"] += q["vx"] * dt
		q["y"] += q["vy"] * dt
	parts = parts.filter(func(q): return q["t"] < q["life"])
	for x in texts:
		x["t"] += dt
		x["y"] += 30.0 * dt
	texts = texts.filter(func(x): return x["t"] < 1.6)
	if banner != null:
		banner["t"] += dt
		if banner["t"] > 3.6:
			banner = null


func land_on(best_pl: Dictionary, V: float) -> void:
	p["y"] = best_pl["y"]
	p["vy"] = V
	p["sq"] = 1.0
	if best_pl == last_pl:
		rep += 1
	else:
		last_pl = best_pl
		rep = 1
	var bt: String = best_pl["type"]
	if bt != "cloud" and bt != "rescue":
		if rep == 4:
			say(p["x"], p["y"] + 60, "Landlord: \"Get off my roof!\"" if bt == "floor" else "This platform is getting tired...", LASER, true)
		if rep >= 5:
			best_pl["dead"] = true
			say(p["x"], p["y"] + 60, "Roof access revoked." if bt == "floor" else "Platform fatigue! Keep climbing.", LASER, true)
			burst(best_pl["x"] + best_pl["w"] / 2, best_pl["y"], 18, Color("#c9ccd3") if bt == "sat" else Color("#b8452f"), 150, .7, -300)
	if bt == "cloud":
		best_pl["dead"] = true
		burst(best_pl["x"] + best_pl["w"] / 2, best_pl["y"] - 6, 16, Color(1, 1, 1), 120, .6)
		if randf() < .25:
			say(best_pl["x"] + best_pl["w"] / 2, best_pl["y"] + 20, ["poof", "so long!", "*evaporates*"][randi() % 3], Color(0.7, 0.72, 0.8))
	else:
		burst(p["x"], p["y"], 4, Color("#aaaabb") if (bt == "rock" or bt == "iss") else Color("#dddddd"), 60, .3, -200)
	if bt == "tip" and randf() < .2:
		say(p["x"], p["y"] + 50, ["Wheee-mill!", "Sail away!", "Lekker draaien"][randi() % 3], BEAM)


func update_hazards(dt: float, V: float) -> void:
	for g in geese:
		g["f"] += dt * (20.0 if g["state"] == "fall" else 9.0)
		if g["warn"] > 0.0:
			g["warn"] -= dt
			g["y"] = cam_y + g["sy"]
			continue
		if g["state"] == "fall":
			g["vy"] -= 1200.0 * dt
			g["y"] += g["vy"] * dt
			g["x"] += g["dir"] * 40.0 * dt
			g["rot"] += dt * 8.0
			continue
		g["x"] += g["dir"] * g["spd"] * dt
		g["y"] += sin(gt * 3.0 + g["ph"]) * 14.0 * dt
		if state == State.PLAY and g["x"] > -10 and g["x"] < CW + 10:
			var dx := wdx(g["x"], p["x"])
			var dy: float = (p["y"] + 16) - g["y"]
			if absf(dx) < 26 and absf(dy) < 26:
				if p["vy"] < 0 and p["y"] > g["y"] - 2 and not flipped:
					g["state"] = "fall"
					g["vy"] = 150.0
					g["rot"] = 0.0
					p["vy"] = V * 1.12
					p["sq"] = 1.0
					stomps += 1
					say(g["x"], g["y"] + 30, ["*offended honk*", "Goose: stomped", "Gans down!", "HO--nk?"][randi() % 4], BEAM, true)
					burst(g["x"], g["y"], 10, Color(1, 1, 1), 130, .6)
				else:
					hurt("goose", g["dir"], g)
	geese = geese.filter(func(g): return g["warn"] > 0.0 or (g["x"] > -90 and g["x"] < CW + 90 and g["y"] > cam_y - 120))
	for j in junk:
		if j["warn"] > 0.0:
			j["warn"] -= dt
			if j["warn"] <= 0.0:
				j["y"] = cam_y + VH + 24
			continue
		j["x"] += j["vx"] * dt
		j["y"] += j["vy"] * dt
		j["rot"] += j["vr"] * dt
		if j["x"] < -20:
			j["x"] += CW + 40
		if j["x"] > CW + 20:
			j["x"] -= CW + 40
		if state == State.PLAY and absf(wdx(j["x"], p["x"])) < j["r"] + 10 and absf((p["y"] + 16) - j["y"]) < j["r"] + 15:
			hurt("junk", 0, j)
	junk = junk.filter(func(j): return j["warn"] > 0.0 or j["y"] > cam_y - 60)
	for r in rocks:
		if r["warn"] > 0.0:
			r["warn"] -= dt
			r["y"] = cam_y + r["sy"]
			continue
		r["x"] += r["vx"] * dt
		r["y"] += r["vy"] * dt
		r["rot"] += dt * 2.0
		if randf() < .5:
			parts.append({"x": r["x"] - signf(r["vx"]) * r["r"], "y": r["y"] + randf_range(-3, 3), "vx": -r["vx"] * .3, "vy": randf_range(-10, 10), "t": 0.0, "life": .4, "c": Color("#ff8a3d") if randf() < .5 else Color("#ffd27a"), "r": randf_range(1.5, 3), "g": 0.0})
		if state == State.PLAY and r["x"] > -5 and r["x"] < CW + 5 and absf(wdx(r["x"], p["x"])) < r["r"] + 9 and absf((p["y"] + 16) - r["y"]) < r["r"] + 14:
			hurt("rock", 0, r)
	rocks = rocks.filter(func(r): return r["warn"] > 0.0 or (r["x"] > -60 and r["x"] < CW + 60 and r["y"] > cam_y - 100))


func spawn_goose(astro: bool) -> void:
	var dir := rsign()
	var sy := randf_range(150, VH - 50)
	var spd: float = randf_range(95, 150) * D["spd"]
	var n := 3 if (not astro and randf() < .28) else 1
	for k in n:
		var off := 0.0 if k == 0 else (-22.0 if k == 1 else 22.0)
		geese.append({"x": -30.0 - k * 34 if dir > 0 else CW + 30.0 + k * 34, "sy": sy + off, "y": 0.0, "dir": dir, "spd": spd, "warn": 1.1, "f": randf() * 6, "ph": randf() * 6, "state": "fly", "astro": astro, "lead": k == 0, "n": n, "vy": 0.0, "rot": 0.0})
	if n == 3:
		say(CW / 2, cam_y + sy + 40, "V-formation! The V stands for Violence", LASER)


func spawn_junk() -> void:
	var k := randi() % JUNK.size()
	junk.append({"x": randf_range(14, CW - 14), "y": 0.0, "vx": randf_range(-30, 30), "vy": -randf_range(150, 225) * D["spd"], "rot": 0.0, "vr": randf_range(-3, 3), "r": 11.0, "kind": k, "label": JUNK[k], "warn": .95})


func spawn_rock() -> void:
	var dir := rsign()
	rocks.append({"x": -24.0 if dir > 0 else CW + 24, "sy": randf_range(130, VH - 40), "y": 0.0, "vx": dir * randf_range(80, 125) * D["spd"], "vy": randf_range(-25, 25), "r": randf_range(8, 13), "rot": 0.0, "warn": .85, "seed": randf()})


func finish(reason: String) -> void:
	if state == State.OVER:
		return
	result_reason = reason
	var alt := 384400000.0 if reason == "moon" else alt_m(max_y)
	new_best = submit_score(int(alt))
	state = State.OVER
	t = 0.0


# ---------------------------------------------------------------- drawing

func sky_at(y: float) -> Color:
	var zf := clampf(y / ZL, 0, 4.999)
	var z := int(zf)
	var f := zf - z
	var c: Color = BG.lerp(ZONES[z]["tint"], ZONES[z]["k"] * (0.55 if z < 3 else 1.0))
	if f > .7 and z < 4:
		var c2: Color = BG.lerp(ZONES[z + 1]["tint"], ZONES[z + 1]["k"] * (0.55 if z + 1 < 3 else 1.0))
		c = c.lerp(c2, (f - .7) / .3)
	return c


func world() -> void:
	draw_set_transform(Vector2(OXS, 0), 0, Vector2(K, K))


func at(pos: Vector2, rot := 0.0, sc := Vector2.ONE) -> void:
	draw_set_transform(Vector2(OXS, 0) + pos * K, rot, sc * K)


func screen() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw() -> void:
	screen()
	var top_c := sky_at(cam_y + VH + 300)
	var bot_c := sky_at(cam_y)
	for i in 24:
		draw_rect(Rect2(-40, i * 32 - 40, W + 80, 34), top_c.lerp(bot_c, i / 23.0))
	world()
	var sa := clampf((cam_y - ZL * 2.6) / (ZL * .8), 0, 1)
	sa = maxf(sa, clampf((cam_y - ZL * 1.5) / ZL, 0, .5))
	if sa > 0:
		for st in stars:
			var yy := fposmod(st["y"] - cam_y * .08, 2000.0)
			if yy > VH:
				continue
			draw_rect(Rect2(st["x"] * (W / K) - OXS / K, yy, st["r"], st["r"]), Color(1, 1, 1, sa * (.55 + .45 * sin(gt * 2.0 + st["tw"]))))
	var e := clampf((cam_y - ZL * 3) / (TOPY - ZL * 3 - 400), 0, 1)
	if e > 0:
		var mr := lerpf(9, 70, e * e)
		var mc := Vector2(CW * .78, lerpf(90, 40, e))
		var ma := minf(1.0, e * 4) * (1.0 - clampf((cam_y - (TOPY - 700)) / 300.0, 0, 1))
		draw_circle(mc, mr, Color("#e9e6d6", ma))
		draw_circle(mc + Vector2(-.3, -.2) * mr, .22 * mr, Color("#cfcab4", ma))
		draw_circle(mc + Vector2(.25, .15) * mr, .18 * mr, Color("#cfcab4", ma))
	var ea := clampf((cam_y - ZL * 3.2) / ZL, 0, 1)
	if ea > 0:
		var er := lerpf(2400, 260, ea)
		var ey := VH + er - lerpf(36, 58, ea)
		var al := minf(1.0, ea * 3) * (1.0 - clampf((cam_y - (TOPY - 900)) / 400.0, 0, 1))
		draw_circle(Vector2(CW / 2, ey), er, Color("#4fa3e8", al))
		draw_circle(Vector2(CW / 2, ey), er * .96, Color("#1f5fae", al))
	var ca := 1.0 - clampf((cam_y - ZL * 2.6) / ZL, 0, 1)
	if ca > 0:
		for k in 6:
			var by := fposmod(k * 173 - cam_y * .3, 640.0) - 100
			var bx := float((k * 211) % 440) - 40
			cloud_shape(Vector2(bx, by), 40 + k % 3 * 12, Color(1, 1, 1, .07 * ca))
	if cam_y < 1400:
		draw_floor()
	for m in mills:
		draw_mill(m)
	for q in plats:
		draw_plat(q)
	draw_moon()
	for w in wafs:
		draw_wafel(w)
	for j in junk:
		if j["warn"] <= 0.0:
			draw_junk(j)
	for r in rocks:
		if r["warn"] <= 0.0:
			draw_rock(r)
	for g in geese:
		if g["warn"] <= 0.0:
			draw_goose(g)
	if state != State.TITLE:
		var jx: float = p["x"]
		var jy := Y(p["y"])
		draw_john(jx, jy)
		if jx < 20:
			draw_john(jx + CW, jy)
		if jx > CW - 20:
			draw_john(jx - CW, jy)
	for q in parts:
		draw_rect(Rect2(q["x"] - q["r"] / 2, Y(q["y"]) - q["r"] / 2, q["r"], q["r"]), Color(q["c"], clampf(1.0 - q["t"] / q["life"], 0, 1)))
	if state == State.LANDED:
		draw_landed()
	for g in geese:
		if g["warn"] > 0.0 and g["lead"]:
			var ex := 16.0 if g["dir"] > 0 else CW - 62.0
			draw_rect(Rect2(ex, Y(g["y"]) - 10, 46, 20), Color(LASER, .6 + .4 * sin(g["warn"] * 20.0)))
			draw_string(font, Vector2(ex, Y(g["y"]) + 5), "HONKx3" if g["n"] > 1 else "HONK!", HORIZONTAL_ALIGNMENT_CENTER, 46, 11, Color(1, 1, 1))
	for j in junk:
		if j["warn"] > 0.0:
			var a := .55 + .45 * sin(j["warn"] * 22.0)
			draw_colored_polygon(PackedVector2Array([Vector2(j["x"], 62), Vector2(j["x"] - 10, 80), Vector2(j["x"] + 10, 80)]), Color(LASER, a))
			draw_string(font, Vector2(j["x"] - 5, 78), "!", HORIZONTAL_ALIGNMENT_CENTER, 10, 12, Color(1, 1, 1, a))
	for r in rocks:
		if r["warn"] > 0.0:
			var ex := 14.0 if r["vx"] > 0 else CW - 14.0
			var y0 := Y(r["y"])
			var s := 1.0 if r["vx"] > 0 else -1.0
			draw_colored_polygon(PackedVector2Array([Vector2(ex + 10 * s, y0), Vector2(ex - 6 * s, y0 - 9), Vector2(ex - 6 * s, y0 + 9)]), Color("#ff8a3d", .55 + .45 * sin(r["warn"] * 22.0)))
	screen()
	# column edges
	draw_rect(Rect2(-40, -40, OXS + 40, H + 80), Color(BG, .55))
	draw_rect(Rect2(OXS + CW * K, -40, OXS + 40, H + 80), Color(BG, .55))
	draw_dashed_line(Vector2(OXS, 0), Vector2(OXS, H), Color(1, 1, 1, .18), 1.0, 7.0)
	draw_dashed_line(Vector2(OXS + CW * K, 0), Vector2(OXS + CW * K, H), Color(1, 1, 1, .18), 1.0, 7.0)
	for x in texts:
		var a := clampf(1.6 - x["t"], 0, 1)
		var sx := OXS + clampf(x["x"], 70, CW - 70) * K
		var fs := 24 if x["big"] else 19
		var sy := Y(x["y"]) * K
		draw_string_outline(font, Vector2(sx - 300, sy), x["s"], HORIZONTAL_ALIGNMENT_CENTER, 600, fs, 6, Color(0.05, 0.05, 0.1, a))
		draw_string(font, Vector2(sx - 300, sy), x["s"], HORIZONTAL_ALIGNMENT_CENTER, 600, fs, Color(x["c"], a))
	if state == State.TITLE:
		card("ESCAPE VELOCITY", [
			"Bounce from a Twente rooftop to the Moon, dodging honking geese,",
			"space junk and meteoroids. Stroopwafels give a syrup boost.",
			"Stomp geese from above. Hold the left or right side of the screen to steer.",
			"Difficulty: %s   (change it on the start screen, or with left / right here)" % DIFFS[diff]["name"],
		], "Tap or press SPACE to launch")
	elif state == State.OVER:
		draw_hud()
		var z := 5 if result_reason == "moon" else zone_at(max_y)
		var titles := ["Roof Pigeon", "Cloud Casualty", "Honked Out", "Space Junk", "Nearly Lunar", "Moon Goose"]
		var verds := [
			"Didn't clear the rooftops. The pigeons of Enschede are talking about you.",
			"Lost in the clouds. Very on-brand for a PhD student.",
			"Honked out of the sky. The geese have filed this under 'wins'.",
			"Bonked by space junk. You are now, technically, also space junk.",
			"So close to the Moon you could smell the cheese. Houston, we have a gouda problem.",
			"Moon landing achieved (upside down). NASA is drafting a strongly worded email.",
		]
		card(titles[z].to_upper(), [
			("384,400 km: landed on the Moon (upside down)" if result_reason == "moon" else "Reached %s in %s" % [fmt_alt(alt_m(max_y)), ZONES[mini(z, 4)]["n"]]) + ("   NEW BEST!" if new_best else ""),
			verds[z],
			"Stroopwafels %d   Geese stomped %d   Honked %d   Junk bonks %d" % [wafels, stomps, honks, bonks],
		], "Tap or press SPACE to continue" if t > 1.0 else "")
	else:
		draw_hud()
	draw_overlay()


func cloud_shape(pos: Vector2, s: float, c: Color) -> void:
	draw_circle(pos, s * .35, c)
	draw_circle(pos + Vector2(s * .35, -s * .12), s * .3, c)
	draw_circle(pos + Vector2(s * .7, 0), s * .3, c)
	draw_rect(Rect2(pos + Vector2(0, -s * .05), Vector2(s * .7, s * .35)), c)


func draw_floor() -> void:
	var y := Y(0)
	if y > VH + 10:
		return
	var cols := [Color("#b6503c"), Color("#8f4a35"), Color("#c9744f"), Color("#7a4b3a"), Color("#a3593f")]
	var hw := 46.0
	for i in int(ceil(CW / hw)) + 1:
		var x := i * hw
		if x >= CW:
			break
		draw_rect(Rect2(x, y + 14, hw - 2, 200), cols[i % 5])
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 14), Vector2(x + 4, y + 14), Vector2(x + 4, y + 4), Vector2(x + 10, y + 4), Vector2(x + 10, y - 4), Vector2(x + hw - 12, y - 4), Vector2(x + hw - 12, y + 4), Vector2(x + hw - 6, y + 4), Vector2(x + hw - 6, y + 14), Vector2(x + hw - 2, y + 14), Vector2(x + hw - 2, y + 16), Vector2(x, y + 16)]), cols[i % 5])
		for r in 3:
			for c in 2:
				draw_rect(Rect2(x + 9 + c * 16, y + 26 + r * 30, 9, 14), Color("#f6e7b0"))
	draw_rect(Rect2(0, y - 4, CW, 4), Color("#5b3a2c"))
	draw_rect(Rect2(CW / 2 - 52, y + 40, 104, 20), Color("#1d4f91"))
	draw_string(font, Vector2(CW / 2 - 52, y + 54), "ENSCHEDE  0 km", HORIZONTAL_ALIGNMENT_CENTER, 104, 11, Color(1, 1, 1))


func draw_mill(m: Dictionary) -> void:
	var cx: float = m["cx"]
	var cy := Y(m["cy"])
	if cy < -120 or cy > VH + 260:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, cy + 4), Vector2(cx + 14, cy + 4), Vector2(cx + 30, cy + 260), Vector2(cx - 30, cy + 260)]), Color("#6b4a35"))
	draw_circle(Vector2(cx, cy + 2), 17, Color("#4b3426"))
	draw_rect(Rect2(cx - 5, cy + 40, 10, 18), Color("#2f2219"))
	draw_rect(Rect2(cx - 6, cy + 110, 12, 20), Color("#2f2219"))
	for i in 4:
		var a: float = m["a"] + i * PI / 2
		at(Vector2(cx, cy), atan2(-sin(a), cos(a)))
		draw_line(Vector2.ZERO, Vector2(m["R"], 0), Color("#3d2c21"), 3.0)
		draw_rect(Rect2(14, 2, m["R"] - 22, 11), Color(0.94, 0.91, 0.84, .85))
		world()
	draw_circle(Vector2(cx, cy), 5, Color("#2f2219"))


func draw_plat(q: Dictionary) -> void:
	var x: float = q["x"]
	var y := Y(q["y"])
	var w: float = q["w"]
	if y < -60 or y > VH + 60:
		return
	match q["type"]:
		"roof":
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, y), Vector2(x + w - 4, y), Vector2(x + w, y + 10), Vector2(x, y + 10)]), Color("#b8452f"))
			var k := x + 8
			while k < x + w - 4:
				draw_line(Vector2(k, y + 1), Vector2(k, y + 10), Color(0, 0, 0, .25), 1.0)
				k += 8
			draw_rect(Rect2(x + w * .7, y - 9, 7, 9), Color("#8b2f1f"))
		"tip":
			draw_rect(Rect2(x, y, w, 8), Color("#8a5a35"))
			draw_rect(Rect2(x + 4, y + 2, w - 8, 2), Color("#d8423a"))
		"bike":
			var bc := Color("#2b2f3a")
			draw_arc(Vector2(x + 12, y + 11), 9, 0, TAU, 16, bc, 2.5)
			draw_arc(Vector2(x + w - 12, y + 11), 9, 0, TAU, 16, bc, 2.5)
			draw_polyline(PackedVector2Array([Vector2(x + 12, y + 11), Vector2(x + w / 2, y + 2), Vector2(x + w - 12, y + 11)]), bc, 2.5)
			draw_rect(Rect2(x + 4, y - 3, w - 8, 5), Color("#1f7a4d"))
		"cloud":
			var c := Color(1, 1, 1, .95)
			draw_circle(Vector2(x + w * .25, y + 7), 10, c)
			draw_circle(Vector2(x + w * .5, y + 2), 13, c)
			draw_circle(Vector2(x + w * .75, y + 7), 10, c)
			draw_rect(Rect2(x, y + 3, w, 12), c)
			draw_rect(Rect2(x + w * .4, y + 5, 2, 2), Color(.24, .27, .4, .55))
			draw_rect(Rect2(x + w * .58, y + 5, 2, 2), Color(.24, .27, .4, .55))
		"balloon", "wball":
			var big: bool = q["type"] == "balloon"
			draw_line(Vector2(x + 6, y), Vector2(x + w / 2 - (16 if big else 6), y - (30 if big else 24)), Color(.24, .16, .12, .7), 1.0)
			draw_line(Vector2(x + w - 6, y), Vector2(x + w / 2 + (16 if big else 6), y - (30 if big else 24)), Color(.24, .16, .12, .7), 1.0)
			if big:
				var bcol: Color = [Color("#e4572e"), Color("#f3a712"), Color("#3b8ea5"), Color("#7d5ba6")][int(q["seed"] * 4) % 4]
				at(Vector2(x + w / 2, y - 54), 0, Vector2(1.0, 1.25))
				draw_circle(Vector2.ZERO, 22, bcol)
				draw_rect(Rect2(-5, -20, 10, 40), Color(1, 1, 1, .3))
				world()
			else:
				draw_circle(Vector2(x + w / 2, y - 34), 13, Color(.98, .98, .98, .92))
			draw_rect(Rect2(x, y, w, 9), Color("#8a5a35") if big else Color("#c9ccd3"))
		"sat":
			draw_rect(Rect2(x, y + 1, w * .3, 9), Color("#2f5fb8"))
			draw_rect(Rect2(x + w * .7, y + 1, w * .3, 9), Color("#2f5fb8"))
			draw_rect(Rect2(x + w * .3, y - 2, w * .4, 14), Color("#c9ccd3"))
			draw_rect(Rect2(x + w * .3, y - 2, w * .4, 3), Color("#e8b93a"))
		"rock":
			draw_colored_polygon(PackedVector2Array([Vector2(x, y + 2), Vector2(x + w * .15, y - 1), Vector2(x + w * .85, y - 1), Vector2(x + w, y + 3), Vector2(x + w * .85, y + 13), Vector2(x + w * .5, y + 17), Vector2(x + w * .15, y + 12)]), Color("#8a8478"))
			draw_circle(Vector2(x + w * .3, y + 7), 3, Color("#6c675d"))
			draw_circle(Vector2(x + w * .65, y + 9), 4, Color("#6c675d"))
		"iss":
			draw_rect(Rect2(x, y, w, 5), Color("#c9ccd3"))
			for k3 in 4:
				draw_rect(Rect2(x + 6 + k3 * (w - 20) / 3, y - 14, 10, 12), Color("#2f5fb8"))
				draw_rect(Rect2(x + 6 + k3 * (w - 20) / 3, y + 7, 10, 12), Color("#2f5fb8"))
			draw_rect(Rect2(x + w / 2 - 16, y - 5, 32, 12), Color("#e1e3e8"))
			draw_string(font, Vector2(x, y + 30), "ISS - wipe feet", HORIZONTAL_ALIGNMENT_CENTER, w, 9, INK)
		"rescue":
			var al := (1.0 if sin(q["life"] * 20.0) > 0 else .4) if q["life"] < 1.5 else 1.0
			at(Vector2(x + w / 2, y - 20), 0, Vector2(1.0, 14.0 / (w / 2)))
			draw_circle(Vector2.ZERO, w / 2, Color("#f28c28", al))
			world()
			draw_string(font, Vector2(x, y - 16), "RESCUE BLIMP", HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color(1, 1, 1, al))
			draw_rect(Rect2(x + 8, y, w - 16, 6), Color("#5b3a2c", al))


func draw_moon() -> void:
	var y := Y(TOPY)
	if y < -20:
		return
	at(Vector2(CW / 2, y - 700), 0, Vector2(900.0 / 700.0, 1.0))
	draw_circle(Vector2.ZERO, 700, Color("#d9d6c8"))
	world()
	for c in [[-.32, -30, 22], [-.1, -14, 12], [.12, -40, 28], [.3, -12, 14], [.45, -36, 18], [-.48, -12, 10]]:
		at(Vector2(CW / 2 + c[0] * CW, y + c[1]), 0, Vector2(1, .45))
		draw_circle(Vector2.ZERO, c[2], Color("#bdb9a7"))
		world()
	draw_string(font, Vector2(0, y - 60), "THE MOON (dairy content unconfirmed)", HORIZONTAL_ALIGNMENT_CENTER, CW, 13, Color("#4b4a45"))


func draw_wafel(w: Dictionary) -> void:
	var x: float = w["x"]
	var y := Y(w["y"]) + sin(w["t"] * 3.0) * 3.0
	if y < -20 or y > VH + 20:
		return
	draw_circle(Vector2(x, y), 16, Color(.95, .77, .43, .35))
	draw_circle(Vector2(x, y), 12, Color("#c98a3a"))
	for k in [-6, 0, 6]:
		draw_line(Vector2(x + k - 6, y - 8), Vector2(x + k + 6, y + 8), Color("#8a5a22"), 1.0)
		draw_line(Vector2(x + k + 6, y - 8), Vector2(x + k - 6, y + 8), Color("#8a5a22"), 1.0)
	draw_arc(Vector2(x, y), 12, 0, TAU, 20, Color("#7a4a18"), 1.5)


func draw_goose(g: Dictionary) -> void:
	var x: float = g["x"]
	var y := Y(g["y"])
	at(Vector2(x, y), g["rot"] if g["state"] == "fall" else 0.0, Vector2(g["dir"], 1))
	var fl := sin(g["f"])
	var wc := Color("#f4f4f2")
	at(Vector2(x, y), g["rot"] if g["state"] == "fall" else 0.0, Vector2(g["dir"] * 17.0 / 9.0, 1))
	draw_circle(Vector2.ZERO, 9, wc)
	at(Vector2(x, y), g["rot"] if g["state"] == "fall" else 0.0, Vector2(g["dir"], 1))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -2), Vector2(-22, -5), Vector2(-14, 3)]), Color("#d9d9d4"))
	draw_polyline(PackedVector2Array([Vector2(12, -3), Vector2(18, -7), Vector2(20, -15)]), wc, 5.0)
	draw_circle(Vector2(21, -16), 5, wc)
	draw_colored_polygon(PackedVector2Array([Vector2(25, -17), Vector2(32, -15), Vector2(25, -13)]), Color("#f28c28"))
	draw_circle(Vector2(22, -17), 1.3, Color("#111111"))
	draw_line(Vector2(19, -21), Vector2(24, -19.5), Color("#111111"), 1.5)
	if absf(fl) > 0.08:
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -3), Vector2(8, -3), Vector2(-2, -3 - fl * 16)]), Color("#c9c9c3"))
	draw_line(Vector2(-2, 8), Vector2(-8, 12), Color("#f28c28"), 2.0)
	draw_line(Vector2(3, 8), Vector2(-3, 12), Color("#f28c28"), 2.0)
	if g["astro"]:
		draw_circle(Vector2(21, -16), 9, Color(.67, .82, 1, .18))
		draw_arc(Vector2(21, -16), 9, 0, TAU, 16, Color(.67, .82, 1, .9), 1.5)
	world()
	if g["state"] == "fly" and sin(gt * 2.0 + g["ph"]) > .93 and g["lead"]:
		draw_string(font, Vector2(x + g["dir"] * 22 - 30, y - 26), "HONK", HORIZONTAL_ALIGNMENT_CENTER, 60, 10, LASER)


func draw_junk(j: Dictionary) -> void:
	at(Vector2(j["x"], Y(j["y"])), j["rot"])
	match j["kind"]:
		0:
			draw_rect(Rect2(-11, -2.5, 18, 5), Color("#9aa1ad"))
			draw_circle(Vector2(9, 0), 6, Color("#9aa1ad"))
		1, 7:
			draw_rect(Rect2(-8, -11, 16, 22), Color(1, 1, 1))
			draw_string(font, Vector2(-8, 2), "R2" if j["kind"] == 1 else "!!", HORIZONTAL_ALIGNMENT_CENTER, 16, 9, Color("#d61f4f") if j["kind"] == 1 else Color("#2f6fdb"))
		2:
			draw_rect(Rect2(-8, -6, 14, 13), Color("#eeeeee"))
			draw_rect(Rect2(-9, 4, 16, 4), Color("#f28c28"))
		3:
			draw_rect(Rect2(-10, -8, 20, 16), Color("#fff2cc"))
			draw_string(font, Vector2(-10, 0), "MAJOR", HORIZONTAL_ALIGNMENT_CENTER, 20, 6, Color("#d61f4f"))
			draw_string(font, Vector2(-10, 6), "REV.", HORIZONTAL_ALIGNMENT_CENTER, 20, 6, Color("#d61f4f"))
		4:
			draw_rect(Rect2(-4, -11, 8, 14), Color("#e4572e"))
			draw_rect(Rect2(-4, 1, 12, 6), Color("#e4572e"))
			draw_rect(Rect2(-4, -11, 8, 3), Color(1, 1, 1))
		5:
			draw_rect(Rect2(-7, -7, 14, 14), Color("#b9bec8"))
			draw_circle(Vector2.ZERO, 3, Color("#d61f4f"))
		_:
			draw_rect(Rect2(-11, -7, 22, 14), Color("#c9ccd3"))
			draw_rect(Rect2(-7, -9, 5, 3), Color("#444444"))
			draw_rect(Rect2(2, -9, 5, 3), Color("#444444"))
	world()


func draw_rock(r: Dictionary) -> void:
	var c := Vector2(r["x"], Y(r["y"]))
	draw_circle(c, r["r"] + 5, Color(1, .54, .24, .3))
	var pts := PackedVector2Array()
	for i in 7:
		var a: float = r["rot"] + i * .9
		pts.append(c + Vector2(cos(a), sin(a)) * r["r"] * (.8 + .2 * sin(i * 2.3 + r["seed"] * 9)))
	draw_colored_polygon(pts, Color("#7a4a3a"))
	draw_circle(c + Vector2(r["r"] * .35 * signf(r["vx"]), 0), r["r"] * .3, Color("#ffb070"))


func draw_john(x: float, y: float) -> void:
	var helmet := max_y > ZL * 3 - 300
	var sq: float = p["sq"] * p["sq"]
	var rot := flip_a
	var origin := Vector2(x, y)
	if flip_a > 0:
		origin = Vector2(x, y - 18) + Vector2(0, 18).rotated(flip_a)
	at(origin, rot, Vector2(1 + sq * .25, 1 - sq * .25))
	var alpha := .45 if (p["inv"] > 0 and p["boost"] <= 0 and state == State.PLAY and sin(gt * 30.0) > 0) else 1.0
	var f: float = p["face"]
	var up: bool = p["vy"] > 0
	draw_rect(Rect2(-8, -13, 6, 12), Color("#2b3a67", alpha))
	draw_rect(Rect2(2, -13, 6, 12), Color("#2b3a67", alpha))
	draw_rect(Rect2(-9, -2, 8, 3), Color("#1d1d1d", alpha))
	draw_rect(Rect2(1, -2, 8, 3), Color("#1d1d1d", alpha))
	var arm := Color("#f28c28", alpha)
	if up:
		draw_line(Vector2(-9, -22), Vector2(-14, -32), arm, 4.0)
		draw_line(Vector2(9, -22), Vector2(14, -32), arm, 4.0)
	else:
		draw_line(Vector2(-9, -22), Vector2(-15, -14), arm, 4.0)
		draw_line(Vector2(9, -22), Vector2(15, -14), arm, 4.0)
	draw_rect(Rect2(-10, -27, 20, 15), arm)
	draw_rect(Rect2(-3, -22, 6, 8), Color("#d9731a", alpha))
	if p["boost"] > 0:
		draw_circle(Vector2(-f * 12, -18), 7, Color("#c98a3a"))
		draw_colored_polygon(PackedVector2Array([Vector2(-f * 12 - 5, -12), Vector2(-f * 12, -12 + randf_range(10, 20)), Vector2(-f * 12 + 5, -12)]), Color("#ffb84d"))
	draw_circle(Vector2(0, -34), 8, Color("#f2c9a0", alpha))
	draw_rect(Rect2(-8, -40, 16, 5), Color("#6b4226", alpha))
	draw_arc(Vector2(f * 2 - 3, -34), 2.6, 0, TAU, 10, Color("#1d2433", alpha), 1.3)
	draw_arc(Vector2(f * 2 + 3, -34), 2.6, 0, TAU, 10, Color("#1d2433", alpha), 1.3)
	if p["stun"] > 0:
		draw_arc(Vector2(f * 2, -29.5), 1.8, 0, TAU, 8, Color("#7a3b2a"), 1.2)
	else:
		draw_arc(Vector2(f * 2, -31), 2.5, .2 * PI, .8 * PI, 6, Color("#7a3b2a"), 1.2)
	if helmet:
		draw_circle(Vector2(0, -33), 13, Color(.67, .82, 1, .16))
		draw_arc(Vector2(0, -33), 13, 0, TAU, 20, Color(.67, .82, 1, .95), 1.6)
	if p["stun"] > 0:
		for i in 3:
			var a := gt * 8.0 + i * 2.1
			draw_circle(Vector2(cos(a) * 12, -46 + sin(a) * 3), 2.2, Color("#f3c623"))
	world()


func draw_landed() -> void:
	var x: float = p["x"]
	var y := Y(TOPY)
	var fh := minf(1.0, end_t / .8)
	draw_line(Vector2(x + 22, y), Vector2(x + 22, y + 44 * fh), Color("#dddddd"), 2.0)
	if fh >= 1.0:
		var cs := [Color("#ae1c28"), Color("#ffffff"), Color("#21468b")]
		for i in 3:
			draw_rect(Rect2(x + 23, y + 22 + i * 6, 24, 6), cs[i])
	if end_t > 1.0:
		var msg := "One small hop for a man..." if end_t < 2.3 else "...one giant honk for goosekind."
		draw_string_outline(font, Vector2(0, VH - 80), msg, HORIZONTAL_ALIGNMENT_CENTER, CW, 13, 4, Color(0, 0, 0, .7))
		draw_string(font, Vector2(0, VH - 80), msg, HORIZONTAL_ALIGNMENT_CENTER, CW, 13, INK)


func draw_hud() -> void:
	var z := mini(zone, 4)
	var ttl: String = "The Moon" if flipped else ZONES[z]["n"]
	var lvl := "Final" if flipped else "L%d" % (z + 1)
	var alt_v := 384400000.0 if state == State.LANDED or (state == State.OVER and result_reason == "moon") else alt_m(TOPY if flipped else (max_y if state != State.PLAY else maxf(0.0, p["y"])))
	draw_rect(Rect2(140, 8, 380, 86), Color(0.09, 0.11, 0.16, 0.9))
	text(Vector2(156, 40), "%s  ·  %s" % [lvl, ttl], 22, LASER)
	text(Vector2(156, 78), fmt_alt(alt_v), 28, INK)
	for i in lives:
		draw_circle(Vector2(372 + i * 24, 70), 8, LASER)
	draw_circle(Vector2(380 + lives * 24, 70), 9, Color("#c98a3a"))
	text(Vector2(394 + lives * 24, 78), "x%d" % wafels, 20, INK)
	text(Vector2(W - 270, 40), "best", 18, Color(1, 0.9, 0.6))
	text(Vector2(W - 270, 68), fmt_alt(best), 22, Color(1, 0.9, 0.6))
	# progress bar
	var bx := W - 40.0
	var by0 := 110.0
	var by1 := H - 30.0
	draw_rect(Rect2(bx, by0, 10, by1 - by0), Color(1, 1, 1, .15))
	var fr := clampf(max_y / TOPY, 0, 1)
	draw_rect(Rect2(bx, by1 - (by1 - by0) * fr, 10, (by1 - by0) * fr), BEAM)
	draw_circle(Vector2(bx + 5, by0 - 4), 7, Color("#d9d6c8"))
	if state != State.TITLE:
		draw_circle(Vector2(bx + 5, by1 - (by1 - by0) * clampf(p["y"] / TOPY, 0, 1)), 7, LASER)
	if banner != null and state != State.OVER:
		var bt: float = banner["t"]
		var a := clampf(bt / .3 if bt < .3 else ((3.6 - bt) / .6 if bt > 3 else 1.0), 0, 1)
		var moon: bool = banner["z"] == 5
		var y := (370.0 if moon else 180.0) - (1 - a) * 20
		draw_rect(Rect2(W / 2 - 330, y, 660, 130), Color(0.09, 0.11, 0.16, 0.95 * a))
		draw_rect(Rect2(W / 2 - 330, y, 10, 130), Color(LASER, a))
		text(Vector2(0, y + 34), "FINAL APPROACH" if moon else "LEVEL %d OF 5" % (banner["z"] + 1), 18, Color(LASER, a), true)
		text(Vector2(0, y + 74), "The Moon" if moon else ZONES[banner["z"]]["n"], 32, Color(INK, a), true)
		text(Vector2(0, y + 110), "Lunar gravity has you now. Enjoy the fall... upwards." if moon else ZONES[banner["z"]]["tip"], 19, Color(0.75, 0.78, 0.85, a), true)


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(W / 2 - 560, 130, 1120, 450), Color(0.09, 0.11, 0.18, 0.96))
	text(Vector2(0, 210), title, 58, LASER, true)
	var y := 280.0
	for l in lines:
		text(Vector2(0, y), l, 23, INK, true)
		y += 42.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 545), prompt, 30, Color(0.6, 1, 0.6), true)
