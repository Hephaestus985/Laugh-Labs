extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var p0: Vector2i = n.get("pos")
	await rt.touch_swipe(Vector2(500, 300), Vector2(-130, 0))
	await rt.frames(2)
	rt.check(name, "dragging sideways slides the piece (phone)", n.get("pos").x < p0.x)
	await rt.touch_swipe(Vector2(500, 200), Vector2(0, 260))
	await rt.frames(3)
	rt.check(name, "swipe down drops the piece (phone)", n.get("grid").filter(func(v): return v != "").size() == 4)


static func win(rt: Node, n) -> void:
	var g: Array = n.get("grid")
	g.fill("")
	for x in 9:
		g[19 * 10 + x] = "T"
	n.set("grid", g)
	n.set("lines", int(n.get("target")) - 1)
	n.set("cells", [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)])
	n.set("piece", "I")
	n.set("pos", Vector2i(9, 0))
	n.call("hard_drop")
	# the target is reached; the round goes on until the stack tops out
	for k in 300:
		if n.state != 1:
			break
		n.call("hard_drop")
