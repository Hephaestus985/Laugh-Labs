class_name DkMapRoom
extends Area2D

signal clicked(room: DkRoom)
signal selected(room: DkRoom)

const ICONS := {
	DkRoom.Type.NOT_ASSIGNED: [null, Vector2.ONE],
	DkRoom.Type.MONSTER: [preload("res://external/deck_builder/art/tile_0103.png"), Vector2.ONE],
	DkRoom.Type.TREASURE: [preload("res://external/deck_builder/art/tile_0089.png"), Vector2.ONE],
	DkRoom.Type.CAMPFIRE: [preload("res://external/deck_builder/art/player_heart.png"), Vector2(0.6, 0.6)],
	DkRoom.Type.SHOP: [preload("res://external/deck_builder/art/gold.png"), Vector2(0.6, 0.6)],
	DkRoom.Type.BOSS: [preload("res://external/deck_builder/art/tile_0105.png"), Vector2(1.25, 1.25)],
	DkRoom.Type.EVENT: [preload("res://external/deck_builder/art/rarity.png"), Vector2(0.9, 0.9)],
}

@onready var sprite_2d: Sprite2D = $Visuals/Sprite2D
@onready var line_2d: Line2D = $Visuals/Line2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var available := false : set = set_available
var room: DkRoom : set = set_room


func set_available(new_value: bool) -> void:
	available = new_value
	
	if available:
		animation_player.play("highlight")
	elif not room.selected:
		animation_player.play("RESET")


func set_room(new_data: DkRoom) -> void:
	room = new_data
	position = room.position
	line_2d.rotation_degrees = randi_range(0, 360)
	sprite_2d.texture = ICONS[room.type][0]
	sprite_2d.scale = ICONS[room.type][1]


func show_selected() -> void:
	line_2d.modulate = Color.WHITE


# [Lab Arcade] a room is picked when the finger lifts without having moved, so
# dragging the map from a room scrolls instead of entering it
var _press_at := Vector2.INF


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available:
		return
	if event.is_action_pressed("deck_left_mouse"):
		_press_at = event.position
		return
	if not event.is_action_released("deck_left_mouse") or _press_at == Vector2.INF:
		return
	var moved: float = (event.position as Vector2).distance_to(_press_at)
	_press_at = Vector2.INF
	if moved > 4.0:
		return

	room.selected = true
	clicked.emit(room)
	animation_player.play("select")


# Called by the AnimationPLayer when the 
# "select" animation finishes.
func _on_map_room_selected() -> void:
	selected.emit(room)
