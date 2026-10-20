extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var p0: int = n.get("player")
	var w: int = n.get("w")
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	# swipe in every direction until one step works
	for d in [Vector2(200, 0), Vector2(-200, 0), Vector2(0, 200), Vector2(0, -200)]:
		await rt.touch_swipe(Vector2(500, 380), d)
		await rt.frames(2)
		if n.get("player") != p0:
			break
	rt.check(name, "swipe walks the worker (phone)", n.get("player") != p0)


static func win(rt: Node, n) -> void:
	n.set("boxes", n.get("goals").duplicate())
	n.call("_check")
