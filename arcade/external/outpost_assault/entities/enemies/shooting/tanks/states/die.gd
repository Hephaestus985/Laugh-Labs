extends "res://external/outpost_assault/entities/enemies/shooting/states/die.gd"


func enter() -> void:
	super()
	(owner as Tank).explosion.play("default")
