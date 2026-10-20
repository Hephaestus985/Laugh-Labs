extends Node
## [Lab Arcade] Phone controls for a match. The game was made for a mouse (left click
## selects, a left drag draws a selection box, right click gives orders, the screen
## edges and the wheel move and zoom the camera). On a phone:
##   tap your unit          select it (tap it again quickly: all of its kind on screen)
##   tap ground / an enemy  order the selected units there (move, attack, mine, build)
##   drag one finger        move the camera; two fingers: pinch to zoom
##   BOX, then drag         draw a selection box;  ALL / NONE  select the army / nothing
##   II                     the match menu
## Placing a building works as in the original: tap where it goes (drag to turn it),
## STOP stops placing. Touches that land on the game's buttons go to the buttons.
## A real mouse keeps the original controls.

const TAP_SLOP := 18.0  # finger movement (px) still counted as a tap

var box_mode := false
var _press_pos = null
var _moved := 0.0
var _touches := {}
var _multi := false
var _pinch := 0.0
var _mid := Vector2.ZERO
var _overlay: TouchOverlay
var _placement: Node = null


func _ready():
	name = "LabArcadeTouch"
	_overlay = TouchOverlay.add_to(self, {
		"small": [["II", _menu], ["BOX", toggle_box], ["ALL", select_army], ["NONE", select_none], ["STOP", cancel_placement]],
		"no_menu": true,  # the match menu (II) leads back: Exit, then Quit in the main menu
		"on_exit": RtsArcade.leave.bind(get_tree()),
		"help": "res://external/open_rts/lab_arcade_help.json",  # "?": goal, resources, units, orders
		"help_id": "open_rts",
	})
	# stay the last child, so this sees finger input before the game's own mouse handlers
	get_parent().child_entered_tree.connect(func(_n): get_parent().move_child.call_deferred(self, -1))


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()


func _placing() -> bool:
	if _placement == null or not is_instance_valid(_placement):
		var found := get_parent().find_children("StructurePlacementHandler", "", true, false)
		_placement = found[0] if not found.is_empty() else null
	return _placement != null and _placement.call("_structure_placement_started")


func _unhandled_input(event: InputEvent) -> void:
	# two fingers: pinch to zoom, move both to pan
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() >= 2:
				_multi = true
				_start_pinch()
		else:
			_touches.erase(event.index)
			if _touches.size() >= 2:
				_start_pinch()
		return
	if event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			var mid: Vector2 = ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0
			if _pinch > 1.0 and d > 1.0:
				var cam := _camera()
				cam.call("set_size_safely", cam.size * _pinch / d)
			pan(mid - _mid)
			_pinch = d
			_mid = mid
		return
	# one finger arrives as an emulated mouse: a real mouse keeps the original controls
	if not (event is InputEventMouse) or event.device != InputEvent.DEVICE_ID_EMULATION:
		return
	if _placing() or box_mode:
		if box_mode and event is InputEventMouseButton and not event.pressed:
			box_mode = false
			_update_labels()
		return  # the game's own placement / box selection handle it
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_press_pos = event.position
			_moved = 0.0
			if _touches.size() <= 1:
				_multi = false
		elif _press_pos != null:
			if not _multi and _moved < TAP_SLOP:
				tap(event.position)
			_press_pos = null
	elif event is InputEventMouseMotion and _press_pos != null:
		get_viewport().set_input_as_handled()
		if _multi:
			return
		_moved += event.relative.length()
		if _moved >= TAP_SLOP:
			pan(event.relative)


func _start_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch = (pts[0] as Vector2).distance_to(pts[1])
	_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) / 2.0


## Moves the camera so the ground follows the finger.
func pan(screen_delta: Vector2) -> void:
	var cam := _camera()
	if cam == null or screen_delta == Vector2.ZERO:
		return
	var k: float = cam.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
	# the camera looks down at 30 degrees, so the ground is twice as deep as it looks
	var move := Vector3(-screen_delta.x * k, 0, -screen_delta.y * k * 2.0).rotated(Vector3.UP, cam.rotation.y)
	cam.global_translate(move)
	cam.call("_align_position_to_bounding_planes")


func _unit_at(pos: Vector2) -> Node:
	var cam := _camera()
	var from := cam.project_ray_origin(pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(pos) * 2000.0)
	q.collide_with_areas = true
	# look through helpers that aren't units (the invisible air-navigation plane, the terrain)
	var skip: Array[RID] = []
	for i in 8:
		q.exclude = skip
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return null
		var n: Node = hit.get("collider")
		while n != null and not n.is_in_group("units"):
			n = n.get_parent()
		if n != null:
			return n
		skip.append(hit["rid"])
	return null


## A tap: select your unit, or order the selected ones.
func tap(pos: Vector2) -> void:
	var unit := _unit_at(pos)
	var selected := get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units")
	)
	if unit != null and unit.is_in_group("controlled_units"):
		var unfinished: bool = unit.has_method("is_constructed") and not unit.is_constructed()
		if not selected.is_empty() and not selected.has(unit) and unfinished:
			RtsMatchSignals.unit_targeted.emit(unit)  # workers: go and build it
		else:
			RtsUtils.Match.select_units(RtsUtils.Set.from_array([unit]))
	elif not selected.is_empty():
		if unit != null:
			RtsMatchSignals.unit_targeted.emit(unit)  # attack it / mine it
		else:
			var point = _camera().call("get_ray_intersection", pos)
			if point != null:
				RtsMatchSignals.terrain_targeted.emit(point)
	elif unit != null:
		RtsUtils.Match.select_units(RtsUtils.Set.from_array([unit]))  # just to look at it


func toggle_box() -> void:
	box_mode = not box_mode
	_update_labels()


func select_army() -> void:
	var cam := _camera()
	var army := get_tree().get_nodes_in_group("controlled_units").filter(
		func(u): return u.visible and u.has_node("Selection") and not u.has_method("is_constructed") and cam.is_position_in_frustum(u.global_position)
	)
	RtsUtils.Match.select_units(RtsUtils.Set.from_array(army))


func select_none() -> void:
	RtsMatchSignals.deselect_all_units.emit()


func cancel_placement() -> void:
	if _placing():
		_placement.call("_finish_blueprint_rotation")
		_placement.call("_cancel_structure_placement")


func _menu() -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = "rts_toggle_match_menu"
		e.pressed = down
		Input.parse_input_event(e)


func _update_labels() -> void:
	_overlay.config["small"][1][0] = "BOX on" if box_mode else "BOX"
	_overlay.layout(_overlay.laid_out_for)
