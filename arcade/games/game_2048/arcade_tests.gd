extends RefCounted
# Phone tests for this game, used by tools/tests/run_tests.gd (puzzle_checks):
#   play(rt, n, name): play a bit by touch and check it worked (rt is the test runner:
#                      rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window)
#   win(rt, n):        bring the round to a win, so the runner can check scoring and saves.


static func play(rt: Node, n, name: String) -> void:
	var moved_anim := false
	for d in [Vector2(-300, 0), Vector2(0, 300), Vector2(300, 0), Vector2(0, -300)]:
		var before := JSON.stringify(n.get("cells"))
		await rt.touch_swipe(n.get("borigin") + Vector2(n.get("bsize"), n.get("bsize")) * 0.5 - d * 0.5, d)
		if JSON.stringify(n.get("cells")) != before and not n.get("slides").is_empty():
			moved_anim = true
	rt.check(name, "tiles slide with an animation", moved_anim)


static func win(rt: Node, n) -> void:
	var c: Array = n.get("cells")
	c.fill(0)
	c[0] = 1024
	c[1] = 1024
	n.set("cells", c)
	n.call("move", Vector2i.LEFT)  # makes 2048; the round goes on
	await rt.frames(1)
	# fill the board so no move is left, which ends the round with the 2048 reached
	var k := 0
	for i in c.size():
		c[i] = 2 << (k % 10) if i != 0 else 2048
		k += 3 if (i % n.get("n")) == 0 else 1
	var vals := [2, 4, 8, 16, 32, 64, 128, 256, 512]
	for i in c.size():
		var x: int = i % int(n.get("n"))
		var y: int = i / int(n.get("n"))
		c[i] = vals[(x + 2 * y) % vals.size()] if i != 0 else 2048
	c[c.size() - 1] = 0
	n.set("cells", c)
	n.call("move", Vector2i.RIGHT)
