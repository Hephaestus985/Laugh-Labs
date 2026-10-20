extends Camera2D

@export var map_size = Vector2(1920, 1080)

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().get_root().size_changed.connect(resized)
	resized()

func resized():
	# [Lab Arcade] the arcade scales the screen: use the visible size, not the window's.
	# The map keeps its shape (one zoom for both directions; it used to stretch on wide
	# phones) and fits the space left of the shop column, centred in it.
	var window_size = get_viewport().get_visible_rect().size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	var ui = get_parent().get_node_or_null("UI")
	if ui and ui.has_method("lab_panel_width") and not get_parent().get("main_menu_mode"):
		window_size.x -= ui.lab_panel_width()
	var z: float = minf(window_size.x / map_size.x, window_size.y / map_size.y)
	if get_parent().get("main_menu_mode"):
		z = maxf(window_size.x / map_size.x, window_size.y / map_size.y)  # the menu's background map fills the screen
	zoom = Vector2(z, z)
	position = -(window_size / z - map_size) / 2.0
