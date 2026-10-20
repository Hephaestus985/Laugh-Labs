extends Node2D
# This acts as a base Map scene. To make a new level,
# just create a scene inheriting this one and use the tilemap to design it.
# You can use the Terrains feature to draw paths which already 
# navigation set-up, then tweak the spawner, objective, camera, etc. to
# your needs.


const STARTING_MONEY := 5000

@onready var objective := $Objective as Objective
@onready var spawner := $Spawner as Spawner
@onready var camera := $Camera2D as Camera2D
@onready var tilemap := $TileMap as TileMap


func _ready() -> void:
	randomize()
	# initialize money
	Global.money = STARTING_MONEY
	# initialize camera
	var map_limits := tilemap.get_used_rect()
	var cell_size := tilemap.tile_set.tile_size
	camera.limit_left = int(map_limits.position.x) * cell_size.x
	camera.limit_top = int(map_limits.position.y) * cell_size.y
	camera.limit_right = int(map_limits.end.x) * cell_size.x
	camera.limit_bottom = int(map_limits.end.y) * cell_size.y
	# connect signals
	spawner.countdown_started.connect(Callable(camera.hud, "_on_spawner_countdown_started"))
	spawner.wave_started.connect(Callable(camera.hud, "_on_spawner_wave_started"))
	spawner.enemies_defeated.connect(Callable(camera.hud, "_on_spawner_enemies_defeated"))
	objective.health_changed.connect(Callable(camera.hud, "_on_objective_health_changed"))
	objective.destroyed.connect(Callable(camera.hud, "_on_objective_destroyed"))
	# initialize HUD parameters
	(camera.hud as Hud).initialize(objective.health)  # objective will have already been initialized
	# start spawning enemies
	spawner.initialize(objective.global_position, map_limits, cell_size)
	_add_touch_buttons()


# [Lab Arcade] on-screen buttons for phones: pause and zoom (no keyboard or mouse wheel)
func _add_touch_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchButtons"
	layer.layer = 5
	add_child(layer)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -112.0
	box.offset_right = -16.0
	box.offset_top = -438.0
	box.offset_bottom = -16.0
	box.add_theme_constant_override("separation", 12)
	layer.add_child(box)
	# "?" opens this game's help page (and it opens by itself the first time)
	var help := "res://external/outpost_assault/lab_arcade_help.json"
	HelpPage.open_first_time(self, "outpost_assault", help)
	for spec in [["HelpButton", "?", func(): HelpPage.open(self, help)], ["ZoomIn", "+", func(): camera.zoom_by(1.25)], ["ZoomOut", "-", func(): camera.zoom_by(0.8)], ["PauseButton", "II", _pause]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(96, 96)
		b.add_theme_font_size_override("font_size", 40)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[2])
		box.add_child(b)


func _pause() -> void:
	var pause: Node = (camera.get("hud") as Node).find_child("Pause", true, false)
	if pause and pause.has_method("_enable") and not Global.is_gameover:
		pause.call("_enable", true)


# [Lab Arcade] Android back button: back to this game's main menu
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not HelpPage.is_open():
		get_tree().paused = false
		Global.is_gameover = false
		Scenes.change_scene.call_deferred(Scenes.MAIN_MENU)  # not while the tree is busy


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and not Global.pan_moved and \
			event.button_index == MOUSE_BUTTON_LEFT:
		# if there's a turret actions UI visible, hide it
		if Global.turret_actions:
			Global.turret_actions.hide()
