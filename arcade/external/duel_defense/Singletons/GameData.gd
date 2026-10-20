extends Node

signal setting_updated(setting_key, setting_value)
signal config_updated(key)

var config = {}

func _ready():
	DdGodotLogger.log_requested.connect(on_log_requested)
	
	DdConsole.add_command("get_setting", on_get_setting, 1)
	DdConsole.add_command("set_setting", on_set_setting, 2)
	DdConsole.add_command("list_settings", on_list_settings)

func update_setting(setting_key, value):
	config.settings[setting_key] = value
	emit_signal('setting_updated', setting_key, value)
	
func update_config(key):
	emit_signal('config_updated', key)
	
func show_toast_error(text):
	DdToastParty.show({
		"text": text,
		"bgcolor": Color.DARK_RED,
		"color": Color(1, 1, 1, 1),
		"gravity": "top",
		"direction": "center", 
	})
	
func show_toast_success(text):
	DdToastParty.show({
		"text": text,
		"bgcolor": Color.DARK_GREEN,
		"color": Color(1, 1, 1, 1),
		"gravity": "top",
		"direction": "center", 
	})

# Console commands related to GameData

func on_log_requested(msg):
	DdConsole.print_line(msg)

func on_get_setting(key):
	if not key:
		DdConsole.print_line("get_setting <key>")
		return
		
	if key not in DdGameData.config.settings:
		DdConsole.print_line("get_setting <key>, key is invalid")
		return
	
	DdConsole.print_line("%s" % DdGameData.config.settings[key])
	
func on_set_setting(key, value):
	if not key or not value:
		DdConsole.print_line("set_setting <key> <value>")
		return
		
	if key not in DdGameData.config.settings_map or key not in DdGameData.config.settings:
		DdConsole.print_line("set_setting <key>, key is invalid")
		return
	
	var final_value = value
	
	var setting_map = DdGameData.config.settings_map[key]
	if setting_map.type == "slider":
		final_value = float(value)
	elif setting_map.type == "checkbox":
		if value == "true":
			final_value = true
		else:
			final_value = false
	
	update_setting(key, final_value)

func on_list_settings():
	DdConsole.print_line(JSON.stringify(DdGameData.config.settings, "\t"))
