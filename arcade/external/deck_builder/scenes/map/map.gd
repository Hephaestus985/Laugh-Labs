class_name DkMap
extends Node2D

const SCROLL_SPEED := 15
const MAP_ROOM = preload("res://external/deck_builder/scenes/map/map_room.tscn")
const MAP_LINE = preload("res://external/deck_builder/scenes/map/map_line.tscn")

@onready var map_generator: DkMapGenerator = $MapGenerator
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var visuals: Node2D = $Visuals
@onready var camera_2d: Camera2D = $Camera2D

var map_data: Array[Array]
var floors_climbed: int
var last_room: DkRoom
var camera_edge_y: float


func _ready() -> void:
	camera_edge_y = DkMapGenerator.Y_DIST * (DkMapGenerator.FLOORS - 1)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	# [Lab Arcade] drag the map with a finger (the original only scrolled with the wheel)
	if event is InputEventScreenDrag:
		camera_2d.position.y -= event.relative.y
	elif event.is_action_pressed("deck_scroll_up"):
		camera_2d.position.y -= SCROLL_SPEED
	elif event.is_action_pressed("deck_scroll_down"):
		camera_2d.position.y += SCROLL_SPEED

	camera_2d.position.y = clamp(camera_2d.position.y, -camera_edge_y, 0)


func generate_new_map() -> void:
	floors_climbed = 0
	map_data = map_generator.generate_map()
	create_map()


func load_map(map: Array[Array], floors_completed: int, last_room_climbed: DkRoom) -> void:
	floors_climbed = floors_completed
	map_data = map
	last_room = last_room_climbed
	create_map()
	
	if floors_climbed > 0:
		unlock_next_rooms()
	else:
		unlock_floor()


func create_map() -> void:
	for current_floor: Array in map_data:
		for room: DkRoom in current_floor:
			if room.next_rooms.size() > 0:
				_spawn_room(room)
	
	# Boss room has no next room but we need to spawn it
	var middle := floori(DkMapGenerator.MAP_WIDTH * 0.5)
	_spawn_room(map_data[DkMapGenerator.FLOORS-1][middle])

	var map_width_pixels := DkMapGenerator.X_DIST * (DkMapGenerator.MAP_WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = get_viewport_rect().size.y / 2


func unlock_floor(which_floor: int = floors_climbed) -> void:
	for map_room: DkMapRoom in rooms.get_children():
		if map_room.room.row == which_floor:
			map_room.available = true


func unlock_next_rooms() -> void:
	for map_room: DkMapRoom in rooms.get_children():
		if last_room.next_rooms.has(map_room.room):
			map_room.available = true


func show_map() -> void:
	show()
	camera_2d.enabled = true


func hide_map() -> void:
	hide()
	camera_2d.enabled = false


func _spawn_room(room: DkRoom) -> void:
	var new_map_room := MAP_ROOM.instantiate() as DkMapRoom
	rooms.add_child(new_map_room)
	new_map_room.room = room
	new_map_room.clicked.connect(_on_map_room_clicked)
	new_map_room.selected.connect(_on_map_room_selected)
	_connect_lines(room)
	
	if room.selected and room.row < floors_climbed:
		new_map_room.show_selected()


func _connect_lines(room: DkRoom) -> void:
	if room.next_rooms.is_empty():
		return
		
	for next: DkRoom in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.add_point(room.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)


func _on_map_room_clicked(room: DkRoom) -> void:
	for map_room: DkMapRoom in rooms.get_children():
		if map_room.room.row == room.row:
			map_room.available = false


func _on_map_room_selected(room: DkRoom) -> void:
	last_room = room
	floors_climbed += 1
	DkEvents.map_exited.emit(room)
