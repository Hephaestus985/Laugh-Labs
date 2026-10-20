class_name DkShopCard
extends VBoxContainer

const CARD_MENU_UI = preload("res://external/deck_builder/scenes/ui/card_menu_ui.tscn")

@export var card: DkCard : set = set_card

@onready var card_container: CenterContainer = %CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@onready var gold_cost := DkRNG.instance.randi_range(100, 300)

var current_card_ui: DkCardMenuUI


func update(run_stats: DkRunStats) -> void:
	if not card_container or not price or not buy_button:
		return

	price_label.text = str(gold_cost)
	
	if run_stats.gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
		buy_button.disabled = false
	else:
		price_label.add_theme_color_override("font_color", Color.RED)
		buy_button.disabled = true


func set_card(new_card: DkCard) -> void:
	if not is_node_ready():
		await ready

	card = new_card
	
	for card_menu_ui: DkCardMenuUI in card_container.get_children():
		card_menu_ui.queue_free()
	
	var new_card_menu_ui := CARD_MENU_UI.instantiate() as DkCardMenuUI
	card_container.add_child(new_card_menu_ui)
	new_card_menu_ui.card = card
	current_card_ui = new_card_menu_ui


func _on_buy_button_pressed() -> void:
	DkEvents.shop_card_bought.emit(card, gold_cost)
	card_container.queue_free()
	price.queue_free()
	buy_button.queue_free()
