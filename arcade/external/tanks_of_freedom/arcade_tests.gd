extends RefCounted
# Phone tests for Tanks of Freedom II, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check, rt.to_window).


static func phone(rt: Node, _menu: Node, name: String) -> void:
	var root: Window = rt.get_tree().root
	rt.check(name, "online and network buttons are hidden", not (_menu.find_child("online_button", true, false) as Control).visible and not (_menu.find_child("multiplayer_button", true, false) as Control).visible)
	var setup: Node = root.get_node("TofMatchSetup")
	setup.reset()
	setup.map_name = "2p_crossroad"
	setup.add_player("blue", 10, "human", true, 0)
	setup.add_player("red", 10, "ai", true, 1)
	root.get_node("TofSceneSwitcher").board()
	var board: Node = null
	for i in 120:
		await rt.frames(5)
		var cur: Node = rt.get_tree().current_scene
		if cur and cur.scene_file_path.ends_with("board/board.tscn") and cur.is_node_ready():
			board = cur
			break
	if not rt.check(name, "a skirmish starts", board != null):
		return
	await rt.frames(120)
	var cam: Node3D = board.get("map").camera
	var size: Vector2 = rt.get_viewport().get_visible_rect().size
	var p0: Vector3 = cam.global_position
	await rt.touch_swipe(size / 2, Vector2(-220, 0))
	await rt.frames(30)
	rt.check(name, "a drag moves the map (phone)", cam.global_position.distance_to(p0) > 0.5, "moved %.2f" % cam.global_position.distance_to(p0))
	# two fingers spreading apart zoom in
	var d0: float = cam.get("camera_distance")
	var a := size / 2 + Vector2(-40, 0)
	var b := size / 2 + Vector2(40, 0)
	for idx in [0, 1]:
		var e := InputEventScreenTouch.new()
		e.index = idx
		e.position = rt.to_window(a if idx == 0 else b)
		e.pressed = true
		Input.parse_input_event(e)
	await rt.frames(2)
	for i in 10:
		var d := InputEventScreenDrag.new()
		d.index = 1
		d.position = rt.to_window(b + Vector2(20 * (i + 1), 0))
		Input.parse_input_event(d)
		await rt.frames(2)
	for idx in [0, 1]:
		var e := InputEventScreenTouch.new()
		e.index = idx
		e.position = rt.to_window(a if idx == 0 else b)
		Input.parse_input_event(e)
	await rt.frames(10)
	rt.check(name, "pinching zooms the board (phone)", not is_equal_approx(float(cam.get("camera_distance")), d0), "%.1f -> %.1f" % [d0, cam.get("camera_distance")])
	var ov: TouchOverlay = board.find_children("*", "TouchOverlay", true, false)[0]
	rt.check(name, "the board has an X (cancel) button", ov.buttons.any(func(x): return x[2] == "X"))
	rt.check(name, "network play is switched off", root.get_node("TofMultiplayer").create_game("2p_crossroad") == ERR_UNAVAILABLE and root.get_node("TofRelay").create_game("x") == ERR_UNAVAILABLE)
