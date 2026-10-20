extends Control

@onready var _screen = find_child("Screen")
@onready var _mouse_movement_restricted = find_child("MouseMovementRestricted")


func _ready():
	RtsArcade.setup(self)  # [Lab Arcade] screen size, texts and the back button
	_mouse_movement_restricted.button_pressed = RtsGlobals.options.mouse_restricted
	_screen.selected = RtsGlobals.options.screen


func _on_mouse_movement_restricted_pressed():
	RtsGlobals.options.mouse_restricted = _mouse_movement_restricted.button_pressed
	ResourceSaver.save(RtsGlobals.options, RtsConstants.OPTIONS_FILE_PATH)


func _on_screen_item_selected(index):
	RtsGlobals.options.screen = {
		0: RtsGlobals.options.Screen.FULL,
		1: RtsGlobals.options.Screen.WINDOW,
	}[index]
	ResourceSaver.save(RtsGlobals.options, RtsConstants.OPTIONS_FILE_PATH)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://external/open_rts/source/main-menu/Main.tscn")
