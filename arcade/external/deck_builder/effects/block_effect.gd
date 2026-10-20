class_name DkBlockEffect
extends DkEffect

var amount := 0


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is DkEnemy or target is DkPlayer:
			target.stats.block += amount
			DkSFXPlayer.play(sound)
