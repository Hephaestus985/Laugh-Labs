class_name DkShopRelic
extends VBoxContainer

const RELIC_UI = preload("res://external/deck_builder/scenes/relic_handler/relic_ui.tscn")

@export var relic: DkRelic : set = set_relic

@onready var relic_container: CenterContainer = %RelicContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@onready var gold_cost := DkRNG.instance.randi_range(100, 300)


func update(run_stats: DkRunStats) -> void:
	if not relic_container or not price or not buy_button:
		return

	price_label.text = str(gold_cost)
	
	if run_stats.gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
		buy_button.disabled = false
	else:
		price_label.add_theme_color_override("font_color", Color.RED)
		buy_button.disabled = true


func set_relic(new_relic: DkRelic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	
	for relic_ui: DkRelicUI in relic_container.get_children():
		relic_ui.queue_free()
	
	var new_relic_ui := RELIC_UI.instantiate() as DkRelicUI
	relic_container.add_child(new_relic_ui)
	new_relic_ui.relic = relic


func _on_buy_button_pressed() -> void:
	DkEvents.shop_relic_bought.emit(relic, gold_cost)
	relic_container.queue_free()
	price.queue_free()
	buy_button.queue_free()
