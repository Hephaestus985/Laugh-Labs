extends Node
## [Lab Arcade] Starts OpenRPG inside the arcade. OpenRPG was made as its own app, so this sets its
## screen size, theme and pixel-art filter while it runs, gives it a fresh start each time, adds the
## phone buttons, and puts its always-loaded helpers (autoloads) to sleep again on the way out.

const GAME := preload("res://external/open_rpg/src/main.tscn")
const THEME := preload("res://external/open_rpg/assets/gui/default.theme")
const Park := preload("res://external/open_rpg/lab_arcade_park.gd")

var _saved := {}


## Called by the launcher: see lab_arcade_park.gd (kept separate so the launcher
## doesn't need this game's files).
static func park(tree: SceneTree) -> void:
	Park.park(tree)


static func _set_awake(tree: SceneTree, awake: bool) -> void:
	Park.set_awake(tree, awake)


func _enter_tree() -> void:
	var root := get_tree().root
	_saved = {"size": root.content_scale_size, "theme": root.theme,
		"filter": root.canvas_item_default_texture_filter}
	root.content_scale_size = Vector2i(1920, 1080)
	root.theme = THEME
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_set_awake(get_tree(), true)
	# a fresh game every time (the helpers keep their state between visits)
	Cutscene._is_cutscene_in_progress = false
	WandPedestalInteraction._correct_pedestals.clear()
	GamepieceRegistry._gamepieces.clear()
	Gameboard.properties = null
	Gameboard.pathfinder.clear()
	Player.gamepiece = null
	Dialogic.clear()
	Transition.clear()
	var inventory := Inventory.restore()
	for item in inventory._items:
		inventory._items[item] = 0
	inventory.save()


func _ready() -> void:
	add_child(GAME.instantiate())
	TouchOverlay.add_to(self, {"small": [["BACK", _press.bind("orpg_back")]]})


## The game reads "back" from input events, so send a real press and release.
func _press(action: String) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)


func _exit_tree() -> void:
	if Dialogic.current_timeline:
		Dialogic.end_timeline(true)
	Camera.gamepiece = null
	var track := Music.get_node("AudioStreamPlayer") as AudioStreamPlayer
	track.stop()
	track.stream = null
	Transition.clear()
	Cutscene._is_cutscene_in_progress = false
	var root := get_tree().root
	root.content_scale_size = _saved["size"]
	root.theme = _saved["theme"]
	root.canvas_item_default_texture_filter = _saved["filter"]
	_set_awake(get_tree(), false)
