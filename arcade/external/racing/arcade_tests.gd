extends RefCounted
# Phone tests for Kenney Racing, used by tools/tests/run_tests.gd (phone_checks).
# rt is the test runner (rt.tap, rt.frames, rt.check). Version 1.0 (free drive) has no race.


static func phone(rt: Node, race: Node, name: String) -> void:
	if not race.has_method("start_race"):
		return
	await rt.frames(5)
	if HelpPage.is_open():
		HelpPage.close_current()
		await rt.frames(2)
	# every track is a closed loop of pieces, with the finish at the start
	for i in race.TRACKS.size():
		race.build_track(i)
		var cells: int = race.grid.get_used_cells().size()
		rt.check(name, "track %s is built (%d cells)" % [race.TRACKS[i]["name"], race.path.size()], race.path.size() > 10 and cells > race.path.size() and race.grid.get_cell_item(Vector3i.ZERO) == race._item_id("track-finish"))
	race.show_menu()
	await rt.frames(3)
	# by touch: tap Race on the first track
	var b: Button = race.menu.find_child("Race_oval", true, false)
	await rt.tap(b.get_global_rect().get_center())
	await rt.frames(3)
	rt.check(name, "tapping a track starts the countdown (phone)", race.state == "countdown" and race.info.size() == 4)
	for i in 30:
		if race.state == "race":
			break
		await rt.frames(10)
	rt.check(name, "GO after the countdown", race.state == "race")
	# the computer drivers drive round the track
	var rival: Vehicle = race.cars[1]
	var start_idx: int = race.info[rival]["idx"]
	await rt.frames(360)
	var it: Dictionary = race.info[rival]
	rt.check(name, "computer drivers go round the track", it["laps"] >= 1 and it["idx"] != start_idx, "laps %d idx %d" % [it["laps"], it["idx"]])
	# items: a banana spins a car out, a mushroom boosts
	race.info[race.player]["item"] = "mushroom"
	race.use_player_item()
	rt.check(name, "ITEM with a mushroom boosts", race.player.boost > 0.0)
	race._spin(rival)
	rt.check(name, "a hit spins a driver out", race.info[rival]["spin"] > 0.0 and not rival.controls_on)
	# finishing: put the player on the last lap just before the line
	var p: Dictionary = race.info[race.player]
	p["laps"] = race.LAPS
	p["idx"] = race.path.size() - 1
	race.place(race.player, race.centers[0], 0.0)
	await rt.frames(4)
	rt.check(name, "crossing the line on the last lap finishes the race", race.state == "finished" and race.finish_panel.visible)
	var best: Dictionary = race._load_best("oval")
	rt.check(name, "the best time is saved", best.has("time") and best["ghost"] is Array)
	# time trial: alone with the ghost of the best time
	var again: Button = race.finish_panel.find_child("Tracks", true, false)
	await rt.tap(again.get_global_rect().get_center())
	await rt.frames(3)
	await rt.tap(race.menu.find_child("Trial_oval", true, false).get_global_rect().get_center())
	await rt.frames(3)
	rt.check(name, "time trial: you race alone", race.mode == "trial" and race.info.size() == 1 and not race.cars[1].visible)
	rt.check(name, "time trial: the ghost of your best time is there", race.ghost != null)
	# II pauses, Tracks leaves
	race.toggle_pause()
	await rt.frames(3)
	rt.check(name, "II pauses the race", rt.get_tree().paused)
	await rt.tap(race.finish_panel.find_child("Tracks", true, false).get_global_rect().get_center())
	await rt.frames(3)
	rt.check(name, "Tracks goes back to the track list", race.state == "menu" and not rt.get_tree().paused, "%s paused %s at %s" % [race.state, rt.get_tree().paused, race.finish_panel.find_child("Tracks", true, false).get_global_rect() if race.finish_panel.find_child("Tracks", true, false) else null])
	DirAccess.remove_absolute("user://racing/oval.json")
