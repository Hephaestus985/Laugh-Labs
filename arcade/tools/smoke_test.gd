extends Node
# Dev tool: plays every game version for a while with random input and
# saves screenshots. Run:  godot --path . res://tools/smoke_test.tscn -- <out_dir> [game_id]
const Games := preload("res://games.gd")
var queue: Array = []
var cur: Node = null
var frame := 0
var out_dir := ""
const FRAMES := 900
var keys := [KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT]
var held := {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://smoke"
	var only: String = args[1] if args.size() > 1 else ""
	for g in Games.LIST:
		if only != "" and g["id"] != only:
			continue
		for v in g["versions"]:
			queue.append([g["id"], v["v"], v["scene"]])
	next_game()

func next_game() -> void:
	if cur:
		cur.queue_free()
		cur = null
	for k in held.keys():
		send(k, false)
	held.clear()
	if queue.is_empty():
		print("SMOKE DONE")
		get_tree().quit()
		return
	var item: Array = queue.pop_front()
	print("SMOKE ", item[0], " v", item[1])
	cur = load(item[2]).instantiate()
	cur.set_meta("smoke_name", "%s_v%d" % [item[0], item[1]])
	add_child(cur)
	frame = 0
	if cur.get_script() == null:
		print("SMOKE FAIL: no script on ", item[2])

func send(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	if down:
		held[k] = true

func _process(_d: float) -> void:
	if cur == null:
		return
	frame += 1
	if frame % 6 == 0:
		var k: int = keys[randi() % keys.size()]
		if held.has(k):
			held.erase(k)
			send(k, false)
		else:
			send(k, true)
	if frame % 45 == 0:
		send(KEY_SPACE, true)
	if frame % 45 == 3:
		send(KEY_SPACE, false)
		held.erase(KEY_SPACE)
	if frame in [60, 400, 850] and DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%d.png" % [out_dir, cur.get_meta("smoke_name"), frame])
	if frame >= FRAMES:
		next_game()
