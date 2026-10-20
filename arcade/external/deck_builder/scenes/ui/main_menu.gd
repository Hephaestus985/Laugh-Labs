extends Control

const CHAR_SELECTOR_SCENE := preload("res://external/deck_builder/scenes/ui/character_selector.tscn")
const RUN_SCENE = preload("res://external/deck_builder/scenes/run/run.tscn")

@export var run_startup: DkRunStartup

@onready var continue_button: Button = %Continue


func _ready() -> void:
	get_tree().paused = false
	DkArcade.setup(self)  # [Lab Arcade] screen size and the back button
	continue_button.disabled = DkSaveGame.load_data() == null


func _on_continue_pressed() -> void:
	run_startup.type = DkRunStartup.Type.CONTINUED_RUN
	get_tree().change_scene_to_packed(RUN_SCENE)


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_packed(CHAR_SELECTOR_SCENE)


func _on_exit_pressed() -> void:
	DkArcade.back_to_arcade(get_tree())  # [Lab Arcade] was: quit the app
