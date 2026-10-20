class_name DkCharacterStats
extends DkStats

@export_group("Visuals")
@export var character_name: String
@export_multiline var description: String
@export var portrait: Texture

@export_group("Gameplay Data")
@export var starting_deck: DkCardPile
@export var draftable_cards: DkCardPile
@export var cards_per_turn: int
@export var max_mana: int
@export var starting_relic: DkRelic

var mana: int : set = set_mana
var deck: DkCardPile
var discard: DkCardPile
var draw_pile: DkCardPile


func set_mana(value: int) -> void:
	mana = value
	stats_changed.emit()


func reset_mana() -> void:
	mana = max_mana


func take_damage(damage: int) -> void:
	var initial_health := health
	super.take_damage(damage)
	if initial_health > health:
		DkEvents.player_hit.emit()


func can_play_card(card: DkCard) -> bool:
	return mana >= card.cost


func create_instance() -> Resource:
	var instance: DkCharacterStats = self.duplicate()
	instance.health = max_health
	instance.block = 0
	instance.reset_mana()
	instance.deck = instance.starting_deck.duplicate()
	instance.draw_pile = DkCardPile.new()
	instance.discard = DkCardPile.new()
	return instance
