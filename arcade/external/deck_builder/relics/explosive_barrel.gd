extends DkRelic

@export var damage := 2


func activate_relic(owner: DkRelicUI) -> void:
	var enemies := owner.get_tree().get_nodes_in_group("enemies")
	var damage_effect := DkDamageEffect.new()
	damage_effect.amount = damage
	damage_effect.receiver_modifier_type = DkModifier.Type.NO_MODIFIER
	damage_effect.execute(enemies)
	
	owner.flash()
