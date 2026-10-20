class_name DkModifierValue
extends Node

enum Type {PERCENT_BASED, FLAT}

@export var type: Type
@export var percent_value: float
@export var flat_value: int
@export var source: String


static func create_new_modifier(modifier_source: String, what_type: Type) -> DkModifierValue:
	var new_modifier := new()
	new_modifier.source = modifier_source
	new_modifier.type = what_type
	
	return new_modifier
