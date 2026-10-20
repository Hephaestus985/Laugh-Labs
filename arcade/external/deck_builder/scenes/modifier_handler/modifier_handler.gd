class_name DkModifierHandler
extends Node


func has_modifier(type: DkModifier.Type) -> bool:
	for modifier: DkModifier in get_children():
		if modifier.type == type:
			return true
			
	return false


func get_modifier(type: DkModifier.Type) -> DkModifier:
	for modifier: DkModifier in get_children():
		if modifier.type == type:
			return modifier
			
	return null


func get_modified_value(base: int, type: DkModifier.Type) -> int:
	var modifier := get_modifier(type)
	
	if not modifier:
		return base
		
	return modifier.get_modified_value(base)
