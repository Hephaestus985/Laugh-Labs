class_name DkEnemyActionPicker
extends Node

@export var enemy: DkEnemy: set = _set_enemy
@export var target: Node2D: set = _set_target

@onready var total_weight := 0.0


func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	setup_chances()


func get_action() -> DkEnemyAction:
	var action := get_first_conditional_action()
	if action:
		return action
		
	return get_chance_based_action()


func get_first_conditional_action() -> DkEnemyAction:
	for action: DkEnemyAction in get_children():
		if not action or action.type != DkEnemyAction.Type.CONDITIONAL:
			continue
			
		if action.is_performable():
			return action
	
	return null


func get_chance_based_action() -> DkEnemyAction:
	var roll := DkRNG.instance.randf_range(0.0, total_weight)
	
	for action: DkEnemyAction in get_children():
		if not action or action.type != DkEnemyAction.Type.CHANCE_BASED:
			continue
		
		if action.accumulated_weight > roll:
			return action
	
	return null


func setup_chances() -> void:
	for action: DkEnemyAction in get_children():
		if not action or action.type != DkEnemyAction.Type.CHANCE_BASED:
			continue
		
		total_weight += action.chance_weight
		action.accumulated_weight = total_weight


func _set_enemy(value: DkEnemy) -> void:
	enemy = value
	
	for action: DkEnemyAction in get_children():
		action.enemy = enemy


func _set_target(value: Node2D) -> void:
	target = value
	
	for action: DkEnemyAction in get_children():
		action.target = target
