class_name DkBattle
extends Node2D

@export var battle_stats: DkBattleStats
@export var char_stats: DkCharacterStats
@export var music: AudioStream
@export var relics: DkRelicHandler

@onready var battle_ui: DkBattleUI = $BattleUI
@onready var player_handler: DkPlayerHandler = $PlayerHandler
@onready var enemy_handler: DkEnemyHandler = $EnemyHandler
@onready var player: DkPlayer = $Player


func _ready() -> void:
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	DkEvents.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	DkEvents.player_turn_ended.connect(player_handler.end_turn)
	DkEvents.player_hand_discarded.connect(enemy_handler.start_turn)
	DkEvents.player_died.connect(_on_player_died)


func start_battle() -> void:
	get_tree().paused = false
	DkMusicPlayer.play(music, true)
	
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.relics = relics
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(DkRelic.Type.START_OF_COMBAT)


func _on_enemies_child_order_changed() -> void:
	if enemy_handler.get_child_count() == 0 and is_instance_valid(relics):
		relics.activate_relics_by_type(DkRelic.Type.END_OF_COMBAT)


func _on_enemy_turn_ended() -> void:
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()


func _on_player_died() -> void:
	DkEvents.battle_over_screen_requested.emit("Game Over!", DkBattleOverPanel.Type.LOSE)
	DkSaveGame.delete_data()


func _on_relics_activated(type: DkRelic.Type) -> void:
	match type:
		DkRelic.Type.START_OF_COMBAT:
			player_handler.start_battle(char_stats)
			battle_ui.initialize_card_pile_ui()
		DkRelic.Type.END_OF_COMBAT:
			DkEvents.battle_over_screen_requested.emit("Victorious!", DkBattleOverPanel.Type.WIN)
