class_name RtsArcade
extends RefCounted
## [Lab Arcade] Open RTS was made as its own app for a 1920x1080 screen. Its menus and
## matches call setup() for that screen size, the game's texts (translations) and the
## phone buttons; leave() tidies up on the way back to the arcade. The launcher and
## start screens put the normal screen back (GameData.reset_window).

const TRANSLATIONS := ["match.en", "main_menu.en"]

static var _texts_added := false


static func setup(scene: Node, with_overlay := true) -> void:
	var win := scene.get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(1920, 1080)
	if not _texts_added:
		_texts_added = true
		for t in TRANSLATIONS:
			var tr = load("res://external/open_rts/assets/translations/%s.translation" % t)
			if tr:
				TranslationServer.add_translation(tr)
	if with_overlay:
		TouchOverlay.add_to(scene, {"on_exit": leave.bind(scene.get_tree())})


static func back_to_arcade(tree: SceneTree) -> void:
	if is_instance_valid(TouchOverlay.current) and TouchOverlay.current.is_inside_tree():
		TouchOverlay.current.back_to_launcher()
	else:
		leave(tree)
		tree.change_scene_to_file.call_deferred(GameData.back_scene())


static func leave(tree: SceneTree) -> void:
	tree.paused = false
	Engine.time_scale = 1.0
