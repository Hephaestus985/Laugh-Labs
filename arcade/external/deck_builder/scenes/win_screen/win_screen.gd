class_name DkWinScreen
extends Control

const MAIN_MENU_PATH = "res://external/deck_builder/scenes/ui/main_menu.tscn"
const MESSAGE := "The %s\nis victorious!"

@export var character: DkCharacterStats : set = set_character

@onready var message: Label = %Message
@onready var character_portrait: TextureRect = %CharacterPortrait


func _ready() -> void:
	GameData.add_win("deck_builder")  # [Lab Arcade] counts for achievements and the profile


func set_character(new_character: DkCharacterStats) -> void:
	character = new_character
	message.text = MESSAGE % character.character_name
	character_portrait.texture = character.portrait


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
