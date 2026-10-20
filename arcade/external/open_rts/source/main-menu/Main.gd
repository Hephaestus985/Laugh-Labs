extends Control


func _ready():
	RtsArcade.setup(self)  # [Lab Arcade] screen size, texts and the back button


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://external/open_rts/source/main-menu/Play.tscn")


func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://external/open_rts/source/main-menu/Options.tscn")


func _on_credits_button_pressed():
	get_tree().change_scene_to_file("res://external/open_rts/source/main-menu/Credits.tscn")


func _on_quit_button_pressed():
	RtsArcade.back_to_arcade(get_tree())  # [Lab Arcade] was: quit the app
