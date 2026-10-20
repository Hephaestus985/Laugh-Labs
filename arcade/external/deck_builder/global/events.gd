extends Node

# Card-related events
signal card_drag_started(card_ui: DkCardUI)
signal card_drag_ended(card_ui: DkCardUI)
signal card_aim_started(card_ui: DkCardUI)
signal card_aim_ended(card_ui: DkCardUI)
signal card_played(card: DkCard)
signal card_tooltip_requested(card: DkCard)
signal tooltip_hide_requested

# Player-related events
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended
signal player_hit
signal player_died

# Enemy-related events
signal enemy_action_completed(enemy: DkEnemy)
signal enemy_turn_ended
signal enemy_died(enemy: DkEnemy)

# Battle-related events
signal battle_over_screen_requested(text: String, type: DkBattleOverPanel.Type)
signal battle_won
signal status_tooltip_requested(statuses: Array[DkStatus])

# Map-related events
signal map_exited(room: DkRoom)

# Shop-related events
signal shop_entered(shop: DkShop)
signal shop_relic_bought(relic: DkRelic, gold_cost: int)
signal shop_card_bought(card: DkCard, gold_cost: int)
signal shop_exited

# Campfire-related events
signal campfire_exited

# Battle Reward-related events
signal battle_reward_exited

# Treasure Room-related events
signal treasure_room_exited(found_relic: DkRelic)

# Relic-related events
signal relic_tooltip_requested(relic: DkRelic)

# Random Event room-related events
signal event_room_exited
