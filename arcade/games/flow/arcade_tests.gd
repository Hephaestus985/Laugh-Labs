extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	# drag along the first solution pipe
	var sol: Array = n.get("solution")[0]
	var nn: int = n.get("n")
	var o: Vector2 = n.get("origin")
	var c: float = n.get("cell")
	var pts := sol.map(func(i): return o + Vector2(i % nn + 0.5, i / nn + 0.5) * c)
	var e := InputEventScreenTouch.new()
	e.position = rt.to_window(pts[0])
	e.pressed = true
	Input.parse_input_event(e)
	await rt.frames(2)
	for k in range(1, pts.size()):
		var d := InputEventScreenDrag.new()
		d.position = rt.to_window(pts[k])
		Input.parse_input_event(d)
		await rt.frames(2)
	var r := InputEventScreenTouch.new()
	r.position = rt.to_window(pts.back())
	Input.parse_input_event(r)
	await rt.frames(3)
	rt.check(name, "dragging from a dot to its partner connects them (phone)", n.call("pipe_done", 0))


static func win(rt: Node, n) -> void:
	var sol: Array = n.get("solution")
	var paths := []
	for k in sol.size():
		paths.append(sol[k].duplicate() if k > 0 else [])
	n.set("paths", paths)
	n.call("_hint")
