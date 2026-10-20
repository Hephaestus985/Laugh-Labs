extends DkCard

var base_damage := 4


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
