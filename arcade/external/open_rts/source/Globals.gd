extends Node

const Options = preload("res://external/open_rts/source/data-model/Options.gd")

# [Lab Arcade] the options file is only loaded when it is plainly this game's own (see SafeResource)
var options = _load_options()


func _load_options():
	var o = SafeResource.load_user(RtsConstants.OPTIONS_FILE_PATH, "res://external/open_rts/")
	return o if o != null else Options.new()
var god_mode = false
var cache = {}


func _unhandled_input(event):
	if event.is_action_pressed("rts_toggle_god_mode"):
		_toggle_god_mode()


func _toggle_god_mode():
	if not RtsFeatureFlags.god_mode:
		return
	god_mode = not god_mode
	if god_mode:
		RtsSignals.god_mode_enabled.emit()
	else:
		RtsSignals.god_mode_disabled.emit()
