extends Node
# Takes a title and a gameplay screenshot of every game (for tools/covers/make_covers.py).
# Needs a real window: godot --path arcade --position 6000,6000 --resolution 1280x720
#   --audio-driver Dummy res://tools/covers/capture.tscn -- <out_dir>
const Games := preload("res://games.gd")
func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
func tap(p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.position = get_tree().root.get_screen_transform() * p
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var r := InputEventScreenTouch.new()
	r.position = e.position
	Input.parse_input_event(r)
func snap(path: String) -> void:
	get_viewport().get_texture().get_image().save_jpg(path, 0.9)
func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	load("res://external/open_rpg/lab_arcade_park.gd").park(get_tree())
	var out: String = OS.get_cmdline_user_args()[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	await frames(3)
	for g in Games.LIST + Games.EXTERNAL:
		var id: String = g["id"]
		var vs: Array = g["versions"]
		var scene: String = vs[vs.size() - 1]["scene"]
		Engine.set_meta("launch_mode", "new")
		var n: Node = load(scene).instantiate()
		get_tree().root.add_child(n)
		get_tree().current_scene = n
		await frames(40)
		snap("%s/%s_title.jpg" % [out, id])
		if n is PuzzleGame:
			if n.state == 0:
				n.start_new()
			await frames(5)
			for k in 14:
				n.game_swipe([Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.UP][k % 4])
				n.game_tap(n.board_rect.position + Vector2(rng.randf(), rng.randf()) * n.board_rect.size)
				await frames(6)
			await frames(30)
		elif not Games.EXTERNAL.has(g):
			await tap(Vector2(640, 360))
			await frames(10)
			# play a few seconds: run right, jump now and then
			for f in 200:
				if f % 25 == 0:
					key(KEY_RIGHT, true)
				if f % 40 == 10:
					key(KEY_SPACE, true)
				if f % 40 == 14:
					key(KEY_SPACE, false)
				await get_tree().process_frame
				if not is_instance_valid(n):
					break
			key(KEY_RIGHT, false)
		else:
			await frames(120)
		snap("%s/%s_play.jpg" % [out, id])
		var cur := get_tree().current_scene
		if is_instance_valid(cur):
			cur.queue_free()
		get_tree().current_scene = self
		get_tree().paused = false
		load("res://external/open_rpg/lab_arcade_park.gd").park(get_tree())
		get_window().content_scale_size = Vector2i(1280, 720)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		await frames(3)
	for g in Games.LIST:
		DirAccess.remove_absolute("user://%s_save.json" % g["id"])
	get_tree().quit()
