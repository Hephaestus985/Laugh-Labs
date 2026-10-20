extends RefCounted
# Phone tests for Duel Defense, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.touch_swipe, rt.frames, rt.check).


static func phone(rt: Node, handler: Node, name: String) -> void:
	await rt.frames(10)
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
	rt.check(name, "the mod system is gone", handler.get_node_or_null("Mods") == null and not ResourceLoader.exists("res://external/duel_defense/CommonScripts/ModManager.gd"))
