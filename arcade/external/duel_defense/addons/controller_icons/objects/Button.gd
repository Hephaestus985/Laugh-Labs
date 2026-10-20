@tool
extends Button
class_name DdControllerButton

@export var path : String = "":
	set(_path):
		path = _path
		if is_inside_tree():
			if force_type > 0:
				icon = DdControllerIcons.parse_path(path, force_type - 1)
			else:
				icon = DdControllerIcons.parse_path(path)

@export_enum("Both", "Keyboard/Mouse", "Controller") var show_only : int = 0:
	set(_show_only):
		show_only = _show_only
		_on_input_type_changed(DdControllerIcons._last_input_type)

@export_enum("None", "Keyboard/Mouse", "Controller") var force_type : int = 0:
	set(_force_type):
		force_type = _force_type
		_on_input_type_changed(DdControllerIcons._last_input_type)

func _ready():
	DdControllerIcons.input_type_changed.connect(_on_input_type_changed)
	self.path = path

func _on_input_type_changed(input_type):
	if show_only == 0 or \
		(show_only == 1 and input_type == DdControllerIcons.InputType.KEYBOARD_MOUSE) or \
		(show_only == 2 and input_type == DdControllerIcons.InputType.CONTROLLER):
		self.path = path
	else:
		icon = null

func get_tts_string() -> String:
	if force_type:
		return DdControllerIcons.parse_path_to_tts(path, force_type - 1)
	else:
		return DdControllerIcons.parse_path_to_tts(path)
