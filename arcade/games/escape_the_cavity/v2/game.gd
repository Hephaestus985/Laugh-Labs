extends ArcadeGame
# Escape the Cavity: you are a photon stuck in a VCSEL. Hop across Bragg
# mirrors, grab carriers, survive 6 increasingly hostile levels for 72 s.

const LT := 12.0
const ROUND := 72.0
const TOP := 70.0  # play area starts below the HUD
const PS := 32.0   # photon size

const DIFFS := [
	{"name": "Easy", "spd": 0.75, "dens": 0.75, "lives": 4, "warn": 1.3, "walk": -1},
	{"name": "Normal", "spd": 1.0, "dens": 1.0, "lives": 3, "warn": 1.0, "walk": 0},
	{"name": "Hard", "spd": 1.3, "dens": 1.3, "lives": 2, "warn": 0.75, "walk": 1},
]
const LAY := [
	[[0.05, 0.78, 0.3], [0.65, 0.78, 0.3], [0.3, 0.58, 0.4], [0.0, 0.38, 0.3], [0.7, 0.38, 0.3], [0.35, 0.2, 0.3]],
	[[0.0, 0.78, 0.25], [0.375, 0.78, 0.25], [0.75, 0.78, 0.25], [0.15, 0.58, 0.25], [0.6, 0.58, 0.25], [0.375, 0.38, 0.25], [0.05, 0.2, 0.25], [0.7, 0.2, 0.25]],
	[[0.0, 0.8, 0.2], [0.22, 0.62, 0.2], [0.44, 0.44, 0.2], [0.66, 0.26, 0.2], [0.8, 0.62, 0.2], [0.05, 0.4, 0.15]],
]
const LV := [
	{"n": "Active Region", "h": "Grab carriers. Nothing can go wrong. Yet.", "lay": 0, "walk": 0, "ws": 45, "dust": 0.0, "lava": false, "beam": 0.0, "ptr": false},
	{"n": "Bottom DBR", "h": "Absorbers patrol the mirrors. No touching.", "lay": 1, "walk": 2, "ws": 45, "dust": 0.0, "lava": false, "beam": 0.0, "ptr": false},
	{"n": "Cleanroom", "h": "Somebody skipped gowning. Dust incoming!", "lay": 2, "walk": 1, "ws": 50, "dust": 1.3, "lava": false, "beam": 0.0, "ptr": false},
	{"n": "Thermal Rollover", "h": "Heat sink called in sick. Floor is lava.", "lay": 0, "walk": 1, "ws": 55, "dust": 0.8, "lava": true, "beam": 0.0, "ptr": false},
	{"n": "Reviewer 2's Laser", "h": "Red dashes = incoming critique. Change rows (or jump it)!", "lay": 1, "walk": 2, "ws": 55, "dust": 0.4, "lava": false, "beam": 2.2, "ptr": false},
	{"n": "The Lab Cat", "h": "All of it at once, and the lab cat has decided YOU are the red dot.", "lay": 2, "walk": 2, "ws": 65, "dust": 1.0, "lava": true, "beam": 2.8, "ptr": true},
]
const GOOD := ["+gain", "stimulated!", "in phase", "coherent!", "population inverted"]

enum State { TITLE, PLAY, OVER }
var state: int = State.TITLE
var diff := 1
var D: Dictionary
var gt := 0.0  # game time
var lvl := 1
var score := 0
var lives := 3
var max_lives := 3
var inv := 0.0
var collected := 0
var banner := 0.0
var survived := false
var new_best := false

var px := 0.0
var py := 0.0
var vx := 0.0
var vy := 0.0
var ground := false
var on_floor := false
var face := 1.0
var jump_buf := 0.0
var coyote := 0.0

var walkers: Array = []
var dust: Array = []
var beams: Array = []
var pops: Array = []
var carriers: Array = []
var dust_t := 0.0
var beam_t := 0.0
var cat = null  # Vector2 or null


func _ready() -> void:
	game_id = "escape_the_cavity"
	load_best()
	diff = difficulty()
	D = DIFFS[diff]


func L() -> Dictionary:
	return LV[lvl - 1]


func area_h() -> float:
	return H - TOP


func plats() -> Array:
	var a: Array = [Rect2(0, H - 16, W, 16)]
	for f in LAY[L()["lay"]]:
		a.append(Rect2(f[0] * W, TOP + f[1] * area_h(), f[2] * W, 16))
	return a


func spawn_carrier() -> void:
	var ps := plats()
	var start := 1 if L()["lava"] else 0
	carriers.append({"p": start + randi() % (ps.size() - start), "f": 0.1 + 0.8 * randf(), "b": randf() * 6.0})


func place_cat() -> void:
	cat = Vector2(W - 60 if px < W / 2.0 else 60.0, TOP + 80)


func set_level(n: int) -> void:
	lvl = n
	banner = 2.6
	var ps := plats()
	var lv := L()
	walkers.clear()
	beams.clear()
	carriers.clear()
	dust.clear()
	var idx: Array = range(1, ps.size())
	idx.shuffle()
	var nw: int = maxi(1, lv["walk"] + D["walk"]) if lv["walk"] > 0 else 0
	for i in nw:
		walkers.append({"p": idx[i % idx.size()], "t": randf(), "d": 1.0 if randf() < 0.5 else -1.0})
	for i in (3 if n >= 4 else 2):
		spawn_carrier()
	dust_t = 1.0
	beam_t = 1.2
	inv = maxf(inv, 1.2)
	if lv["ptr"]:
		place_cat()
	else:
		cat = null
	if n > 1:
		shake(4.0)


func start() -> void:
	D = DIFFS[diff]
	gt = 0.0
	score = 0
	max_lives = D["lives"]
	lives = max_lives
	inv = 0.0
	collected = 0
	pops.clear()
	jump_buf = 0.0
	coyote = 0.0
	px = W / 2.0 - PS / 2.0
	py = H - 16 - PS
	vx = 0.0
	vy = 0.0
	face = 1.0
	set_level(1)
	new_best = false
	state = State.PLAY


func pop(p: Vector2, s: String, c: Color) -> void:
	pops.append({"p": p, "s": s, "t": 1.1, "c": c})


func hurt(why: String) -> bool:
	if inv > 0.0 or state != State.PLAY:
		return false
	lives -= 1
	inv = 1.5
	shake(10.0)
	pop(Vector2(px + PS / 2, py - 12), why, Color(1, 0.4, 0.5))
	if lives <= 0:
		finish(false)
	return true


func on_input(event: InputEvent) -> void:
	if state == State.PLAY and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_UP, KEY_W]:
		jump_buf = 0.15
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
			set_difficulty(game_id, diff)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
			set_difficulty(game_id, diff)


func _process(delta: float) -> void:
	tick(delta)
	match state:
		State.TITLE:
			if pressed_b():
				diff = (diff + 1) % 3
				set_difficulty(game_id, diff)
			if start_pressed():
				start()
		State.OVER:
			if start_pressed() and t > 0.8:
				state = State.TITLE
				t = 0.0
		State.PLAY:
			update(minf(delta, 0.04))
	for p in pops:
		p["t"] -= delta
		p["p"].y -= 60.0 * delta
	pops = pops.filter(func(p): return p["t"] > 0.0)
	queue_redraw()


func update(dt: float) -> void:
	if pressed_a():
		jump_buf = 0.15
	gt += dt
	var nl := mini(LV.size(), int(gt / LT) + 1)
	if nl != lvl:
		set_level(nl)
	if gt >= ROUND:
		finish(true)
		return
	var lv := L()
	var ps := plats()
	inv = maxf(0.0, inv - dt)
	banner = maxf(0.0, banner - dt)
	var ax := axis().x
	if absf(ax) > 0.2:
		face = signf(ax)
	px = clampf(px + ax * 560.0 * dt, 0.0, W - PS)
	jump_buf -= dt
	coyote -= dt
	if ground:
		coyote = 0.1
	if jump_buf > 0.0 and coyote > 0.0:
		vy = -1080.0
		jump_buf = 0.0
		coyote = 0.0
		ground = false
	vy = minf(1800.0, vy + 3000.0 * dt)
	var prev_b := py + PS
	py += vy * dt
	ground = false
	on_floor = false
	if vy >= 0.0:
		for i in ps.size():
			var p: Rect2 = ps[i]
			if px + PS > p.position.x + 4 and px < p.end.x - 4 and prev_b <= p.position.y + 1.0 and py + PS >= p.position.y:
				py = p.position.y - PS
				vy = 0.0
				ground = true
				on_floor = i == 0
				break
	if py + PS > ps[0].position.y:
		py = ps[0].position.y - PS
		vy = 0.0
		ground = true
		on_floor = true
	if py < TOP:
		py = TOP
		vy = maxf(vy, 0.0)
	if lv["lava"] and on_floor:
		hurt("Thermal rollover!")
		vy = -1240.0
		ground = false
		if state != State.PLAY:
			return
	var c := Vector2(px + PS / 2, py + PS / 2)
	for i in range(carriers.size() - 1, -1, -1):
		var cr: Dictionary = carriers[i]
		if cr["p"] >= ps.size():
			carriers.remove_at(i)
			spawn_carrier()
			continue
		var p: Rect2 = ps[cr["p"]]
		var cp := Vector2(p.position.x + cr["f"] * p.size.x, p.position.y - 24 + sin(cr["b"] + gt * 4.0) * 4.0)
		if cp.distance_to(c) < 32.0:
			carriers.remove_at(i)
			var g := 10 * lvl
			score += g
			collected += 1
			pop(cp - Vector2(0, 16), "+%d %s" % [g, GOOD[randi() % GOOD.size()]], Color(0.5, 0.75, 1))
			spawn_carrier()
	for w in walkers:
		var p: Rect2 = ps[w["p"]]
		w["t"] += w["d"] * lv["ws"] * 2.0 * D["spd"] * dt / maxf(40.0, p.size.x - 36.0)
		if w["t"] > 1.0:
			w["t"] = 1.0
			w["d"] = -1.0
		if w["t"] < 0.0:
			w["t"] = 0.0
			w["d"] = 1.0
		var wr := walker_rect(w, p)
		if wr.grow(-4).intersects(Rect2(px, py, PS, PS)):
			hurt("Absorbed by a defect!")
	if state != State.PLAY:
		return
	if lv["dust"] > 0.0:
		dust_t -= dt
		if dust_t <= 0.0:
			dust_t = (1.0 / (lv["dust"] * D["dens"])) * (0.6 + randf() * 0.8)
			dust.append({"x": 16 + randf() * (W - 32), "y": TOP, "vy": (220.0 + randf() * 180.0) * D["spd"]})
	for i in range(dust.size() - 1, -1, -1):
		var d: Dictionary = dust[i]
		d["y"] += d["vy"] * dt
		if d["y"] > H:
			dust.remove_at(i)
			continue
		var n := Vector2(clampf(d["x"], px, px + PS), clampf(d["y"], py, py + PS))
		if n.distance_to(Vector2(d["x"], d["y"])) < 10.0:
			dust.remove_at(i)
			hurt("Cleanroom particle!")
	if state != State.PLAY:
		return
	if lv["beam"] > 0.0:
		beam_t -= dt
		if beam_t <= 0.0:
			beam_t = lv["beam"] / D["dens"]
			var ys: Array = []
			for i in ps.size():
				if lv["lava"] and i == 0:
					continue
				var yy: float = ps[i].position.y
				if not ys.has(yy):
					ys.append(yy)
			beams.append({"y": ys[randi() % ys.size()] - 16.0, "t": 0.0, "w": D["warn"], "z": false})
	for i in range(beams.size() - 1, -1, -1):
		var b: Dictionary = beams[i]
		b["t"] += dt
		if b["t"] >= b["w"] and not b["z"]:
			b["z"] = true
			shake(3.0)
		if b["t"] >= b["w"] and b["t"] < b["w"] + 0.4 and py < b["y"] + 6 and py + PS > b["y"] - 6:
			hurt("Peer-reviewed by laser!")
		if b["t"] > b["w"] + 0.4:
			beams.remove_at(i)
	if state != State.PLAY:
		return
	if cat != null:
		var dv: Vector2 = c - cat
		var dl := maxf(1.0, dv.length())
		cat += dv / dl * (150.0 * D["spd"]) * dt
		if dl < 30.0 and hurt("Pounced by the lab cat!"):
			place_cat()


func walker_rect(w: Dictionary, p: Rect2) -> Rect2:
	return Rect2(p.position.x + w["t"] * (p.size.x - 36.0), p.position.y - 24, 36, 24)


func verdict(s: int) -> String:
	if s < 100:
		return "Below threshold. Your photon is mostly spontaneous emission and vibes."
	if s < 300:
		return "LED behaviour: bright-ish, incoherent, and only moths are impressed."
	if s < 600:
		return "Lasing achieved! Einstein would like it noted that he called it in 1917."
	if s < 1000:
		return "Single-mode, low threshold. Reviewer 2 found nothing to complain about and is furious."
	return "Nobel-adjacent. Maiman wants to hang you next to his 1960 ruby laser."


func finish(ok: bool) -> void:
	if state != State.PLAY:
		return
	survived = ok
	if ok:
		score += lives * 50
	state = State.OVER
	t = 0.0
	new_best = submit_score(score)


func _draw() -> void:
	var bg := Color(0.09, 0.10, 0.16)
	var laser := Color(1.0, 0.35, 0.5)
	var beam := Color(0.43, 0.64, 1.0)
	draw_rect(Rect2(-40, -40, W + 80, H + 80), bg)
	var lv := L()
	match lvl:
		2, 6:
			for y in range(int(TOP), int(H), 28):
				draw_rect(Rect2(0, y, W, 14), Color(beam if (y / 28) % 2 else laser, 0.07))
		3:
			for i in 90:
				draw_rect(Rect2(fmod(i * 197.0, W), TOP + fmod(i * 53.0 + gt * 40.0, area_h()), 4, 4), Color(1, 1, 1, 0.08))
		4:
			for i in 12:
				draw_rect(Rect2(0, H - (i + 1) * 30, W, 30), Color(laser, 0.03 * (12 - i)))
		5:
			for x in range(0, int(W), 60):
				draw_line(Vector2(x, TOP), Vector2(x, H), Color(laser, 0.08), 2.0)
	var ps := plats()
	for i in ps.size():
		var p: Rect2 = ps[i]
		if i == 0 and lv["lava"]:
			draw_rect(p, laser)
			for x in range(0, int(W), 32):
				draw_rect(Rect2(x, p.position.y - 6 + sin(gt * 8.0 + x) * 4.0, 16, 8), Color(1, 0.7, 0.75))
		else:
			draw_rect(p, Color(0.16, 0.19, 0.27))
			draw_rect(p, Color(0.3, 0.35, 0.45), false, 2.0)
			draw_rect(Rect2(p.position, Vector2(p.size.x, 4)), beam)
	for b in beams:
		if b["t"] < b["w"]:
			if int(b["t"] * 10.0) % 2 == 0:
				draw_dashed_line(Vector2(0, b["y"]), Vector2(W, b["y"]), Color(laser, 0.7), 4.0, 16.0)
		else:
			draw_rect(Rect2(0, b["y"] - 10, W, 20), Color(laser, 0.3))
			draw_rect(Rect2(0, b["y"] - 5, W, 10), laser)
	for cr in carriers:
		if cr["p"] >= ps.size():
			continue
		var p: Rect2 = ps[cr["p"]]
		var cp := Vector2(p.position.x + cr["f"] * p.size.x, p.position.y - 24 + sin(cr["b"] + gt * 4.0) * 4.0)
		draw_circle(cp, 18, Color(beam, 0.25))
		draw_circle(cp, 10, beam)
	for w in walkers:
		var r := walker_rect(w, ps[w["p"]])
		draw_circle(r.get_center() + Vector2(-6, 2), 14, Color(0.5, 0.52, 0.6))
		draw_circle(r.get_center() + Vector2(6, 2), 14, Color(0.5, 0.52, 0.6))
		var e := r.get_center() + Vector2(w["d"] * 2.0, -2)
		draw_rect(Rect2(e + Vector2(-9, -3), Vector2(6, 6)), bg)
		draw_rect(Rect2(e + Vector2(3, -3), Vector2(6, 6)), bg)
		draw_line(e + Vector2(-12, -10), e + Vector2(-4, -6), bg, 2.0)
		draw_line(e + Vector2(12, -10), e + Vector2(4, -6), bg, 2.0)
	for d in dust:
		draw_circle(Vector2(d["x"], d["y"]), 8, Color(0.6, 0.62, 0.7))
	if cat != null:
		draw_cat(cat)
	if not (inv > 0.0 and int(inv * 12.0) % 2 == 1):
		var c := Vector2(px + PS / 2, py + PS / 2)
		var pts := PackedVector2Array()
		for i in 14:
			pts.append(c + Vector2(-face * (20 + i * 2.5), sin(i * 0.9 + gt * 20.0) * 6.0))
		draw_polyline(pts, Color(1, 0.7, 0.78, 0.7), 4.0)
		draw_circle(c, 26, Color(laser, 0.25))
		draw_circle(c, 16, laser)
		draw_rect(Rect2(c + Vector2(-6 + face * 4, -6), Vector2(4, 6)), bg)
		draw_rect(Rect2(c + Vector2(2 + face * 4, -6), Vector2(4, 6)), bg)
	for p in pops:
		text(p["p"] - Vector2(100, 0), p["s"], 22, Color(p["c"], minf(1.0, p["t"] * 2.0)))
	# HUD
	draw_rect(Rect2(0, 0, W * minf(1.0, gt / ROUND), 6), Color(1, 0.7, 0.78))
	text(Vector2(150, 34), "LV %d/%d  %s" % [lvl, LV.size(), lv["n"]], 24, Color(1, 1, 1))
	for i in max_lives:
		var hc := Vector2(160 + i * 26, 54)
		draw_circle(hc, 9, laser if i < lives else Color(laser, 0.25))
	text(Vector2(170 + max_lives * 26, 62), "%d s to lasing" % maxi(0, ceili(ROUND - gt)), 22, laser)
	text(Vector2(W - 220, 40), "%d" % score, 34, beam)
	text(Vector2(W - 220, 64), "best %d" % best, 18, Color(1, 0.9, 0.6))
	if banner > 0.0 and state == State.PLAY:
		var a := minf(1.0, banner * 1.5)
		draw_rect(Rect2(W / 2 - 360, 270, 720, 110), Color(0.12, 0.13, 0.2, 0.92 * a))
		draw_rect(Rect2(W / 2 - 360, 270, 720, 110), Color(laser, a), false, 2.0)
		text(Vector2(0, 312), "Level %d: %s" % [lvl, lv["n"]], 34, Color(laser, a), true)
		text(Vector2(0, 355), lv["h"], 22, Color(1, 1, 1, a), true)
	if state == State.TITLE:
		overlay_card("ESCAPE THE CAVITY", [
			"You are a photon stuck in a VCSEL. Lasing needs gain, gain needs carriers,",
			"and carriers need YOU to jump. Survive 6 increasingly hostile levels for 72 s.",
			"Move: arrows / stick.  Jump: SPACE / up / A button.",
			"Difficulty: %s   (change it on the start screen, or with left / right here)" % DIFFS[diff]["name"],
		], "Tap A or press SPACE to start")
	elif state == State.OVER:
		overlay_card("LASING!" if survived else "DECOHERENCE", [
			"Score %d%s" % [score, "   NEW BEST!" if new_best else ""],
			"%d carriers, level %d/%d, %s" % [collected, lvl, LV.size(), D["name"]],
			verdict(score),
		], "Tap A or press SPACE to continue" if t > 0.8 else "")
	draw_overlay("JUMP" if state == State.PLAY else "GO", "DIFF")


func overlay_card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(W / 2 - 520, 140, 1040, 420), Color(0.12, 0.13, 0.2, 0.95))
	text(Vector2(0, 220), title, 64, Color(1, 0.4, 0.55), true)
	var y := 290.0
	for l in lines:
		text(Vector2(0, y), l, 25, Color(1, 1, 1), true)
		y += 44.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 520), prompt, 30, Color(0.6, 1, 0.6), true)


func draw_cat(p: Vector2) -> void:
	var ink := Color(0.92, 0.92, 0.95)
	var f := 1.0 if px + PS / 2 > p.x else -1.0
	var bob := sin(gt * 12.0) * 3.0
	draw_circle(p + Vector2(-f * 12, 12 + bob), 20, ink)
	draw_circle(p + Vector2(-f * 24, 14 + bob), 14, ink)
	draw_line(p + Vector2(-f * 34, 8), p + Vector2(-f * 46, -20 + sin(gt * 6.0) * 8.0), ink, 6.0)
	draw_circle(p + Vector2(f * 12, -4 + bob), 16, ink)
	draw_colored_polygon(PackedVector2Array([p + Vector2(f * 2, -14 + bob), p + Vector2(f * 4, -32 + bob), p + Vector2(f * 12, -18 + bob)]), ink)
	draw_colored_polygon(PackedVector2Array([p + Vector2(f * 14, -18 + bob), p + Vector2(f * 24, -32 + bob), p + Vector2(f * 24, -10 + bob)]), ink)
	draw_rect(Rect2(p + Vector2(f * 8 - 2, -8 + bob), Vector2(4, 6)), Color(0.43, 0.64, 1.0))
	draw_rect(Rect2(p + Vector2(f * 18 - 2, -8 + bob), Vector2(4, 6)), Color(0.43, 0.64, 1.0))
	draw_string(font, p + Vector2(-60, 50), "lab cat", HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(0.7, 0.7, 0.8))
