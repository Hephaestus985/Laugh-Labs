extends RefCounted
# Phone tests for City Builder, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check).


static func phone(rt: Node, map: Node, name: String) -> void:
	var b: Node = map.find_child("Builder", true, false)
	var view: Node3D = map.find_child("View", true, false)
	var grid: GridMap = b.get("gridmap")
	var size: Vector2 = rt.get_viewport().get_visible_rect().size
	var spot := size / 2 + Vector2(80, 60)
	b.new_city()
	b.new_city()  # the second tap really clears it
	await rt.frames(2)
	var cash0: int = b.get("map").cash
	await rt.tap(spot)
	await rt.frames(3)
	rt.check(name, "a tap builds on that square (phone)", grid.get_used_cells().size() == 1 and b.get("map").cash < cash0)
	var before: Vector3 = view.get("camera_position")
	await rt.touch_swipe(spot, Vector2(-200, 0))
	await rt.frames(3)
	rt.check(name, "a drag moves the view, not builds (phone)", (view.get("camera_position") as Vector3).distance_to(before) > 1.0 and grid.get_used_cells().size() == 1)
	view.set("camera_position", before)
	view.position = before
	await rt.frames(2)
	var ov: TouchOverlay = map.find_children("*", "TouchOverlay", true, false)[0]
	var nxt: Array = ov.buttons.filter(func(x): return x[2] == ">")
	var idx0: int = b.get("index")
	await rt.tap((nxt[0][0] as Rect2).get_center())
	await rt.frames(2)
	rt.check(name, "> picks the next piece (phone)", b.get("index") == idx0 + 1)
	rt.check(name, "the city saves itself", FileAccess.file_exists("user://city_builder.json"))
	b.load_city()
	rt.check(name, "the saved city comes back", grid.get_used_cells().size() == 1)
	var cell: Vector3i = grid.get_used_cells()[0]
	b.toggle_remove()
	b.action_demolish(Vector3(cell))
	await rt.frames(2)
	rt.check(name, "DEL mode removes a piece", grid.get_used_cells().is_empty())
	b.toggle_remove()
	DirAccess.remove_absolute("user://city_builder.json")
