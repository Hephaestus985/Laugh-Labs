extends RefCounted
# Phone tests for Open RTS, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check).


static func phone(rt: Node, play: Node, name: String) -> void:
	var start: Button = play.find_child("StartButton", true, false)
	await rt.tap(start.get_global_rect().get_center())
	var m: Node = null
	for i in 120:
		await rt.frames(5)
		var cur: Node = rt.get_tree().current_scene
		if cur and cur.scene_file_path.ends_with("match/Match.tscn") and cur.is_node_ready():
			m = cur
			break
	if not rt.check(name, "Start begins a match (phone)", m != null):
		return
	await rt.frames(60)
	var cam: Camera3D = m.find_child("IsometricCamera3D", true, false)
	var size: Vector2 = rt.get_viewport().get_visible_rect().size
	# one finger drag moves the camera; a finger resting near the edge doesn't scroll
	var p0 := cam.global_position
	await rt.touch_swipe(size / 2, Vector2(-200, 0))
	await rt.frames(5)
	rt.check(name, "a drag moves the camera (phone)", cam.global_position.distance_to(p0) > 1.0)
	var p1 := cam.global_position
	await rt.tap(Vector2(size.x - 2, size.y / 2))
	await rt.frames(30)
	rt.check(name, "a tap at the screen edge doesn't scroll forever", cam.global_position.distance_to(p1) < 0.5)
	cam.global_position = p0
	await rt.frames(5)
	# tap a worker: it is selected; tap the ground: it walks there
	var workers: Array = rt.get_tree().get_nodes_in_group("controlled_units").filter(func(u): return u.scene_file_path.ends_with("Worker.tscn"))
	if not rt.check(name, "the player has workers", not workers.is_empty()):
		return
	var w: Node3D = workers[0]
	await rt.tap(cam.unproject_position(w.global_position + Vector3(0, 0.3, 0)))
	await rt.frames(5)
	rt.check(name, "a tap on a unit selects it (phone)", w.is_in_group("selected_units"))
	var target := w.global_position + Vector3(3, 0, 3)
	await rt.tap(cam.unproject_position(target))
	await rt.frames(5)
	rt.check(name, "a tap on the ground sends the selected unit there (phone)", w.get("action") != null, str(w.get("action")))
	var ov: TouchOverlay = m.find_children("*", "TouchOverlay", true, false)[0]
	var btn := func(label): return (ov.buttons.filter(func(b): return b[2] == label)[0][0] as Rect2).get_center()
	await rt.tap(btn.call("NONE"))
	await rt.frames(3)
	rt.check(name, "NONE clears the selection", rt.get_tree().get_nodes_in_group("selected_units").is_empty())
	await rt.tap(btn.call("ALL"))
	await rt.frames(3)
	rt.check(name, "ALL selects the army on screen", rt.get_tree().get_nodes_in_group("selected_units").size() >= 1)
	await rt.tap(btn.call("II"))
	await rt.frames(3)
	rt.check(name, "II opens the match menu (phone)", rt.get_tree().paused)
	rt.get_tree().paused = false
	var menu: Node = m.find_child("Menu", true, false)
	if menu:
		menu.hide()
