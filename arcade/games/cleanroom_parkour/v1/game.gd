extends ArcadeGame
# Cleanroom Parkour: you're late for your cleanroom slot. Every 14 seconds
# you run into a new room with new hazards. Double jump allowed.

const GROUND := 620.0
const PW := 44.0
const PH := 68.0
const PX := 160.0
const GRAV := 4800.0

const ZONES := [
	{"name": "The corridor", "tint": Color(0.16, 0.17, 0.24), "kinds": [
		{"label": "STOOL", "w": 52, "h": 60}, {"label": "CABLE", "w": 92, "h": 24}, {"label": "WET FLOOR", "w": 48, "h": 84}]},
	{"name": "Gowning room", "tint": Color(0.13, 0.19, 0.30), "kinds": [
		{"label": "DEADLINE", "w": 128, "h": 36, "fly": 92}, {"label": "2 STOOLS", "w": 112, "h": 60}]},
	{"name": "Yellow room", "tint": Color(0.30, 0.25, 0.10), "kinds": [
		{"label": "FUME HOOD", "w": 68, "h": 104}, {"pit": true, "w": 108}]},
	{"name": "Wet bench", "tint": Color(0.08, 0.26, 0.24), "kinds": [
		{"pit": true, "w": 148}, {"label": "HF!", "w": 44, "h": 44, "hop": true}]},
	{"name": "Group meeting", "tint": Color(0.28, 0.10, 0.17), "kinds": [
		{"label": "REVIEW", "w": 80, "h": 44, "fall": true}, {"label": "DEADLINE", "w": 180, "h": 36, "fly": 92}]},
]

enum State { TITLE, PLAY, DEAD }
var state: int = State.TITLE
var py := GROUND - PH
var vy := 0.0
var jumps := 0
var obs: Array = []
var pickups: Array = []
var dist := 0.0
var bonus := 0.0
var speed := 520.0
var next_gap := 760.0
var next_pick := 1000.0
var level := 1
var secs := 0.0
var banner := ""
var banner_t := 0.0
var flash := 0.0
var why := ""
var new_best := false
var run_anim := 0.0


func _ready() -> void:
	game_id = "cleanroom_parkour"
	use_stick = false
	tap_is_a = true
	load_best()


func zone() -> Dictionary:
	return ZONES[mini(level, ZONES.size()) - 1]


func meters() -> int:
	return int((dist + bonus) / 20.0)


func reset() -> void:
	py = GROUND - PH
	vy = 0.0
	jumps = 0
	obs.clear()
	pickups.clear()
	dist = 0.0
	bonus = 0.0
	speed = 520.0
	next_gap = 760.0
	next_pick = 1000.0
	level = 1
	secs = 0.0
	new_best = false
	banner = "Level 1: The corridor"
	banner_t = 1.6
	state = State.PLAY


func over_pit() -> bool:
	for o in obs:
		if o.get("pit", false) and PX + 12 > o["x"] and PX + PW - 12 < o["x"] + o["w"]:
			return true
	return false


func _process(delta: float) -> void:
	tick(delta)
	banner_t = maxf(0.0, banner_t - delta)
	flash = maxf(0.0, flash - delta)
	match state:
		State.TITLE:
			if pressed_a():
				reset()
		State.DEAD:
			if pressed_a() and t > 0.6:
				reset()
		State.PLAY:
			play(minf(delta, 0.04))
	queue_redraw()


func jump() -> void:
	if jumps < 2:
		vy = -1560.0 if jumps == 0 else -1320.0
		jumps += 1


func on_input(event: InputEvent) -> void:
	if state == State.PLAY and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_UP, KEY_W]:
		jump()


func play(dt: float) -> void:
	if pressed_a():
		jump()
	secs += dt
	var nl := 1 + int(secs / 14.0)
	if nl != level:
		level = nl
		banner = ("Level %d: %s" % [level, zone()["name"]]) if level <= ZONES.size() else "Level %d: faster!" % level
		banner_t = 1.6
		shake(5.0)
	speed = minf(1300.0, 520.0 + (level - 1) * 120.0 + secs * 4.0)
	var dx := speed * dt
	dist += dx
	run_anim += dt * speed / 40.0

	var was_above := py <= GROUND - PH + 1.0
	vy += GRAV * dt
	py += vy * dt
	if was_above and py >= GROUND - PH and not over_pit():
		py = GROUND - PH
		vy = 0.0
		jumps = 0
	if py > H:
		die("You fell into a pit. Your sample didn't survive either.")
		return

	next_gap -= dx
	if next_gap <= 0.0:
		var fresh: Array = zone()["kinds"]
		var all: Array = []
		for i in mini(level, ZONES.size()):
			all.append_array(ZONES[i]["kinds"])
		var k: Dictionary = fresh[randi() % fresh.size()] if randf() < 0.5 else all[randi() % all.size()]
		var o := k.duplicate()
		o["x"] = W + 20.0
		o["w"] = float(k["w"])
		o["h"] = 0.0 if k.get("pit", false) else float(k["h"])
		o["base"] = GROUND - o["h"]
		o["vy"] = 0.0
		o["ph"] = randf() * 6.0
		if k.get("pit", false):
			o["y"] = GROUND
		elif k.has("fly"):
			o["y"] = GROUND - PH - float(k["fly"]) + 16.0
		elif k.get("fall", false):
			o["y"] = -o["h"]
		else:
			o["y"] = o["base"]
		obs.append(o)
		var min_gap := maxf(300.0, 660.0 - level * 50.0)
		next_gap = min_gap + randf() * 440.0 + speed * 0.12

	for o in obs:
		o["x"] -= dx
		if o.get("fall", false) and o["x"] < PX + 380.0 and o["y"] < o["base"]:
			o["vy"] += 3200.0 * dt
			o["y"] = minf(o["base"], o["y"] + o["vy"] * dt)
		if o.get("hop", false):
			o["y"] = o["base"] - absf(sin(t * 3.85 + o["ph"])) * 80.0
	obs = obs.filter(func(o): return o["x"] + o["w"] > -20.0)

	next_pick -= dx
	if next_pick <= 0.0:
		pickups.append(Vector2(W + 20.0, GROUND - 80.0 - randf() * 180.0))
		next_pick = 840.0 + randf() * 1000.0
	var keep: Array = []
	for w in pickups:
		w.x -= dx
		if absf(w.x - (PX + PW / 2.0)) < 36.0 and absf(w.y - (py + PH / 2.0)) < 48.0:
			bonus += 300.0
			flash = 0.4
		elif w.x > -20.0:
			keep.append(w)
	pickups = keep

	for o in obs:
		if o.get("pit", false):
			continue
		if PX + 8 < o["x"] + o["w"] and PX + PW - 8 > o["x"] and py + 8 < o["y"] + o["h"] and py + PH - 4 > o["y"]:
			die("Hit by a %s." % String(o["label"]).to_lower())
			return


func die(reason: String) -> void:
	why = reason
	state = State.DEAD
	t = 0.0
	shake(12.0)
	new_best = submit_score(meters())


func verdict() -> String:
	var m := meters()
	if m >= 600:
		return "You made your slot. The cleanroom manager is visibly disappointed."
	if m >= 250:
		return "Late, but within the 15-minute grace period."
	return "Your slot has been given to a master's student."


func _draw() -> void:
	var tint: Color = zone()["tint"]
	draw_rect(Rect2(-40, -40, W + 80, H + 80), tint)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.85, 0.2, flash))
	# ceiling lights scroll by
	for i in 8:
		var x := fmod(i * 190.0 - dist * 0.3, W + 200.0)
		if x < -100.0:
			x += W + 200.0
		draw_rect(Rect2(x, 110, 110, 10), Color(1, 1, 0.9, 0.25))
	# floor with pits
	var pits: Array = obs.filter(func(o): return o.get("pit", false))
	pits.sort_custom(func(a, b): return a["x"] < b["x"])
	var gx := -20.0
	for p in pits:
		if p["x"] > gx:
			draw_rect(Rect2(gx, GROUND, p["x"] - gx, H - GROUND), Color(0.55, 0.57, 0.62))
		draw_rect(Rect2(p["x"], GROUND + 4, p["w"], H - GROUND), Color(0.03, 0.03, 0.06))
		gx = p["x"] + p["w"]
	draw_rect(Rect2(gx, GROUND, W + 20 - gx, H - GROUND), Color(0.55, 0.57, 0.62))
	for w in pickups:
		draw_circle(w, 17, Color(0.9, 0.68, 0.0))
		draw_circle(w, 6, Color(1, 1, 1))
	for o in obs:
		if o.get("pit", false):
			continue
		var r := Rect2(o["x"], o["y"], o["w"], o["h"])
		var fly: bool = o.has("fly")
		draw_rect(r, Color(0.85, 0.2, 0.35) if fly else Color(0.98, 0.85, 0.88))
		draw_rect(r, Color(0.85, 0.2, 0.35), false, 3.0)
		if o["h"] >= 24:
			draw_string(font, Vector2(r.position.x, r.get_center().y + 7), o["label"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, mini(18, int(r.size.x * 1.7 / String(o["label"]).length())), Color(1, 1, 1) if fly else Color(0.2, 0.1, 0.15))
	draw_runner()
	text(Vector2(150, 50), zone()["name"].to_upper(), 24, Color(1, 1, 1, 0.8))
	text(Vector2(W - 330, 50), "%d m   Level %d" % [meters(), level], 28, Color(1, 1, 1))
	text(Vector2(W - 330, 84), "Best %d m" % maxi(best, meters()), 22, Color(1, 0.9, 0.6))
	if banner_t > 0.0 and state == State.PLAY:
		text(Vector2(0, 260), banner, 48, Color(1, 0.9, 0.4, minf(1.0, banner_t)), true)
	if state == State.TITLE:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		text(Vector2(0, 210), "CLEANROOM PARKOUR", 76, Color(0.6, 0.85, 1.0), true)
		text(Vector2(0, 280), "You're late for your cleanroom slot. Every level is a new room.", 28, Color(1, 1, 1), true)
		text(Vector2(0, 325), "Pits, flying deadlines, falling reviews. Grab wafers for bonus metres.", 26, Color(1, 1, 1), true)
		text(Vector2(0, 380), "Tap / SPACE to jump, again in the air for a double jump.", 26, Color(0.85, 0.85, 1), true)
		if int(t * 2.0) % 2 == 0:
			text(Vector2(0, 490), "Tap or press SPACE to run", 36, Color(0.6, 1, 0.6), true)
	elif state == State.DEAD:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		text(Vector2(0, 220), "TRIPPED!", 80, Color(1, 0.45, 0.5), true)
		text(Vector2(0, 290), why, 30, Color(1, 1, 1), true)
		text(Vector2(0, 345), "Ran %d m, level %d. %s" % [meters(), level, verdict()], 26, Color(1, 1, 1), true)
		if new_best:
			text(Vector2(0, 410), "NEW BEST!", 36, Color(0.6, 1, 0.6), true)
		if t > 0.6 and int(t * 2.0) % 2 == 0:
			text(Vector2(0, 500), "Tap or press SPACE to run again", 32, Color(1, 1, 0.6), true)
	draw_overlay()


func draw_runner() -> void:
	# a researcher in a white bunny suit
	var x := PX
	var y := py
	var suit := Color(0.95, 0.96, 1.0)
	draw_rect(Rect2(x + 6, y + 18, PW - 12, PH - 34), suit)
	draw_circle(Vector2(x + PW / 2.0, y + 14), 16, suit)
	draw_rect(Rect2(x + 10, y + 8, PW - 20, 12), Color(0.3, 0.6, 0.95))  # visor
	var leg := sin(run_anim) * 10.0 if py >= GROUND - PH - 1.0 else 6.0
	draw_line(Vector2(x + 14, y + PH - 16), Vector2(x + 14 + leg, y + PH), suit, 8.0)
	draw_line(Vector2(x + PW - 14, y + PH - 16), Vector2(x + PW - 14 - leg, y + PH), suit, 8.0)
	draw_line(Vector2(x + 8, y + 26), Vector2(x - 4 - leg * 0.5, y + 40), suit, 7.0)
	draw_line(Vector2(x + PW - 8, y + 26), Vector2(x + PW + 6 + leg * 0.5, y + 38), suit, 7.0)
