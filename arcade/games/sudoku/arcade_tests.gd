extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var grid: Array = n.get("grid")
	var empty := grid.find(0)
	var cell_pos: Vector2 = n.ORIGIN + Vector2(empty % 9 + 0.5, empty / 9 + 0.5) * n.CELL
	await rt.tap(cell_pos)
	await rt.frames(2)
	var want: int = n.get("solution")[empty]
	var pad: Vector2 = n.call("pad_rect", want).get_center()
	await rt.tap(pad)
	await rt.frames(2)
	rt.check(name, "tap a cell, then a number, fills it (phone)", n.get("grid")[empty] == want)
	var copy: Array = n.get("solution").duplicate()
	var given: Array = n.get("given")
	var puzzle := []
	for i in 81:
		puzzle.append(copy[i] if given[i] else 0)
	rt.check(name, "the puzzle has exactly one solution", n._solve(puzzle, 2, false) == 1)


static func win(rt: Node, n) -> void:
	var sol: Array = n.get("solution")
	var g: Array = sol.duplicate()
	var last := 0
	for i in 81:
		if not n.get("given")[i]:
			last = i
	g[last] = 0
	n.set("grid", g)
	n.set("sel", last)
	n.call("put", sol[last])
