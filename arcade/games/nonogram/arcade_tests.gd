extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	await rt.tap(o + Vector2(0.5, 0.5) * c)
	await rt.frames(2)
	rt.check(name, "tap fills a cell (phone)", n.get("cells")[0] == 1)
	# drag along the second row paints it
	await rt.touch_swipe(o + Vector2(0.5, 1.5) * c, Vector2(c * 3, 0))
	await rt.frames(2)
	var nn: int = n.get("n")
	rt.check(name, "drag paints a row (phone)", n.get("cells")[nn] == 1 and n.get("cells")[nn + 3] == 1)


static func win(rt: Node, n) -> void:
	var tgt: Array = n.get("target")
	var cells: Array = tgt.map(func(v): return 1 if v else 0)
	var last := tgt.rfind(true)
	cells[last] = 0
	n.set("cells", cells)
	n.call("_hint")
