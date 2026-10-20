class_name DkArcade
extends RefCounted
## [Lab Arcade] The deckbuilder was made as its own app with a tiny 256x144 pixel-art
## screen. Each of its screens calls setup() to get that screen size, sharp pixels,
## the phone buttons ("< MENU", and II to pause during a run) and the back button.
## The launcher and start screens put the normal screen back (GameData.reset_window).

const SIZE := Vector2i(256, 144)
const THEME := preload("res://external/deck_builder/main_theme.tres")


static func setup(scene: Node, pause := false) -> void:
	var win := scene.get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = SIZE
	win.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# The game's pixel font and button styles were its project theme. A theme on the
	# window doesn't reach controls under a CanvasLayer, so each top control gets it.
	for c in scene.find_children("*", "Control", true, false):
		_themed(c)
	if not scene.get_tree().node_added.is_connected(_themed):
		scene.get_tree().node_added.connect(_themed)
	var cfg := {"on_exit": _leave.bind(scene.get_tree()),
		"help": "res://external/deck_builder/lab_arcade_help.json", "help_id": "deck_builder"}  # "?": how to play
	if pause:
		# during a run "< MENU" would cover the health; II opens the pause menu,
		# whose "Save and quit" leads to the main menu and its Exit to the arcade
		cfg["small"] = [["II", _press.bind("deck_pause")]]
		cfg["no_menu"] = true
	TouchOverlay.add_to(scene, cfg)


static func back_to_arcade(tree: SceneTree) -> void:
	if is_instance_valid(TouchOverlay.current) and TouchOverlay.current.is_inside_tree():
		TouchOverlay.current.back_to_launcher()
	else:
		_leave(tree)
		tree.change_scene_to_file.call_deferred(GameData.back_scene())


static func _themed(n: Node) -> void:
	if n is Control and not n.get_parent() is Control and (n as Control).theme == null:
		(n as Control).theme = THEME


static func _leave(tree: SceneTree) -> void:
	tree.paused = false
	if tree.node_added.is_connected(_themed):
		tree.node_added.disconnect(_themed)
	for n in ["DkMusicPlayer", "DkSFXPlayer"]:
		var p := tree.root.get_node_or_null(n)
		if p:
			p.stop()


## The pause menu reads the key from input events, so send a real press and release.
static func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)
