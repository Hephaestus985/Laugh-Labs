class_name TouchOverlay
extends CanvasLayer
# On-screen phone controls for games made by others, which were built for a
# keyboard or gamepad. It presses the game's own input actions, so the game
# code doesn't need to change. Also adds a "< MENU" button and the Android
# back button, both returning to the Lab Arcade launcher.
#
#   TouchOverlay.add_to(node, {
#       "stick": ["move_left", "move_right", "move_forward", "move_back"],  # optional
#       "buttons": [["JUMP", "jump"], ["FIRE", "fire"]],  # bottom right, first = biggest
#       "small": [["<", "camera_left"], [">", "camera_right"]],  # optional, above them
#       "small_left": true,  # optional: put the small buttons under "< MENU" instead
#       "dpad": ["left", "right", "up", "down"],  # optional: arrow buttons bottom left
#   })
# An action can also be a Callable, which is called once per tap.
# Games that read mouse clicks can ask TouchOverlay.covers(point) to ignore
# taps that landed on these controls.

const LAUNCHER := "res://menu.tscn"
const STICK_R := 110.0

var stick_actions: Array = []
var stick_idx := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var held := {}  # touch index -> action name
var buttons: Array = []  # [Rect2, action, label, is_small]
var draw_node: Control
static var current: TouchOverlay


## True when a point (in viewport coordinates) is on one of the overlay's controls.
static func covers(p: Vector2) -> bool:
	if not is_instance_valid(current) or not current.is_inside_tree():
		return false
	for b in current.buttons:
		if (b[0] as Rect2).grow(14 * current.k).has_point(p):
			return true
	return false


static func add_to(node: Node, config: Dictionary) -> TouchOverlay:
	var o := TouchOverlay.new()
	o.setup(config)
	node.add_child(o)
	return o


var config: Dictionary = {}
var laid_out_for := Vector2.ZERO
var k := 1.0  # size factor, see layout()


func setup(cfg: Dictionary) -> void:
	config = cfg
	# "help": the game's help.json -> a "?" button that opens it (and it opens by itself
	# the first time the game is played)
	if cfg.has("help"):
		var path: String = cfg["help"]
		var small: Array = cfg.get("small", []).duplicate()
		small.append(["?", func(): HelpPage.open(self, path)])
		config["small"] = small
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	stick_actions = config.get("stick", [])


## Place the buttons along the right and bottom edges of the visible screen.
## Sizes follow the game's design height (720 for the arcade, bigger for games made at 1080).
func layout(size: Vector2) -> void:
	laid_out_for = size
	# (tiny pixel-art canvases get proportionally smaller numbers, same size on screen)
	k = get_tree().root.content_scale_size.y / 720.0 if is_inside_tree() and get_tree().root.content_scale_size.y > 0 else 1.0
	buttons.clear()
	var x := size.x - 40.0 * k
	var big: Array = config.get("buttons", [])
	for i in big.size():
		var r := (92.0 if i == 0 else 72.0) * k
		var c := Vector2(x - r, size.y - 40.0 * k - r - (0.0 if i % 2 == 0 else 70.0 * k))
		buttons.append([Rect2(c - Vector2(r, r), Vector2(r, r) * 2), big[i][1], big[i][0], false])
		x -= r * 2 + 24.0 * k
	var small: Array = config.get("small", [])
	var sx := size.x - 40.0 * k
	for i in small.size():
		if config.get("small_left", false):
			buttons.append([Rect2(Vector2(12.0 + i * 96.0, 96.0) * k, Vector2(84.0, 72.0) * k), small[i][1], small[i][0], true])
		else:
			buttons.append([Rect2(Vector2(sx - 84.0 * k, 110.0 * k), Vector2(84.0, 72.0) * k), small[i][1], small[i][0], true])
		sx -= 96.0 * k
	var dpad: Array = config.get("dpad", [])
	if dpad.size() == 4:
		var c := Vector2(160.0, -160.0) * k + Vector2(0, size.y)
		var h := Vector2(42, 42) * k
		for d in [[Vector2(-80, 0), dpad[0], "<"], [Vector2(80, 0), dpad[1], ">"], [Vector2(0, -80), dpad[2], "^"], [Vector2(0, 80), dpad[3], "v"]]:
			buttons.append([Rect2(c + d[0] * k - h, h * 2), d[1], d[2], true])
	if not config.get("no_menu", false):  # games whose own menu leads back can drop it
		buttons.append([Rect2(Vector2(12, 12) * k, Vector2(150, 64) * k), "__menu", "< MENU", true])


func _ready() -> void:
	current = self
	if config.has("help"):
		HelpPage.open_first_time(self, str(config.get("help_id", config["help"])), config["help"])
	draw_node = Control.new()
	draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_node.draw.connect(_draw_controls)
	add_child(draw_node)
	layout(get_viewport().get_visible_rect().size)


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	if size != laid_out_for:
		layout(size)
	draw_node.queue_redraw()


func to_canvas(p: Vector2) -> Vector2:
	return p  # events in _input are already in screen-canvas coordinates


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var p := to_canvas(event.position)
		if event.pressed:
			for b in buttons:
				if (b[0] as Rect2).grow(14 * k).has_point(p):
					get_viewport().set_input_as_handled()
					if b[1] is Callable:
						(b[1] as Callable).call()
					elif b[1] == "__menu":
						back_to_launcher()
					else:
						held[event.index] = b[1]
						Input.action_press(b[1])
					return
			if stick_actions.size() == 4 and p.x < laid_out_for.x * 0.45 and p.y > 120 and stick_idx == -1:
				stick_idx = event.index
				stick_origin = p
				stick_vec = Vector2.ZERO
				get_viewport().set_input_as_handled()
		else:
			if held.has(event.index):
				Input.action_release(held[event.index])
				held.erase(event.index)
				get_viewport().set_input_as_handled()
			if event.index == stick_idx:
				stick_idx = -1
				stick_vec = Vector2.ZERO
				apply_stick()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == stick_idx:
		stick_vec = (to_canvas(event.position) - stick_origin).limit_length(STICK_R) / STICK_R
		apply_stick()
		get_viewport().set_input_as_handled()


func apply_stick() -> void:
	var a := stick_actions
	_axis(a[0], a[1], stick_vec.x)
	_axis(a[2], a[3], stick_vec.y)


func _axis(neg: String, pos: String, v: float) -> void:
	if v < -0.15:
		Input.action_press(neg, minf(1.0, -v))
		Input.action_release(pos)
	elif v > 0.15:
		Input.action_press(pos, minf(1.0, v))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func back_to_launcher() -> void:
	if config.get("on_exit") is Callable:
		(config["on_exit"] as Callable).call()
	for idx in held:
		Input.action_release(held[idx])
	held.clear()
	if stick_actions.size() == 4:
		stick_vec = Vector2.ZERO
		apply_stick()
	get_tree().paused = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	# deferred: the game may still be in the middle of handling this input event
	get_tree().change_scene_to_file.call_deferred(GameData.back_scene())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not HelpPage.is_open():
		# a game may handle back itself first (close a pop-up): "on_back" returns true then
		if config.get("on_back") is Callable and (config["on_back"] as Callable).call():
			return
		back_to_launcher()


func _exit_tree() -> void:
	for idx in held:
		Input.action_release(held[idx])


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	if stick_actions.size() == 4:
		if stick_idx != -1:
			draw_node.draw_circle(stick_origin, STICK_R, Color(1, 1, 1, 0.15))
			draw_node.draw_arc(stick_origin, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
			draw_node.draw_circle(stick_origin + stick_vec * STICK_R, 44, Color(1, 1, 1, 0.5))
		else:
			draw_node.draw_string(font, Vector2(40, laid_out_for.y - 30), "drag here to move", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
	for b in buttons:
		var r: Rect2 = b[0]
		var down: bool = b[1] is String and held.values().has(b[1])
		var col := Color(0, 0, 0, 0.45 if down else 0.3)
		if b[3]:
			draw_node.draw_rect(r, col)
			draw_node.draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
		else:
			draw_node.draw_circle(r.get_center(), r.size.x / 2, col)
			draw_node.draw_arc(r.get_center(), r.size.x / 2, 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
		draw_node.draw_string(font, Vector2(r.position.x, r.get_center().y + 9 * k), b[2], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(26 * k), Color(1, 1, 1, 0.9))
