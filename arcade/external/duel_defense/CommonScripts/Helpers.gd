extends Node

class_name DdHelpers

static func play_button_sound():
	DdSoundManager.play_ui_sound(load("res://external/duel_defense/Assets/Audio/Sounds/click_003.ogg"))
	
static func play_error_sound():
	DdSoundManager.play_ui_sound(load("res://external/duel_defense/Assets/Audio/Sounds/error_007.ogg"))
	
static func play_confirm_sound():
	DdSoundManager.play_ui_sound(load("res://external/duel_defense/Assets/Audio/Sounds/confirmation_001.ogg"))

static func play_upgrade_sound():
	DdSoundManager.play_ui_sound(load("res://external/duel_defense/Assets/Audio/Sounds/confirmation_002.ogg"))
