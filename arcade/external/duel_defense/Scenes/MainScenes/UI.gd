extends CanvasLayer

@onready var money = $HUD/InfoBar/M/H/Money

@onready var wave_wrapper = $HUD/WaveContainer
@onready var wave = $HUD/WaveContainer/WaveWrapper/Wave
@onready var wave_label = $HUD/WaveContainer/WaveWrapper/WaveLabel
@onready var remaining = $HUD/WaveContainer/WaveWrapper/Remaining
@onready var next_wave = $HUD/WaveContainer/WaveWrapper/NextWave

@onready var info_bar = $HUD/InfoBar
@onready var build_bar = $HUD/InfoBar/M/H/BuildBar
@onready var upgrade_bar = $HUD/InfoBar/M/H/UpgradeBar

@onready var pause_play_button = $HUD/InfoBar/M/H/GameControls/PausePlay
@onready var speed_up_button = $HUD/InfoBar/M/H/GameControls/SpeedUp

var money_number = 0
var remaining_number

var bar_focus = false
var small_ui = false

var small_ui_set = 0  # [Lab Arcade] was 1024: the shop column always has room

var cooldown_timers = []

func _ready():
	_lab_side_panel()  # [Lab Arcade]
	for i in upgrade_bar.get_children():
		i.connect("pressed", Callable(self, "upgrade_requested").bind(i.get_name()))
		
	DdConsole.add_command("list_towers", on_list_towers)
	DdConsole.add_command("list_tower_data", on_list_tower_data, 1)
	DdConsole.add_command("toggle_play", on_toggle_play)
	
	get_tree().get_root().size_changed.connect(on_window_resized)
	get_tree().get_root().size_changed.connect(_lab_layout)  # [Lab Arcade]
	
func _physics_process(_delta):
	if Input.is_action_just_pressed("dd_fastforward"):
		_on_SpeedUp_pressed()
	if Input.is_action_just_pressed("dd_play"):
		_on_PausePlay_pressed()
	
	for timer_metadata in cooldown_timers:
		if not timer_metadata.timer.is_stopped():
			var timer_percentage = (timer_metadata.timer.time_left / timer_metadata.total_time) * 100
			update_cooldown_progress(timer_percentage, timer_metadata)
	
### UI controller functions

func ui_bar_focus_toggle(force_off = false, bar = build_bar):
	if force_off:
		bar_focus = false
	else:
		bar_focus = !bar_focus
	
	if small_ui and not bar_focus:
		get_tree().set_group("ui_details", "visible", true)
		get_tree().set_group("ui_build", "visible", false)
		get_tree().set_group("ui_buildsmall", "visible", true)
	elif small_ui and bar_focus:
		get_tree().set_group("ui_details", "visible", false)
		if bar.name != "UpgradeBar":
			get_tree().set_group("ui_build", "visible", true)
		get_tree().set_group("ui_buildsmall", "visible", false)
		
	if bar_focus:
		info_bar.self_modulate = "000000b4"
		var build_bar_children = bar.get_children()
		if len(build_bar_children):
			build_bar_children[0].grab_focus()
	else:
		info_bar.self_modulate = "00000078"
		if not small_ui:
			bar.visible = false
			bar.visible = true
		
func on_window_resized():
	if bar_focus:
		return
	var window_size = get_viewport().get_visible_rect().size  # [Lab Arcade] scaled screen
	
	if small_ui and window_size.x >= small_ui_set:
		get_tree().set_group("ui_details", "visible", true)
		get_tree().set_group("ui_build", "visible", true)
		get_tree().set_group("ui_buildsmall", "visible", false)
		small_ui = false
	elif not small_ui and window_size.x < small_ui_set:
		get_tree().set_group("ui_details", "visible", true)
		get_tree().set_group("ui_build", "visible", false)
		get_tree().set_group("ui_buildsmall", "visible", true)
		small_ui = true
	
func _on_start_build_mode_pressed():
	ui_bar_focus_toggle()

### game control functions

func _on_PausePlay_pressed():
	DdHelpers.play_button_sound()
	if get_parent().build_mode:
		get_parent().cancel_build_mode()
	if get_tree().is_paused():
		get_tree().paused = false
		pause_play_button.text = DdMaterialIconsDB.get_icon_char("pause")
		DdGodotLogger.info("game resumed")
	elif get_parent().current_wave == 0:
		DdGodotLogger.info("game started")
		pause_play_button.text = DdMaterialIconsDB.get_icon_char("pause")
		get_parent().start_next_wave()
	else:
		pause_play_button.text = DdMaterialIconsDB.get_icon_char("play")
		DdGodotLogger.info("game paused")
		get_tree().paused = true


func _on_SpeedUp_pressed():
	DdHelpers.play_button_sound()
	if get_parent().build_mode:
		get_parent().cancel_build_mode()
	if Engine.get_time_scale() != 1.0:
		speed_up_button.set("theme_override_colors/font_color", Color.WHITE)
		speed_up_button.set("theme_override_colors/font_focus_color", Color.WHITE)
		Engine.set_time_scale(1.0)
	else:
		speed_up_button.set("theme_override_colors/font_color", Color.YELLOW)
		speed_up_button.set("theme_override_colors/font_focus_color", Color.YELLOW)
		Engine.set_time_scale(2.0)

func update_money(current_money, immediate = false):
	if immediate:
		money.text = str(int(current_money))  # [Lab Arcade] was str(): "1000.0"
		money_number = current_money
	else:
		var tween = get_tree().create_tween()
		tween.tween_method(on_money_tween_step, int(money.text), current_money, 0.7)
		
func on_money_tween_step(value):
	if money:
		money.text = str(int(value))
	
func update_wave_data(enemies_in_wave, current_wave):
	if not wave_wrapper.visible:
		wave_wrapper.visible = true
		
	wave_label.visible = true
	wave.visible = true
	next_wave.visible = false
	remaining.visible = true
	wave_label.text = "WAVE"
	
	if wave.text != str(current_wave):
		wave.text = str(current_wave)
	
	if remaining.text != str(enemies_in_wave):
		remaining.text = str(enemies_in_wave)
		
func wave_completed():
	remaining.visible = false
	wave.visible = false
	next_wave.visible = true
	next_wave.value = 100
	wave_label.text = "WAVE COMPLETE!"
	
func update_next_wave_progress(progress):
	next_wave.value = progress
	
func show_upgrade_bar(upgrades, map_data):
	build_bar.visible = false
	upgrade_bar.visible = true
	var new_tower_data = {}
	for upgrade_name in upgrades:
		var upgrade_data = DdGameData.config.tower_data[upgrade_name]
		if "spawn_tank_mode" in upgrade_data and upgrade_data.spawn_tank_mode and ("spawn_tank_mode" not in map_data or not map_data.spawn_tank_mode):
			continue
		new_tower_data[upgrade_name] = upgrade_data
	setup_build_buttons(new_tower_data, upgrade_bar, true, "upgrade_requested")
	bar_focus = false
	ui_bar_focus_toggle(false, upgrade_bar)

func hide_upgrade_bar():
	upgrade_bar.visible = false
	build_bar.visible = true
	ui_bar_focus_toggle(true)

func upgrade_requested(upgrade_name):
	get_parent().upgrade_requested(upgrade_name)
	
func setup_build_buttons(buttons, parent_node, show_regardless = false, func_name = "initiate_build_mode"):
	for child in parent_node.get_children():
		child.free()
		
	var font = preload("res://external/duel_defense/Assets/UI/OperationNapalm-Regular.ttf")
	
	for button_name in buttons:
		var item = buttons[button_name]
		if show_regardless or ('in_build_menu' in item and item.in_build_menu):
			var button = Button.new()
			button.name = button_name
			button.custom_minimum_size = Vector2(80, 80)
			button.size_flags_horizontal = TextureButton.SIZE_SHRINK_CENTER
			button.size_flags_vertical = TextureButton.SIZE_SHRINK_CENTER
			button.offset_left = 10
			button.connect("pressed", Callable(get_parent(), func_name).bind(button.get_name()))
			
			if item.category != "Action":
				var turret_path = "res://external/duel_defense/Scenes/Turrets/" + item.scene_name + ".tscn"
				if "custom_scene_start_path" in item:
					var custom_scene_start_path = item.custom_scene_start_path
					turret_path = custom_scene_start_path + "/Scenes/Turrets/" + item.scene_name + ".tscn"
				var icon = load(turret_path).instantiate()
				icon.name = button_name
				icon.type = button_name
				icon.scale = Vector2(0.7, 0.7)
				icon.position = Vector2(40, 40)
				icon.icon_mode = true
					
				button.add_child(icon)
				
				var label = Label.new()
				if func_name == "upgrade_requested":
					label.text = "$%s" % item.upgrade_cost
				else:
					label.text = "$%s" % item.cost
				label.set("theme_override_fonts/font", font)
				button.add_child(label)
			else:
				var icon_script = load("res://external/duel_defense/addons/material-design-icons/nodes/MaterialIcon.gd")
				var icon = Label.new()
				icon.set_script(icon_script)
				icon.icon_name = item.icon
				icon.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon.icon_size = 50
				icon.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
				icon.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
				button.add_child(icon)
				
				var label = Label.new()
				label.text = item.label
				label.set("theme_override_fonts/font", font)
				button.add_child(label)
			
			parent_node.add_child(button)
			_lab_style_button(button)  # [Lab Arcade] bigger, for fingers
			
func start_button_cooldown(build_type):
	for button in build_bar.get_children():
		if button.name == build_type:
			DdGodotLogger.debug("start_button_cooldown, found button for %s" % build_type)
			
			var progress_scene = load("res://external/duel_defense/Scenes/SupportScenes/ProgressCircle.tscn").instantiate()
			button.add_child(progress_scene)
			button.disabled = true
			
			var timer = Timer.new()
			timer.one_shot = true
			timer.autostart = false
			timer.name = build_type
			add_child(timer)
			
			var total_time = DdGameData.config.tower_data[build_type]["cooldown"]
			var metadata = {"timer": timer, "total_time": total_time, "build_type": build_type, "progress_scene": progress_scene}
			cooldown_timers.append(metadata)
			
			timer.start(total_time); await timer.timeout
			progress_scene.queue_free()
			button.disabled = false
			timer.queue_free()
			cooldown_timers.erase(metadata)
			
			break
			
func update_cooldown_progress(timer_percentage, timer_metadata):
	timer_metadata.progress_scene.value = timer_percentage

# console commands related to UI

func on_list_towers():
	var tower_types = []
	for tower_type in DdGameData.config.tower_data:
		tower_types.append(tower_type)
	
	DdConsole.print_line(JSON.stringify(tower_types))
	
func on_list_tower_data(tower_type):
	if not tower_type:
		DdConsole.print_line("list_tower_data <tower_type>")
		return
		
	if not tower_type in DdGameData.config.tower_data:
		DdConsole.print_line("list_tower_data <tower_type>, tower_type is invalid")
		return
		
	DdConsole.print_line(JSON.stringify(DdGameData.config.tower_data[tower_type], "\t"))

func on_toggle_play():
	_on_PausePlay_pressed()


func _on_menu_pressed():
	var menu_event = InputEventAction.new()
	menu_event.action = "dd_menu"
	menu_event.pressed = true
	Input.parse_input_event(menu_event)


# ---------------------------------------------------------------- [Lab Arcade] phone layout
# On a phone the shop was a bar along the bottom, over the map, with small prices. Phones
# are wider than the 16:9 map, so the shop is now a column on the right: money at the top,
# the turrets two by two with big prices, menu / play / fast forward at the bottom. The
# camera fits the map into the space left of it (Camera.gd).
const LAB_PANEL_MIN := 260.0
const LAB_FONT := preload("res://external/duel_defense/Assets/UI/OperationNapalm-Regular.ttf")


func lab_panel_width() -> float:
	var vis := get_viewport().get_visible_rect().size
	return clampf(vis.x - vis.y * 16.0 / 9.0, LAB_PANEL_MIN, maxf(LAB_PANEL_MIN, vis.x * 0.3))


func _lab_swap(old: Node, new: Node) -> Node:
	var n := old.name
	old.replace_by(new, true)
	old.free()
	new.name = n
	return new


func _lab_side_panel() -> void:
	var col: VBoxContainer = _lab_swap($HUD/InfoBar/M/H, VBoxContainer.new())
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	for bar_name in ["BuildBar", "UpgradeBar"]:
		var old: Node = col.get_node(bar_name)
		var vis: bool = old.visible
		var grid: GridContainer = _lab_swap(old, GridContainer.new())
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.visible = vis
	build_bar = col.get_node("BuildBar")
	upgrade_bar = col.get_node("UpgradeBar")
	# money on one line at the top
	var row := HBoxContainer.new()
	row.name = "MoneyRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	col.move_child(row, 0)
	for n in ["Symbol", "Money"]:
		var l: Label = col.get_node(n)
		l.reparent(row)
		l.add_theme_font_size_override("font_size", 44)
		l.custom_minimum_size = Vector2(0, 56)
	col.get_node("Sep2").visible = false
	col.get_node("BuildBarSmall").visible = false
	col.get_node("BuildBarSmall").remove_from_group("ui_buildsmall")
	# keyboard / controller hints don't fit a phone column
	for t in col.find_children("ControllerTextureRect", "", true, false):
		t.visible = false
		t.set_script(null)
	col.get_node("Sep").size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.get_node("Sep").custom_minimum_size = Vector2.ZERO
	var controls: HBoxContainer = col.get_node("GameControls")
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 6)
	var m: MarginContainer = $HUD/InfoBar/M
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	for b in controls.get_children():
		if b is Button:
			b.add_theme_font_size_override("font_size", 64)
			b.custom_minimum_size = Vector2(76, 76)
			if "icon_size" in b:
				b.icon_size = 64
	info_bar.custom_minimum_size = Vector2.ZERO
	# a solid background: the column isn't over the map, and the map's edge shouldn't show through
	var bg := ColorRect.new()
	bg.name = "LabPanelBg"
	bg.color = Color(0.035, 0.2, 0.145)
	bg.show_behind_parent = true
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bar.add_child(bg)
	info_bar.move_child(bg, 0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lab_layout()


func _lab_layout() -> void:
	var w := lab_panel_width()
	var hud: Control = $HUD
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.offset_right = -w  # the wave counter centres over the map
	info_bar.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	info_bar.offset_left = 0
	info_bar.offset_right = w
	info_bar.offset_top = 0
	info_bar.offset_bottom = 0
	for bar in [build_bar, upgrade_bar]:
		for b in bar.get_children():
			_lab_style_button(b)


func _lab_style_button(button: Control) -> void:
	var side := floorf((lab_panel_width() - 24.0 - 10.0) / 2.0)
	side = clampf(side, 96.0, 150.0)
	button.custom_minimum_size = Vector2(side, side)
	for c in button.get_children():
		if c is Node2D:  # the turret picture
			c.position = Vector2(side / 2.0, side / 2.0 - 8.0)
			c.scale = Vector2.ONE * 0.7 * side / 80.0 * 0.8
		elif c is Label and c.get_script() == null:  # the price
			c.text = c.text.trim_suffix(".0")
			c.add_theme_font_override("font", LAB_FONT)
			c.add_theme_font_size_override("font_size", 26)
			c.add_theme_color_override("font_shadow_color", Color.BLACK)
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			c.offset_bottom = -2
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
