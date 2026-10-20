extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var c: float = n.get("cell")
	var start_cell: int = 3 * int(n.get("cols")) + 3
	await rt.tap(n.call("cell_pos", start_cell) + Vector2(c, c) * 0.5)
	await rt.frames(2)
	rt.check(name, "first tap opens safe cells (phone)", n.get("open").count(true) > 1 and n.state == 1)
	# long-press a closed cell to flag it
	var closed: int = n.get("open").find(false)
	var p: Vector2 = n.call("cell_pos", closed) + Vector2(c, c) * 0.5
	var e := InputEventScreenTouch.new()
	e.position = rt.to_window(p)
	e.pressed = true
	Input.parse_input_event(e)
	await rt.frames(45)
	var r := InputEventScreenTouch.new()
	r.position = e.position
	Input.parse_input_event(r)
	await rt.frames(3)
	rt.check(name, "long-press places a flag (phone)", n.get("flag")[closed])


static func win(rt: Node, n) -> void:
	n.call("reveal", 0)  # places the mines
	var mine: Array = n.get("mine")
	var open: Array = n.get("open")
	for i in mine.size():
		if not mine[i] and not open[i]:
			n.call("reveal", i)
			if n.state != 1:
				return
