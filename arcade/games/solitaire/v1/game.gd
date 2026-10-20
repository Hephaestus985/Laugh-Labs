extends PuzzleGame
# Klondike solitaire. Build the four foundations up by suit from Ace to King.
# On the seven piles, cards go down in alternating colours; only a King fills an
# empty pile. Easy and Normal draw one card at a time, Hard draws three.
# Tap a card to send it to the best place, or drag it (with the cards on top of it).
#
# Cards are ints 0-51: suit = c / 13 (0 spades, 1 hearts, 2 diamonds, 3 clubs),
# rank = c % 13 + 1. In the piles a face-down card is stored as -(c + 1).

var CW := 112.0
var CH := 156.0
var GAP := 18.0
var LEFT := 40.0
var TOP := 84.0
var PILE_Y := 262.0
var fly: Array = []  # cards in flight: [card, from, to]
var flip_pile := -1  # pile whose top card was just turned over
var _drop_from: Array = []

var stock: Array = []
var waste: Array = []
var found: Array = [[], [], [], []]
var piles: Array = [[], [], [], [], [], [], []]
var draw_n := 1
var undo_stack: Array = []

# dragging
var drag_cards: Array = []  # card ints being dragged
var drag_from := ""  # "waste", "f0".."f3", "p0".."p6"
var drag_index := 0
var drag_pos := Vector2.ZERO
var drag_offset := Vector2.ZERO


func _init() -> void:
	game_id = "solitaire"
	panel_slots = 3
	title = "Solitaire"
	help = ["Build each suit from Ace to King on the four spaces top right.", "On the seven piles, go down in alternating colours. Only a King fills an empty pile.", "Tap a card to move it where it fits, or drag it. Tap the deck to draw."]


static func suit(c: int) -> int: return c / 13
static func rank(c: int) -> int: return c % 13 + 1
static func red(c: int) -> bool: return suit(c) == 1 or suit(c) == 2


func new_game() -> void:
	draw_n = 3 if diff == 2 else 1
	var deck := range(52)
	deck.shuffle()
	piles = [[], [], [], [], [], [], []]
	for p in 7:
		for k in p + 1:
			var c: int = deck.pop_back()
			piles[p].append(c if k == p else -(c + 1))
	stock = deck
	waste = []
	found = [[], [], [], []]
	undo_stack.clear()
	drag_cards = []


func to_save() -> Dictionary:
	return {"stock": stock, "waste": waste, "found": found, "piles": piles, "draw": draw_n}


func _ints(a) -> Array:
	return (a as Array).map(func(v): return int(v))


func from_save(d: Dictionary) -> void:
	stock = _ints(d.get("stock", []))
	waste = _ints(d.get("waste", []))
	found = d.get("found", [[], [], [], []]).map(func(a): return _ints(a))
	piles = d.get("piles", []).map(func(a): return _ints(a))
	draw_n = int(d.get("draw", 1))
	var total := stock.size() + waste.size()
	for f in found:
		total += f.size()
	for p in piles:
		total += p.size()
	if found.size() != 4 or piles.size() != 7 or total != 52:
		new_game()
	undo_stack.clear()
	drag_cards = []


func save_info() -> String:
	var n := 0
	for f in found:
		n += f.size()
	return "%d of 52 cards home" % n


func play_buttons() -> Array:
	var b := [["Undo", _undo]]
	if _can_auto_finish():
		b.append(["Auto finish", _auto_finish])
	b.append(["New deal", start_new])
	return b


# ---------------------------------------------------------------- rules

func _snapshot() -> void:
	undo_stack.append(JSON.stringify(to_save()))
	if undo_stack.size() > 300:
		undo_stack.pop_front()


func _undo() -> void:
	if undo_stack.is_empty():
		toast("Nothing to undo")
		return
	var d = JSON.parse_string(undo_stack.pop_back())
	var keep := undo_stack.duplicate()
	from_save(d)
	undo_stack = keep
	save_game()


func fits_foundation(c: int, f: int) -> bool:
	var pile: Array = found[f]
	if pile.is_empty():
		return rank(c) == 1
	var top: int = pile.back()
	return suit(top) == suit(c) and rank(c) == rank(top) + 1


func fits_pile(c: int, p: int) -> bool:
	var pile: Array = piles[p]
	if pile.is_empty():
		return rank(c) == 13
	var top: int = pile.back()
	return top >= 0 and red(top) != red(c) and rank(c) == rank(top) - 1


## The cards at a source, from index i upwards.
func cards_at(src: String, i: int) -> Array:
	if src == "waste":
		return [waste.back()] if not waste.is_empty() else []
	if src.begins_with("f"):
		var f: Array = found[int(src.substr(1))]
		return [f.back()] if not f.is_empty() else []
	var p: Array = piles[int(src.substr(1))]
	return p.slice(i)


func _remove(src: String, count: int) -> void:
	var arr: Array
	if src == "waste":
		arr = waste
	elif src.begins_with("f"):
		arr = found[int(src.substr(1))]
	else:
		arr = piles[int(src.substr(1))]
	for k in count:
		arr.pop_back()
	if src.begins_with("p") and not arr.is_empty() and arr.back() < 0:
		arr[arr.size() - 1] = -arr.back() - 1  # turn the new top card face up


## Try to move cards (from src at index i) onto dst ("f0".."f3" or "p0".."p6").
func try_move(src: String, i: int, dst: String) -> bool:
	if src == dst:
		return false
	var cards := cards_at(src, i)
	if cards.is_empty() or cards[0] < 0:
		return false
	var froms := []
	for k in cards.size():
		froms.append(_drop_from[k] if k < _drop_from.size() else _card_from_pos(src, i + k))
	var had_hidden: bool = src.begins_with("p") and piles[int(src.substr(1))].size() > cards.size() and piles[int(src.substr(1))][piles[int(src.substr(1))].size() - cards.size() - 1] < 0
	if dst.begins_with("f"):
		var f := int(dst.substr(1))
		if cards.size() != 1 or not fits_foundation(cards[0], f):
			return false
		_snapshot()
		_remove(src, 1)
		found[f].append(cards[0])
	else:
		var p := int(dst.substr(1))
		if not fits_pile(cards[0], p):
			return false
		_snapshot()
		_remove(src, cards.size())
		piles[p].append_array(cards)
	_fly(cards, froms, dst)
	if had_hidden:
		flip_pile = int(src.substr(1))
		start_anim("flip", 0.25)
	moves += 1
	_after_move()
	return true


## Tap: send the card to a foundation if it fits, else to the best pile.
func auto_move(src: String, i: int) -> bool:
	var cards := cards_at(src, i)
	if cards.is_empty() or cards[0] < 0:
		return false
	if cards.size() == 1 and not src.begins_with("f"):
		for f in 4:
			if try_move(src, i, "f%d" % f):
				return true
	# prefer a pile that has cards, then an empty one (only useful if this isn't a whole pile)
	for p in 7:
		if not piles[p].is_empty() and try_move(src, i, "p%d" % p):
			return true
	if not (src.begins_with("p") and i == 0):
		for p in 7:
			if piles[p].is_empty() and try_move(src, i, "p%d" % p):
				return true
	return false


func draw_card() -> void:
	_snapshot()
	if stock.is_empty():
		if waste.is_empty():
			undo_stack.pop_back()
			return
		waste.reverse()
		stock = waste
		waste = []
	else:
		var drawn := []
		for k in mini(draw_n, stock.size()):
			drawn.append(stock.pop_back())
			waste.append(drawn.back())
		var froms := []
		for c in drawn:
			froms.append(stock_rect().position)
		_fly(drawn, froms, "waste")
	moves += 1
	save_game()


func _after_move() -> void:
	var home := 0
	for f in found:
		home += f.size()
	if home == 52:
		finish(true, maxi(100, (diff + 1) * 1000 + 520 - int(elapsed) - moves * 2))
	else:
		save_game()


func _can_auto_finish() -> bool:
	if not stock.is_empty() or not waste.is_empty():
		return false
	for p in piles:
		for c in p:
			if c < 0:
				return false
	return true


func _auto_finish() -> void:
	var guard := 0
	while state == 1 and guard < 200:
		guard += 1
		var moved := false
		for p in 7:
			if not piles[p].is_empty():
				for f in 4:
					if try_move("p%d" % p, piles[p].size() - 1, "f%d" % f):
						moved = true
						break
		if not moved:
			break


# ---------------------------------------------------------------- layout and input

func layout() -> void:
	GAP = 18.0 if not portrait else 6.0
	CW = minf(112.0, floorf((board_rect.size.x - 6 * GAP - 10) / 7.0))
	CH = floorf(CW * 1.39)
	LEFT = board_rect.position.x + (board_rect.size.x - 7 * CW - 6 * GAP) / 2.0
	TOP = board_rect.position.y + (8.0 if portrait else 8.0)
	PILE_Y = TOP + CH + (24.0 if portrait else 22.0)


func _card_from_pos(src: String, i: int) -> Vector2:
	if src == "waste":
		return Vector2(col_x(1) + (mini(draw_n, waste.size()) - 1) * CW * 0.18, TOP)
	if src.begins_with("f"):
		return found_rect(int(src.substr(1))).position
	if src == "stock":
		return stock_rect().position
	return card_pos(int(src.substr(1)), i)


func _fly(cards: Array, froms: Array, dst: String) -> void:
	fly = []
	for k in cards.size():
		var to: Vector2
		if dst.begins_with("f"):
			to = found_rect(int(dst.substr(1))).position
		elif dst == "waste":
			to = Vector2(col_x(1) + (mini(draw_n, waste.size()) - cards.size() + k) * CW * 0.18, TOP)
		else:
			var p := int(dst.substr(1))
			to = card_pos(p, piles[p].size() - cards.size() + k)
		fly.append([cards[k], froms[k], to])
	start_anim("fly", 0.2)

func col_x(k: int) -> float:
	return LEFT + k * (CW + GAP)


func stock_rect() -> Rect2: return Rect2(col_x(0), TOP, CW, CH)
func waste_rect() -> Rect2: return Rect2(col_x(1), TOP, CW + (CW * 0.36 if draw_n == 3 else 0.0), CH)
func found_rect(f: int) -> Rect2: return Rect2(col_x(3 + f), TOP, CW, CH)


## Vertical step between cards in a pile, squeezed so long piles fit the screen.
func pile_steps(p: int) -> Vector2:
	var pile: Array = piles[p]
	var down := 18.0
	var up := 38.0
	var downs := pile.filter(func(c): return c < 0).size()
	var ups := pile.size() - downs
	var room := board_rect.end.y - 6 - PILE_Y - CH
	var need := downs * down + maxi(0, ups - 1) * up
	if need > room and need > 0:
		var k := room / need
		down *= k
		up *= k
	return Vector2(down, up)


func card_pos(p: int, i: int) -> Vector2:
	var st := pile_steps(p)
	var y := PILE_Y
	for k in i:
		y += st.x if piles[p][k] < 0 else st.y
	return Vector2(col_x(p), y)


## What is under a point: [source, index] or ["", -1].
func hit(pos: Vector2) -> Array:
	if stock_rect().has_point(pos):
		return ["stock", 0]
	if waste_rect().has_point(pos):
		return ["waste", 0]
	for f in 4:
		if found_rect(f).has_point(pos):
			return ["f%d" % f, 0]
	for p in 7:
		var pile: Array = piles[p]
		for i in range(pile.size() - 1, -1, -1):
			if Rect2(card_pos(p, i), Vector2(CW, CH)).has_point(pos):
				return ["p%d" % p, i]
		if pile.is_empty() and Rect2(col_x(p), PILE_Y, CW, CH).has_point(pos):
			return ["p%d" % p, 0]
	return ["", -1]


func game_press(pos: Vector2) -> void:
	drag_cards = []
	var h := hit(pos)
	if h[0] == "" or h[0] == "stock":
		return
	var cards := cards_at(h[0], h[1])
	if cards.is_empty() or cards[0] < 0:
		return
	drag_from = h[0]
	drag_index = h[1]
	var origin: Vector2
	if h[0] == "waste":
		origin = Vector2(col_x(1) + (mini(draw_n, waste.size()) - 1) * CW * 0.18, TOP)
	elif h[0].begins_with("f"):
		origin = found_rect(int(h[0].substr(1))).position
	else:
		origin = card_pos(int(h[0].substr(1)), h[1])
	drag_offset = pos - origin
	drag_pos = pos
	drag_cards = cards


func game_drag(_from: Vector2, to: Vector2) -> void:
	if not drag_cards.is_empty():
		drag_pos = to


func game_release(_from: Vector2, to: Vector2) -> void:
	if drag_cards.is_empty() or not _dragged:
		drag_cards = []
		return
	var cards := drag_cards
	drag_cards = []
	# drop on whatever column the card's centre is over
	var centre := to - drag_offset + Vector2(CW, CH) / 2.0
	var best := ""
	var best_d := 1e9
	for f in 4:
		var d := found_rect(f).get_center().distance_to(centre)
		if d < best_d and centre.y < PILE_Y:
			best_d = d
			best = "f%d" % f
	for p in 7:
		var top := card_pos(p, maxi(0, piles[p].size() - 1)) + Vector2(CW, CH) / 2.0
		var d := absf(top.x - centre.x) + (0.0 if centre.y >= PILE_Y - 40 else 400.0)
		if d < best_d:
			best_d = d
			best = "p%d" % p
	if best != "" and best_d < CW:
		_drop_from = []
		for k in cards.size():
			_drop_from.append(to - drag_offset + Vector2(0, k * CH * 0.25))
		var ok := try_move(drag_from, drag_index, best)
		_drop_from = []
		if not ok:
			toast("That card doesn't fit there")


func game_tap(pos: Vector2) -> void:
	var h := hit(pos)
	if h[0] == "stock":
		draw_card()
	elif h[0] != "":
		var cards := cards_at(h[0], h[1])
		if cards.is_empty() or cards[0] < 0:
			return
		if not auto_move(h[0], h[1]):
			toast("No place for that card yet")


func game_key(k: int) -> void:
	if k in [KEY_SPACE, KEY_D]:
		draw_card()
	elif k == KEY_U:
		_undo()


# ---------------------------------------------------------------- drawing

func draw_suit(c: Vector2, s: int, size: float) -> void:
	var col := Color(0.85, 0.12, 0.15) if s == 1 or s == 2 else Color(0.08, 0.08, 0.12)
	var r := size * 0.5
	match s:
		0:  # spade: an upside-down heart with a stem
			draw_circle(c + Vector2(-r * 0.45, r * 0.15), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.45, r * 0.15), r * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, r * 0.05), c + Vector2(r * 0.95, r * 0.05), c + Vector2(0, -r)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 0.2), c + Vector2(-r * 0.35, r), c + Vector2(r * 0.35, r)]), col)
		1:  # heart
			draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.5, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.1), c + Vector2(r * 0.95, -r * 0.1), c + Vector2(0, r)]), col)
		2:  # diamond
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.75, 0), c + Vector2(0, r), c + Vector2(-r * 0.75, 0)]), col)
		3:  # club
			draw_circle(c + Vector2(0, -r * 0.45), r * 0.42, col)
			draw_circle(c + Vector2(-r * 0.48, r * 0.12), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.48, r * 0.12), r * 0.42, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(-r * 0.3, r), c + Vector2(r * 0.3, r)]), col)


const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]


func draw_card_at(pos: Vector2, c: int, squeeze := 1.0) -> void:
	var r := Rect2(pos, Vector2(CW, CH))
	if squeeze < 1.0:  # turning over: drawn narrower
		r = Rect2(pos + Vector2(CW * (1.0 - squeeze) / 2.0, 0), Vector2(CW * squeeze, CH))
		draw_rect(r, Color(0.98, 0.98, 0.96) if c >= 0 else Color(0.20, 0.35, 0.70))
		return
	if c < 0:
		draw_rect(r, Color(0.20, 0.35, 0.70))
		draw_rect(r.grow(-8), Color(0.28, 0.45, 0.85), false, 3.0)
		draw_rect(r, Color(0.05, 0.05, 0.1, 0.6), false, 1.5)
		return
	draw_rect(r, Color(0.98, 0.98, 0.96))
	draw_rect(r, Color(0.2, 0.2, 0.25, 0.8), false, 1.5)
	var col := Color(0.85, 0.12, 0.15) if red(c) else Color(0.08, 0.08, 0.12)
	var k := CW / 112.0
	draw_string(font, pos + Vector2(8, 34) * k, RANKS[rank(c)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * k), col)
	draw_suit(pos + Vector2(CW - 26 * k, 22 * k), suit(c), 26 * k)
	draw_suit(pos + Vector2(CW / 2, CH * 0.62), suit(c), 54 * k)


func draw_slot(r: Rect2, label := "") -> void:
	draw_rect(r, Color(1, 1, 1, 0.06))
	draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
	if label != "":
		draw_string(font, Vector2(r.position.x, r.get_center().y + 12), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color(1, 1, 1, 0.3))


func _hidden(src: String, i: int) -> bool:
	return not drag_cards.is_empty() and _dragged and src == drag_from and i >= drag_index


## Cards still flying to this spot are drawn in flight, not in place.
func _in_flight(c: int) -> bool:
	if not animating("fly"):
		return false
	for f in fly:
		if f[0] == c:
			return true
	return false


func draw_game() -> void:
	draw_rect(Rect2(0, 0, sw, panel_rect.position.y - 8) if portrait else Rect2(0, 0, panel_rect.position.x - 10, sh), Color(0.10, 0.36, 0.22))
	# stock and waste
	if stock.is_empty():
		draw_slot(stock_rect(), "redeal")
	else:
		draw_card_at(stock_rect().position, -1)
		draw_string(font, stock_rect().position + Vector2(0, CH + 20), "%d" % stock.size(), HORIZONTAL_ALIGNMENT_CENTER, CW, 18, Color(1, 1, 1, 0.6))
	if waste.is_empty():
		draw_slot(Rect2(col_x(1), TOP, CW, CH))
	else:
		var show := mini(draw_n, waste.size())
		for k in show:
			var idx := waste.size() - show + k
			if (k == show - 1 and _hidden("waste", 0)) or _in_flight(waste[idx]):
				continue
			draw_card_at(Vector2(col_x(1) + k * CW * 0.18, TOP), waste[idx])
	for f in 4:
		if found[f].is_empty() or (_hidden("f%d" % f, 0) and found[f].size() == 1):
			draw_slot(found_rect(f), "A")
		else:
			var pile: Array = found[f]
			var shown := pile.size() - 1
			if _hidden("f%d" % f, 0) or _in_flight(pile.back()):
				shown -= 1
			if shown >= 0:
				draw_card_at(found_rect(f).position, pile[shown])
			else:
				draw_slot(found_rect(f), "A")
	for p in 7:
		if piles[p].is_empty():
			draw_slot(Rect2(col_x(p), PILE_Y, CW, CH), "K")
		for i in piles[p].size():
			if _hidden("p%d" % p, i):
				break
			if _in_flight(piles[p][i]):
				continue
			var sq := 1.0
			if p == flip_pile and i == piles[p].size() - 1 and animating("flip"):
				sq = absf(cos(anim("flip") * PI))
			draw_card_at(card_pos(p, i), piles[p][i], sq)
	if animating("fly"):
		var k := ease_out(anim("fly"))
		for f in fly:
			draw_card_at((f[1] as Vector2).lerp(f[2], k), f[0])
	if not drag_cards.is_empty() and _dragged:
		for k in drag_cards.size():
			draw_card_at(drag_pos - drag_offset + Vector2(0, k * CH * 0.25), drag_cards[k])
	draw_stats(["Moves %d   %s" % [moves, time_text(elapsed)], "Draw %d" % draw_n])
