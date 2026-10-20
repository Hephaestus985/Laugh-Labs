extends PuzzleGame
# Connect Four against the computer. Drop discs into the 7 columns; four in a row
# (across, down or diagonal) wins. You are red and go first.
# Easy: the computer looks one move ahead and sometimes plays loosely.
# Normal: it looks 4 moves ahead. Hard: 6 moves ahead.

const COLS := 7
const ROWS := 6
var CELL := 92.0
var ORIGIN := Vector2(170, 110)
const YOU := 1
const CPU := 2

var board: Array = []  # COLS*ROWS, row 0 at the top
var turn := YOU
var think := 0.0
var last_drop := -1
var win_line: Array = []
var undo_stack: Array = []
var hover_col := -1


func _init() -> void:
	game_id = "connect_four"
	title = "Connect Four"
	help = ["Tap a column to drop a red disc. Get four in a row before the computer:", "across, down or diagonally. You go first.", "Undo takes back your last move (and the computer's answer)."]


func new_game() -> void:
	board = []
	board.resize(COLS * ROWS)
	board.fill(0)
	turn = YOU
	think = 0.0
	last_drop = -1
	win_line = []
	undo_stack.clear()


func to_save() -> Dictionary:
	return {"board": board, "turn": turn}


func from_save(d: Dictionary) -> void:
	board = d.get("board", []).map(func(v): return int(v))
	turn = int(d.get("turn", YOU))
	if board.size() != COLS * ROWS:
		new_game()
		return
	think = 0.0
	last_drop = -1
	win_line = []
	undo_stack.clear()


func save_info() -> String:
	return "%d discs played" % board.filter(func(v): return v != 0).size()


func play_buttons() -> Array:
	return [["Undo", _undo], ["New game", start_new]]


func layout() -> void:
	CELL = floorf(minf(minf((board_rect.size.x - 30) / COLS, (board_rect.size.y - 60) / ROWS), 110.0))
	ORIGIN = board_rect.position + Vector2((board_rect.size.x - COLS * CELL) / 2.0, 40 + (board_rect.size.y - 50 - ROWS * CELL) / 2.0)


static func drop_row(b: Array, c: int) -> int:
	for r in range(ROWS - 1, -1, -1):
		if b[r * COLS + c] == 0:
			return r
	return -1


## The four cells of a winning line through the board, or [] if nobody has four.
static func find_four(b: Array) -> Array:
	for r in ROWS:
		for c in COLS:
			var p: int = b[r * COLS + c]
			if p == 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var cells := [r * COLS + c]
				for k in range(1, 4):
					var rr: int = r + d.y * k
					var cc: int = c + d.x * k
					if rr < 0 or rr >= ROWS or cc >= COLS or b[rr * COLS + cc] != p:
						break
					cells.append(rr * COLS + cc)
				if cells.size() == 4:
					return cells
	return []


func play(c: int, who: int) -> bool:
	var r := drop_row(board, c)
	if r < 0:
		return false
	if who == YOU:
		undo_stack.append([board.duplicate(), turn])
	board[r * COLS + c] = who
	last_drop = r * COLS + c
	start_anim("drop", 0.12 + 0.04 * r)
	moves += 1
	win_line = find_four(board)
	if not win_line.is_empty():
		var you_won: bool = board[win_line[0]] == YOU
		finish(you_won, maxi(100, (diff + 1) * 500 + (42 - board.filter(func(v): return v != 0).size()) * 10) if you_won else 0)
		return true
	if not board.has(0):
		toast("A draw!")
		finish(false, 0)
		return true
	turn = CPU if who == YOU else YOU
	think = 0.45
	save_game()
	return true


func _undo() -> void:
	if undo_stack.is_empty() or turn != YOU:
		toast("Nothing to undo")
		return
	var u: Array = undo_stack.pop_back()
	board = u[0]
	turn = YOU
	last_drop = -1
	save_game()


func game_tap(p: Vector2) -> void:
	if turn != YOU:
		return
	var c := int((p.x - ORIGIN.x) / CELL)
	if p.x < ORIGIN.x or c < 0 or c >= COLS or p.y > ORIGIN.y + ROWS * CELL + 20:
		return
	if not play(c, YOU):
		toast("That column is full")


func game_key(k: int) -> void:
	if k >= KEY_1 and k <= KEY_7 and turn == YOU:
		play(k - KEY_1, YOU)
	elif k == KEY_U:
		_undo()


func game_update(delta: float) -> void:
	if turn != CPU:
		return
	think -= delta
	if think > 0.0:
		return
	play(cpu_move(), CPU)


# ---------------------------------------------------------------- the computer

const ORDER := [3, 2, 4, 1, 5, 0, 6]


func cpu_move() -> int:
	var legal := ORDER.filter(func(c): return drop_row(board, c) >= 0)
	# always take a win, always block a loss
	for who in [CPU, YOU]:
		for c in legal:
			var b := board.duplicate()
			b[drop_row(b, c) * COLS + c] = who
			if not find_four(b).is_empty():
				return c
	if diff == 0 and randf() < 0.35:
		return legal[randi() % legal.size()]
	var depth: int = [1, 4, 6][diff]
	var best_c: int = legal[0]
	var best := -1e9
	for c in legal:
		var b := board.duplicate()
		b[drop_row(b, c) * COLS + c] = CPU
		var v := _minimax(b, depth - 1, -1e9, 1e9, false)
		if v > best:
			best = v
			best_c = c
	return best_c


func _minimax(b: Array, depth: int, alpha: float, beta: float, cpu_turn: bool) -> float:
	var four := find_four(b)
	if not four.is_empty():
		return (100000.0 + depth) if b[four[0]] == CPU else (-100000.0 - depth)
	if depth == 0 or not b.has(0):
		return _score(b)
	if cpu_turn:
		var v := -1e9
		for c in ORDER:
			var r := drop_row(b, c)
			if r < 0:
				continue
			b[r * COLS + c] = CPU
			v = maxf(v, _minimax(b, depth - 1, alpha, beta, false))
			b[r * COLS + c] = 0
			alpha = maxf(alpha, v)
			if alpha >= beta:
				break
		return v
	var v2 := 1e9
	for c in ORDER:
		var r := drop_row(b, c)
		if r < 0:
			continue
		b[r * COLS + c] = YOU
		v2 = minf(v2, _minimax(b, depth - 1, alpha, beta, true))
		b[r * COLS + c] = 0
		beta = minf(beta, v2)
		if alpha >= beta:
			break
	return v2


## How good a board is for the computer: open lines of two and three, the centre.
func _score(b: Array) -> float:
	var s := 0.0
	for r in ROWS:
		if b[r * COLS + 3] == CPU:
			s += 3
		elif b[r * COLS + 3] == YOU:
			s -= 3
	for r in ROWS:
		for c in COLS:
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var er: int = r + d.y * 3
				var ec: int = c + d.x * 3
				if er < 0 or er >= ROWS or ec >= COLS:
					continue
				var mine := 0
				var theirs := 0
				for k in 4:
					var v: int = b[(r + d.y * k) * COLS + c + d.x * k]
					if v == CPU:
						mine += 1
					elif v == YOU:
						theirs += 1
				if theirs == 0:
					s += float([0, 1, 5, 40, 0][mine])
				elif mine == 0:
					s -= float([0, 1, 6, 50, 0][theirs])
	return s


# ---------------------------------------------------------------- drawing

func draw_game() -> void:
	var frame := Rect2(ORIGIN - Vector2(12, 12), Vector2(COLS, ROWS) * CELL + Vector2(24, 24))
	# the falling disc is drawn behind the frame's holes: draw it first, then the frame with holes
	draw_rect(frame, Color(0.15, 0.30, 0.75))
	for r in ROWS:
		for c in COLS:
			var i := r * COLS + c
			var center := ORIGIN + Vector2(c + 0.5, r + 0.5) * CELL
			var col := Color(0.08, 0.09, 0.15)
			var falling := i == last_drop and animating("drop")
			if board[i] == YOU and not falling:
				col = Color(0.92, 0.20, 0.20)
			elif board[i] == CPU and not falling:
				col = Color(0.98, 0.82, 0.20)
			draw_circle(center, CELL * 0.4, col)
			if i == last_drop and not falling:
				draw_arc(center, CELL * 0.42, 0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
			if win_line.has(i):
				draw_arc(center, CELL * 0.3, 0, TAU, 32, Color.WHITE, 5.0)
	if last_drop >= 0 and animating("drop"):
		var k := anim("drop")
		var target := ORIGIN + Vector2(last_drop % COLS + 0.5, last_drop / COLS + 0.5) * CELL
		var start := Vector2(target.x, ORIGIN.y - CELL * 0.5)
		var col2 := Color(0.92, 0.20, 0.20) if board[last_drop] == YOU else Color(0.98, 0.82, 0.20)
		draw_circle(start.lerp(target, k * k), CELL * 0.4, col2)
	for c in COLS:
		draw_string(font, ORIGIN + Vector2(c * CELL, -22), "v", HORIZONTAL_ALIGNMENT_CENTER, CELL, 26, Color(1, 1, 1, 0.25 if turn == YOU else 0.08))
	draw_stats(["You: red   CPU: yellow", ("Your turn" if turn == YOU else "Computer is thinking...")])
