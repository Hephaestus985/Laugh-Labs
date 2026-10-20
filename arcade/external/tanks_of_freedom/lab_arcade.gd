class_name TofArcade
extends RefCounted
## [Lab Arcade] Tanks of Freedom II was made as its own app (1280x800 screen, physics at
## 144 steps a second, its own texts and always-loaded helpers). Its screens call setup()
## for that, plus the phone buttons; leave() puts things back on the way to the arcade,
## and park() keeps its helpers asleep in the launcher and other games.

const LISTENERS := ["TofGamepadAdapter", "TofRelay", "TofAutodiscovery", "TofSimpleAudioLibrary"]
const TRANSLATIONS := ["common.en.en", "core.en.en", "common.pl.pl", "core.pl.pl"]

static var _texts_added := false


static func park(tree: SceneTree) -> void:
	_set_awake(tree, false)


static func _set_awake(tree: SceneTree, awake: bool) -> void:
	for n in LISTENERS:
		var node := tree.root.get_node_or_null(n)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	var audio := tree.root.get_node_or_null("TofSimpleAudioLibrary")
	if audio and not awake:
		audio.stop()
		audio.master_switch = false


## Board and map editor: in_match adds the cancel button and two-finger zoom.
static func setup(scene: Node, in_match := false) -> void:
	var tree := scene.get_tree()
	var win := tree.root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	win.content_scale_size = Vector2i(1280, 800)
	Engine.physics_ticks_per_second = 144
	if not _texts_added:
		_texts_added = true
		for t in TRANSLATIONS:
			var tr = load("res://external/tanks_of_freedom/assets/translations/%s.translation" % t)
			if tr:
				TranslationServer.add_translation(tr)
	_set_awake(tree, true)
	tree.root.get_node("TofSimpleAudioLibrary").lab_load()
	var cfg := {"on_exit": leave.bind(tree)}
	if in_match:
		# its own menu leads back (and "< MENU" would cover its panels); X cancels a selection
		cfg["no_menu"] = true
		cfg["small"] = [["X", _cancel]]
		var pinch := preload("res://external/tanks_of_freedom/lab_arcade_pinch.gd").new()
		scene.add_child(pinch)
	TouchOverlay.add_to(scene, cfg)


static func back_to_arcade(tree: SceneTree) -> void:
	if is_instance_valid(TouchOverlay.current) and TouchOverlay.current.is_inside_tree():
		TouchOverlay.current.back_to_launcher()
	else:
		leave(tree)
		tree.change_scene_to_file.call_deferred(GameData.back_scene())


static func leave(tree: SceneTree) -> void:
	tree.paused = false
	Engine.physics_ticks_per_second = 60
	var mouse_layer := tree.root.get_node_or_null("TofMouseLayer")
	if mouse_layer:
		mouse_layer.detach()
	_set_awake(tree, false)


## The game cancels a selection on a right click or the controller's B (ui_cancel),
## read from input events, so send a real press and release.
static func _cancel() -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = "ui_cancel"
		e.pressed = down
		Input.parse_input_event(e)
