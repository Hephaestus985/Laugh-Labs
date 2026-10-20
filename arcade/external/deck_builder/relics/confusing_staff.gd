extends DkRelic

var relic_ui: DkRelicUI


func initialize_relic(owner: DkRelicUI) -> void:
	relic_ui = owner
	DkEvents.player_hand_drawn.connect(_on_player_hand_drawn)


func deactivate_relic(_owner: DkRelicUI) -> void:
	DkEvents.player_hand_drawn.disconnect(_on_player_hand_drawn)


func _on_player_hand_drawn() -> void:
	relic_ui.flash()
	var player_handler := relic_ui.get_tree().get_first_node_in_group("player_handler") as DkPlayerHandler
	
	for card_ui: DkCardUI in player_handler.hand.get_children():
		card_ui.card.cost = DkRNG.instance.randi_range(0, 3)
		card_ui.card = card_ui.card
