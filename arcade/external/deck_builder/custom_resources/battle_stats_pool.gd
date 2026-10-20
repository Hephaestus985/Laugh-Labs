class_name DkBattleStatsPool
extends Resource

@export var pool: Array[DkBattleStats]

var total_weights_by_tier := [0.0, 0.0, 0.0]


func _get_all_battles_for_tier(tier: int) -> Array[DkBattleStats]:
	return pool.filter(
		func(battle: DkBattleStats):
			return battle.battle_tier == tier
	)


func _setup_weight_for_tier(tier: int) -> void:
	var battles := _get_all_battles_for_tier(tier)
	total_weights_by_tier[tier] = 0.0
	
	for battle: DkBattleStats in battles:
		total_weights_by_tier[tier] += battle.weight
		battle.accumulated_weight = total_weights_by_tier[tier]


func get_random_battle_for_tier(tier: int) -> DkBattleStats:
	var roll := randf_range(0.0, total_weights_by_tier[tier])
	var battles := _get_all_battles_for_tier(tier)
	
	for battle: DkBattleStats in battles:
		if battle.accumulated_weight > roll:
			return battle
		
	return null


func setup() -> void:
	for i in 3:
		_setup_weight_for_tier(i)
