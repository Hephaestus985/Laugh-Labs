# Player turn order:
# 1. START_OF_TURN Relics 
# 2. START_OF_TURN Statuses
# 3. Draw Hand
# 4. End Turn 
# 5. END_OF_TURN Relics 
# 6. END_OF_TURN Statuses
# 7. Discard Hand
class_name DkPlayerHandler
extends Node

const HAND_DRAW_INTERVAL := 0.25
const HAND_DISCARD_INTERVAL := 0.25

@export var relics: DkRelicHandler
@export var player: DkPlayer
@export var hand: DkHand

var character: DkCharacterStats


func _ready() -> void:
	DkEvents.card_played.connect(_on_card_played)


func start_battle(char_stats: DkCharacterStats) -> void:
	character = char_stats
	character.draw_pile = character.deck.custom_duplicate()
	character.draw_pile.shuffle()
	character.discard = DkCardPile.new()
	relics.relics_activated.connect(_on_relics_activated)
	player.status_handler.statuses_applied.connect(_on_statuses_applied)
	start_turn()


func start_turn() -> void:
	character.block = 0
	character.reset_mana()
	relics.activate_relics_by_type(DkRelic.Type.START_OF_TURN)


func end_turn() -> void:
	hand.disable_hand()
	relics.activate_relics_by_type(DkRelic.Type.END_OF_TURN)


func draw_card() -> void:
	reshuffle_deck_from_discard()
	hand.add_card(character.draw_pile.draw_card())
	reshuffle_deck_from_discard()


func draw_cards(amount: int, is_start_of_turn_draw: bool = false) -> void:
	var tween := create_tween()
	for i in range(amount):
		tween.tween_callback(draw_card)
		tween.tween_interval(HAND_DRAW_INTERVAL)
	
	tween.finished.connect(
		func(): 
			hand.enable_hand()
			if is_start_of_turn_draw:
				DkEvents.player_hand_drawn.emit()
	)


func discard_cards() -> void:
	if hand.get_child_count() == 0:
		DkEvents.player_hand_discarded.emit()
		return

	var tween := create_tween()
	for card_ui: DkCardUI in hand.get_children():
		tween.tween_callback(character.discard.add_card.bind(card_ui.card))
		tween.tween_callback(hand.discard_card.bind(card_ui))
		tween.tween_interval(HAND_DISCARD_INTERVAL)
	
	tween.finished.connect(
		func():
			DkEvents.player_hand_discarded.emit()
	)


func reshuffle_deck_from_discard() -> void:
	if not character.draw_pile.empty():
		return

	while not character.discard.empty():
		character.draw_pile.add_card(character.discard.draw_card())

	character.draw_pile.shuffle()


func _on_card_played(card: DkCard) -> void:
	if card.exhausts or card.type == DkCard.Type.POWER:
		return
	
	character.discard.add_card(card)


func _on_statuses_applied(type: DkStatus.Type) -> void:
	match type:
		DkStatus.Type.START_OF_TURN:
			draw_cards(character.cards_per_turn, true)
		DkStatus.Type.END_OF_TURN:
			discard_cards()


func _on_relics_activated(type: DkRelic.Type) -> void:
	match type:
		DkRelic.Type.START_OF_TURN:
			player.status_handler.apply_statuses_by_type(DkStatus.Type.START_OF_TURN)
		DkRelic.Type.END_OF_TURN:
			player.status_handler.apply_statuses_by_type(DkStatus.Type.END_OF_TURN)
