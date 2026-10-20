extends Node3D

@export var structures: Array[CityStructure] = []

var map:CityDataMap

var index:int = 0 # Index of structure being built

@export var selector:Node3D # The 'cursor'
@export var selector_container:Node3D # Node that holds a preview of the structure
@export var view_camera:Camera3D # Used for raycasting mouse
@export var gridmap:GridMap
@export var cash_display:Label

var plane:Plane # Used for raycasting mouse

# [Lab Arcade] phone controls and saving. Tap a square to build the selected piece
# there (or remove what's there in REMOVE mode); < and > pick the piece, TURN
# rotates it. The city saves itself after every change (as plain JSON, not a
# Godot resource, so a save file can't carry code) and comes back next time.
const SAVE_PATH := "user://city_builder.json"
var removing := false
var overlay: TouchOverlay
var piece_label: Label
var sfx: Node
var cursor := Vector3.ZERO
var confirm_new := false
var mouse_hover := false  # a real mouse moves the cursor, like the original

func _ready():

	map = CityDataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	sfx = $"../CityAudio"

	# Create new MeshLibrary dynamically, can also be done in the editor
	# See: https://docs.godotengine.org/en/stable/tutorials/3d/using_gridmaps.html

	var mesh_library = MeshLibrary.new()

	for structure in structures:

		var id = mesh_library.get_last_unused_item_id()

		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		mesh_library.set_item_mesh_transform(id, Transform3D())

	gridmap.mesh_library = mesh_library

	_setup_phone_ui()
	if Engine.get_meta("launch_mode", "") == "new":  # "New game" on the start screen
		DirAccess.remove_absolute(SAVE_PATH)
	load_city()
	update_structure()
	update_cash()

func _process(delta):

	# Map position: the last square tapped, or under a real mouse

	if mouse_hover:
		var world_position = plane.intersects_ray(
			view_camera.project_ray_origin(get_viewport().get_mouse_position()),
			view_camera.project_ray_normal(get_viewport().get_mouse_position()))
		if world_position != null:
			cursor = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = lerp(selector.position, cursor, min(delta * 40, 1.0))

func _unhandled_input(event):
	# [Lab Arcade] keyboard: Q / E pick the piece, R turns it, Delete removes
	if event is InputEventMouseMotion:
		mouse_hover = event.device != InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventScreenTouch:
		mouse_hover = false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: pick(1)
			KEY_Q: pick(-1)
			KEY_R: action_rotate()
			KEY_DELETE: action_demolish(cursor)

# Retrieve the mesh from a PackedScene, used for dynamically creating a MeshLibrary

func get_mesh(packed_scene):
	var scene_state:SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)

					return prop_value.duplicate()

# [Lab Arcade] a tap on the ground: build or remove on that square
func tap(screen_position: Vector2):
	var world_position = plane.intersects_ray(
		view_camera.project_ray_origin(screen_position),
		view_camera.project_ray_normal(screen_position))
	if world_position == null:
		return
	cursor = Vector3(round(world_position.x), 0, round(world_position.z))
	selector.position = cursor
	if removing:
		action_demolish(cursor)
	else:
		action_build(cursor)

# Build (place) a structure

func action_build(gridmap_position):
	var previous_tile = gridmap.get_cell_item(gridmap_position)
	var orientation = gridmap.get_orthogonal_index_from_basis(selector.basis)
	if previous_tile == index and gridmap.get_cell_item_orientation(gridmap_position) == orientation:
		return
	gridmap.set_cell_item(gridmap_position, index, orientation)

	if previous_tile != index:
		map.cash -= structures[index].price
		update_cash()

	sfx.play("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)
	save_city()

# Demolish (remove) a structure

func action_demolish(gridmap_position):
	if gridmap.get_cell_item(gridmap_position) != -1:
		gridmap.set_cell_item(gridmap_position, -1)

		sfx.play("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)
		save_city()

# Rotates the 'cursor' 90 degrees

func action_rotate():
	selector.rotate_y(deg_to_rad(90))

	sfx.play("sounds/rotate.ogg", -30)

# Toggle between structures to build

func pick(step: int):
	index = wrap(index + step, 0, structures.size())
	removing = false
	sfx.play("sounds/toggle.ogg", -30)
	update_structure()

# Update the structure visual in the 'cursor'

func update_structure():
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		n.queue_free()

	# Create new structure preview in selector
	if not removing:
		var _model = structures[index].model.instantiate()
		selector_container.add_child(_model)
		_model.position.y += 0.25
	_update_labels()

func update_cash():
	cash_display.text = "$" + str(map.cash)

# ---------------------------------------------------------------- [Lab Arcade] saving

func save_city():
	var cells := []
	for cell in gridmap.get_used_cells():
		cells.append([cell.x, cell.z, gridmap.get_cell_item(cell), gridmap.get_cell_item_orientation(cell)])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"info": "%d pieces built" % cells.size(), "cash": map.cash, "cells": cells}))

func load_city():
	gridmap.clear()
	map = CityDataMap.new()
	if not FileAccess.file_exists(SAVE_PATH):
		_starter_land()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		return
	map.cash = int(data.get("cash", map.cash))
	for c in data.get("cells", []):
		if c is Array and c.size() == 4:
			var item := int(c[2])
			if item >= 0 and item < structures.size():
				gridmap.set_cell_item(Vector3i(int(c[0]), 0, int(c[1])), item, int(c[3]))

# [Lab Arcade] a new city starts on a piece of land (grass with some trees around the
# edge), so there's ground to build on instead of an empty grey void; building on a
# square replaces the grass, as in the original
const LAND := 7  # squares from the middle to the edge
func _starter_land():
	var grass := _structure_index("grass")
	var trees := _structure_index("grass-trees")
	var tall := _structure_index("grass-trees-tall")
	if grass < 0:
		return
	for x in range(-LAND, LAND + 1):
		for z in range(-LAND, LAND + 1):
			var edge := maxi(absi(x), absi(z)) == LAND
			var item := grass
			if edge and (x * 7 + z * 3) % 4 == 0:
				item = tall if (x + z) % 2 == 0 else trees
			gridmap.set_cell_item(Vector3i(x, 0, z), item, 0)

func _structure_index(model_name: String) -> int:
	for i in structures.size():
		if structures[i].model.resource_path.get_file().get_basename() == model_name:
			return i
	return -1

func new_city():
	if not confirm_new:
		confirm_new = true
		_update_labels()
		return
	confirm_new = false
	DirAccess.remove_absolute(SAVE_PATH)
	load_city()
	update_cash()
	_update_labels()

# ---------------------------------------------------------------- [Lab Arcade] phone UI

func _setup_phone_ui():
	var view = view_camera.get_parent()
	view.tapped.connect(tap)
	overlay = TouchOverlay.add_to(self, {
		"small": [["NEW", new_city], ["DEL", toggle_remove], ["TURN", action_rotate], [">", pick.bind(1)], ["<", pick.bind(-1)]],
	})
	piece_label = Label.new()
	piece_label.name = "Piece"
	piece_label.add_theme_font_override("font", cash_display.label_settings.font)
	piece_label.add_theme_font_size_override("font_size", 26)
	piece_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	piece_label.add_theme_constant_override("shadow_offset_y", 3)
	piece_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	piece_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	piece_label.offset_left = -700
	piece_label.offset_right = -40
	piece_label.offset_top = 196
	piece_label.offset_bottom = 300
	piece_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cash_display.get_parent().get_parent().add_child(piece_label)
	# the cash moves below "< MENU"
	cash_display.get_parent().position.y = 80

func toggle_remove():
	removing = not removing
	sfx.play("sounds/toggle.ogg", -30)
	update_structure()

func _update_labels():
	if piece_label == null:
		return
	if confirm_new:
		piece_label.text = "Tap NEW again to clear the whole city"
	elif removing:
		piece_label.text = "REMOVE: tap a square to clear it\n(DEL again to build)"
	else:
		var s: CityStructure = structures[index]
		var nm := s.model.resource_path.get_file().get_basename().replace("-", " ").capitalize()
		piece_label.text = "%s  $%d\nTap a square to build" % [nm, s.price]
	if overlay:
		overlay.config["small"][1][0] = "BUILD" if removing else "DEL"
		overlay.layout(overlay.laid_out_for)
