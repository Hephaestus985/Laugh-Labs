class_name DkPlayer
extends Node2D

const WHITE_SPRITE_MATERIAL := preload("res://external/deck_builder/art/white_sprite_material.tres")

@export var stats: DkCharacterStats : set = set_character_stats

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var stats_ui: DkStatsUI = $StatsUI
@onready var status_handler: DkStatusHandler = $StatusHandler
@onready var modifier_handler: DkModifierHandler = $ModifierHandler


func _ready() -> void:
	status_handler.status_owner = self


func set_character_stats(value: DkCharacterStats) -> void:
	stats = value
	
	if not stats.stats_changed.is_connected(update_stats):
		stats.stats_changed.connect(update_stats)

	update_player()


func update_player() -> void:
	if not stats is DkCharacterStats: 
		return
	if not is_inside_tree(): 
		await ready

	sprite_2d.texture = stats.art
	update_stats()


func update_stats() -> void:
	stats_ui.update_stats(stats)


func take_damage(damage: int, which_modifier: DkModifier.Type) -> void:
	if stats.health <= 0:
		return
	
	sprite_2d.material = WHITE_SPRITE_MATERIAL
	var modified_damage := modifier_handler.get_modified_value(damage, which_modifier)
	
	var tween := create_tween()
	tween.tween_callback(DkShaker.shake.bind(self, 16, 0.15))
	tween.tween_callback(stats.take_damage.bind(modified_damage))
	tween.tween_interval(0.17)
	
	tween.finished.connect(
		func():
			sprite_2d.material = null
			
			if stats.health <= 0:
				DkEvents.player_died.emit()
				queue_free()
	)
