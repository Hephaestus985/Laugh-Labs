extends DkRelic

@export var skills_required := 3
@export var damage := 5

var relic_ui: DkRelicUI
var skills_this_turn: int


func initialize_relic(owner: DkRelicUI) -> void:
	relic_ui = owner
	DkEvents.player_hand_drawn.connect(_reset)
	DkEvents.map_exited.connect(_reset.unbind(1))
	DkEvents.card_played.connect(_on_card_played)


func deactivate_relic(_owner: DkRelicUI) -> void:
	DkEvents.player_hand_drawn.disconnect(_reset)
	DkEvents.map_exited.disconnect(_reset)
	DkEvents.card_played.disconnect(_on_card_played)


func _reset() -> void:
	skills_this_turn = 0


func _on_card_played(card: DkCard) -> void:
	if card.type != DkCard.Type.SKILL:
		return
	
	skills_this_turn += 1
	
	if skills_this_turn % skills_required == 0:
		var enemies := relic_ui.get_tree().get_nodes_in_group("enemies")
		var damage_effect := DkDamageEffect.new()
		damage_effect.amount = damage
		damage_effect.receiver_modifier_type = DkModifier.Type.NO_MODIFIER
		damage_effect.execute(enemies)
		
		relic_ui.flash()
		skills_this_turn = 0
