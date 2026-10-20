extends DkEnemyAction

@export var block := 4


func perform_action() -> void:
	if not enemy or not target:
		return
	
	var block_effect := DkBlockEffect.new()
	block_effect.amount = block
	block_effect.sound = sound
	block_effect.execute([enemy])
	
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			DkEvents.enemy_action_completed.emit(enemy)
	)

