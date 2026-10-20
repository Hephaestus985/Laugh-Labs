extends Node3D

var camera_position:Vector3
var camera_rotation:Vector3

var zoom:float = 30.0 # 30 = Standard zoom level, in meters

@onready var camera = $Camera

# [Lab Arcade] phone controls: drag with one finger to move around, pinch to zoom,
# twist two fingers to turn the view. A short tap (no drag) is passed to the
# builder, which builds (or removes) on that square. PC: the original keys and
# mouse still work (WASD, wheel, middle mouse).
signal tapped(screen_position: Vector2)

const TAP_SLOP := 14.0  # finger movement (pixels) still counted as a tap
var touches := {}  # index -> position
var touch_moved := 0.0
var touch_multi := false
var pinch_distance := 0.0
var pinch_angle := 0.0
var mouse_down := false
var mouse_moved := 0.0

func _ready():

	camera_rotation = rotation_degrees # Initial rotation

	pass

func _process(delta):

	# Set position and rotation to targets

	position = position.lerp(camera_position, delta * 8)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)

	# Smoothly update zoom

	camera.position = camera.position.lerp(Vector3(0, 0, zoom), delta * 8)

	handle_input(delta)

# Handle input

func handle_input(_delta):

	# Rotation

	var input := Vector3.ZERO

	# [Lab Arcade] keys read directly (WASD / arrows), so no project-wide input actions are needed
	input.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	input.z = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))

	input = input.rotated(Vector3.UP, rotation.y).normalized()

	camera_position += input / 4

	# Back to center

	if Input.is_physical_key_pressed(KEY_F):
		camera_position = Vector3()

# [Lab Arcade] move the view by a drag on screen: the ground follows the finger
func pan(screen_delta: Vector2):
	var k := zoom / maxf(200.0, get_viewport().get_visible_rect().size.y) * 1.1
	var right := Vector3(1, 0, 0).rotated(Vector3.UP, rotation.y)
	var forward := Vector3(0, 0, 1).rotated(Vector3.UP, rotation.y)
	camera_position -= (right * screen_delta.x + forward * screen_delta.y) * k
	camera_position = camera_position.clamp(Vector3(-60, 0, -60), Vector3(60, 0, 60))

func zoom_by(factor: float):
	zoom = clampf(zoom * factor, 15, 80) # 15 = Minimum zoom level, 80 = maximum, in meters

func turn(degrees: float):
	camera_rotation.y += degrees

func _unhandled_input(event):
	# [Lab Arcade] touch: one finger pans (or taps), two fingers pinch and twist
	if event is InputEventScreenTouch:
		if event.pressed:
			if touches.is_empty():
				touch_moved = 0.0
				touch_multi = false
			touches[event.index] = event.position
			if touches.size() >= 2:
				touch_multi = true
				_start_pinch()
		elif touches.has(event.index):
			touches.erase(event.index)
			if touches.is_empty() and not touch_multi and touch_moved < TAP_SLOP:
				tapped.emit(event.position)
			elif touches.size() >= 2:
				_start_pinch()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var before: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if touches.size() == 1:
			touch_moved += before.distance_to(event.position)
			if touch_moved >= TAP_SLOP:
				pan(event.position - before)
		elif touches.size() >= 2:
			var pts: Array = touches.values()
			var d: float = (pts[0] as Vector2).distance_to(pts[1])
			var a: float = ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()
			if pinch_distance > 1.0 and d > 1.0:
				zoom_by(pinch_distance / d)
			turn(rad_to_deg(angle_difference(pinch_angle, a)) * -1.0)
			pinch_distance = d
			pinch_angle = a
		get_viewport().set_input_as_handled()
	# A real mouse (not a finger turned into mouse events): left drag pans, a click
	# taps, the wheel zooms, the middle button turns the view
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = true
				mouse_moved = 0.0
			elif mouse_down:
				mouse_down = false
				if mouse_moved < TAP_SLOP:
					tapped.emit(event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.85)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 0.85)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera_rotation += Vector3(0, -event.relative.x / 10, 0)
		elif mouse_down:
			mouse_moved += event.relative.length()
			if mouse_moved >= TAP_SLOP:
				pan(event.relative)

func _start_pinch():
	var pts: Array = touches.values()
	pinch_distance = (pts[0] as Vector2).distance_to(pts[1])
	pinch_angle = ((pts[1] as Vector2) - (pts[0] as Vector2)).angle()
