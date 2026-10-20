class_name DkBattleReward
extends Control

const CARD_REWARDS = preload("res://external/deck_builder/scenes/ui/card_rewards.tscn")
const REWARD_BUTTON = preload("res://external/deck_builder/scenes/ui/reward_button.tscn")
const GOLD_ICON := preload("res://external/deck_builder/art/gold.png")
const GOLD_TEXT := "%s gold"
const CARD_ICON := preload("res://external/deck_builder/art/rarity.png")
const CARD_TEXT := "Add New Card"

@export var run_stats: DkRunStats
@export var character_stats: DkCharacterStats
@export var relic_handler: DkRelicHandler

@onready var rewards: VBoxContainer = %Rewards

var card_reward_total_weight := 0.0
var card_rarity_weights := {
	DkCard.Rarity.COMMON: 0.0,
	DkCard.Rarity.UNCOMMON: 0.0,
	DkCard.Rarity.RARE: 0.0
}


func _ready() -> void:
	for node: Node in rewards.get_children():
		node.queue_free()


func add_gold_reward(amount: int) -> void:
	var gold_reward := REWARD_BUTTON.instantiate() as DkRewardButton
	gold_reward.reward_icon = GOLD_ICON
	gold_reward.reward_text = GOLD_TEXT % amount
	gold_reward.pressed.connect(_on_gold_reward_taken.bind(amount))
	rewards.add_child.call_deferred(gold_reward)


func add_card_reward() -> void:
	var card_reward := REWARD_BUTTON.instantiate() as DkRewardButton
	card_reward.reward_icon = CARD_ICON
	card_reward.reward_text = CARD_TEXT
	card_reward.pressed.connect(_show_card_rewards)
	rewards.add_child.call_deferred(card_reward)


func add_relic_reward(relic: DkRelic) -> void:
	if not relic:
		return

	var relic_reward := REWARD_BUTTON.instantiate() as DkRewardButton
	relic_reward.reward_icon = relic.icon
	relic_reward.reward_text = relic.relic_name
	relic_reward.pressed.connect(_on_relic_reward_taken.bind(relic))
	rewards.add_child.call_deferred(relic_reward)


func _show_card_rewards() -> void:
	if not run_stats or not character_stats:
		return
	
	var card_rewards := CARD_REWARDS.instantiate() as DkCardRewards
	add_child(card_rewards)
	card_rewards.card_reward_selected.connect(_on_card_reward_taken)
	
	var card_reward_array: Array[DkCard] = []
	var available_cards: Array[DkCard] = character_stats.draftable_cards.duplicate_cards()
	
	for i in run_stats.card_rewards:
		_setup_card_chances()
		var roll := DkRNG.instance.randf_range(0.0, card_reward_total_weight)
		
		for rarity: DkCard.Rarity in card_rarity_weights:
			if card_rarity_weights[rarity] > roll:
				_modify_weights(rarity)
				var picked_card := _get_random_available_card(available_cards, rarity)
				card_reward_array.append(picked_card)
				available_cards.erase(picked_card)
				break

	card_rewards.rewards = card_reward_array
	card_rewards.show()


func _setup_card_chances() -> void:
	card_reward_total_weight = run_stats.common_weight + run_stats.uncommon_weight + run_stats.rare_weight
	card_rarity_weights[DkCard.Rarity.COMMON] = run_stats.common_weight
	card_rarity_weights[DkCard.Rarity.UNCOMMON] = run_stats.common_weight + run_stats.uncommon_weight
	card_rarity_weights[DkCard.Rarity.RARE] = card_reward_total_weight


func _modify_weights(rarity_rolled: DkCard.Rarity) -> void:
	if rarity_rolled == DkCard.Rarity.RARE:
		run_stats.rare_weight = DkRunStats.BASE_RARE_WEIGHT
	else:
		run_stats.rare_weight = clampf(run_stats.rare_weight + 0.3, run_stats.BASE_RARE_WEIGHT, 5.0)


func _get_random_available_card(available_cards: Array[DkCard], with_rarity: DkCard.Rarity) -> DkCard:
	var all_possible_cards := available_cards.filter(
		func(card: DkCard):
			return card.rarity == with_rarity
	)
	return DkRNG.array_pick_random(all_possible_cards)


func _on_gold_reward_taken(amount: int) -> void:
	if not run_stats:
		return
	
	run_stats.gold += amount


func _on_card_reward_taken(card: DkCard) -> void:
	if not character_stats or not card:
		return
		
	character_stats.deck.add_card(card)


func _on_relic_reward_taken(relic: DkRelic) -> void:
	if not relic or not relic_handler:
		return
		
	relic_handler.add_relic(relic)


func _on_back_button_pressed() -> void: 
	DkEvents.battle_reward_exited.emit()
