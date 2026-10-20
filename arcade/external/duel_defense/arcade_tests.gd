extends RefCounted
# Phone tests for Duel Defense, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check).


static func phone(rt: Node, handler: Node, name: String) -> void:
	await rt.frames(10)
	# by touch: Level select opens a big pop-up, the back button closes it, a level starts
	var ls_btn: Button = handler.get_node("MainMenu/Container/VBoxContainer/NewGame")
	await rt.tap(ls_btn.get_global_rect().get_center())
	await rt.frames(6)
	var popup: Window = handler.get("level_select")
	var view: Vector2 = rt.get_viewport().get_visible_rect().size
	rt.check(name, "Level select opens a phone-sized pop-up (phone)", popup.visible and popup.size.x > view.x * 0.7, "%s in %s" % [popup.size, view])
	rt.get_tree().root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await rt.frames(6)
	rt.check(name, "the back button closes a pop-up and stays in the game", not popup.visible and rt.get_tree().current_scene == handler)
	await rt.tap(ls_btn.get_global_rect().get_center())
	await rt.frames(6)
	var first: Button = popup.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())[0]
	# the pop-up's contents are scaled up, and it sits at its position on the screen
	var r: Rect2 = first.get_global_rect()
	await rt.tap(Vector2(popup.position) + r.get_center() * popup.content_scale_factor)
	await rt.frames(10)
	var started := false
	for i in 40:
		var gs: Node = handler.get_node_or_null("GameScene")
		if gs and not gs.get("main_menu_mode"):
			started = true
			break
		await rt.frames(5)
	rt.check(name, "tapping a level starts it (phone)", started)
	rt.check(name, "the menu has How to play and Back to Arcade", handler.get_node("MainMenu/Container/VBoxContainer/HowToPlay") != null and handler.get_node("MainMenu/Container/VBoxContainer/Quit").text == "Back to Arcade")
	if not started:
		handler.call("on_load_map", "Map1")
	var game: Node = null
	for i in 60:
		await rt.frames(5)
		game = handler.get_node_or_null("GameScene")
		if game and not game.get("main_menu_mode") and game.get("current_money") != null:
			break
	if not rt.check(name, "a map loads", game != null and not game.get("main_menu_mode")):
		return
	await rt.frames(20)
	var money0: int = int(game.get("current_money"))
	# tap the cheapest turret in the bar, then drag it to a spot on the grass and lift
	var bar: Node = handler.find_child("BuildBar", true, false)
	var buttons: Array = bar.find_children("*", "BaseButton", true, false).filter(func(b): return b.is_visible_in_tree())
	if not rt.check(name, "the turret bar has buttons", not buttons.is_empty()):
		return
	await rt.tap((buttons[0] as Control).get_global_rect().get_center())
	await rt.frames(5)
	rt.check(name, "a tap on a turret starts placing it (phone)", game.get("build_mode") == true)
	# a free square next to the road, away from the screen edges
	var excl: TileMap = game.get("map_node").get_node("TowerExclusion")
	var ground: TileMap = game.get("map_node").get_node("Ground")
	var spot := Vector2.ZERO
	for x in range(4, 12):
		for y in range(3, 7):
			var c := Vector2i(x, y)
			if spot == Vector2.ZERO and excl.get_cell_source_id(0, c) == -1 and ground.get_cell_source_id(1, c) == -1:
				spot = excl.get_global_transform_with_canvas() * excl.map_to_local(c)
	await rt.touch_swipe(spot + Vector2(-60, 0), Vector2(60, 0))
	await rt.frames(10)
	rt.check(name, "lifting the finger on the grass builds it (phone)", int(game.get("current_money")) < money0, "money %d -> %d, mode %s valid %s at %s" % [money0, int(game.get("current_money")), game.get("build_mode"), game.get("build_valid"), game.get("build_location")])
	var turrets: Array = game.get("map_node").get_node("Turrets").get_children()
	if not turrets.is_empty():
		await rt.tap((turrets[0] as Node2D).get_global_transform_with_canvas().origin)
		await rt.frames(5)
		rt.check(name, "a tap on a turret opens its upgrades (phone)", game.get("upgrade_mode") == true)
	# the shop is a column beside the map, and the map keeps its shape
	var view_w: float = rt.get_viewport().get_visible_rect().size.x
	var cam: Camera2D = game.get_node("Camera")
	rt.check(name, "the turret shop is a column on the right, beside the map (phone)", (bar as Control).get_global_rect().position.x > view_w * 0.6 and cam.zoom.x == cam.zoom.y, "shop at x %.0f of %.0f, zoom %s" % [(bar as Control).get_global_rect().position.x, view_w, cam.zoom])
	rt.check(name, "the mod system is gone", handler.get_node_or_null("Mods") == null and not ResourceLoader.exists("res://external/duel_defense/CommonScripts/ModManager.gd"))

