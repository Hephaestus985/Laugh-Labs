extends Node
## [Lab Arcade] Two fingers pinch to zoom the board (the game zooms with the mouse wheel,
## or with Android's own pinch gesture, which the arcade leaves off for the other games).

var _touches := {}
var _distance := 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_distance = _spread()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		var d := _spread()
		if _distance > 1.0 and d > 1.0:
			var map = get_parent().get("map")
			if map and map.camera:
				map.camera._mouse_zoom((_distance - d) * 0.05)
		_distance = d


func _spread() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])
