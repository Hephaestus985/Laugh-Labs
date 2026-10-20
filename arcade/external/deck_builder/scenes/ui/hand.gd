class_name DkHand
extends HBoxContainer

const CARD_UI_SCENE := preload("res://external/deck_builder/scenes/card_ui/card_ui.tscn")

@export var player: DkPlayer
@export var char_stats: DkCharacterStats


func add_card(card: DkCard) -> void:
	var new_card_ui := CARD_UI_SCENE.instantiate() as DkCardUI
	add_child(new_card_ui)
	new_card_ui.reparent_requested.connect(_on_card_ui_reparent_requested)
	new_card_ui.card = card
	new_card_ui.parent = self
	new_card_ui.char_stats = char_stats
	new_card_ui.player_modifiers = player.modifier_handler


func discard_card(card: DkCardUI) -> void:
	card.queue_free()


func enable_hand() -> void:
	for card: DkCardUI in get_children():
		card.disabled = false
		if card.is_hovered():
			card.card_state_machine.on_mouse_entered()


func disable_hand() -> void:
	for card: DkCardUI in get_children():
		card.disabled = true


func _on_card_ui_reparent_requested(child: DkCardUI) -> void:
	child.disabled = true
	child.reparent(self)
	var new_index := clampi(child.original_index, 0, get_child_count())
	move_child.call_deferred(child, new_index)
	child.set_deferred("disabled", false)
