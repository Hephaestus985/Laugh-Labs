class_name DkMapGenerator
extends Node

const X_DIST := 30
const Y_DIST := 25
const PLACEMENT_RANDOMNESS := 5
const FLOORS := 15
const MAP_WIDTH := 7
const PATHS := 6
const MONSTER_ROOM_WEIGHT := 12.0
const EVENT_ROOM_WEIGHT := 5.0
const SHOP_ROOM_WEIGHT := 2.5
const CAMPFIRE_ROOM_WEIGHT := 4.0

@export var battle_stats_pool: DkBattleStatsPool
@export var event_room_pool: DkEventRoomPool

var random_room_type_weights = {
	DkRoom.Type.MONSTER: 0.0,
	DkRoom.Type.CAMPFIRE: 0.0,
	DkRoom.Type.SHOP: 0.0,
	DkRoom.Type.EVENT: 0.0
}
var random_room_type_total_weight := 0
var map_data: Array[Array]


func generate_map() -> Array[Array]:
	map_data = _generate_initial_grid()
	var starting_points := _get_random_starting_points()
	
	for j in starting_points:
		var current_j := j
		for i in FLOORS - 1:
			current_j = _setup_connection(i, current_j)
			
	battle_stats_pool.setup()
	
	_setup_boss_room()
	_setup_random_room_weights()
	_setup_room_types()
	
	return map_data


func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []
	
	for i in FLOORS:
		var adjacent_rooms: Array[DkRoom]= []
		
		for j in MAP_WIDTH:
			var current_room := DkRoom.new()
			var offset := Vector2(randf(), randf()) * PLACEMENT_RANDOMNESS
			current_room.position = Vector2(j * X_DIST, i * -Y_DIST) + offset
			current_room.row = i
			current_room.column = j
			current_room.next_rooms = []
			
			# Boss room has a non-random Y
			if i == FLOORS - 1:
				current_room.position.y = (i + 1) * -Y_DIST
			
			adjacent_rooms.append(current_room)
			
		result.append(adjacent_rooms)

	return result


func _get_random_starting_points() -> Array[int]:
	var y_coordinates: Array[int]
	var unique_points: int = 0
	
	while unique_points < 2:
		unique_points = 0
		y_coordinates = []

		for i in PATHS:
			var starting_point := randi_range(0, MAP_WIDTH - 1)
			if not y_coordinates.has(starting_point):
				unique_points += 1
			
			y_coordinates.append(starting_point)
		
	return y_coordinates


func _setup_connection(i: int, j: int) -> int:
	var next_room: DkRoom = null
	var current_room := map_data[i][j] as DkRoom
	
	while not next_room or _would_cross_existing_path(i, j, next_room):
		var random_j := clampi(randi_range(j - 1, j + 1), 0, MAP_WIDTH - 1)
		next_room = map_data[i + 1][random_j]
		
	current_room.next_rooms.append(next_room)
	
	return next_room.column


func _would_cross_existing_path(i: int, j: int, room: DkRoom) -> bool:
	var left_neighbour: DkRoom
	var right_neighbour: DkRoom
	
	# if j == 0, there's no left neighbour
	if j > 0:
		left_neighbour = map_data[i][j - 1]
	# if j == MAP_WIDTH - 1, there's no right neighbour
	if j < MAP_WIDTH - 1:
		right_neighbour = map_data[i][j + 1]
	
	# can't cross in right dir if right neighbour goes to left
	if right_neighbour and room.column > j:
		for next_room: DkRoom in right_neighbour.next_rooms:
			if next_room.column < room.column:
				return true
	
	# can't cross in left dir if left neighbour goes to right
	if left_neighbour and room.column < j:
		for next_room: DkRoom in left_neighbour.next_rooms:
			if next_room.column > room.column:
				return true
	
	return false


func _setup_boss_room() -> void:
	var middle := floori(MAP_WIDTH * 0.5)
	var boss_room := map_data[FLOORS - 1][middle] as DkRoom
	
	for j in MAP_WIDTH:
		var current_room = map_data[FLOORS - 2][j] as DkRoom
		if current_room.next_rooms:
			current_room.next_rooms = [] as Array[DkRoom]
			current_room.next_rooms.append(boss_room)
			
	boss_room.type = DkRoom.Type.BOSS
	boss_room.battle_stats = battle_stats_pool.get_random_battle_for_tier(2)


func _setup_random_room_weights() -> void:
	random_room_type_weights[DkRoom.Type.MONSTER] = MONSTER_ROOM_WEIGHT
	random_room_type_weights[DkRoom.Type.CAMPFIRE] = MONSTER_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT
	random_room_type_weights[DkRoom.Type.SHOP] = MONSTER_ROOM_WEIGHT + CAMPFIRE_ROOM_WEIGHT + SHOP_ROOM_WEIGHT
	random_room_type_weights[DkRoom.Type.EVENT] = random_room_type_weights[DkRoom.Type.SHOP] + EVENT_ROOM_WEIGHT
	
	random_room_type_total_weight = random_room_type_weights[DkRoom.Type.EVENT]


func _setup_room_types() -> void:
	# first floor is always a battle
	for room: DkRoom in map_data[0]:
		if room.next_rooms.size() > 0:
				room.type = DkRoom.Type.MONSTER
				room.battle_stats = battle_stats_pool.get_random_battle_for_tier(0)

	# 9th floor is always a treasure
	for room: DkRoom in map_data[8]:
		if room.next_rooms.size() > 0:
				room.type = DkRoom.Type.TREASURE
				
	# last floor before the boss is always a campfire
	for room: DkRoom in map_data[13]:
		if room.next_rooms.size() > 0:
				room.type = DkRoom.Type.CAMPFIRE
	
	# rest of rooms
	for current_floor in map_data:
		for room: DkRoom in current_floor:
			for next_room: DkRoom in room.next_rooms:
				if next_room.type == DkRoom.Type.NOT_ASSIGNED:
					_set_room_randomly(next_room)


func _set_room_randomly(room_to_set: DkRoom) -> void:
	var campfire_below_4 := true
	var consecutive_campfire := true
	var consecutive_shop := true
	var campfire_on_13 := true
	
	var type_candidate: DkRoom.Type
	
	while campfire_below_4 or consecutive_campfire or consecutive_shop or campfire_on_13:
		type_candidate = _get_random_room_type_by_weight()
		
		var is_campfire := type_candidate == DkRoom.Type.CAMPFIRE
		var has_campfire_parent := _room_has_parent_of_type(room_to_set, DkRoom.Type.CAMPFIRE)
		var is_shop := type_candidate == DkRoom.Type.SHOP
		var has_shop_parent := _room_has_parent_of_type(room_to_set, DkRoom.Type.SHOP)
		
		campfire_below_4 = is_campfire and room_to_set.row < 3
		consecutive_campfire = is_campfire and has_campfire_parent
		consecutive_shop = is_shop and has_shop_parent
		campfire_on_13 = is_campfire and room_to_set.row == 12
		
	room_to_set.type = type_candidate

	if type_candidate == DkRoom.Type.MONSTER:
		var tier_for_monster_rooms := 0
		
		if room_to_set.row > 2:
			tier_for_monster_rooms = 1
			
		room_to_set.battle_stats = battle_stats_pool.get_random_battle_for_tier(tier_for_monster_rooms)
	
	if type_candidate == DkRoom.Type.EVENT:
		room_to_set.event_scene = event_room_pool.get_random()


func _room_has_parent_of_type(room: DkRoom, type: DkRoom.Type) -> bool:
	var parents: Array[DkRoom] = []
	# left parent
	if room.column > 0 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column - 1] as DkRoom
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	# parent below
	if room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column] as DkRoom
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	# right parent
	if room.column < MAP_WIDTH-1 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column + 1] as DkRoom
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	
	for parent: DkRoom in parents:
		if parent.type == type:
			return true
	
	return false


func _get_random_room_type_by_weight() -> DkRoom.Type:
	var roll := randf_range(0.0, random_room_type_total_weight)
	
	for type: DkRoom.Type in random_room_type_weights:
		if random_room_type_weights[type] > roll:
			return type
	
	return DkRoom.Type.MONSTER
