extends DkRelic


func activate_relic(owner: DkRelicUI) -> void:
	DkEvents.player_hand_drawn.connect(_add_mana.bind(owner), CONNECT_ONE_SHOT)


func _add_mana(owner: DkRelicUI) -> void:
	var player := owner.get_tree().get_first_node_in_group("player") as DkPlayer
	if player:
		player.stats.mana += 1
		owner.flash()
