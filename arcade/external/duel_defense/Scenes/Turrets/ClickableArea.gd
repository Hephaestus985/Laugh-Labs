extends Area2D

class_name DdClickableArea

func _on_ClickableArea_input_event(_viewport, event, _shape_idx):
	# [Lab Arcade] the game's own ui_accept / ui_cancel also held the mouse buttons; the
	# arcade keeps the standard ones, so clicks and taps (on release) are checked here
	var left_up: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	var right_down: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
	if(event.is_action_pressed("ui_accept") or left_up):
		self.get_parent().accept_clicked()
	elif(event.is_action_pressed("ui_cancel") or right_down):
		self.get_parent().cancel_clicked()
