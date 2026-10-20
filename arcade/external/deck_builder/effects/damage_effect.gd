class_name DkDamageEffect
extends DkEffect

var amount := 0
var receiver_modifier_type := DkModifier.Type.DMG_TAKEN


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is DkEnemy or target is DkPlayer:
			target.take_damage(amount, receiver_modifier_type)
			DkSFXPlayer.play(sound)
