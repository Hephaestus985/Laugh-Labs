class_name DkCardMenuUI
extends CenterContainer

signal tooltip_requested(card: DkCard)

const BASE_STYLEBOX := preload("res://external/deck_builder/scenes/card_ui/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://external/deck_builder/scenes/card_ui/card_hover_stylebox.tres")

@export var card: DkCard : set = set_card

@onready var visuals: DkCardVisuals = $Visuals


func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("deck_left_mouse"):
		tooltip_requested.emit(card)


func _on_visuals_mouse_entered() -> void:
	visuals.panel.set("theme_override_styles/panel", HOVER_STYLEBOX)


func _on_visuals_mouse_exited() -> void:
	visuals.panel.set("theme_override_styles/panel", BASE_STYLEBOX)


func set_card(value: DkCard) -> void:
	if not is_node_ready():
		await ready

	card = value
	visuals.card = card
