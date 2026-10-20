class_name DkRelicHandler
extends HBoxContainer

signal relics_activated(type: DkRelic.Type)

const RELIC_APPLY_INTERVAL := 0.5
const RELIC_UI = preload("res://external/deck_builder/scenes/relic_handler/relic_ui.tscn")

@onready var relics_control: DkRelicsControl = $RelicsControl
@onready var relics: HBoxContainer = %Relics


func _ready() -> void:
	relics.child_exiting_tree.connect(_on_relics_child_exiting_tree)


func activate_relics_by_type(type: DkRelic.Type) -> void:
	if type == DkRelic.Type.EVENT_BASED:
		return
		
	var relic_queue: Array[DkRelicUI] = _get_all_relic_ui_nodes().filter(
		func(relic_ui: DkRelicUI):
			return relic_ui.relic.type == type
	)
	if relic_queue.is_empty():
		relics_activated.emit(type)
		return
	
	var tween := create_tween()
	for relic_ui: DkRelicUI in relic_queue:
		tween.tween_callback(relic_ui.relic.activate_relic.bind(relic_ui))
		tween.tween_interval(RELIC_APPLY_INTERVAL)
	
	tween.finished.connect(func(): relics_activated.emit(type))


func add_relics(relics_array: Array[DkRelic]) -> void:
	for relic: DkRelic in relics_array:
		add_relic(relic)


func add_relic(relic: DkRelic) -> void:
	if has_relic(relic.id):
		return
	
	var new_relic_ui := RELIC_UI.instantiate() as DkRelicUI
	relics.add_child(new_relic_ui)
	new_relic_ui.relic = relic
	new_relic_ui.relic.initialize_relic(new_relic_ui)


func has_relic(id: String) -> bool:
	for relic_ui: DkRelicUI in relics.get_children():
		if relic_ui.relic.id == id and is_instance_valid(relic_ui):
			return true

	return false


func get_all_relics() -> Array[DkRelic]:
	var relic_ui_nodes := _get_all_relic_ui_nodes()
	var relics_array: Array[DkRelic] = []
	
	for relic_ui: DkRelicUI in relic_ui_nodes:
		relics_array.append(relic_ui.relic)
	
	return relics_array


func _get_all_relic_ui_nodes() -> Array[DkRelicUI]:
	var all_relics: Array[DkRelicUI] = []
	for relic_ui: DkRelicUI in relics.get_children():
		all_relics.append(relic_ui)
		
	return all_relics


func _on_relics_child_exiting_tree(relic_ui: DkRelicUI) -> void:
	if not relic_ui:
		return
	
	if relic_ui.relic:
		relic_ui.relic.deactivate_relic(relic_ui)
