extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var pair: Array = n.call("_pairs")
	if pair.is_empty():
		n.call("_shuffle")
		pair = n.call("_pairs")
	var left: int = n.call("_alive").size()
	for i in pair:
		await rt.tap(n.call("tile_rect", i).get_center())
		await rt.frames(2)
	rt.check(name, "tap two matching free tiles removes them (phone)", n.call("_alive").size() == left - 2)


static func win(rt: Node, n) -> void:
	# the deal is built to be clearable: keep taking pairs (shuffle if stuck)
	var guard := 0
	while n.state == 1 and guard < 300:
		guard += 1
		var pair: Array = n.call("_pairs")
		if pair.is_empty():
			n.call("_shuffle")
			continue
		n.call("pick", pair[0])
		n.call("pick", pair[1])
