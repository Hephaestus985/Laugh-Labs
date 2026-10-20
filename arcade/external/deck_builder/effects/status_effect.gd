class_name DkStatusEffect
extends DkEffect

var status: DkStatus


func execute(targets: Array[Node]) -> void:
	for target in targets:
		if not target:
			continue
		if target is DkEnemy or target is DkPlayer:
			target.status_handler.add_status(status.duplicate())
