extends ArcadeGame
# Bend It Like Einstein: photons refuse to turn, so hold to summon a pocket
# black hole and bend them into the fiber. 5 levels, 60 seconds.

const LT := 12.0
const ROUND := 60.0
const TOP := 84.0
const DIFFS := [
	{"name": "Easy", "v": 0.8, "spawn": 1.3, "dh": 1.25, "move": 0.75},
	{"name": "Normal", "v": 1.0, "spawn": 1.0, "dh": 1.0, "move": 1.0},
	{"name": "Hard", "v": 1.25, "spawn": 0.77, "dh": 0.8, "move": 1.3},
]
const LV := [
	{"name": "Clean Bench", "note": "Hold to summon a pocket black hole. Bend the light!", "ey": .3, "dy": .72, "amp": 0.0, "spd": 0.0, "spawn": .9, "spread": 0.0, "dh": 150.0, "goose": false, "box": false, "rogue": false, "fog": 0},
	{"name": "Goose Pond", "note": "New hazard: a goose who never read the T&Cs.", "ey": .75, "dy": .3, "amp": 0.0, "spd": 0.0, "spawn": .8, "spread": .05, "dh": 130.0, "goose": true, "box": false, "rogue": false, "fog": 0},
	{"name": "Monolith Alley", "note": "A monolith drifts by (apes not included). The fiber drifts too.", "ey": .5, "dy": .5, "amp": .28, "spd": .9, "spawn": .75, "spread": .08, "dh": 118.0, "goose": false, "box": true, "rogue": false, "fog": 0},
	{"name": "Nebula Fog", "note": "A nebula hides your photons and the beam diverges. Goose AND monolith.", "ey": .25, "dy": .72, "amp": .12, "spd": 1.2, "spawn": .7, "spread": .28, "dh": 110.0, "goose": true, "box": true, "rogue": false, "fog": 2},
	{"name": "Stray Black Hole", "note": "A rogue black hole wandered in. No refunds past the event horizon.", "ey": .5, "dy": .3, "amp": .22, "spd": 1.8, "spawn": .6, "spread": .15, "dh": 104.0, "goose": true, "box": false, "rogue": true, "fog": 1},
]

enum State { TITLE, PLAY, OVER }
var state: int = State.TITLE
var diff := 1
var D: Dictionary
var gt := 0.0
var score := 0
var coupled := 0
var emitted := 0
var lvl := 0
var banner := 0.0
var spawn_t := 0.0
var photons: Array = []
var fx: Array = []
var hole := Vector2(640, 400)
var kb_used := false
var det_y := 0.0
var goose := Vector2.ZERO
var box := Rect2()
var rogue := Vector2.ZERO
var fogs: Array = []
var new_best := false


func _ready() -> void:
	game_id = "bend_it_like_einstein"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()
	D = DIFFS[diff]


func ah() -> float:
	return H - TOP


func start() -> void:
	D = DIFFS[diff]
	gt = 0.0
	score = 0
	coupled = 0
	emitted = 0
	lvl = 0
	banner = 2.4
	spawn_t = 0.8
	photons.clear()
	fx.clear()
	hole = Vector2(W / 2, TOP + ah() / 2)
	new_best = false
	state = State.PLAY
	clear_presses()


func active() -> bool:
	return a_down or pointer_down


func add_fx(p: Vector2, s: String, c: Color) -> void:
	if fx.size() > 14:
		fx.pop_front()
	fx.append({"p": Vector2(clampf(p.x, 160, W - 160), clampf(p.y, TOP + 30, H - 20)), "s": s, "c": c, "a": 1.2})


func on_input(event: InputEvent) -> void:
	if state == State.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A]:
			diff = maxi(0, diff - 1)
		elif event.keycode in [KEY_RIGHT, KEY_D]:
			diff = mini(2, diff + 1)
	if state == State.PLAY and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouseMotion and pointer_down)):
		hole = pointer
		kb_used = false


func _process(delta: float) -> void:
	tick(delta)
	match state:
		State.TITLE:
			if pressed_b():
				diff = (diff + 1) % 3
			if pressed_a():
				start()
		State.OVER:
			if pressed_a() and t > 0.8:
				state = State.TITLE
				t = 0.0
		State.PLAY:
			update(minf(delta, 0.04))
	for f in fx:
		f["a"] -= delta * 0.9
		f["p"].y -= delta * 40.0
	fx = fx.filter(func(f): return f["a"] > 0.0)
	queue_redraw()


func pull(p: Dictionary, target: Vector2, k: float, acc: Vector2) -> Array:
	var d: Vector2 = target - p["pos"]
	var d2 := maxf(d.length_squared(), 1150.0)
	var dl := maxf(1.0, d.length())
	var a := minf(8500.0, k / d2)
	return [acc + d / dl * a, dl]


func update(dt: float) -> void:
	gt += dt
	if gt >= ROUND:
		gt = ROUND
		finish()
		return
	var li := mini(4, int(gt / LT))
	if li != lvl:
		lvl = li
		banner = 2.6
		shake(4.0)
	banner = maxf(0.0, banner - dt)
	var L: Dictionary = LV[lvl]
	var mt: float = (gt - lvl * LT) * D["move"]
	var dh: float = L["dh"] * D["dh"]
	det_y = clampf(TOP + L["dy"] * ah() + sin(mt * L["spd"]) * L["amp"] * ah(), TOP + 60, H - 60)
	goose = Vector2(W * .5 + sin(mt * .7) * W * .12, TOP + ah() * .52 + sin(mt * 1.3) * ah() * .28)
	box = Rect2(W * .68, TOP + ah() * .52 + sin(mt * 1.1) * ah() * .3 - 85, 26, 170)
	rogue = Vector2(W * .47, TOP + ah() * .5 + sin(mt * .8) * 50.0)
	fogs.clear()
	for i in L["fog"]:
		fogs.append({"p": Vector2(W * (.62 if i else .36) + sin(mt * .5 + i * 2) * W * .1, TOP + ah() * (.35 if i else .66) + cos(mt * .4 + i) * ah() * .08), "r": 110.0})
	var ax := axis()
	if ax != Vector2.ZERO:
		hole += ax * 520.0 * dt
		kb_used = true
	hole = hole.clamp(Vector2(0, TOP), Vector2(W, H))
	var on := active()
	var v: float = 380.0 * D["v"]
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t += L["spawn"] * D["spawn"]
		var an: float = (randf() * 2.0 - 1.0) * L["spread"]
		photons.append({"pos": Vector2(34, TOP + L["ey"] * ah()), "vel": Vector2(cos(an), sin(an)) * v, "dead": false})
		emitted += 1
	var h := dt / 2.0
	for p in photons:
		for s in 2:
			if p["dead"]:
				break
			var acc := Vector2.ZERO
			var d_p := 1e9
			var d_r := 1e9
			if on:
				var r := pull(p, hole, 1.75e7, acc)
				acc = r[0]
				d_p = r[1]
			if L["rogue"]:
				var r2 := pull(p, rogue, 1.1e7, acc)
				acc = r2[0]
				d_r = r2[1]
			var vel: Vector2 = p["vel"] + acc * h
			vel = vel.normalized() * v
			p["vel"] = vel
			p["pos"] += vel * h
			var pos: Vector2 = p["pos"]
			if on and d_p < 20.0:
				p["dead"] = true
				score = maxi(0, score - 1)
				add_fx(pos - Vector2(0, 24), "Spaghettified! -1", Color(1, 0.4, 0.5))
			elif L["rogue"] and d_r < 24.0:
				p["dead"] = true
				add_fx(pos - Vector2(0, 24), "No refunds past the event horizon", Color(0.7, 0.7, 0.8))
			elif L["goose"] and pos.distance_to(goose) < 34.0:
				p["dead"] = true
				add_fx(goose - Vector2(0, 44), "HONK. Photon eaten.", Color(1, 0.4, 0.5))
			elif L["box"] and box.has_point(pos):
				p["dead"] = true
				add_fx(box.position - Vector2(0, 14), "Monolith ate it. Apes confused.", Color(0.7, 0.7, 0.8))
			elif pos.x >= W - 20:
				p["dead"] = true
				if absf(pos.y - det_y) < dh / 2.0:
					coupled += 1
					score += lvl + 1
					add_fx(Vector2(W - 100, det_y - dh / 2 - 16), "+%d coupled!" % (lvl + 1), Color(0.43, 0.64, 1.0))
				else:
					add_fx(Vector2(W - 100, pos.y), "Insertion loss", Color(0.7, 0.7, 0.8))
			elif pos.x < 0 or pos.y < TOP or pos.y > H:
				p["dead"] = true
				add_fx(pos, "Lost to Enschede", Color(0.7, 0.7, 0.8))
	photons = photons.filter(func(p): return not p["dead"])


func verdict(s: int) -> String:
	if s < 15:
		return "Coupling efficiency comparable to a goose holding a flashlight."
	if s < 40:
		return "Newton calls it \"a lucky apple\". Promising, though."
	if s < 80:
		return "Eddington would put this on his 1919 eclipse slides."
	if s < 140:
		return "Textbook lensing. The photons have filed no complaints."
	return "Einstein would like a word about your gravity licence."


func finish() -> void:
	state = State.OVER
	t = 0.0
	new_best = submit_score(score)


func _draw() -> void:
	var bg := Color(0.08, 0.09, 0.14)
	var laser := Color(1.0, 0.35, 0.5)
	var beam := Color(0.43, 0.64, 1.0)
	var muted := Color(0.6, 0.62, 0.72)
	draw_rect(Rect2(-40, -40, W + 80, H + 80), bg)
	var gs := 66.0 - lvl * 6.0
	var gc := Color(1, 1, 1, 0.04 + lvl * 0.012)
	var x := 0.0
	while x < W:
		draw_line(Vector2(x, TOP), Vector2(x, H), gc, 1.0)
		x += gs
	var y := TOP
	while y < H:
		draw_line(Vector2(0, y), Vector2(W, y), gc, 1.0)
		y += gs
	var L: Dictionary = LV[lvl]
	var ey: float = TOP + L["ey"] * ah()
	var dh: float = L["dh"] * D["dh"]
	draw_rect(Rect2(0, ey - 24, 30, 48), Color(0.15, 0.16, 0.24))
	draw_rect(Rect2(0, ey - 24, 30, 48), laser, false, 3.0)
	draw_string(font, Vector2(4, ey - 30), "VCSEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
	if state != State.TITLE:
		draw_rect(Rect2(W - 20, det_y - dh / 2, 20, dh), Color(laser, 0.25))
		draw_rect(Rect2(W - 20, det_y - dh / 2, 20, dh), laser, false, 3.0)
		draw_rect(Rect2(W - 20, det_y - 5, 20, 10), beam)
		draw_string(font, Vector2(W - 90, det_y + 6), "fiber", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, muted)
		if L["box"]:
			draw_rect(box, Color(0.9, 0.9, 0.95))
			draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(5, box.size.y - 8)), Color(muted, 0.6))
			draw_string(font, box.position + Vector2(-40, -8), "monolith", HORIZONTAL_ALIGNMENT_CENTER, box.size.x + 80, 16, muted)
		if L["goose"]:
			var gc2 := Color(0.95, 0.95, 0.97)
			draw_set_transform(goose, 0, Vector2(1.6, 1.0))
			draw_circle(Vector2.ZERO, 17, gc2)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			draw_line(goose + Vector2(16, -6), goose + Vector2(22, -32), gc2, 7.0)
			draw_circle(goose + Vector2(24, -36), 8, gc2)
			draw_colored_polygon(PackedVector2Array([goose + Vector2(30, -40), goose + Vector2(44, -35), goose + Vector2(30, -31)]), Color(1, 0.6, 0.1))
			draw_string(font, goose + Vector2(-50, 42), "goose", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, muted)
		if L["rogue"]:
			draw_circle(rogue, 22, Color(0, 0, 0))
			draw_arc(rogue, 30, 0, TAU, 32, beam, 3.0)
			draw_string(font, rogue + Vector2(-80, 56), "stray black hole", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, muted)
	for p in photons:
		var pos: Vector2 = p["pos"]
		var dir: Vector2 = p["vel"].normalized()
		draw_line(pos, pos - dir * 20.0, Color(beam, 0.5), 3.0)
		draw_circle(pos, 5.5, beam)
	for f in fogs:
		var c: Vector2 = f["p"]
		var r: float = f["r"]
		var fc := Color(0.17, 0.18, 0.27, 0.95)
		draw_circle(c, r, fc)
		draw_circle(c + Vector2(-r * .6, r * .3), r * .7, fc)
		draw_circle(c + Vector2(r * .6, -r * .2), r * .65, fc)
		for k in 3:
			draw_arc(c + Vector2(sin(gt + k) * 12, cos(gt * .8 + k) * 9), r * (.35 + k * .2), .3 + k, 2.2 + k, 16, Color(muted, 0.35), 2.0)
		draw_string(font, c + Vector2(-60, 6), "nebula", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, muted)
	if state == State.PLAY:
		if active():
			draw_arc(hole, 100, 0, TAU, 48, Color(laser, 0.3), 2.0)
			draw_circle(hole, 16, Color(0, 0, 0))
			draw_arc(hole, 23, gt * 6.0, gt * 6.0 + PI * 1.4, 20, laser, 4.0)
		elif kb_used:
			draw_arc(hole, 20, 0, TAU, 24, Color(muted, 0.7), 2.0)
	for f in fx:
		draw_string(font, f["p"] - Vector2(150, 0), f["s"], HORIZONTAL_ALIGNMENT_CENTER, 300, 20, Color(f["c"], minf(1.0, f["a"])))
	# HUD
	draw_rect(Rect2(0, 0, W, TOP), Color(0.12, 0.13, 0.2, 0.92))
	draw_rect(Rect2(0, TOP - 4, W * (gt / ROUND), 4), beam)
	text(Vector2(150, 36), "LEVEL %d/5 · %s" % [lvl + 1, L["name"]], 26, laser)
	text(Vector2(150, 70), "Score %d    %d s left    coupled %d    best %d" % [score, ceili(ROUND - gt), coupled, best], 22, Color(1, 1, 1))
	if state == State.PLAY and banner > 0.0:
		var a := minf(1.0, banner)
		draw_rect(Rect2(W / 2 - 380, H / 2 - 60, 760, 110), Color(0.12, 0.13, 0.2, 0.95 * a))
		draw_rect(Rect2(W / 2 - 380, H / 2 - 60, 760, 110), Color(laser, a), false, 2.0)
		text(Vector2(0, H / 2 - 16), "LEVEL %d: %s" % [lvl + 1, L["name"]], 32, Color(laser, a), true)
		text(Vector2(0, H / 2 + 26), L["note"], 22, Color(1, 1, 1, a), true)
	if state == State.TITLE:
		card("BEND IT LIKE EINSTEIN", [
			"Photons refuse to turn, so you summon a pocket black hole to bend them",
			"into the fiber. Don't let them fall in: spaghettified photons cost a point.",
			"Hold the screen (or mouse) where the black hole should be.",
			"On a PC: arrows move it, hold SPACE to switch it on.",
			"Difficulty: < %s >   (left/right to change)" % DIFFS[diff]["name"],
		], "Tap or press SPACE to start")
	elif state == State.OVER:
		var eff := int(round(100.0 * coupled / emitted)) if emitted > 0 else 0
		card("TIME!", [
			"Score %d%s" % [score, "   NEW BEST!" if new_best else ""],
			"Coupled %d of %d photons (%d%% efficiency), level %d/5, %s" % [coupled, emitted, eff, lvl + 1, D["name"]],
			verdict(score),
		], "Tap or press SPACE to continue" if t > 0.8 else "")
	draw_overlay()


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(W / 2 - 540, 130, 1080, 450), Color(0.12, 0.13, 0.2, 0.96))
	text(Vector2(0, 210), title, 60, Color(1, 0.4, 0.55), true)
	var y := 280.0
	for l in lines:
		text(Vector2(0, y), l, 25, Color(1, 1, 1), true)
		y += 42.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 545), prompt, 30, Color(0.6, 1, 0.6), true)
