extends ArcadeGame
# Lighthouse Keeper: Mind the Very Expensive Laser. Swing the beam across a
# night sea so captains can see the rocks. Don't light the smugglers, and
# look away when the serpent gets close.
# The simulation runs in the web version's coordinates (782 x 440) and is
# scaled up to the 1280 x 720 screen.

const K := 720.0 / 440.0
const WW := 1280.0 / K
const HH := 440.0
const DFS := [
	{"spd": 0.75, "gap": 1.3, "lives": 4, "half": 0.2, "know": 72.0, "turn": 3.4, "label": "Easy"},
	{"spd": 1.0, "gap": 1.0, "lives": 3, "half": 0.17, "know": 62.0, "turn": 2.9, "label": "Normal"},
	{"spd": 1.3, "gap": 0.74, "lives": 3, "half": 0.145, "know": 52.0, "turn": 2.5, "label": "Hard"},
]
const NAMES := ["Halve Maen (Half Full)", "Zeven Provincien", "Stroopwafel Express", "VCSEL Voyager", "HMS Overfull Hbox", "Thesis_v37_FINAL", "Free Spectral Rover", "Honk Kong", "Gans Gans Revolution", "Kroket Carrier", "Pindakaas Princess", "De Ruyter's Duck", "Batavia II (Please)", "Spice Spice Baby", "VOC: Very Odd Cargo", "Tulip Bubble", "Dijkstra's Shortest Path", "Gezelligheid", "Bitterbal Bay", "Polder Pioneer", "Cleanroom Cruiser", "Peer Review Pending", "Quantum Wel", "Fiber Optimist", "Snell's Window", "Brewster Angle", "Hagelslag Hauler", "Twente Tide", "Nachtwacht Night Shift", "Dutch Courage", "Klompen Clipper", "Total Internal Reflection", "Gouda Intentions", "Bike Lane Ferry", "Abstract Rejected", "Postdoc Dreams", "Cheese Louise", "Frikandel Fleet", "Reviewer 3", "Herring Aid"]
const SMUG := ["Definitely Fish", "Not Jenever", "Totally Legal Kaas", "Tax-Free Tulips", "Herring (Wink)", "Undeclared Drop"]
const CRASH := ["{n} found a rock. The rock is fine.", "{n} is now a submarine.", "{n} discovered geology by touch.", "{n}: 'Who put that there?!'", "{n} sank. Insurance says 'act of Dutch'.", "{n} has been peer-reviewed by a rock."]
const SHORE := ["{n} parked on the beach. Ticket issued.", "{n} ran aground. The geese are laughing."]
const EATEN := ["{n} was eaten. Serpent rates it 3/5, needs salt.", "Serpent ate {n}. It was well lit, like a buffet.", "{n}: served flambe by your laser."]
const SAVED := ["Dank je wel!", "Thanks for the photons!", "Stroopwafels inbound!", "Bon voyage!", "Lekker!", "Coherent rescue!"]
const BUST := ["Busted! 'It's just herring, officer.'", "Spotted! They file a light-pollution complaint.", "Smugglers sue for photon damages!"]
const LEVELS := [
	{"n": "A Calm Night", "s": "Light up ships near rocks. Lit captains learn the rocks and steer around."},
	{"n": "Dutch Fog", "s": "Fog banks scatter your beam (thanks, Mie). Rocks hide in the murk."},
	{"n": "Storm of the Century (this week)", "s": "Wind shoves ships around. The fog blew away, at least."},
	{"n": "Smugglers' Run", "s": "Dark boats with 'definitely fish'. Do NOT light them: -150 each."},
	{"n": "Here Be Serpent", "s": "It eats LIT ships. When it gets close, look away."},
	{"n": "The Everything Night", "s": "Fog, storm, smugglers, serpent. Fresnel would weep."},
]
const HULLS := [Color("#c9773b"), Color("#b5523b"), Color("#d1a054"), Color("#8f5a3c"), Color("#c26a4a"), Color("#a8763e")]
const SAILS := [Color("#f4efe2"), Color("#f6e7c8"), Color("#e9f0f4"), Color("#f3d9d0")]

enum State { TITLE, PLAY, OVER }
var state: int = State.TITLE
var diff := 1
var DF: Dictionary
var LX := WW / 2.0
var LY := HH - 34.0
var name_bag: Array = []
var aim_target = null

# game
var level := 0
var score := 0
var lives := 3
var saved := 0
var lost := 0
var busted := 0
var eaten := 0
var done := 0
var quota := 6
var ships: Array = []
var rocks: Array = []
var fog: Array = []
var wrecks: Array = []
var fxp: Array = []
var texts: Array = []
var rain: Array = []
var aim := -PI / 2
var half := 0.17
var beam_len := 900.0
var spawn_t := 2.2
var smug_t := 8.0
var serp = null
var wind := {"x": 0.0, "y": 0.0, "tx": 0.0, "ty": 0.0, "t": 0.0}
var flash := 0.0
var th_t := 6.0
var banner = null
var gt := 0.0
var over_t := -1.0
var F: Dictionary
var new_best := false


func _ready() -> void:
	game_id = "lighthouse_keeper"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()
	diff = difficulty()
	DF = DFS[diff]
	for i in 60:
		rain.append({"x": randf() * WW, "y": randf() * HH, "s": randf_range(0.6, 1.0)})


func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


func pick(a: Array):
	return a[randi() % a.size()]


func next_name() -> String:
	if name_bag.is_empty():
		name_bag = NAMES.duplicate()
		name_bag.shuffle()
	return name_bag.pop_back()


func shore_y(x: float) -> float:
	return HH - 24.0 - 20.0 * exp(-pow((x - WW / 2.0) / (WW * 0.13 + 30.0), 2))


func lv_info(l: int) -> Dictionary:
	return LEVELS[l - 1] if l <= 6 else {"n": "Everything Night %d" % (l - 5), "s": "Faster. Darker. More rocks. Same salary."}


func feat(l: int) -> Dictionary:
	var storm := 0.0
	if l == 3:
		storm = 1.0
	elif l >= 6:
		storm = 0.75
	elif l == 4 or l == 5:
		storm = 0.35
	return {"fog": l == 2 or l >= 6, "storm": storm, "smug": l >= 4, "serp": l >= 5}


func new_game() -> void:
	DF = DFS[diff]
	level = 0
	score = 0
	lives = DF["lives"]
	saved = 0
	lost = 0
	busted = 0
	eaten = 0
	done = 0
	ships.clear()
	rocks.clear()
	fog.clear()
	wrecks.clear()
	fxp.clear()
	texts.clear()
	aim = -PI / 2
	aim_target = null
	beam_len = 900.0
	spawn_t = 2.2
	smug_t = 8.0
	serp = null
	wind = {"x": 0.0, "y": 0.0, "tx": 0.0, "ty": 0.0, "t": 0.0}
	flash = 0.0
	th_t = 6.0
	gt = 0.0
	over_t = -1.0
	new_best = false
	for i in 4 + roundi(WW / 240.0):
		add_rock(true)
	start_level(1)


func add_rock(init: bool):
	for tries in 80:
		var r := {"x": randf_range(34, WW - 34), "y": randf_range(62, HH - 118), "r": randf_range(9, 16), "seed": randf() * 10.0}
		if Vector2(r["x"], r["y"]).distance_to(Vector2(LX, LY)) < 120:
			continue
		var ok := true
		for o in rocks:
			if Vector2(o["x"], o["y"]).distance_to(Vector2(r["x"], r["y"])) < r["r"] + o["r"] + 46:
				ok = false
				break
		if ok and not init:
			for s in ships:
				if Vector2(s["x"], s["y"]).distance_to(Vector2(r["x"], r["y"])) < 90:
					ok = false
					break
		if ok:
			rocks.append(r)
			return r
	return null


func start_level(l: int) -> void:
	level = l
	done = 0
	quota = 6 if l == 1 else 7
	F = feat(l)
	if l > 1:
		var nr: Variant = null
		if rocks.size() < roundi(4 + WW / 100.0):
			nr = add_rock(false)
		if l == 3:
			add_rock(false)
		if nr != null:
			say(nr["x"], nr["y"] - 20, "New rock! (It was always there)", Color("#ffd27a"))
	fog.clear()
	if F["fog"]:
		var n := 1 + roundi(WW / 300.0) if l == 2 else 1 + roundi(WW / 420.0)
		for i in n:
			fog.append({"x": (i + randf_range(0.1, 0.9)) * WW / n, "y": randf_range(70, HH - 215), "r": randf_range(44, 66), "vx": randf_range(6, 13) * (-1.0 if randf() < 0.5 else 1.0), "ph": randf() * 6.0})
	if F["serp"] and serp == null:
		serp = {"x": WW * 0.2, "y": -30.0, "a": PI / 2, "sp": 0.0, "trail": [], "cool": 2.0, "wx": WW / 2, "wy": 150.0, "wt": 0.0, "full": 0.0, "near": null}
	var I := lv_info(l)
	banner = {"t": 3.6, "n": "Level %d: %s" % [l, I["n"]], "s": I["s"]}
	spawn_t = minf(spawn_t, 2.2)
	shake(4.0)


func spawn_ship(smug: bool) -> void:
	var left := randf() < 0.5
	var sx := -16.0 if left else WW + 16.0
	var sy := randf_range(64, HH - 140)
	var tx := WW + 40.0 if left else -40.0
	var ty := 0.0
	var cands: Array = rocks.filter(func(r): return r["x"] > sx + 60 if left else r["x"] < sx - 60)
	if not smug and cands.size() > 0 and randf() < 0.78:
		var r: Dictionary = pick(cands)
		var k: float = (tx - sx) / (r["x"] - sx)
		ty = sy + (r["y"] + randf_range(-5, 5) - sy) * k
		if ty < 50 or ty > HH - 110:
			ty = clampf(ty, 50, HH - 110)
			sy = r["y"] - (ty - r["y"]) * (r["x"] - sx) / (tx - r["x"])
	else:
		ty = randf_range(60, HH - 120)
	sy = clampf(sy, 58, HH - 130)
	var base: float = (26.0 + WW * 0.023) * DF["spd"] * (1.0 + minf(0.9, maxf(0.0, level - 5) * 0.1))
	ships.append({"x": sx, "y": sy, "tx": tx, "ty": ty, "a": atan2(ty - sy, tx - sx), "sp": base * randf_range(0.85, 1.15) * (1.1 if smug else 1.0),
		"smug": smug, "name": pick(SMUG) if smug else next_name(), "lit": false, "aware": 0.0, "known": [], "lit_t": 0.0, "busted": false,
		"danger": 0.0, "col": pick(HULLS), "sail": pick(SAILS), "bob": randf() * 6.0, "wake": [], "dead": false})


func in_beam(x: float, y: float) -> bool:
	var d := Vector2(x - LX, y - LY)
	var dl := d.length()
	if dl > beam_len + 5 or dl < 10:
		return false
	return absf(ang_diff(d.angle(), aim)) < half + 7.0 / dl


func fog_at(x: float, y: float) -> float:
	var m := 0.0
	for f in fog:
		var d: float = Vector2(x - f["x"], y - f["y"]).length() / f["r"]
		if d < 1.0:
			m = maxf(m, 1.0 - d * d)
	return m


func say(x: float, y: float, s: String, c: Color, dur := 2.6) -> void:
	texts.append({"x": x, "y": y, "t": s, "c": c, "life": dur})


func fmt(s: String, n: String) -> String:
	return s.replace("{n}", n)


func on_input(event: InputEvent) -> void:
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
			set_difficulty(game_id, diff)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
			set_difficulty(game_id, diff)
	if state != State.PLAY:
		return
	var aim_now := false
	if event is InputEventScreenTouch and event.pressed:
		aim_now = true
	elif event is InputEventScreenDrag:
		aim_now = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		aim_now = not is_mobile
	if aim_now:
		var p: Vector2 = pointer / K
		aim_target = clampf(atan2(minf(p.y, LY - 4) - LY, p.x - LX), -PI + 0.06, -0.06)


func _process(delta: float) -> void:
	tick(delta)
	match state:
		State.TITLE:
			gt += delta
			aim = -PI / 2 + sin(gt * 0.6) * 1.1
			if pressed_b():
				diff = (diff + 1) % 3
				set_difficulty(game_id, diff)
			if start_pressed():
				new_game()
				state = State.PLAY
				clear_presses()
		State.OVER:
			gt += delta
			for x in texts:
				x["life"] -= delta
			if start_pressed() and t > 1.0:
				state = State.TITLE
		State.PLAY:
			clear_presses()
			update(minf(delta, 0.04))
	queue_redraw()


func update(dt: float) -> void:
	gt += dt
	half = DF["half"]
	var turn: float = DF["turn"] * dt
	var kx := -axis().x
	if absf(kx) > 0.2:
		aim -= signf(kx) * turn
		aim_target = null
	elif aim_target != null:
		aim += clampf(ang_diff(aim_target, aim), -turn, turn)
	aim = clampf(aim, -PI + 0.06, -0.06)
	for f in fog:
		f["x"] += f["vx"] * dt
		f["ph"] += dt
		if f["x"] < -f["r"] - 20:
			f["x"] = WW + f["r"]
		if f["x"] > WW + f["r"] + 20:
			f["x"] = -f["r"]
	var length := 900.0
	if fog.size() > 0:
		var acc := 0.0
		var ca := cos(aim)
		var sa := sin(aim)
		var tt := 20.0
		while tt < 900.0:
			acc += fog_at(LX + ca * tt, LY + sa * tt) * 6.0
			if acc > 44.0:
				length = tt
				break
			tt += 6.0
	beam_len = length
	if F["storm"] > 0.0:
		wind["t"] -= dt
		if wind["t"] <= 0.0:
			wind["t"] = randf_range(3, 6)
			var wa := randf() * TAU
			var wm: float = randf_range(14, 26) * F["storm"] * DF["spd"]
			wind["tx"] = cos(wa) * wm
			wind["ty"] = sin(wa) * wm * 0.7
	else:
		wind["tx"] = 0.0
		wind["ty"] = 0.0
	wind["x"] += (wind["tx"] - wind["x"]) * minf(1.0, dt * 0.8)
	wind["y"] += (wind["ty"] - wind["y"]) * minf(1.0, dt * 0.8)
	if F["storm"] >= 0.75:
		th_t -= dt
		if th_t <= 0.0:
			th_t = randf_range(7, 13)
			flash = 1.0
	flash = maxf(0.0, flash - dt * 2.2)
	if banner != null:
		banner["t"] -= dt
		if banner["t"] <= 0.0:
			banner = null
	var regular := ships.filter(func(s): return not s["smug"]).size()
	var max_s := mini(7, 2 + (level + 1) / 2 + maxi(0, level - 6)) + 1
	spawn_t -= dt
	var remaining := quota - done - regular
	if spawn_t <= 0.0 and regular < max_s and remaining > 0:
		spawn_ship(false)
		var gap: float = maxf(2.0, 4.7 - level * 0.3) * DF["gap"]
		if level > 6:
			gap *= pow(0.88, level - 6)
		spawn_t = gap * randf_range(0.8, 1.2)
	if F["smug"]:
		smug_t -= dt
		if smug_t <= 0.0:
			smug_t = randf_range(6, 10) * DF["gap"]
			if ships.filter(func(s): return s["smug"]).size() < (2 if level >= 6 else 1) + 1:
				spawn_ship(true)
	for i in range(ships.size() - 1, -1, -1):
		upd_ship(ships[i], dt)
		if ships[i]["dead"]:
			ships.remove_at(i)
	if serp != null:
		upd_serp(dt)
	for r in wrecks:
		r["t"] += dt
	wrecks = wrecks.filter(func(r): return r["t"] < 3.0)
	for x in texts:
		x["life"] -= dt
		x["y"] -= dt * 9.0
	texts = texts.filter(func(x): return x["life"] > 0.0)
	for p in fxp:
		p["t"] += dt
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
	fxp = fxp.filter(func(p): return p["t"] < p["l"])
	if F["storm"] > 0.0:
		for r in rain:
			r["y"] += dt * 420.0 * r["s"]
			r["x"] += (wind["x"] * 4.0 + 40.0) * dt * r["s"]
			if r["y"] > HH:
				r["y"] = -10.0
				r["x"] = randf_range(-40, WW)
			if r["x"] > WW + 20:
				r["x"] -= WW + 40
	if done >= quota and lives > 0:
		start_level(level + 1)
	if lives <= 0 and over_t < 0.0:
		over_t = 1.6
	if over_t >= 0.0:
		over_t -= dt
		if over_t <= 0.0:
			game_over()


func lose(s: Dictionary, kind: String) -> void:
	s["dead"] = true
	if lives > 0:
		lives -= 1
		lost += 1
		done += 1
	var txt := fmt(pick(SHORE if kind == "shore" else (EATEN if kind == "eat" else CRASH)), s["name"])
	if kind == "eat":
		eaten += 1
	shake(8.0)
	say(clampf(s["x"], 70, WW - 70), s["y"] - 14, txt, Color("#ffb3a8"), 3.2)
	wrecks.append({"x": s["x"], "y": s["y"], "a": s["a"], "t": 0.0, "col": s["col"], "eat": kind == "eat"})
	for j in 14:
		var a := randf() * TAU
		var v := randf_range(10, 50)
		fxp.append({"x": s["x"], "y": s["y"], "vx": cos(a) * v, "vy": sin(a) * v, "t": 0.0, "l": randf_range(0.6, 1.3), "c": s["col"] if j % 2 else Color("#e8f2ff")})


func upd_ship(s: Dictionary, dt: float) -> void:
	s["bob"] += dt * 3.0
	s["lit"] = in_beam(s["x"], s["y"])
	if s["smug"]:
		if s["lit"] and not s["busted"]:
			s["lit_t"] += dt
			if s["lit_t"] > 0.22:
				s["busted"] = true
				score = maxi(0, score - 150)
				busted += 1
				say(clampf(s["x"], 80, WW - 80), s["y"] - 14, pick(BUST) + " -150", Color("#ffb3a8"), 2.8)
				s["sp"] *= 1.5
	else:
		if s["lit"]:
			s["aware"] = 0.9
			for r in rocks:
				if not s["known"].has(r) and Vector2(r["x"] - s["x"], r["y"] - s["y"]).length() < DF["know"] + r["r"]:
					s["known"].append(r)
		else:
			s["aware"] = maxf(0.0, s["aware"] - dt)
	var des := atan2(s["ty"] - s["y"], s["tx"] - s["x"])
	var vx := cos(des)
	var vy := sin(des)
	var hx := cos(s["a"])
	var hy := sin(s["a"])
	var avoid: Array = rocks if (s["smug"] or s["aware"] > 0.0) else s["known"]
	for r in avoid:
		var dx: float = s["x"] - r["x"]
		var dy: float = s["y"] - r["y"]
		var d := maxf(0.001, sqrt(dx * dx + dy * dy))
		var R: float = r["r"] + 11.0
		var reach := R + 58.0
		if d < reach and (dx * hx + dy * hy) / d < 0.35:
			var wgt := (reach - d) / (reach - R + 1.0)
			wgt = minf(2.6, wgt * wgt * 2.4 + wgt * 0.6)
			var side := 1.0 if (hx * dy - hy * dx) >= 0.0 else -1.0
			vx += (dx / d) * wgt * 0.9
			vy += (dy / d) * wgt * 0.9
			vx += (dy / d) * side * wgt * 0.8
			vy -= (dx / d) * side * wgt * 0.8
	if s["smug"] or s["aware"] > 0.0:
		var sy := shore_y(s["x"])
		if s["y"] > sy - 60:
			vy -= (s["y"] - (sy - 60)) / 30.0 * 1.5
	if s["y"] < 44:
		vy += (44 - s["y"]) / 20.0
	des = atan2(vy, vx)
	var tr := (2.6 if (s["aware"] > 0.0 or s["smug"]) else 1.2) * dt
	s["a"] += clampf(ang_diff(des, s["a"]), -tr, tr)
	var drift := 0.18 if (s["aware"] > 0.0 or s["smug"]) else 1.0
	var spf := 0.62 if fog.size() > 0 and fog_at(s["x"], s["y"]) > 0.25 else 1.0
	s["x"] += cos(s["a"]) * s["sp"] * spf * dt + wind["x"] * drift * dt
	s["y"] += sin(s["a"]) * s["sp"] * spf * dt + wind["y"] * drift * dt
	if s["y"] < 34:
		s["y"] = 34.0
	s["wake"].append(Vector2(s["x"], s["y"]))
	if s["wake"].size() > 22:
		s["wake"].pop_front()
	s["danger"] = 0.0
	if not s["smug"] and s["aware"] <= 0.0:
		var px: float = s["x"]
		var py: float = s["y"]
		var vxx: float = cos(s["a"]) * s["sp"] + wind["x"]
		var vyy: float = sin(s["a"]) * s["sp"] + wind["y"]
		var tt := 0.0
		while tt < 2.4 and s["danger"] == 0.0:
			px += vxx * 0.15
			py += vyy * 0.15
			for r in rocks:
				if not s["known"].has(r) and Vector2(px - r["x"], py - r["y"]).length() < r["r"] + 8:
					s["danger"] = 1.0 - tt / 2.4
					break
			if py > shore_y(px) - 6:
				s["danger"] = 1.0 - tt / 2.4
			tt += 0.15
	for r in rocks:
		if Vector2(s["x"] - r["x"], s["y"] - r["y"]).length() < r["r"] + 5:
			if s["smug"]:
				s["dead"] = true
				say(s["x"], s["y"] - 12, s["name"] + " sank. Nobody saw anything.", Color("#cfd8e3"))
				wrecks.append({"x": s["x"], "y": s["y"], "a": s["a"], "t": 0.0, "col": Color("#333333"), "eat": false})
			else:
				lose(s, "rock")
			return
	if s["y"] > shore_y(s["x"]) - 5:
		if s["smug"]:
			s["dead"] = true
		else:
			lose(s, "shore")
		return
	if s["x"] < -34 or s["x"] > WW + 34 or s["y"] < -30:
		s["dead"] = true
		if not s["smug"] and lives > 0:
			saved += 1
			done += 1
			var pts := 100 + 20 * (level - 1)
			score += pts
			say(clampf(s["x"], 60, WW - 60), clampf(s["y"], 50, HH - 90) - 8, "+%d %s" % [pts, pick(SAVED)], Color("#c9f7c4"))


func upd_serp(dt: float) -> void:
	var S: Dictionary = serp
	S["cool"] = maxf(0.0, S["cool"] - dt)
	S["full"] = maxf(0.0, S["full"] - dt)
	var det := 155.0
	var tgt = null
	var bestd := 1e9
	var boost := 1.0 + maxf(0.0, level - 5) * 0.08
	if S["cool"] <= 0.0:
		for s in ships:
			if s["lit"]:
				var d := Vector2(s["x"] - S["x"], s["y"] - S["y"]).length()
				if d < det and d < bestd:
					bestd = d
					tgt = s
	var tx: float
	var ty: float
	if tgt != null:
		tx = tgt["x"]
		ty = tgt["y"]
		S["sp"] += (62.0 * DF["spd"] * boost - S["sp"]) * minf(1.0, dt * 2.0)
	else:
		S["wt"] -= dt
		if S["wt"] <= 0.0 or Vector2(S["wx"] - S["x"], S["wy"] - S["y"]).length() < 20:
			S["wt"] = randf_range(3, 5)
			if randf() < 0.4:
				var tl := minf(beam_len, 330.0) * randf_range(0.4, 0.8)
				S["wx"] = LX + cos(aim) * tl
				S["wy"] = LY + sin(aim) * tl
			else:
				S["wx"] = randf_range(40, WW - 40)
				S["wy"] = randf_range(70, HH - 140)
			S["wy"] = clampf(S["wy"], 60, HH - 130)
		tx = S["wx"]
		ty = S["wy"]
		S["sp"] += (34.0 * DF["spd"] - S["sp"]) * minf(1.0, dt * 2.0)
	var des := atan2(ty - S["y"], tx - S["x"])
	S["a"] += clampf(ang_diff(des, S["a"]), -2.4 * dt, 2.4 * dt)
	S["x"] += cos(S["a"]) * S["sp"] * dt
	S["y"] += sin(S["a"]) * S["sp"] * dt
	S["trail"].push_front(Vector2(S["x"], S["y"]))
	if S["trail"].size() > 70:
		S["trail"].pop_back()
	S["near"] = null
	for s in ships:
		var d := Vector2(s["x"] - S["x"], s["y"] - S["y"]).length()
		if s["lit"] and d < 80:
			S["near"] = s
		if d < 15 and s["lit"] and S["cool"] <= 0.0:
			if s["smug"]:
				s["dead"] = true
				say(s["x"], s["y"] - 12, "Serpent ate the smugglers. Crime solved?", Color("#c9f7c4"))
			else:
				lose(s, "eat")
			S["cool"] = 3.2
			S["full"] = 3.2
			break


func game_over() -> void:
	state = State.OVER
	t = 0.0
	new_best = submit_score(score)


func verdict() -> String:
	var v := ""
	if saved < 3:
		v = "Your lighthouse is now officially a 'decorative tower'."
	elif saved < 8:
		v = "The insurers would like a word. In Dutch. Loudly."
	elif saved < 15:
		v = "Decent keeper. The geese on the dike nod approvingly."
	elif saved < 25:
		v = "Fresnel would be proud. Lens-ed to tears, even."
	else:
		v = "Legendary. The VOC wants to name a ship after you (it will sink)."
	if eaten >= 2:
		v += " The serpent sends a thank-you card."
	elif busted >= 3:
		v += " Smugglers have put a price on your bulb."
	return v


# ---------------------------------------------------------------- drawing (world coords)

func world() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(K, K))


func screen() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func label(x: float, y: float, s: String, c: Color, size := 11) -> void:
	# world-space text, drawn in screen space so it stays sharp
	var p := Vector2(x, y) * K
	var fs := int(size * K)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	p.x = clampf(p.x - w / 2.0, 6, W - w - 6)
	screen()
	draw_string_outline(font, p + Vector2(0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0.02, 0.04, 0.08, 0.75 * c.a))
	draw_string(font, p + Vector2(0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	world()


func _draw() -> void:
	var storm: bool = state != State.TITLE and F.get("storm", 0.0) > 0.5
	world()
	# sea
	for i in 20:
		draw_rect(Rect2(-30, i * HH / 20.0 - 2, WW + 60, HH / 20.0 + 4), Color("#122a49").lerp(Color("#1f3d63"), i / 19.0))
	var amp := 5.0 if storm else 2.5
	for j in 13:
		var y := 40.0 + j * (HH - 60) / 13.0
		var x := -10.0
		while x <= WW + 10:
			var yy := y + sin(x * 0.035 + gt * (2.4 if storm else 0.9) + j * 1.7) * amp
			if sin(x * 0.011 + j * 2.1 + gt * 0.3) > 0.25:
				draw_line(Vector2(x, yy), Vector2(x + 9, yy + sin(x * 0.035 + gt * (2.4 if storm else 0.9) + j * 1.7 + 0.3) * amp), Color(0.75, 0.85, 0.95, 0.16 if storm else 0.09), 1.2)
			x += 14.0
	if state == State.TITLE:
		for r in [[0.22, 0.3, 12], [0.7, 0.22, 15], [0.45, 0.55, 10], [0.85, 0.6, 13], [0.15, 0.66, 11]]:
			draw_rock({"x": r[0] * WW, "y": r[1] * HH, "r": float(r[2]), "seed": float(r[2])}, false)
		draw_shore()
		draw_beam(900.0, 0.17)
		draw_lighthouse()
		screen()
		card("LIGHTHOUSE KEEPER", [
			"Swing a very expensive laser beam across a night sea so captains can see",
			"the rocks. Lit captains learn where the rocks are and steer around them.",
			"Touch / move the mouse to aim, or use left / right.",
			"Difficulty: %s   (change it in the menu, or with left / right here)" % DFS[diff]["label"],
		], "Tap or press SPACE to light up")
		draw_overlay()
		return
	for r in wrecks:
		var k: float = r["t"] / 3.0
		draw_arc(Vector2(r["x"], r["y"]), 6 + r["t"] * 14, 0, TAU, 24, Color(0.9, 0.94, 1, 0.6 * (1 - k)), 1.5)
		if not r["eat"]:
			draw_set_transform(Vector2(r["x"], r["y"]) * K, r["a"] + r["t"] * 0.6, Vector2(K, K) * (1 - k * 0.7))
			draw_rect(Rect2(-8, -3, 16, 6), Color(r["col"], 1 - k))
			world()
	for r in rocks:
		draw_rock(r, in_beam(r["x"], r["y"]))
	if serp != null:
		draw_serp(serp)
	for s in ships:
		draw_ship(s)
	draw_shore()
	draw_beam(beam_len, half)
	for f in fog:
		var c := Vector2(f["x"], f["y"])
		var fr: float = f["r"]
		for k in 5:
			draw_circle(c, fr * 1.25 * (1.0 - k * 0.16), Color(0.55, 0.6, 0.66, 0.25))
		for i in 3:
			draw_circle(c + Vector2(cos(f["ph"] * 0.4 + i * 2) * fr * 0.5, sin(f["ph"] * 0.3 + i * 2) * fr * 0.35), fr * 0.45, Color(0.63, 0.67, 0.72, 0.35))
	for s in ships:
		if not s["smug"]:
			var fl := 0.75 + 0.25 * sin(gt * 9.0 + s["bob"] * 3.0)
			draw_circle(Vector2(s["x"], s["y"]), 6, Color(1, 0.8, 0.43, 0.35 * fl))
			draw_circle(Vector2(s["x"], s["y"]), 1.8, Color("#ffd77a"))
	for p in fxp:
		draw_rect(Rect2(p["x"] - 1.5, p["y"] - 1.5, 3, 3), Color(p["c"], 1.0 - p["t"] / p["l"]))
	for s in ships:
		if s["smug"]:
			if s["lit"] or s["busted"]:
				label(s["x"], s["y"] - 15, "BUSTED" if s["busted"] else "SMUGGLER!", Color("#ff9b8a"), 10)
			continue
		if s["lit"]:
			draw_arc(Vector2(s["x"], s["y"]), 14, 0, TAU, 24, Color(1, 0.94, 0.67, 0.9), 1.5)
			if fog.is_empty() or fog_at(s["x"], s["y"]) < 0.5:
				label(s["x"], s["y"] - 21, s["name"], Color("#fff3c4"), 10)
		elif s["danger"] > 0.0:
			var pp := 0.5 + 0.5 * sin(gt * 14.0)
			draw_arc(Vector2(s["x"], s["y"]), 11 + s["danger"] * 6 + pp * 2, 0, TAU, 24, Color(1, 0.35, 0.31, 0.45 + 0.5 * pp), 2.0)
			label(s["x"], s["y"] - 20, "?!", Color("#ff8a7a"), 12)
	if serp != null and serp["near"] != null:
		var n: Dictionary = serp["near"]
		draw_dashed_line(Vector2(serp["x"], serp["y"]), Vector2(n["x"], n["y"]), Color(1, 0.3, 0.3, 0.5 + 0.5 * sin(gt * 20.0)), 2.0, 4.0)
		label(n["x"], n["y"] + 22, "SERPENT! look away", Color("#ff8a7a"), 10)
	if storm:
		for r in rain:
			draw_line(Vector2(r["x"], r["y"]), Vector2(r["x"] - (wind["x"] * 0.25 + 3), r["y"] - 12 * r["s"]), Color(0.78, 0.86, 1, 0.28), 1.0)
	draw_lighthouse()
	if flash > 0.0:
		draw_rect(Rect2(0, 0, WW, HH), Color(0.92, 0.94, 1, flash * 0.55))
	for x in texts:
		label(x["x"], x["y"], x["t"], Color(x["c"], minf(1.0, x["life"] * 1.5)), 11)
	screen()
	draw_hud()
	if state == State.OVER and t > 0.3:
		card("LIGHTS OUT", [
			"%d pts%s" % [score, "   NEW BEST!" if new_best else ""],
			"%d ships saved, %d lost, reached level %d (%s)" % [saved, lost, level, lv_info(level)["n"]],
			verdict(),
		], "Tap or press SPACE to continue" if t > 1.0 else "")
	draw_overlay()


func draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, 84), Color(0.08, 0.1, 0.16, 0.88))
	text(Vector2(150, 36), "Level %d   %d pts   ships %d/%d   best %d" % [level, score, mini(done, quota), quota, best], 26, Color(1, 1, 1))
	text(Vector2(150, 70), lv_info(level)["n"], 22, Color(1, 0.45, 0.55))
	for i in mini(6, lives):
		draw_set_transform(Vector2(W - 60 - i * 34, 42), 0, Vector2(2.2, 2.2))
		draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(2, -4), Vector2(-6, -3), Vector2(-6, 3), Vector2(2, 4)]), Color(0.43, 0.64, 1.0))
		screen()
	if F.get("storm", 0.0) > 0.0 and Vector2(wind["x"], wind["y"]).length() > 3:
		var a := atan2(wind["y"], wind["x"])
		var m := minf(1.0, Vector2(wind["x"], wind["y"]).length() / 22.0)
		draw_set_transform(Vector2(60, 140), a, Vector2(2.5, 2.5))
		draw_line(Vector2(-10, 0), Vector2(8 * m + 4, 0), Color(1, 1, 1, 0.7), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(8 * m + 6, 0), Vector2(8 * m, -4), Vector2(8 * m, 4)]), Color(1, 1, 1, 0.7))
		screen()
		draw_string(font, Vector2(30, 185), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
	if banner != null:
		var a := clampf(minf(banner["t"] * 2.0, (3.6 - banner["t"]) * 4.0), 0.0, 1.0)
		draw_rect(Rect2(W / 2 - 430, 200, 860, 110), Color(0.1, 0.12, 0.2, 0.95 * a))
		draw_rect(Rect2(W / 2 - 430, 200, 860, 110), Color(1, 0.4, 0.55, a), false, 2.0)
		text(Vector2(0, 245), banner["n"], 32, Color(1, 0.45, 0.55, a), true)
		text(Vector2(0, 288), banner["s"], 21, Color(1, 1, 1, a), true)


func draw_shore() -> void:
	var pts := PackedVector2Array([Vector2(0, HH)])
	var x := 0.0
	while x <= WW:
		pts.append(Vector2(x, shore_y(x) + 3))
		x += 8.0
	pts.append(Vector2(WW, HH))
	draw_colored_polygon(pts, Color("#5a4a33"))
	var line := PackedVector2Array()
	x = 0.0
	while x <= WW:
		line.append(Vector2(x, shore_y(x) + sin(x * 0.08 + gt * 2.0) * 1.2))
		x += 8.0
	draw_polyline(line, Color(0.9, 0.94, 1, 0.35), 2.0)
	x = 6.0
	while x < WW:
		var yy := shore_y(x) + 10
		if yy < HH - 4:
			draw_circle(Vector2(x, yy + 4), 4, Color("#4b6b37"))
		x += 23.0
	for i in 2:
		var gx := WW * (0.12 if i == 0 else 0.86)
		var y := shore_y(gx) + 13 + sin(gt * 3.0 + i)
		draw_set_transform(Vector2(gx, y) * K, 0, Vector2(K * 1.0, K * 0.64))
		draw_circle(Vector2.ZERO, 5, Color("#f2f2ee"))
		world()
		var hd := -5.0 if i == 1 else 5.0
		draw_circle(Vector2(gx + hd, y - 3), 1.8, Color("#222222"))
		draw_rect(Rect2(gx + (-8.0 if i == 1 else 6.0), y - 3.6, 2.4, 1.4), Color("#f2a33a"))


func draw_lighthouse() -> void:
	var c := Vector2(LX, LY)
	draw_circle(c + Vector2(4, 6), 20, Color(0, 0, 0, 0.25))
	draw_circle(c, 19, Color("#d7d2c8"))
	draw_arc(c, 14, 0, TAU, 32, Color("#c0392b"), 5.0)
	draw_circle(c, 10.5, Color("#f4f1ea"))
	draw_arc(c, 19, 0, TAU, 32, Color("#2b2b2b"), 1.0)
	for i in 12:
		var a := i / 12.0 * TAU
		draw_line(c + Vector2(cos(a), sin(a)) * 16.5, c + Vector2(cos(a), sin(a)) * 19, Color("#2b2b2b"), 1.0)
	draw_circle(c, 9, Color(1, 0.95, 0.7, 0.6))
	draw_circle(c, 5, Color("#ffe9a3"))
	draw_set_transform(c * K, aim, Vector2(K, K))
	draw_rect(Rect2(4, -3, 7, 6), Color("#3b3b3b"))
	world()


func draw_beam(length: float, hw: float) -> void:
	var L := minf(length, 900.0)
	var c := Vector2(LX, LY)
	for band in 3:
		var r := L * (1.0 - band * 0.3)
		var pts := PackedVector2Array([c])
		for i in 17:
			var a := aim - hw + 2.0 * hw * i / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(1, 0.9, 0.55, 0.09 + band * 0.07))
	draw_line(c, c + Vector2(cos(aim - hw), sin(aim - hw)) * L, Color(1, 0.93, 0.67, 0.28), 1.0)
	draw_line(c, c + Vector2(cos(aim + hw), sin(aim + hw)) * L, Color(1, 0.93, 0.67, 0.28), 1.0)
	if length < 880.0:
		var e := c + Vector2(cos(aim), sin(aim)) * length
		for k in 4:
			draw_circle(e, 48.0 - k * 11.0, Color(1, 0.96, 0.84, 0.12))


func draw_rock(r: Dictionary, lit: bool) -> void:
	var c := Vector2(r["x"], r["y"])
	var rr: float = r["r"]
	draw_arc(c, rr + 4 + sin(gt * 1.6 + r["seed"]) * 1.2, 0, TAU, 24, Color(1, 1, 1, 0.75) if lit else Color(0.82, 0.9, 1, 0.22 + 0.1 * sin(gt * 2.0 + r["seed"])), 2.0 if lit else 1.5)
	var pts := PackedVector2Array()
	for i in 7:
		var a := i / 7.0 * TAU
		pts.append(c + Vector2(cos(a), sin(a)) * rr * (0.8 + 0.25 * sin(r["seed"] * 7.0 + i * 2.3)))
	draw_colored_polygon(pts, Color("#8d8a82") if lit else Color("#3a4350"))
	draw_circle(c - Vector2(rr, rr) * 0.25, rr * 0.42, Color("#bdb8ab") if lit else Color("#4d5868"))


func draw_ship(s: Dictionary) -> void:
	var lit: bool = s["lit"]
	if s["wake"].size() > 1:
		draw_polyline(PackedVector2Array(s["wake"]), Color(0.86, 0.92, 1, 0.18), 1.5)
	var bob := sin(s["bob"]) * 0.06
	draw_set_transform(Vector2(s["x"], s["y"]) * K, s["a"] + bob, Vector2(K, K) * 1.2)
	var hc: Color = s["col"]
	var hull := Color("#1a1c22") if s["smug"] else (hc if lit else Color(hc.r * 0.55, hc.g * 0.58, hc.b * 0.7))
	var sail: Color = Color("#2a2d35") if s["smug"] else (s["sail"] if lit else Color("#7f8a99"))
	draw_set_transform(Vector2(s["x"], s["y"]) * K + Vector2(1.5, 2.5) * K, s["a"] + bob, Vector2(K * 1.2 * 1.0, K * 1.2 * 0.45))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(s["x"], s["y"]) * K, s["a"] + bob, Vector2(K, K) * 1.2)
	draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(7, -4.5), Vector2(0, -5.5), Vector2(-9, -5), Vector2(-10, 5), Vector2(0, 5.5), Vector2(7, 4.5)]), hull)
	draw_colored_polygon(PackedVector2Array([Vector2(1, -8.5), Vector2(3.5, -4), Vector2(4, 0), Vector2(3.5, 4), Vector2(1, 8.5), Vector2(-1, 8.5), Vector2(1.5, 0), Vector2(-1, -8.5)]), sail)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(-4.2, 0), Vector2(-6, 6), Vector2(-7.5, 6), Vector2(-5.7, 0), Vector2(-7.5, -6)]), sail)
	if s["smug"]:
		draw_circle(Vector2(-3, 0), 1.6, Color("#e9e9e9"))
	world()


func draw_serp(S: Dictionary) -> void:
	var tr: Array = S["trail"]
	if tr.size() < 2:
		return
	var lit := in_beam(S["x"], S["y"])
	for k in range(4, -1, -1):
		var p: Vector2 = tr[mini(tr.size() - 1, 6 + k * 12)]
		var hump := sin(gt * 4.0 - k) * 0.5 + 0.5
		draw_circle(p, 10, Color(1, 1, 1, 0.12))
		draw_circle(p, 5.5 + hump * 4.5 - k * 0.5, Color("#4caf6a") if lit else Color("#24573a"))
	draw_set_transform(Vector2(S["x"], S["y"]) * K, S["a"], Vector2(K, K) * 1.35)
	draw_set_transform(Vector2(S["x"], S["y"]) * K, S["a"], Vector2(K * 1.35, K * 1.35 * 0.72))
	draw_circle(Vector2(2, 0), 9, Color("#57c27a") if lit else Color("#2d6b46"))
	draw_set_transform(Vector2(S["x"], S["y"]) * K, S["a"], Vector2(K, K) * 1.35)
	draw_circle(Vector2(5, -3.2), 1.9, Color("#ffe14d"))
	draw_circle(Vector2(5, 3.2), 1.9, Color("#ffe14d"))
	draw_circle(Vector2(5.6, -3.2), 0.9, Color("#111111"))
	draw_circle(Vector2(5.6, 3.2), 0.9, Color("#111111"))
	world()
	if S["full"] > 0.0:
		label(S["x"], S["y"] - 14, "*burp*", Color("#fff6d8"), 10)


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(W / 2 - 540, 130, 1080, 450), Color(0.08, 0.1, 0.18, 0.95))
	text(Vector2(0, 210), title, 56, Color(1, 0.85, 0.45), true)
	var y := 280.0
	for l in lines:
		text(Vector2(0, y), l, 24, Color(1, 1, 1), true)
		y += 42.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 545), prompt, 30, Color(0.6, 1, 0.6), true)
