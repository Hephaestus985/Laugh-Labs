extends Node2D
# SOCK ESCAPE - a runaway sock flees the washing machine.
# Everything is drawn with code, so the project needs no image files.

const W := 1280.0
const H := 720.0
const GROUND := 600.0
const PX := 260.0
const GRAVITY := 2800.0
const JUMP_V := -1000.0
const DJUMP_V := -880.0
const MENU_BTN := Rect2(10, 10, 120, 60)
const SAVE_PATH := "user://sock_escape_best.dat"
const MENU_SCENE := "res://menu.tscn"

const STAGE_SCORES := [0, 200, 600, 1100, 1800, 2700]
const STAGE_NAMES := ["Gentle Rinse", "Warm Wash", "Spin Cycle", "Heavy Duty", "TURBO SPIN", "DRYER OF DOOM"]
const STAGE_QUIPS := [
	"Run, little sock!",
	"Soap bars incoming. Do not slip.",
	"Bubbles! Hold DOWN to duck under them.",
	"A cat has entered the laundry room.",
	"The hairdryer is hunting you.",
	"Nobody has ever seen this far. Not even the dryer.",
]
const STAGE_COLORS := [
	Color(0.62, 0.82, 0.95), Color(0.70, 0.88, 0.80), Color(0.95, 0.85, 0.62),
	Color(0.96, 0.70, 0.62), Color(0.90, 0.55, 0.75), Color(0.55, 0.45, 0.70),
]
const DEATH_LINES := {
	"duck": ["Defeated by a rubber duck. It squeaked in triumph.", "The duck didn't even move. You ran into it."],
	"soap": ["Slipped on soap. A true classic.", "You are now the cleanest loser in the house."],
	"cat": ["The cat has claimed you as a toy. Forever.", "You are now under the sofa. With the others."],
	"bubble": ["Popped by a bubble. That's... embarrassing.", "Death by bubble. Your foot will never live this down."],
	"drone": ["The hairdryer got you. You are now very fluffy.", "Blown dry. Shrunk two sizes. Fits a hamster now."],
}
const DEATH_TAILS := [
	"Your left foot has filed a missing sock report.",
	"The washing machine burps happily.",
	"Somewhere, your partner sock sheds a single tear.",
	"Back to the laundry pile with you.",
]
const PICKUP_CHEERS := ["REUNITED!", "SOCK PAIR!", "TWINSIES!", "MATCHED!", "+25 FRIENDSHIP"]

enum State { TITLE, PLAY, DEAD }

var state: int = State.TITLE
var font: Font
var t := 0.0
var play_time := 0.0

# player
var py := GROUND
var vy := 0.0
var on_ground := true
var jumps_left := 2
var ducking := false
var spinning := false
var spin := 0.0
var squash := 1.0

# world
var speed := 430.0
var distance := 0.0
var bonus := 0
var best := 0
var new_best := false
var next_spawn := 700.0
var obstacles: Array = []
var pickups: Array = []
var particles: Array = []
var popups: Array = []
var shake := 0.0
var death_msg := ""
var death_tail := ""
var dead_timer := 0.0
var bg_offset := 0.0
var stage := 0
var stage_flash := 0.0
var mult := 1.0
var touch_duck := -1  # finger index holding the duck zone, -1 when none
var is_mobile := false


func _ready() -> void:
	randomize()
	ArcadeGame.use_game_screen(get_window())
	font = ThemeDB.fallback_font
	is_mobile = OS.has_feature("mobile")
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best = f.get_32()
	# opened from the game's start screen with Play: skip the title
	if Engine.get_meta("auto_start", false):
		Engine.set_meta("auto_start", false)
		reset_game()


func save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(best)


func score() -> int:
	return int(distance / 10.0) + bonus


func reset_game() -> void:
	py = GROUND
	vy = 0.0
	on_ground = true
	jumps_left = 2
	spinning = false
	spin = 0.0
	squash = 1.0
	speed = 430.0
	distance = 0.0
	bonus = 0
	new_best = false
	next_spawn = 700.0
	obstacles.clear()
	pickups.clear()
	popups.clear()
	play_time = 0.0
	stage = 0
	stage_flash = 2.0
	mult = ArcadeGame.DIFF_MULT[ArcadeGame.get_difficulty("sock_escape")]
	touch_duck = -1
	state = State.PLAY


# ---------------------------------------------------------------- input

func is_jump_key(k: int) -> bool:
	return k == KEY_SPACE or k == KEY_UP or k == KEY_W or k == KEY_ENTER or k == KEY_KP_ENTER


func _unhandled_input(event: InputEvent) -> void:
	var pressed_jump := false
	var released_jump := false
	if event is InputEventKey:
		var k: int = event.keycode
		if event.pressed and not event.echo:
			if k == KEY_ESCAPE:
				back_to_menu()
				return
			if is_jump_key(k):
				pressed_jump = true
		elif not event.pressed and is_jump_key(k):
			released_jump = true
	elif event is InputEventScreenTouch:
		# phone: menu button top-left, hold the left third to duck, tap anywhere else to jump
		if event.pressed and MENU_BTN.has_point(event.position):
			back_to_menu()
			return
		if event.pressed and event.position.x < W * 0.33 and state == State.PLAY:
			touch_duck = event.index
		elif not event.pressed and event.index == touch_duck:
			touch_duck = -1
		elif event.pressed:
			pressed_jump = true
		else:
			released_jump = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not is_mobile:
		if event.pressed and MENU_BTN.has_point(event.position):
			back_to_menu()
			return
		if event.pressed:
			pressed_jump = true
		else:
			released_jump = true

	if pressed_jump:
		match state:
			State.TITLE:
				reset_game()
			State.PLAY:
				try_jump()
			State.DEAD:
				if dead_timer > 0.6:
					reset_game()
	if released_jump and state == State.PLAY and vy < -350.0:
		vy *= 0.5  # short hop when you let go early


func back_to_menu() -> void:
	get_tree().change_scene_to_file(GameData.back_scene())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button
		back_to_menu.call_deferred()  # not while the tree is busy delivering the notification


func try_jump() -> void:
	if on_ground:
		vy = JUMP_V
		on_ground = false
		jumps_left = 1
		squash = 1.35
		puff(PX, GROUND, 6, Color(1, 1, 1, 0.8))
	elif jumps_left > 0:
		vy = DJUMP_V
		jumps_left = 0
		spinning = true
		spin = 0.0
		puff(PX + 10, py - 20, 8, Color(0.8, 0.95, 1.0, 0.9))


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	t += delta
	shake = maxf(0.0, shake - delta * 40.0)
	stage_flash = maxf(0.0, stage_flash - delta)
	update_fx(delta)
	match state:
		State.PLAY:
			update_play(delta)
		State.DEAD:
			dead_timer += delta
		State.TITLE:
			bg_offset += 120.0 * delta
			py = GROUND
	if shake > 0.0:
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		position = Vector2.ZERO
	queue_redraw()


func current_stage() -> int:
	var s := 0
	var sc := score()
	for i in STAGE_SCORES.size():
		if sc >= STAGE_SCORES[i]:
			s = i
	return s


func update_play(delta: float) -> void:
	play_time += delta
	speed = minf(430.0 + play_time * 13.0, 1150.0) * mult
	var dx := speed * delta
	distance += dx
	bg_offset += dx

	ducking = Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or touch_duck != -1
	vy += GRAVITY * delta
	if ducking and not on_ground:
		vy += GRAVITY * 1.6 * delta  # fast fall
	py += vy * delta
	if py >= GROUND:
		if not on_ground:
			squash = 0.65
			puff(PX, GROUND, 5, Color(1, 1, 1, 0.7))
		py = GROUND
		vy = 0.0
		on_ground = true
		jumps_left = 2
		spinning = false
		spin = 0.0
	else:
		on_ground = false
	if spinning:
		spin += delta * 15.0
		if spin >= TAU:
			spin = 0.0
			spinning = false
	squash = lerpf(squash, 1.0, minf(1.0, delta * 10.0))

	var s := current_stage()
	if s > stage:
		stage = s
		stage_flash = 2.5
		shake = 6.0

	next_spawn -= dx
	if next_spawn <= 0.0:
		spawn_obstacle()
		var factor: float = maxf(0.8, 1.3 - stage * 0.1)
		var gap: float = speed * factor + 120.0
		next_spawn = randf_range(gap, gap * 1.7)
		if randf() < 0.4:
			pickups.append({"x": W + 60.0 + next_spawn * 0.5, "y": GROUND - randf_range(90.0, 230.0), "got": false})

	for o in obstacles:
		o["x"] -= dx
		if o["kind"] == "drone":
			o["y"] = o["base"] + sin(t * 3.0 + o["phase"]) * 75.0
	obstacles = obstacles.filter(func(o): return o["x"] + o["w"] > -80.0)
	for p in pickups:
		p["x"] -= dx
	pickups = pickups.filter(func(p): return p["x"] > -80.0 and not p["got"])

	var pr := player_rect()
	for o in obstacles:
		if pr.intersects(obstacle_rect(o)):
			die(o["kind"])
			return
	for p in pickups:
		if not p["got"] and pr.intersects(Rect2(p["x"] - 18.0, p["y"] - 18.0, 36.0, 36.0)):
			p["got"] = true
			bonus += 25
			popups.append({"x": p["x"], "y": p["y"] - 20.0, "text": PICKUP_CHEERS[randi() % PICKUP_CHEERS.size()], "life": 1.0})
			puff(p["x"], p["y"], 10, Color(1.0, 0.9, 0.3, 1.0))

	if on_ground and randf() < 0.3:
		particles.append({"x": PX - 10.0, "y": GROUND - 4.0, "vx": -speed * 0.3, "vy": randf_range(-60.0, -10.0), "r": randf_range(3.0, 6.0), "life": 0.4, "max": 0.4, "c": Color(1, 1, 1, 0.5)})


func spawn_obstacle() -> void:
	var kinds := ["duck", "duck"]
	if stage >= 1:
		kinds.append("soap")
	if stage >= 2:
		kinds.append("bubble")
		kinds.append("bubble")
	if stage >= 3:
		kinds.append("cat")
	if stage >= 4:
		kinds.append("drone")
		kinds.append("drone")
	if stage >= 5:
		kinds.append("cat")
	var kind: String = kinds[randi() % kinds.size()]
	add_obstacle(kind, W + 40.0)
	# later stages sometimes send two ducks in a row: a long jump or a double jump
	if stage >= 3 and kind == "duck" and randf() < 0.35:
		add_obstacle("duck", W + 40.0 + 170.0)


func add_obstacle(kind: String, x: float) -> void:
	var o := {"kind": kind, "x": x, "w": 60.0, "h": 52.0, "y": 0.0, "base": 0.0, "phase": randf() * TAU}
	match kind:
		"duck":
			o["w"] = 60.0
			o["h"] = 52.0
			o["y"] = GROUND - 52.0
		"soap":
			o["w"] = 56.0
			o["h"] = 95.0
			o["y"] = GROUND - 95.0
		"cat":
			o["w"] = 120.0
			o["h"] = 58.0
			o["y"] = GROUND - 58.0
		"bubble":
			o["w"] = 60.0
			o["h"] = 56.0
			o["y"] = GROUND - 62.0 - 56.0
		"drone":
			o["w"] = 70.0
			o["h"] = 44.0
			o["base"] = GROUND - 150.0
			o["y"] = o["base"]
	obstacles.append(o)


func player_h() -> float:
	return 40.0 if ducking else 70.0


func player_rect() -> Rect2:
	var h := player_h()
	return Rect2(PX - 14.0, py - h + 6.0, 48.0, h - 6.0)


func obstacle_rect(o: Dictionary) -> Rect2:
	return Rect2(o["x"] + 6.0, o["y"] + 6.0, o["w"] - 12.0, o["h"] - 10.0)


func die(kind: String) -> void:
	state = State.DEAD
	dead_timer = 0.0
	shake = 14.0
	var lines: Array = DEATH_LINES[kind]
	death_msg = lines[randi() % lines.size()]
	death_tail = DEATH_TAILS[randi() % DEATH_TAILS.size()]
	puff(PX + 10.0, py - 35.0, 30, Color(1.0, 0.5, 0.5, 1.0))
	GameData.add_score("sock_escape", score(), ArcadeGame.get_difficulty("sock_escape"))
	if score() > best:
		best = score()
		new_best = true
		save_best()


func puff(x: float, y: float, n: int, c: Color) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(80.0, 320.0)
		particles.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - 80.0, "r": randf_range(3.0, 8.0), "life": 0.6, "max": 0.6, "c": c})


func update_fx(delta: float) -> void:
	for p in particles:
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["vy"] += 400.0 * delta
		p["life"] -= delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	for p in popups:
		p["y"] -= 60.0 * delta
		p["life"] -= delta
	popups = popups.filter(func(p): return p["life"] > 0.0)


# ---------------------------------------------------------------- drawing

func text(pos: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	var width := W if center else -1.0
	var p := Vector2(0.0, pos.y) if center else pos
	draw_string_outline(font, p, s, align, width, size, 6, Color(0.1, 0.1, 0.2, 0.9))
	draw_string(font, p, s, align, width, size, c)


func _draw() -> void:
	draw_background()
	draw_machine()
	for p in pickups:
		draw_pickup(p["x"], p["y"])
	for o in obstacles:
		draw_obstacle(o)
	if state != State.DEAD or int(dead_timer * 10.0) % 2 == 0:
		draw_sock(PX, py)
	for p in particles:
		var c: Color = p["c"]
		c.a *= p["life"] / p["max"]
		draw_circle(Vector2(p["x"], p["y"]), p["r"], c)
	for p in popups:
		text(Vector2(p["x"] - 50.0, p["y"]), p["text"], 26, Color(1.0, 0.95, 0.4, p["life"]))
	draw_hud()
	draw_rect(MENU_BTN, Color(0, 0, 0, 0.25))
	text(MENU_BTN.position + Vector2(14, 40), "< MENU", 22, Color(1, 1, 1, 0.85))


func draw_background() -> void:
	var col: Color = STAGE_COLORS[stage]
	draw_rect(Rect2(-40, -40, W + 80, H + 80), col)
	# wall tiles
	var tile := 80.0
	var off := fmod(bg_offset * 0.3, tile)
	var line := col.darkened(0.12)
	var x := -off
	while x < W + tile:
		draw_line(Vector2(x, 0), Vector2(x, GROUND), line, 3.0)
		x += tile
	var y := 40.0
	while y < GROUND:
		draw_line(Vector2(0, y), Vector2(W, y), line, 3.0)
		y += tile
	# floor
	draw_rect(Rect2(-40, GROUND, W + 80, H - GROUND + 40), Color(0.45, 0.33, 0.28))
	draw_rect(Rect2(-40, GROUND, W + 80, 10), Color(0.35, 0.25, 0.2))
	var foff := fmod(bg_offset, 120.0)
	x = -foff
	while x < W + 120.0:
		draw_rect(Rect2(x, GROUND + 30, 60, 8), Color(0.52, 0.39, 0.33))
		x += 120.0


func draw_machine() -> void:
	# the washing machine chasing you from the left edge
	var bob := sin(t * 18.0) * 3.0
	var mx := -70.0 + bob
	var top := GROUND - 230.0
	draw_rect(Rect2(mx, top, 170, 230), Color(0.95, 0.95, 0.97))
	draw_rect(Rect2(mx, top, 170, 36), Color(0.82, 0.84, 0.88))
	draw_circle(Vector2(mx + 140, top + 18), 8, Color(0.9, 0.3, 0.3))
	var c := Vector2(mx + 90, top + 125)
	draw_circle(c, 66, Color(0.6, 0.62, 0.68))
	draw_circle(c, 56, Color(0.3, 0.55, 0.85))
	var ang := t * (speed / 60.0)
	for i in 3:
		var a := ang + i * TAU / 3.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 50.0, Color(0.7, 0.85, 1.0), 6.0)
	# angry eyebrows
	draw_line(Vector2(mx + 50, top + 52), Vector2(mx + 85, top + 62), Color(0.15, 0.15, 0.2), 6.0)
	draw_line(Vector2(mx + 130, top + 52), Vector2(mx + 95, top + 62), Color(0.15, 0.15, 0.2), 6.0)
	if state == State.PLAY and int(t * 2.0) % 6 == 0:
		text(Vector2(mx + 110, top - 14), "COME BACK!", 22, Color(1, 1, 1))


func draw_sock(x: float, feet: float) -> void:
	var sy := squash * (0.57 if ducking else 1.0)
	var sx: float = 1.25 if ducking else 1.0 / maxf(0.6, squash)
	draw_set_transform(Vector2(x, feet - (35.0 if spinning else 0.0)), spin, Vector2(sx, sy))
	var o := Vector2(0, 35.0 if spinning else 0.0)
	var body := Color(0.97, 0.97, 0.97)
	var stripe := Color(0.9, 0.25, 0.3)
	draw_rect(Rect2(o + Vector2(-16, -70), Vector2(28, 50)), body)
	draw_rect(Rect2(o + Vector2(-16, -26), Vector2(44, 26)), body)
	draw_circle(o + Vector2(28, -13), 13, body)
	draw_circle(o + Vector2(-14, -12), 12, body)
	draw_rect(Rect2(o + Vector2(-16, -70), Vector2(28, 7)), stripe)
	draw_rect(Rect2(o + Vector2(-16, -58), Vector2(28, 5)), stripe)
	draw_circle(o + Vector2(32, -13), 8, Color(0.95, 0.8, 0.3))  # toe patch
	# googly eyes that look where you're going
	var look := Vector2(2.5, clampf(vy / 400.0, -2.5, 2.5))
	for ex: float in [-8.0, 6.0]:
		var e := o + Vector2(ex, -44)
		draw_circle(e, 7.5, Color(1, 1, 1))
		draw_arc(e, 7.5, 0, TAU, 16, Color(0.2, 0.2, 0.2), 1.5)
		draw_circle(e + look + Vector2(sin(t * 25.0 + ex) * 0.8, 0), 3.5, Color(0.05, 0.05, 0.1))
	# mouth: panicked "O"
	draw_circle(o + Vector2(-1, -32), 4.0 if state == State.PLAY else 2.0, Color(0.3, 0.1, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# little legs scurrying
	if on_ground and state != State.DEAD:
		var phase := sin(t * 30.0) * 8.0
		draw_line(Vector2(x - 6, feet), Vector2(x - 6 + phase, feet + 6), Color(0.2, 0.2, 0.2), 3.0)
		draw_line(Vector2(x + 18, feet), Vector2(x + 18 - phase, feet + 6), Color(0.2, 0.2, 0.2), 3.0)


func draw_obstacle(o: Dictionary) -> void:
	var x: float = o["x"]
	var y: float = o["y"]
	var w: float = o["w"]
	var h: float = o["h"]
	match o["kind"]:
		"duck":
			var yel := Color(1.0, 0.85, 0.15)
			draw_circle(Vector2(x + 26, y + 36), 22, yel)
			draw_rect(Rect2(x + 4, y + 30, 44, 22), yel)
			draw_circle(Vector2(x + 18, y + 16), 15, yel)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y + 14), Vector2(x - 12, y + 20), Vector2(x + 4, y + 24)]), Color(1.0, 0.5, 0.1))
			draw_circle(Vector2(x + 14, y + 12), 3, Color(0.05, 0.05, 0.05))
			draw_line(Vector2(x + 30, y + 34), Vector2(x + 44, y + 30), Color(0.9, 0.7, 0.1), 4.0)
		"soap":
			draw_rect(Rect2(x, y, w, h), Color(0.95, 0.6, 0.8))
			draw_rect(Rect2(x + 6, y + 6, w - 12, 10), Color(1.0, 0.8, 0.92))
			text(Vector2(x + 2, y + 56), "SOAP", 16, Color(1, 1, 1))
			draw_circle(Vector2(x + 10, y - 6 + sin(t * 4.0) * 3.0), 6, Color(1, 1, 1, 0.7))
			draw_circle(Vector2(x + 34, y - 14 + sin(t * 5.0) * 3.0), 4, Color(1, 1, 1, 0.7))
		"cat":
			var fur := Color(0.25, 0.25, 0.3)
			draw_rect(Rect2(x + 10, y + 20, 90, 38), fur)
			draw_circle(Vector2(x + 18, y + 22), 22, fur)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, y + 10), Vector2(x + 6, y - 14), Vector2(x + 18, y + 2)]), fur)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 20, y + 2), Vector2(x + 32, y - 14), Vector2(x + 36, y + 10)]), fur)
			draw_circle(Vector2(x + 10, y + 20), 5, Color(0.6, 1.0, 0.3))
			draw_circle(Vector2(x + 26, y + 20), 5, Color(0.6, 1.0, 0.3))
			draw_line(Vector2(x + 10, y + 16), Vector2(x + 10, y + 24), Color(0, 0, 0), 2.0)
			draw_line(Vector2(x + 26, y + 16), Vector2(x + 26, y + 24), Color(0, 0, 0), 2.0)
			var tail := sin(t * 6.0) * 14.0
			draw_line(Vector2(x + 100, y + 30), Vector2(x + 118, y + 4 + tail), fur, 8.0)
		"bubble":
			var c := Vector2(x + w / 2.0, y + h / 2.0)
			var r := 28.0 + sin(t * 8.0 + o["phase"]) * 2.0
			draw_circle(c, r, Color(0.75, 0.9, 1.0, 0.45))
			draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
			draw_circle(c + Vector2(-9, -9), 6, Color(1, 1, 1, 0.9))
			draw_circle(c + Vector2(-6, 4), 2.5, Color(0.1, 0.1, 0.2))
			draw_circle(c + Vector2(6, 4), 2.5, Color(0.1, 0.1, 0.2))
			draw_arc(c + Vector2(0, 8), 6, 0.2, PI - 0.2, 8, Color(0.1, 0.1, 0.2), 2.0)
		"drone":
			var body := Color(0.85, 0.2, 0.35)
			draw_rect(Rect2(x + 14, y + 6, 56, 26), body)
			draw_circle(Vector2(x + 16, y + 19), 15, body.darkened(0.2))
			draw_rect(Rect2(x + 44, y + 30, 14, 16), body.darkened(0.3))
			for i in 3:
				var wx := x - 6.0 - i * 14.0 - fmod(t * 200.0, 14.0)
				draw_line(Vector2(wx, y + 12), Vector2(wx - 10, y + 12), Color(1, 1, 1, 0.7), 3.0)
				draw_line(Vector2(wx, y + 26), Vector2(wx - 10, y + 26), Color(1, 1, 1, 0.7), 3.0)
			draw_circle(Vector2(x + 50, y + 14), 4, Color(1, 1, 0.6))


func draw_pickup(x: float, y: float) -> void:
	var bob := sin(t * 5.0 + x * 0.01) * 6.0
	var c := Color(1.0, 0.85, 0.3)
	draw_rect(Rect2(x - 8, y - 18 + bob, 14, 24), c)
	draw_rect(Rect2(x - 8, y + bob, 22, 12), c)
	draw_circle(Vector2(x + 14, y + 6 + bob), 6, c)
	draw_rect(Rect2(x - 8, y - 18 + bob, 14, 4), Color(0.9, 0.3, 0.3))
	draw_circle(Vector2(x, y - 26 + bob), 4, Color(1, 0.4, 0.5))
	draw_circle(Vector2(x + 6, y - 26 + bob), 4, Color(1, 0.4, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y - 25 + bob), Vector2(x + 10, y - 25 + bob), Vector2(x + 3, y - 17 + bob)]), Color(1, 0.4, 0.5))


func draw_hud() -> void:
	var white := Color(1, 1, 1)
	match state:
		State.TITLE:
			draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(0, 0, 0, 0.35))
			text(Vector2(0, 190), "SOCK ESCAPE", 96, Color(1.0, 0.9, 0.4), true)
			text(Vector2(0, 250), "The washing machine wants you back. Do NOT go back.", 28, white, true)
			if is_mobile:
				text(Vector2(0, 340), "Tap the right side to jump   (tap again in the air to double jump)", 24, white, true)
				text(Vector2(0, 378), "Hold the left side to duck under bubbles, or slam back to the floor", 24, white, true)
			else:
				text(Vector2(0, 340), "SPACE / UP / click  =  jump   (press again in the air to double jump)", 24, white, true)
				text(Vector2(0, 378), "DOWN / S  =  duck under bubbles, or slam back to the floor", 24, white, true)
			text(Vector2(0, 416), "Grab the yellow lost socks for bonus points. ESC = menu.", 24, white, true)
			text(Vector2(0, 454), "Difficulty: %s (change it on the start screen)" % ArcadeGame.DIFF_NAMES[ArcadeGame.get_difficulty("sock_escape")], 22, white, true)
			if int(t * 2.0) % 2 == 0:
				text(Vector2(0, 500), "Tap to run!" if is_mobile else "Press SPACE to run!", 40, Color(0.6, 1.0, 0.6), true)
			if best > 0:
				text(Vector2(0, 560), "Best: %d" % best, 26, white, true)
		State.PLAY, State.DEAD:
			if is_mobile and state == State.PLAY:
				var zone := Color(1, 1, 1, 0.18 if touch_duck != -1 else 0.07)
				draw_rect(Rect2(0, GROUND + 10, W * 0.33, H - GROUND - 10), zone)
				text(Vector2(W * 0.33 / 2.0 - 40.0, H - 40.0), "DUCK", 30, Color(1, 1, 1, 0.5))
				text(Vector2(W * 0.66 - 40.0, H - 40.0), "JUMP", 30, Color(1, 1, 1, 0.5))
			text(Vector2(W - 260, 50), "Score %d" % score(), 32, white)
			text(Vector2(W - 260, 84), "Best  %d" % maxi(best, score()), 22, Color(0.95, 0.95, 0.8))
			text(Vector2(140, 50), STAGE_NAMES[stage], 28, white)
			if stage_flash > 0.0 and state == State.PLAY:
				var a: float = minf(1.0, stage_flash)
				text(Vector2(0, 230), STAGE_NAMES[stage].to_upper() + "!", 64, Color(1.0, 0.9, 0.4, a), true)
				text(Vector2(0, 275), STAGE_QUIPS[stage], 28, Color(1, 1, 1, a), true)
			if state == State.DEAD:
				var a: float = minf(1.0, dead_timer * 3.0)
				draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(0, 0, 0, 0.5 * a))
				text(Vector2(0, 200), "SOCKED OUT!", 84, Color(1.0, 0.45, 0.45, a), true)
				text(Vector2(0, 270), death_msg, 30, Color(1, 1, 1, a), true)
				text(Vector2(0, 310), death_tail, 24, Color(0.9, 0.9, 0.9, a), true)
				text(Vector2(0, 390), "Score: %d" % score(), 40, Color(1, 1, 1, a), true)
				if new_best:
					text(Vector2(0, 440), "NEW BEST! The dryer is nervous.", 30, Color(0.6, 1.0, 0.6, a), true)
				if dead_timer > 0.6 and int(t * 2.0) % 2 == 0:
					text(Vector2(0, 520), ("Tap to run again" if is_mobile else "SPACE to run again"), 34, Color(1, 1, 0.6), true)
