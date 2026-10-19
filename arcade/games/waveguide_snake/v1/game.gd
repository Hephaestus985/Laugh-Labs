extends ArcadeGame
# Waveguide Snake: you are a light pulse in a waveguide. Eat photons, grow,
# and avoid the walls, your own tail and scattering defects.

const COLS := 30
const ROWS := 15
const CELL := 40.0
const OX := 40.0
const OY := 90.0

enum State { TITLE, PLAY, DEAD }
var state: int = State.TITLE
var snake: Array[Vector2i] = []
var dir := Vector2i(1, 0)
var queue: Array[Vector2i] = []
var food := Vector2i(-1, -1)
var walls: Array[Vector2i] = []
var eaten := 0
var level := 1
var step_time := 0.16
var acc := 0.0
var banner := ""
var banner_t := 0.0
var cause := ""
var new_best := false
var swipe_from := Vector2.ZERO
var swiping := false
var eat_flash := 0.0
var mult := 1.0


func _ready() -> void:
	game_id = "waveguide_snake"
	use_stick = false
	show_a = false
	tap_is_a = true
	load_best()


func reset() -> void:
	snake = [Vector2i(6, 7), Vector2i(5, 7), Vector2i(4, 7)]
	dir = Vector2i(1, 0)
	queue.clear()
	walls.clear()
	eaten = 0
	level = 1
	mult = DIFF_MULT[difficulty()]
	step_time = 0.16 / mult
	acc = 0.0
	food = free_cell(true)
	new_best = false
	state = State.PLAY
	banner = "Level 1: a clean waveguide"
	banner_t = 1.6


func occupied(c: Vector2i) -> bool:
	return snake.has(c) or walls.has(c)


func free_cell(avoid_head: bool) -> Vector2i:
	for i in 500:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if occupied(c) or c == food:
			continue
		if avoid_head and absi(c.x - snake[0].x) + absi(c.y - snake[0].y) <= 4:
			continue
		return c
	return Vector2i(-1, -1)


func turn(d: Vector2i) -> void:
	var last_dir: Vector2i = queue[queue.size() - 1] if queue.size() > 0 else dir
	if (d.x != 0 and last_dir.x != 0) or (d.y != 0 and last_dir.y != 0):
		return
	if queue.size() < 2:
		queue.append(d)


func on_input(event: InputEvent) -> void:
	if state != State.PLAY:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W: turn(Vector2i(0, -1))
			KEY_DOWN, KEY_S: turn(Vector2i(0, 1))
			KEY_LEFT, KEY_A: turn(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D: turn(Vector2i(1, 0))
	elif event is InputEventScreenTouch:
		swiping = event.pressed
		swipe_from = event.position
	elif event is InputEventScreenDrag and swiping:
		var dv: Vector2 = event.position - swipe_from
		if dv.length() > 45.0:
			if absf(dv.x) > absf(dv.y):
				turn(Vector2i(signi(int(dv.x)), 0))
			else:
				turn(Vector2i(0, signi(int(dv.y))))
			swipe_from = event.position


func _process(delta: float) -> void:
	tick(delta)
	banner_t = maxf(0.0, banner_t - delta)
	eat_flash = maxf(0.0, eat_flash - delta)
	match state:
		State.TITLE:
			if start_pressed():
				reset()
		State.DEAD:
			if start_pressed() and t > 0.6:
				reset()
		State.PLAY:
			clear_presses()
			acc += minf(delta, 0.1)
			while acc >= step_time and state == State.PLAY:
				acc -= step_time
				step()
	queue_redraw()


func step() -> void:
	if queue.size() > 0:
		dir = queue.pop_front()
	var head: Vector2i = snake[0] + dir
	var why := ""
	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS:
		why = "You left the waveguide. Radiation loss."
	elif walls.has(head):
		why = "Scattered by a sidewall defect."
	elif snake.slice(0, snake.size() - 1).has(head):
		why = "You coupled into your own tail. Classic."
	if why != "":
		die(why)
		return
	snake.push_front(head)
	if head == food:
		eaten += 1
		eat_flash = 0.25
		step_time = maxf(0.065, 0.16 - eaten * 0.004) / mult
		if eaten % 5 == 0:
			level += 1
			for i in level:
				var c := free_cell(true)
				if c.x >= 0:
					walls.append(c)
			banner = "Level %d: more scattering defects" % level
			banner_t = 1.6
			shake(5.0)
		food = free_cell(false)
	else:
		snake.pop_back()


func die(why: String) -> void:
	cause = why
	state = State.DEAD
	t = 0.0
	shake(12.0)
	new_best = submit_score(eaten)


func verdict() -> String:
	if eaten >= 30:
		return "Low-loss waveguide. Publish it in Optica."
	if eaten >= 15:
		return "Respectable propagation. Your chip salutes you."
	return "That waveguide needs another trip to the cleanroom."


func cell_rect(c: Vector2i, inset: float) -> Rect2:
	return Rect2(OX + c.x * CELL + inset, OY + c.y * CELL + inset, CELL - inset * 2, CELL - inset * 2)


func _draw() -> void:
	draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(0.07, 0.08, 0.14))
	var board := Rect2(OX, OY, COLS * CELL, ROWS * CELL)
	draw_rect(board, Color(0.10, 0.12, 0.2))
	# cladding glow
	draw_rect(board.grow(6), Color(0.3, 0.5, 0.9, 0.35), false, 4.0)
	for w in walls:
		var r := cell_rect(w, 4)
		draw_rect(r, Color(0.55, 0.55, 0.65))
		draw_line(r.position, r.end, Color(0.3, 0.3, 0.4), 3.0)
		draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(0.3, 0.3, 0.4), 3.0)
	if food.x >= 0:
		var c := cell_rect(food, 0).get_center()
		var pulse := 0.7 + 0.3 * sin(t * 6.0)
		draw_circle(c, CELL * 0.55 * pulse, Color(1.0, 0.3, 0.45, 0.25))
		draw_circle(c, CELL * 0.3, Color(1.0, 0.35, 0.5))
	for i in snake.size():
		var a := maxf(0.35, 1.0 - float(i) / (snake.size() + 4))
		var col := Color(0.35, 0.65, 1.0, a)
		if eat_flash > 0.0:
			col = col.lerp(Color(1, 1, 1, a), eat_flash * 3.0)
		var r := cell_rect(snake[i], 2)
		if i == 0:
			draw_circle(r.get_center(), CELL * 0.48, col)
			var eye := Vector2(dir) * 7.0
			draw_circle(r.get_center() + eye + Vector2(dir.y, dir.x) * 7.0, 4, Color(1, 1, 1))
			draw_circle(r.get_center() + eye - Vector2(dir.y, dir.x) * 7.0, 4, Color(1, 1, 1))
		else:
			draw_rect(r, col)
	text(Vector2(150, 55), "Photons %d" % eaten, 30, Color(1, 1, 1))
	text(Vector2(420, 55), "Level %d" % level, 30, Color(1, 1, 1))
	text(Vector2(W - 230, 55), "Best %d" % maxi(best, eaten), 26, Color(1, 0.9, 0.6))
	if banner_t > 0.0 and state == State.PLAY:
		text(Vector2(0, 360), banner, 44, Color(1, 0.9, 0.4, minf(1.0, banner_t)), true)
	if state == State.TITLE:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		text(Vector2(0, 220), "WAVEGUIDE SNAKE", 80, Color(0.5, 0.8, 1.0), true)
		text(Vector2(0, 290), "You are a light pulse. Collect photons and grow.", 30, Color(1, 1, 1), true)
		text(Vector2(0, 340), "Don't hit the walls, your tail, or scattering defects. It speeds up.", 26, Color(1, 1, 1), true)
		text(Vector2(0, 400), "Swipe to steer on a phone, arrows / WASD on a PC.", 26, Color(0.85, 0.85, 1), true)
		text(Vector2(0, 445), "Difficulty: %s (change it in the menu)" % DIFF_NAMES[difficulty()], 22, Color(0.85, 0.85, 1), true)
		if int(t * 2.0) % 2 == 0:
			text(Vector2(0, 500), "Tap or press SPACE to start", 36, Color(0.6, 1, 0.6), true)
	elif state == State.DEAD:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.55))
		text(Vector2(0, 230), "SIGNAL LOST", 80, Color(1, 0.45, 0.5), true)
		text(Vector2(0, 300), cause, 32, Color(1, 1, 1), true)
		text(Vector2(0, 360), "Guided %d photons, level %d. %s" % [eaten, level, verdict()], 26, Color(1, 1, 1), true)
		if new_best:
			text(Vector2(0, 420), "NEW BEST!", 36, Color(0.6, 1, 0.6), true)
		if t > 0.6 and int(t * 2.0) % 2 == 0:
			text(Vector2(0, 510), "Tap or press SPACE to try again", 32, Color(1, 1, 0.6), true)
	draw_overlay()
