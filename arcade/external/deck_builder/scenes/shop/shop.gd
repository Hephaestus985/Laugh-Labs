class_name DkShop
extends Control

const SHOP_CARD = preload("res://external/deck_builder/scenes/shop/shop_card.tscn")
const SHOP_RELIC = preload("res://external/deck_builder/scenes/shop/shop_relic.tscn")

@export var shop_relics: Array[DkRelic]
@export var char_stats: DkCharacterStats
@export var run_stats: DkRunStats
@export var relic_handler: DkRelicHandler

@onready var cards: HBoxContainer = %Cards
@onready var relics: HBoxContainer = %Relics
@onready var shop_keeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var card_tooltip_popup: DkCardTooltipPopup = %CardTooltipPopup
@onready var modifier_handler: DkModifierHandler = $ModifierHandler


func _ready() -> void:
	for shop_card: DkShopCard in cards.get_children():
		shop_card.queue_free()
		
	for shop_relic: DkShopRelic in relics.get_children():
		shop_relic.queue_free()
		
	DkEvents.shop_card_bought.connect(_on_shop_card_bought)
	DkEvents.shop_relic_bought.connect(_on_shop_relic_bought)

	_blink_timer_setup()
	blink_timer.timeout.connect(_on_blink_timer_timeout)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and card_tooltip_popup.visible:
		card_tooltip_popup.hide_tooltip()


func populate_shop() -> void:
	_generate_shop_cards()
	_generate_shop_relics()


func _blink_timer_setup() -> void:
	blink_timer.wait_time = randf_range(1.0, 5.0)
	blink_timer.start()


func _generate_shop_cards() -> void:
	var shop_card_array: Array[DkCard] = []
	var available_cards: Array[DkCard] = char_stats.draftable_cards.duplicate_cards()
	DkRNG.array_shuffle(available_cards)
	shop_card_array = available_cards.slice(0, 3)
	
	for card: DkCard in shop_card_array:
		var new_shop_card := SHOP_CARD.instantiate() as DkShopCard
		cards.add_child(new_shop_card)
		new_shop_card.card = card
		new_shop_card.current_card_ui.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
		new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
		new_shop_card.update(run_stats)


func _generate_shop_relics() -> void:
	var shop_relics_array: Array[DkRelic] = []
	var available_relics := shop_relics.filter(
		func(relic: DkRelic):
			var can_appear := relic.can_appear_as_reward(char_stats)
			var already_had_it := relic_handler.has_relic(relic.id)
			return can_appear and not already_had_it
	)
	
	DkRNG.array_shuffle(available_relics)
	shop_relics_array = available_relics.slice(0, 3)
	
	for relic: DkRelic in shop_relics_array:
		var new_shop_relic := SHOP_RELIC.instantiate() as DkShopRelic
		relics.add_child(new_shop_relic)
		new_shop_relic.relic = relic
		new_shop_relic.gold_cost = _get_updated_shop_cost(new_shop_relic.gold_cost)
		new_shop_relic.update(run_stats)


func _update_items() -> void:
	for shop_card: DkShopCard in cards.get_children():
		shop_card.update(run_stats)

	for shop_relic: DkShopRelic in relics.get_children():
		shop_relic.update(run_stats)


func _update_item_costs() -> void:
	for shop_card: DkShopCard in cards.get_children():
		shop_card.gold_cost = _get_updated_shop_cost(shop_card.gold_cost)
		shop_card.update(run_stats)

	for shop_relic: DkShopRelic in relics.get_children():
		shop_relic.gold_cost = _get_updated_shop_cost(shop_relic.gold_cost)
		shop_relic.update(run_stats)


func _get_updated_shop_cost(original_cost: int) -> int:
	return modifier_handler.get_modified_value(original_cost, DkModifier.Type.SHOP_COST)


func _on_back_button_pressed() -> void:
	DkEvents.shop_exited.emit()


func _on_shop_card_bought(card: DkCard, gold_cost: int) -> void:
	char_stats.deck.add_card(card)
	run_stats.gold -= gold_cost
	_update_items()


func _on_shop_relic_bought(relic: DkRelic, gold_cost: int) -> void:
	relic_handler.add_relic(relic)
	run_stats.gold -= gold_cost

	if relic is DkCouponsRelic:
		var coupons_relic := relic as DkCouponsRelic
		coupons_relic.add_shop_modifier(self)
		_update_item_costs()
	else:
		_update_items()


func _on_blink_timer_timeout() -> void:
	shop_keeper_animation.play("blink")
	_blink_timer_setup()
