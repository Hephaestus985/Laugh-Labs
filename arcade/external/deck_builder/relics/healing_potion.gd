extends DkRelic

@export var heal_amount := 6


func activate_relic(owner: DkRelicUI) -> void:
	var player := owner.get_tree().get_first_node_in_group("player") as DkPlayer
	if player:
		player.stats.heal(heal_amount)
		owner.flash()
