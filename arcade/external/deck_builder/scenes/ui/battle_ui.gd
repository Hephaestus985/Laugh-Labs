class_name DkBattleUI
extends CanvasLayer

@export var char_stats: DkCharacterStats : set = _set_char_stats

@onready var hand: DkHand = $Hand
@onready var mana_ui: DkManaUI = $ManaUI
@onready var end_turn_button: Button = %EndTurnButton
@onready var draw_pile_button: DkCardPileOpener = %DrawPileButton
@onready var discard_pile_button: DkCardPileOpener = %DiscardPileButton
@onready var draw_pile_view: DkCardPileView = %DrawPileView
@onready var discard_pile_view: DkCardPileView = %DiscardPileView


func _ready() -> void:
	DkEvents.player_hand_drawn.connect(_on_player_hand_drawn)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	draw_pile_button.pressed.connect(draw_pile_view.show_current_view.bind("Draw Pile", true))
	discard_pile_button.pressed.connect(discard_pile_view.show_current_view.bind("Discard Pile"))


func initialize_card_pile_ui() -> void:
	draw_pile_button.card_pile = char_stats.draw_pile
	draw_pile_view.card_pile = char_stats.draw_pile
	discard_pile_button.card_pile = char_stats.discard
	discard_pile_view.card_pile = char_stats.discard


func _set_char_stats(value: DkCharacterStats) -> void:
	char_stats = value
	mana_ui.char_stats = char_stats
	hand.char_stats = char_stats


func _on_player_hand_drawn() -> void:
	end_turn_button.disabled = false


func _on_end_turn_button_pressed() -> void:
	end_turn_button.disabled = true
	DkEvents.player_turn_ended.emit()
