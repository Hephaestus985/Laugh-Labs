extends Node
## [Lab Arcade] Starts OpenRPG inside the arcade. OpenRPG was made as its own app, so this sets its
## screen size, theme and pixel-art filter while it runs, gives it a fresh start each time, adds the
## phone buttons, and puts its always-loaded helpers (autoloads) to sleep again on the way out.

const GAME := preload("res://external/open_rpg/src/main.tscn")
const THEME := preload("res://external/open_rpg/assets/gui/default.theme")
const AUTOLOADS := ["Camera", "CombatEvents", "FieldEvents", "Gameboard", "GamepieceRegistry",
	"Music", "Player", "Transition", "Dialogic"]

var _saved := {}


## Called by the launcher: OpenRPG's helpers do nothing (and draw nothing) while other games run.
static func park(tree: SceneTree) -> void:
	_set_awake(tree, false)


static func _set_awake(tree: SceneTree, awake: bool) -> void:
	for n in AUTOLOADS:
		var node := tree.root.get_node_or_null(n)
		if node:
			node.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	var cam := tree.root.get_node_or_null("Camera") as Camera2D
	if cam:
		cam.enabled = awake
	var cover := tree.root.get_node_or_null("Transition") as CanvasLayer
	if cover:
		cover.visible = awake


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
