extends DkCard

const EXPOSED_STATUS = preload("res://external/deck_builder/statuses/exposed.tres")

var base_damage := 4
var exposed_duration := 2


func get_default_tooltip() -> String:
	return tooltip_text % base_damage


func get_updated_tooltip(player_modifiers: DkModifierHandler, enemy_modifiers: DkModifierHandler) -> String:
	var modified_dmg := player_modifiers.get_modified_value(base_damage, DkModifier.Type.DMG_DEALT)

	if enemy_modifiers:
		modified_dmg = enemy_modifiers.get_modified_value(modified_dmg, DkModifier.Type.DMG_TAKEN)
		
	return tooltip_text % modified_dmg


func apply_effects(targets: Array[Node], modifiers: DkModifierHandler) -> void:
	var damage_effect := DkDamageEffect.new()
	damage_effect.amount = modifiers.get_modified_value(base_damage, DkModifier.Type.DMG_DEALT)
	damage_effect.sound = sound
	damage_effect.execute(targets)
	
	var status_effect := DkStatusEffect.new()
	var exposed := EXPOSED_STATUS.duplicate()
	exposed.duration = exposed_duration
	status_effect.status = exposed
	status_effect.execute(targets)
