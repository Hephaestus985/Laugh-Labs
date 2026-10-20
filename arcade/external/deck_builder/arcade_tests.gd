extends RefCounted
# Phone tests for Deck Crawler, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check).


static func _screen(n: Node) -> Vector2:
	return (n as CanvasItem).get_global_transform_with_canvas().origin


static func phone(rt: Node, run: Node, name: String) -> void:
	var map: Node = run.find_child("Map", true, false)
	var cam: Camera2D = map.find_child("Camera2D", true, false)
	await rt.frames(5)
	# drag the map
	var y0 := cam.position.y
	var mid: Vector2 = rt.get_viewport().get_visible_rect().size / 2
	var lit: Array = map.find_children("*", "Area2D", true, false).filter(func(r): return r.get("available"))
	var start: Vector2 = _screen(lit[0]) if not lit.is_empty() else mid
	await rt.touch_swipe(start, Vector2(0, 60))
	await rt.frames(2)
	rt.check(name, "a drag scrolls the map (phone)", absf(cam.position.y - y0) > 5.0, "moved %d" % (cam.position.y - y0))
	rt.check(name, "a drag that starts on a room doesn't enter it", run.find_child("Battle", true, false) == null and map.find_children("*", "Area2D", true, false).any(func(r): return r.get("available")))
	cam.position.y = y0
	await rt.frames(2)
	# tap a lit room on the first floor
	for i in 30:
		if map.find_children("*", "Area2D", true, false).any(func(r): return r.get("available")):
			break
		await rt.frames(5)
	var rooms: Array = map.find_children("*", "Area2D", true, false).filter(func(r): return r.get("available"))
	var all_rooms: Array = map.find_children("*", "Area2D", true, false)
	if not rt.check(name, "the map shows rooms to pick", rooms.size() > 0, "%d rooms, type %s, map %s" % [all_rooms.size(), str(run.get("run_startup").type), str(map.get("map_data").size())]):
		return
	await rt.tap(_screen(rooms[0]))
	await rt.frames(90)
	var battle: Node = run.find_child("Battle", true, false)
	if not rt.check(name, "a tap on a room starts the battle (phone)", battle != null):
		return
	await rt.frames(120)
	# drag the first playable card onto an enemy (or up onto the battlefield)
	var hand: Node = battle.find_child("Hand", true, false)
	var enemies: Array = battle.find_child("EnemyHandler", true, false).get_children()
	var mana_ui: Node = battle.find_child("ManaUI", true, false)
	var stats = battle.get("char_stats")
	var mana0: int = stats.mana if stats else -1
	var played := false
	for card in hand.get_children():
		if not card.visible:
			continue
		var from: Vector2 = (card as Control).get_global_rect().get_center()
		var to: Vector2 = _screen(enemies[0]) if card.card.is_single_targeted() else from + Vector2(0, -70)
		await _drag(rt, from, to)
		await rt.frames(60)
		if stats and stats.mana < mana0:
			played = true
			break
	rt.check(name, "dragging a card onto an enemy plays it (phone)", played, "mana %d -> %d" % [mana0, stats.mana if stats else -1])
	var ov: TouchOverlay = run.find_children("*", "TouchOverlay", true, false)[0]
	var pause_btn: Array = ov.buttons.filter(func(x): return x[2] == "II")
	await rt.tap((pause_btn[0][0] as Rect2).get_center())
	await rt.frames(3)
	rt.check(name, "II pauses the run (phone)", rt.get_tree().paused and (run.find_child("PauseMenu", true, false) as CanvasLayer).visible)
	(run.find_child("PauseMenu", true, false)).call("_unpause")
	await rt.frames(2)
	rt.check(name, "the run saves", FileAccess.file_exists("user://deck_builder_save.tres") and SafeResource.is_safe("user://deck_builder_save.tres", "res://external/deck_builder/"))
	# a doctored save with code in it is not loaded
	var good := FileAccess.get_file_as_string("user://deck_builder_save.tres")
	var f := FileAccess.open("user://deck_builder_save.tres", FileAccess.WRITE)
	f.store_string(good.replace("[resource]", '[sub_resource type="GDScript" id="x"]\nscript/source = "extends Resource"\n\n[resource]'))
	f = null
	rt.check(name, "a save with code in it is refused", DkSaveGame.load_data() == null)
	DkSaveGame.delete_data()


## A finger drag in small steps (the game follows the emulated mouse).
static func _drag(rt: Node, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.position = rt.to_window(from)
	e.pressed = true
	Input.parse_input_event(e)
	await rt.frames(3)
	var last := from
	for i in 20:
		var p := from.lerp(to, (i + 1) / 20.0)
		var d := InputEventScreenDrag.new()
		d.position = rt.to_window(p)
		d.relative = rt.to_window(p) - rt.to_window(last)
		Input.parse_input_event(d)
		last = p
		await rt.frames(2)
	await rt.frames(10)
	var r := InputEventScreenTouch.new()
	r.position = rt.to_window(to)
	Input.parse_input_event(r)
	await rt.frames(3)
