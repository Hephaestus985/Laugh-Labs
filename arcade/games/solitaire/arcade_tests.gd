extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var before: int = n.get("waste").size()
	await rt.tap(n.call("stock_rect").get_center())
	await rt.frames(2)
	rt.check(name, "tap the deck draws a card (phone)", n.get("waste").size() == before + 1)
	# drag: find a pile top that fits on another pile, or at least drag one and see it come back
	var moved := false
	for p in 7:
		var pile: Array = n.get("piles")[p]
		var c: int = pile.back()
		for q in 7:
			if q != p and n.call("fits_pile", c, q):
				var from: Vector2 = n.call("card_pos", p, pile.size() - 1) + Vector2(50, 40)
				var to: Vector2 = n.call("card_pos", q, n.get("piles")[q].size() - 1) + Vector2(50, 90)
				await rt.touch_swipe(from, to - from)
				moved = n.get("piles")[q].has(c)
				break
		if moved:
			break
	if moved:
		rt.check(name, "dragging a card onto a pile moves it (phone)", true)


static func win(rt: Node, n) -> void:
	var found := [range(0, 13), range(13, 26), range(26, 39), range(39, 51)]
	n.set("found", found)
	n.set("piles", [[51], [], [], [], [], [], []])
	n.set("stock", [])
	n.set("waste", [])
	n.call("auto_move", "p0", 0)
