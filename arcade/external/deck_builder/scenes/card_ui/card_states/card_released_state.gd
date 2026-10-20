extends DkCardState


func enter() -> void:
	if card_ui.targets.is_empty():
		return

	var single_targeted := card_ui.card.is_single_targeted()
	var first_target_is_enemy := card_ui.targets[0] is DkEnemy
	
	if single_targeted and not first_target_is_enemy:
		return
		
	DkEvents.tooltip_hide_requested.emit()
	card_ui.play()


func post_enter() -> void:
	transition_requested.emit(self, DkCardState.State.BASE)
