extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var tiles: Array = n.get("tiles")
	var nn: int = n.get("n")
	var g := tiles.find(0)
	var pick := g - 1 if g % nn > 0 else g + 1
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	await rt.tap(o + Vector2(pick % nn + 0.5, pick / nn + 0.5) * c)
	await rt.frames(2)
	rt.check(name, "tap a tile next to the gap slides it (phone)", n.get("tiles")[pick] == 0)


static func win(rt: Node, n) -> void:
	var nn: int = n.get("n")
	var tiles := []
	for i in nn * nn - 1:
		tiles.append(i + 1)
	tiles.append(0)
	# one step away from solved: the gap one to the left
	tiles[nn * nn - 1] = nn * nn - 1
	tiles[nn * nn - 2] = 0
	n.set("tiles", tiles)
	n.call("slide", nn * nn - 1)
