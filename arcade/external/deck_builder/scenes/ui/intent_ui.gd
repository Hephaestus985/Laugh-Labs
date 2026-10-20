class_name DkIntentUI
extends HBoxContainer

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label


func update_intent(intent: DkIntent) -> void:
	if not intent:
		hide()
		return
	
	icon.texture = intent.icon
	icon.visible = icon.texture != null
	label.text = str(intent.current_text)
	label.visible = intent.current_text.length() > 0
	show()
