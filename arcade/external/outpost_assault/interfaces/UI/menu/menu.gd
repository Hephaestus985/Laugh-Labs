extends Control


@onready var menu_panel := $PanelContainer as PanelContainer
@onready var how_to_play := $HowToPlay as Panel


func _on_start_pressed() -> void:
	Scenes.change_scene(Scenes.MAP_TEMPLATE)


# [Lab Arcade] go back to the arcade launcher instead of quitting the app
func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GameData.back_scene())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # [Lab Arcade] Android back button
		_on_quit_pressed.call_deferred()  # not while the tree is busy delivering the notification


func _on_how_to_play_pressed() -> void:
	how_to_play.show()
	menu_panel.hide()


func _on_back_pressed() -> void:
	how_to_play.hide()
	menu_panel.show()
