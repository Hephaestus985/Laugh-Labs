
var templates = {
    'building_lost' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/building_lost.gd"),
    'turn' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/turn.gd"),
    'move' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/move.gd"),
    'deploy' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/deploy.gd"),
    'claim' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/claim.gd"),
    'decimate' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/decimate.gd"),
    'assassination' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/assassination.gd"),
    'attacked' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/attacked.gd"),
    'resources' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/resources.gd"),
    'ability' : preload("res://external/tanks_of_freedom/scenes/board/logic/scripting/triggers/ability.gd"),
}

func get_trigger(name):
    return self.templates[name].new()
    
