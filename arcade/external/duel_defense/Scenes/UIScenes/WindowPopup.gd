extends Window

class_name DdWindowPopup

@export var content_container: Node

func _unhandled_input(event):
	if event.is_action_released("ui_cancel") or event.is_action_released("dd_menu"):
		self.visible = false

# [Lab Arcade] phone-sized: most of the screen, bigger text and title bar
func lab_fit() -> void:
	var view: Vector2 = get_tree().root.get_visible_rect().size
	content_scale_factor = 1.35
	add_theme_constant_override("title_height", 54)
	add_theme_font_size_override("title_font_size", 30)
	if theme == null:
		theme = DdArcade.THEME
	size = Vector2i(view * Vector2(0.86, 0.82))
	position = Vector2i((view - Vector2(size)) / 2.0)


func open_popup():
	lab_fit()
	self.popup_centered(size)
	var container = content_container
	if not container:
		return
	var container_children = container.get_children()
	for child in container_children:
		if child is Label:
			continue
		child.grab_focus()
		break
	
func add_ui(node):
	add_to_scroll_container(node)

func add_to_scroll_container(node):
	content_container.add_child(node)

func clear_scroll_container():
	for child in content_container.get_children():
		child.queue_free()

func signal_config_updated(key):
	DdGameData.update_config(key)
