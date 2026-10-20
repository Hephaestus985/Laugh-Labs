class_name DkRun
extends Node

const BATTLE_SCENE := preload("res://external/deck_builder/scenes/battle/battle.tscn")
const BATTLE_REWARD_SCENE := preload("res://external/deck_builder/scenes/battle_reward/battle_reward.tscn")
const CAMPFIRE_SCENE := preload("res://external/deck_builder/scenes/campfire/campfire.tscn")
const SHOP_SCENE := preload("res://external/deck_builder/scenes/shop/shop.tscn")
const TREASURE_SCENE = preload("res://external/deck_builder/scenes/treasure/treasure.tscn")
const WIN_SCREEN_SCENE := preload("res://external/deck_builder/scenes/win_screen/win_screen.tscn")
const MAIN_MENU_PATH := "res://external/deck_builder/scenes/ui/main_menu.tscn"

@export var run_startup: DkRunStartup

@onready var map: DkMap = $Map
@onready var current_view: Node = $CurrentView
@onready var health_ui: DkHealthUI = %HealthUI
@onready var gold_ui: DkGoldUI = %GoldUI
@onready var relic_handler: DkRelicHandler = %RelicHandler
@onready var relic_tooltip: DkRelicTooltip = %RelicTooltip
@onready var deck_button: DkCardPileOpener = %DeckButton
@onready var deck_view: DkCardPileView = %DeckView
@onready var pause_menu: DkPauseMenu = $PauseMenu

@onready var battle_button: Button = %BattleButton
@onready var campfire_button: Button = %CampfireButton
@onready var map_button: Button = %MapButton
@onready var rewards_button: Button = %RewardsButton
@onready var shop_button: Button = %ShopButton
@onready var treasure_button: Button = %TreasureButton

var stats: DkRunStats
var character: DkCharacterStats
var save_data: DkSaveGame


func _ready() -> void:
	DkArcade.setup(self, true)  # [Lab Arcade] screen size, back and pause buttons
	if not run_startup:
		return
	
	pause_menu.save_and_quit.connect(
		func(): 
			get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)
	
	match run_startup.type:
		DkRunStartup.Type.NEW_RUN:
			character = run_startup.picked_character.create_instance()
			_start_run()
		DkRunStartup.Type.CONTINUED_RUN:
			_load_run()


func _start_run() -> void:
	stats = DkRunStats.new()
	
	_setup_event_connections()
	_setup_top_bar()
	
	map.generate_new_map()
	map.unlock_floor(0)
	
	save_data = DkSaveGame.new()
	_save_run(true)


func _save_run(was_on_map: bool) -> void:
	save_data.rng_seed = DkRNG.instance.seed
	save_data.rng_state = DkRNG.instance.state
	save_data.run_stats = stats
	save_data.char_stats = character
	save_data.current_deck = character.deck
	save_data.current_health = character.health
	save_data.relics = relic_handler.get_all_relics()
	save_data.last_room = map.last_room
	save_data.map_data = map.map_data.duplicate()
	save_data.floors_climbed = map.floors_climbed
	save_data.was_on_map = was_on_map
	save_data.save_data()


func _load_run() -> void:
	save_data = DkSaveGame.load_data()
	assert(save_data, "Couldn't load last save")
	
	DkRNG.set_from_save_data(save_data.rng_seed, save_data.rng_state)
	stats = save_data.run_stats
	character = save_data.char_stats
	character.deck = save_data.current_deck
	character.health = save_data.current_health
	relic_handler.add_relics(save_data.relics)
	_setup_top_bar()
	_setup_event_connections()
	
	map.load_map(save_data.map_data, save_data.floors_climbed, save_data.last_room)
	if save_data.last_room and not save_data.was_on_map:
		_on_map_exited(save_data.last_room)


func _change_view(scene: PackedScene) -> Node:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()
	
	get_tree().paused = false
	var new_view := scene.instantiate()
	current_view.add_child(new_view)
	map.hide_map()
	
	return new_view


func _show_map() -> void:
	if current_view.get_child_count() > 0:
		current_view.get_child(0).queue_free()

	map.show_map()
	map.unlock_next_rooms()
	
	_save_run(true)


func _setup_event_connections() -> void:
	DkEvents.battle_won.connect(_on_battle_won)
	DkEvents.battle_reward_exited.connect(_show_map)
	DkEvents.campfire_exited.connect(_show_map)
	DkEvents.map_exited.connect(_on_map_exited)
	DkEvents.shop_exited.connect(_show_map)
	DkEvents.treasure_room_exited.connect(_on_treasure_room_exited)
	DkEvents.event_room_exited.connect(_show_map)
	
	battle_button.pressed.connect(_change_view.bind(BATTLE_SCENE))
	campfire_button.pressed.connect(_change_view.bind(CAMPFIRE_SCENE))
	map_button.pressed.connect(_show_map)
	rewards_button.pressed.connect(_change_view.bind(BATTLE_REWARD_SCENE))
	shop_button.pressed.connect(_change_view.bind(SHOP_SCENE))
	treasure_button.pressed.connect(_change_view.bind(TREASURE_SCENE))


func _setup_top_bar():
	character.stats_changed.connect(health_ui.update_stats.bind(character))
	health_ui.update_stats(character)
	gold_ui.run_stats = stats
	
	relic_handler.add_relic(character.starting_relic)
	DkEvents.relic_tooltip_requested.connect(relic_tooltip.show_tooltip)
	
	deck_button.card_pile = character.deck
	deck_view.card_pile = character.deck
	deck_button.pressed.connect(deck_view.show_current_view.bind("Deck"))


func _show_regular_battle_rewards() -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as DkBattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character

	reward_scene.add_gold_reward(map.last_room.battle_stats.roll_gold_reward())
	reward_scene.add_card_reward()


func _on_battle_room_entered(room: DkRoom) -> void:
	var battle_scene: DkBattle = _change_view(BATTLE_SCENE) as DkBattle
	battle_scene.char_stats = character
	battle_scene.battle_stats = room.battle_stats
	battle_scene.relics = relic_handler
	battle_scene.start_battle()


func _on_treasure_room_entered() -> void:
	var treasure_scene := _change_view(TREASURE_SCENE) as DkTreasure
	treasure_scene.relic_handler = relic_handler
	treasure_scene.char_stats = character
	treasure_scene.generate_relic()


func _on_treasure_room_exited(relic: DkRelic) -> void:
	var reward_scene := _change_view(BATTLE_REWARD_SCENE) as DkBattleReward
	reward_scene.run_stats = stats
	reward_scene.character_stats = character
	reward_scene.relic_handler = relic_handler
	
	reward_scene.add_relic_reward(relic)


func _on_campfire_entered() -> void:
	var campfire := _change_view(CAMPFIRE_SCENE) as DkCampfire
	campfire.char_stats = character


func _on_shop_entered() -> void:
	var shop := _change_view(SHOP_SCENE) as DkShop
	shop.char_stats = character
	shop.run_stats = stats
	shop.relic_handler = relic_handler
	DkEvents.shop_entered.emit(shop)
	shop.populate_shop()


func _on_event_room_entered(room: DkRoom) -> void:
	var event_room := _change_view(room.event_scene) as DkEventRoom
	event_room.character_stats = character
	event_room.run_stats = stats
	event_room.setup()


func _on_battle_won() -> void:
	if map.floors_climbed == DkMapGenerator.FLOORS:
		var win_screen := _change_view(WIN_SCREEN_SCENE) as DkWinScreen
		win_screen.character = character
		DkSaveGame.delete_data()
	else:
		_show_regular_battle_rewards()


func _on_map_exited(room: DkRoom) -> void:
	_save_run(false)
	
	match room.type:
		DkRoom.Type.MONSTER:
			_on_battle_room_entered(room)
		DkRoom.Type.TREASURE:
			_on_treasure_room_entered()
		DkRoom.Type.CAMPFIRE:
			_on_campfire_entered()
		DkRoom.Type.SHOP:
			_on_shop_entered()
		DkRoom.Type.BOSS:
			_on_battle_room_entered(room)
		DkRoom.Type.EVENT:
			_on_event_room_entered(room)
