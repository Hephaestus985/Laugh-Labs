class_name DkSaveGame
extends Resource

const SAVE_PATH := "user://deck_builder_save.tres"  # [Lab Arcade] own name inside the arcade

@export var rng_seed: int
@export var rng_state: int
@export var run_stats: DkRunStats
@export var char_stats: DkCharacterStats
@export var current_deck: DkCardPile
@export var current_health: int
@export var relics: Array[DkRelic]
@export var map_data: Array[Array]
@export var last_room: DkRoom
@export var floors_climbed: int
@export var was_on_map: bool


func save_data() -> void:
	var err := ResourceSaver.save(self, SAVE_PATH)
	assert(err == OK, "Couldn't save the game!")


static func load_data() -> DkSaveGame:
	# [Lab Arcade] only a save that is plainly this game's own is loaded (see SafeResource)
	if FileAccess.file_exists(SAVE_PATH):
		return SafeResource.load_user(SAVE_PATH, "res://external/deck_builder/") as DkSaveGame
	
	return null


static func delete_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
