extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var o: Vector2 = n.ORIGIN
	await rt.tap(o + Vector2(3.5 * n.CELL, 3 * n.CELL))
	await rt.frames(2)
	rt.check(name, "tap a column drops a disc (phone)", n.get("board")[5 * 7 + 3] == 1)
	for k in 120:
		if n.get("turn") == 1:
			break
		await rt.frames(1)
	rt.check(name, "the computer answers", n.get("board").filter(func(v): return v == 2).size() == 1)


static func win(rt: Node, n) -> void:
	var b: Array = n.get("board")
	b.fill(0)
	for c in 3:
		b[5 * 7 + c] = 1
	b[4 * 7 + 0] = 2
	b[4 * 7 + 1] = 2
	n.set("board", b)
	n.set("turn", 1)
	n.call("play", 3, 1)
