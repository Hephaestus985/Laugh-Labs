extends CanvasLayer


func _ready():
	if not RtsGlobals.god_mode:
		hide()
	RtsSignals.god_mode_enabled.connect(show)
	RtsSignals.god_mode_disabled.connect(hide)
