extends "res://external/tanks_of_freedom/scenes/abilities/production/heroes/hero.gd"

func _execute(board, position):
    super._execute(board, position)

    var units = board.map.model.get_player_units(board.state.get_current_side())
    for unit in units:
        board.abilities.apply_passive_modifiers(unit)
