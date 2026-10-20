class_name DkCardState
extends Node

enum State {BASE, CLICKED, DRAGGING, AIMING, RELEASED}

signal transition_requested(from: DkCardState, to: int)

# [Lab Arcade] typed as int: "State" alone means another game's global class inside the arcade
@export_enum("BASE", "CLICKED", "DRAGGING", "AIMING", "RELEASED") var state: int

var card_ui: DkCardUI


func enter() -> void:
	pass


func exit() -> void:
	pass


func post_enter() -> void:
	pass


func on_input(_event: InputEvent) -> void:
	pass


func on_gui_input(_event: InputEvent) -> void:
	pass


func on_mouse_entered() -> void:
	pass


func on_mouse_exited() -> void:
	pass
