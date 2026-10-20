class_name DkStatsUI
extends HBoxContainer

@onready var block: HBoxContainer = $Block
@onready var block_label: Label = %BlockLabel
@onready var health: DkHealthUI = $Health


func update_stats(stats: DkStats) -> void:
	block_label.text = str(stats.block)
	health.update_stats(stats)
	
	block.visible = stats.block > 0
	health.visible = stats.health > 0
