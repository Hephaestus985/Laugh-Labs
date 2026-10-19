class_name ArcadeGame
extends Node2D
# Shared base for arcade games: 1280x720 canvas, keyboard + touch input,
# a "< MENU" button, Esc / Android back to the menu, and a saved best score.
#
# Controls every game gets for free:
#   move  : arrows / WASD, or the touch stick (drag anywhere on the left half)
#   A     : Space / Enter / Z / J / left click, or the big touch button
#   B     : Shift / X / K / right click, or the small touch button
# A game sets `use_stick` / `use_b` to hide controls it doesn't need, and
# `tap_is_a` to make a tap anywhere (outside the stick) count as A.

const W := 1280.0
const H := 720.0
const MENU_SCENE := "res://menu.tscn"
const MENU_BTN := Rect2(10, 10, 120, 56)
const STICK_R := 90.0
const BTN_A_C := Vector2(1150, 600)
const BTN_B_C := Vector2(1010, 640)
const BTN_A_R := 78.0
const BTN_B_R := 56.0

var game_id := "game"
var use_stick := true
var use_b := false
var tap_is_a := false
var show_a := true  # draw the A touch button
var custom_keys := false  # true: the game reads its own keys (base only handles Esc)

var font: Font
var t := 0.0
var is_mobile := false
var best := 0

var a_down := false
var b_down := false
var _a_just := false
var _tap_just := false
var _b_just := false
var _a_released := false
var pointer := Vector2.ZERO  # last mouse / touch position, for games that aim
var pointer_down := false

var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _a_idx := -1
var _b_idx := -1
var _shake := 0.0


func _enter_tree() -> void:
	font = ThemeDB.fallback_font
	is_mobile = OS.has_feature("mobile")


func best_path() -> String:
	return "user://best_%s.dat" % game_id


func load_best() -> void:
	best = 0
	if FileAccess.file_exists(best_path()):
		var f := FileAccess.open(best_path(), FileAccess.READ)
		if f:
			best = f.get_32()


func submit_score(score: int) -> bool:
	if score > best:
		best = score
		var f := FileAccess.open(best_path(), FileAccess.WRITE)
		if f:
			f.store_32(best)
		return true
	return false


# ---------------------------------------------------------------- settings shared with the menu

const SETTINGS_PATH := "user://settings.cfg"
const DIFF_NAMES := ["Easy", "Normal", "Hard"]
const DIFF_MULT := [0.8, 1.0, 1.25]


static func get_difficulty(id: String) -> int:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return 1
	return clampi(int(cf.get_value("difficulty", id, 1)), 0, 2)


static func set_difficulty(id: String, d: int) -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_PATH)
	cf.set_value("difficulty", id, clampi(d, 0, 2))
	cf.save(SETTINGS_PATH)


func difficulty() -> int:
	return get_difficulty(game_id)


## How the menu launched this game: "" (normal), "continue" or "new".
func launch_mode() -> String:
	var m: String = Engine.get_meta("launch_mode", "")
	Engine.set_meta("launch_mode", "")
	return m


func back_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back_to_menu()


# ---------------------------------------------------------------- input

func pressed_a() -> bool:
	var v := _a_just
	_a_just = false
	return v


func pressed_b() -> bool:
	var v := _b_just
	_b_just = false
	return v


func released_a() -> bool:
	var v := _a_released
	_a_released = false
	return v


## A tap anywhere, the A button, SPACE or ENTER: used on title and game-over screens.
func start_pressed() -> bool:
	var v := _tap_just or _a_just
	_tap_just = false
	_a_just = false
	return v


func clear_presses() -> void:
	_tap_just = false
	_a_just = false
	_b_just = false
	_a_released = false


func axis() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.y += 1.0
	if v != Vector2.ZERO:
		return v.normalized()
	return _stick_vec


func _set_a(down: bool) -> void:
	if down and not a_down:
		_a_just = true
	if not down and a_down:
		_a_released = true
	a_down = down


func _set_b(down: bool) -> void:
	if down and not b_down:
		_b_just = true
	b_down = down


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var k: int = event.keycode
		if event.pressed and k == KEY_ESCAPE:
			back_to_menu()
			return
		if custom_keys:
			pass
		elif k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_J]:
			_set_a(event.pressed)
		elif k in [KEY_SHIFT, KEY_X, KEY_K]:
			_set_b(event.pressed)
	elif event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if event.index == _stick_idx:
			_stick_vec = (event.position - _stick_origin).limit_length(STICK_R) / STICK_R
		pointer = event.position
	elif event is InputEventMouseButton and not is_mobile:
		pointer = event.position
		if event.pressed and MENU_BTN.has_point(event.position):
			back_to_menu()
			return
		if event.pressed:
			_tap_just = true
		if event.button_index == MOUSE_BUTTON_LEFT:
			pointer_down = event.pressed
			_set_a(event.pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_set_b(event.pressed)
	elif event is InputEventMouseMotion and not is_mobile:
		pointer = event.position
	on_input(event)


func _touch(idx: int, pos: Vector2, down: bool) -> void:
	if down:
		pointer = pos
		pointer_down = true
		if MENU_BTN.has_point(pos):
			back_to_menu()
			return
		_tap_just = true
		if show_a and pos.distance_to(BTN_A_C) < BTN_A_R * 1.3:
			_a_idx = idx
			_set_a(true)
		elif use_b and pos.distance_to(BTN_B_C) < BTN_B_R * 1.3:
			_b_idx = idx
			_set_b(true)
		elif use_stick and pos.x < W * 0.5 and _stick_idx == -1:
			_stick_idx = idx
			_stick_origin = pos
			_stick_vec = Vector2.ZERO
		elif tap_is_a:
			_a_idx = idx
			_set_a(true)
	else:
		pointer_down = false
		if idx == _stick_idx:
			_stick_idx = -1
			_stick_vec = Vector2.ZERO
		if idx == _a_idx:
			_a_idx = -1
			_set_a(false)
		if idx == _b_idx:
			_b_idx = -1
			_set_b(false)


## Override for extra input handling (called after the base handled it).
func on_input(_event: InputEvent) -> void:
	pass


# ---------------------------------------------------------------- drawing helpers

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Call at the start of _process.
func tick(delta: float) -> void:
	t += delta
	_shake = maxf(0.0, _shake - delta * 40.0)
	position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.0 else Vector2.ZERO


func text(pos: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	var width := W if center else -1.0
	var p := Vector2(0.0, pos.y) if center else pos
	draw_string_outline(font, p, s, align, width, size, 6, Color(0.08, 0.08, 0.15, 0.9 * c.a))
	draw_string(font, p, s, align, width, size, c)


## Draw the menu button and touch controls. Call at the end of _draw.
func draw_overlay(a_label := "A", b_label := "B") -> void:
	draw_rect(MENU_BTN, Color(0, 0, 0, 0.3))
	text(MENU_BTN.position + Vector2(14, 37), "< MENU", 22, Color(1, 1, 1, 0.9))
	if not is_mobile:
		return
	if use_stick and _stick_idx != -1:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(_stick_origin + _stick_vec * STICK_R, 36, Color(1, 1, 1, 0.45))
	elif use_stick:
		text(Vector2(60, H - 30), "drag here to move", 20, Color(1, 1, 1, 0.35))
	if show_a:
		draw_circle(BTN_A_C, BTN_A_R, Color(1, 1, 1, 0.28 if a_down else 0.14))
		draw_arc(BTN_A_C, BTN_A_R, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
		draw_string(font, BTN_A_C + Vector2(-BTN_A_R, 9), a_label, HORIZONTAL_ALIGNMENT_CENTER, BTN_A_R * 2, 26, Color(1, 1, 1, 0.85))
	if use_b:
		draw_circle(BTN_B_C, BTN_B_R, Color(1, 1, 1, 0.28 if b_down else 0.14))
		draw_arc(BTN_B_C, BTN_B_R, 0, TAU, 40, Color(1, 1, 1, 0.5), 3.0)
		draw_string(font, BTN_B_C + Vector2(-BTN_B_R, 8), b_label, HORIZONTAL_ALIGNMENT_CENTER, BTN_B_R * 2, 20, Color(1, 1, 1, 0.85))
