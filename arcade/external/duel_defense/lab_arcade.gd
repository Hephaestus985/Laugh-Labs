class_name DdArcade
extends RefCounted
## [Lab Arcade] Duel Defense was made as its own app for a 1920x1080 screen, with its own
## theme and global helpers (autoloads). While it runs it gets that screen size, theme
## and background colour; outside it, its helpers that listen to every key press
## (developer console, debug overlay, controller icons) sleep. The launcher calls park().

const THEME := preload("res://external/duel_defense/Resources/Themes/MainTheme.tres")
const CLEAR_COLOR := Color(0.0666667, 0.341176, 0.25098, 1)
const LISTENERS := ["DdConsole", "DdDebugMenu", "DdControllerIcons"]

static var _old_clear := Color(0.3, 0.3, 0.3)


static func park(tree: SceneTree) -> void:
	_set_awake(tree, false)


static func _set_awake(tree: SceneTree, awake: bool) -> void:
	for n in LISTENERS:
		var node := tree.root.get_node_or_null(n)
		if node:
			node.process_mode = Node.PROCESS_MODE_ALWAYS if awake else Node.PROCESS_MODE_DISABLED
	var console := tree.root.get_node_or_null("DdConsole")
	if console and not awake and console.get("control"):
		console.control.visible = false
	var debug := tree.root.get_node_or_null("DdDebugMenu")
	if debug and not awake:
		debug.visible = false


static func setup(scene: Node) -> void:
	var tree := scene.get_tree()
	var win := tree.root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(1920, 1080)
	_old_clear = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(CLEAR_COLOR)
	_set_awake(tree, true)
	# its sound settings use its own mixer channels (buses); add those that are missing
	for bus in ["BackgroundMusic", "InterfaceEffects", "SoundEffects", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# its theme was the project theme; a window theme doesn't reach controls under a
	# CanvasLayer, so each top control gets it
	for c in scene.find_children("*", "Control", true, false):
		_themed(c)
	if not tree.node_added.is_connected(_themed):
		tree.node_added.connect(_themed)
	# the game has its own menu (and pause); this adds the phone's back button
	TouchOverlay.add_to(scene, {"no_menu": true, "on_exit": leave.bind(tree)})


static func _themed(n: Node) -> void:
	if n is Control and not n.get_parent() is Control and (n as Control).theme == null:
		(n as Control).theme = THEME


static func back_to_arcade(tree: SceneTree) -> void:
	if is_instance_valid(TouchOverlay.current) and TouchOverlay.current.is_inside_tree():
		TouchOverlay.current.back_to_launcher()
	else:
		leave(tree)
		tree.change_scene_to_file.call_deferred(GameData.back_scene())


static func leave(tree: SceneTree) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
	if tree.node_added.is_connected(_themed):
		tree.node_added.disconnect(_themed)
	RenderingServer.set_default_clear_color(_old_clear)
	var sm := tree.root.get_node_or_null("DdSoundManager")
	if sm:
		sm.stop_music()
	_set_awake(tree, false)
