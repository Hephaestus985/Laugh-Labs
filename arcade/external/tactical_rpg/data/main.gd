extends Node
## A placeholder script that is meant to be replaced by your own level loader system

#region: --- Props ---
## The current instance of the TacticsLevel
var level_instance: TacticsLevel

## Reference to the World node
@onready var world: Node3D = $World
## Reference to the demo map button
@onready var demo_map: Button = $UI/MapSelector/LoadMap0
#endregion

#region: --- Processing ---
## Called when the node enters the scene tree for the first time
func _ready() -> void:
	demo_map.grab_focus() # Set focus on the demo map button
	# [Lab Arcade] the shared resources keep the last battle's state while the app runs
	# (Play again, or a second visit): start clean.
	var participant: TacticsParticipantResource = load("res://external/tactical_rpg/data/models/world/combat/participant/participant.tres")
	participant.stage = 0
	participant.curr_pawn = null
	participant.attackable_pawn = null
	participant.targets = null
	participant.display_opponent_stats = false
	participant.turn_just_started = true
	var cam: TacticsCameraResource = load("res://external/tactical_rpg/data/models/view/camera/tactics/camera.tres")
	cam.target = null
	cam.target_velocity = Vector3.ZERO
	TacticsCameraResource.is_rotating = false
	TacticsCameraResource.in_free_look = false
	load("res://external/tactical_rpg/data/models/world/combat/arena/arena.tres").path_tiles_stack.clear()
	# [Lab Arcade] phone controls: tap a unit or tile to pick it, arrows move the
	# camera, the small buttons turn and zoom it.
	demo_map.custom_minimum_size = Vector2(260, 90)
	demo_map.text = "Start battle"
	demo_map.add_theme_font_size_override("font_size", 34)
	TouchOverlay.add_to(self, {
		"dpad": ["trpg_camera_left", "trpg_camera_right", "trpg_camera_forward", "trpg_camera_backwards"],
		"small_left": true,
		"small": [["<<", _rotate_camera.bind(-90)], [">>", _rotate_camera.bind(90)], ["+", _zoom_camera.bind(-1.0)], ["-", _zoom_camera.bind(1.0)]],
	})
	if DisplayServer.is_touchscreen_available():
		$TacticsControls/Hints.visible = false # keyboard / gamepad picture


## [Lab Arcade] the original demo has no ending: fallen units now leave the
## board, and the battle ends when one side has no units left.
var _result_panel: Control


func _process(_delta: float) -> void:
	if not is_instance_valid(level_instance) or not level_instance.player or _result_panel:
		return
	var players_left := _remove_fallen(level_instance.player)
	var opponents_left := _remove_fallen(level_instance.opponent)
	if players_left == 0 or opponents_left == 0:
		_show_result(opponents_left == 0)


func _remove_fallen(side: Node) -> int:
	var left := 0
	for p in side.get_children():
		if p is TacticsPawn and p.is_node_ready():
			if p.is_alive():
				left += 1
			elif p.visible:
				p.visible = false
				p.collision_layer = 0
				p.end_pawn_turn()
	return left


func _show_result(won: bool) -> void:
	_result_panel = VBoxContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := Label.new()
	title.text = "Victory!" if won else "Defeat..."
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.add_child(title)
	for b in [["Play again", func() -> void: get_tree().reload_current_scene()], ["Back to Lab Arcade", func() -> void: TouchOverlay.current.back_to_launcher()]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.custom_minimum_size = Vector2(320, 80)
		btn.pressed.connect(b[1])
		_result_panel.add_child(btn)
	$UI.add_child(_result_panel)
	_result_panel.position = $UI.size / 2 - _result_panel.get_combined_minimum_size() / 2


## [Lab Arcade] camera buttons for phones (same as Q / E and the mouse wheel)
func _rotate_camera(degrees: int) -> void:
	if not TacticsCameraResource.in_free_look:
		TacticsCameraResource.y_rot += degrees


func _zoom_camera(direction: float) -> void:
	if TacticsCamera.serv:
		TacticsCamera.serv.zoom.zoom_camera(direction * TacticsCameraResource.zoom_speed)
#endregion

#region: --- Signals ---
## Called when the Load Map 0 button is pressed
func _on_load_map_0_pressed() -> void:
	load_level("test") # Load the test level
#endregion

#region: --- Methods ---
## Unloads the current level instance
func unload_level() -> void:
	if is_instance_valid(level_instance): # Check if the level instance is valid
		level_instance.queue_free() # Free the current level instance
	level_instance = null # Reset the level instance variable

## Loads the current level instance -- clears existing level in the process
##
## @param level_name: The name of the level to load
func load_level(level_name: String) -> void:
	unload_level() # Unload the current level
	var level_path: String = "res://external/tactical_rpg/assets/maps/level/%s_level.tscn" % level_name # Construct the level path
	level_instance = load(level_path).instantiate() # Load and instantiate the new level
	world.add_child(level_instance) # Add the new level to the World node
	$UI/MapSelector.visible = false # Hide the map selector UI
#endregion
