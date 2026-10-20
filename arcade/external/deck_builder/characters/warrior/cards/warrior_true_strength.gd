extends DkCard

const TRUE_STRENGTH_FORM_STATUS = preload("res://external/deck_builder/statuses/true_strength_form.tres")


func apply_effects(targets: Array[Node], _modifiers: DkModifierHandler) -> void:
	var status_effect := DkStatusEffect.new()
	var true_strength := TRUE_STRENGTH_FORM_STATUS.duplicate()
	status_effect.status = true_strength
	status_effect.execute(targets)
