extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	var before: Array = n.get("lit").duplicate()
	await rt.tap(o + Vector2(1.5, 1.5) * c)
	await rt.frames(2)
	var nn: int = n.get("n")
	var i := nn + 1
	var after: Array = n.get("lit")
	rt.check(name, "tap flips a light and its neighbours (phone)", after[i] != before[i] and after[i - 1] != before[i - 1] and after[i + nn] != before[i + nn] and after[i + 1] != before[i + 1] and after[i - nn] != before[i - nn])


static func win(rt: Node, n) -> void:
	var need: Array = n.get("need")
	for i in need.size():
		if need[i] and n.state == 1:
			n.call("tap_cell", i)
