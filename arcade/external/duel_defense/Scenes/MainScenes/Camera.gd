extends Camera2D

@export var map_size = Vector2(1920, 1080)

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().get_root().size_changed.connect(resized)
	resized()

func resized():
	# [Lab Arcade] the arcade scales the screen: use the visible size, not the window's
	var window_size = get_viewport().get_visible_rect().size
	if window_size.x <= 0 or window_size.y <= 0:
		return
	if window_size.x < map_size.x:
		zoom.x = window_size.x / map_size.x
		DdGodotLogger.info("setting camera zoom x to %s" % zoom.x)
	else:
		if zoom.x != 1:
			zoom.x = 1
			
	if window_size.x > map_size.x:
		position.x = -(window_size.x - map_size.x)/2
	else:
		if position.x != 0:
			position.x = 0
		
	if window_size.y < map_size.y:
		zoom.y = window_size.y / map_size.y
		DdGodotLogger.info("setting camera zoom y to %s" % zoom.y)
	else:
		if zoom.y != 1:
			zoom.y = 1
			
	if window_size.y > map_size.y:
		position.y = -(window_size.y - map_size.y)/2
	else:
		if position.y != 0:
			position.y = 0
