extends CanvasLayer

const Human = preload("res://external/open_rts/source/match/players/human/Human.gd")

@onready var _victory_tile = find_child("Victory")
@onready var _defeat_tile = find_child("Defeat")
@onready var _finish_tile = find_child("Finish")


func _ready():
	if not RtsFeatureFlags.handle_match_end:
		queue_free()
		return
	hide()
	_victory_tile.hide()
	_defeat_tile.hide()
	_finish_tile.hide()
	await find_parent("Match").ready
	RtsMatchSignals.setup_and_spawn_unit.connect(_on_new_unit)
	for unit in get_tree().get_nodes_in_group("units"):
		unit.tree_exited.connect(_on_unit_tree_exited)


func _handle_defeat():
	_defeat_tile.show()
	_show()
	RtsMatchSignals.match_finished_with_defeat.emit()


func _handle_victory():
	_victory_tile.show()
	_show()
	RtsMatchSignals.match_finished_with_victory.emit()


func _handle_finish():
	_finish_tile.show()
	_show()


func _show():
	show()
	get_tree().paused = true


func _on_new_unit(unit, _transform, _player):
	unit.tree_exited.connect(_on_unit_tree_exited)


func _on_unit_tree_exited():
	if visible or not is_inside_tree():
		return
	var players = RtsUtils.Set.new()
	for unit in get_tree().get_nodes_in_group("units"):
		players.add(unit.player)
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	if not human_players.is_empty() and not players.has(human_players[0]):
		_handle_defeat()
	elif not human_players.is_empty() and players.has(human_players[0]) and players.size() == 1:
		_handle_victory()
	elif players.size() == 1:
		_handle_finish()


func _on_exit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://external/open_rts/source/main-menu/Main.tscn")
