extends Node3D


func _ready() -> void:
	# [Lab Arcade] phone controls: stick to walk, JUMP, camera turn and zoom buttons
	TouchOverlay.add_to(self, {
		"stick": ["move_left", "move_right", "move_forward", "move_back"],
		"buttons": [["JUMP", "jump"]],
		"small": [[">", "camera_right"], ["<", "camera_left"], ["-", "zoom_out"], ["+", "zoom_in"]],
	})
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# Reduce background and sun brightness when using the Compatibility renderer;
		# this tries to roughly match the appearance of Forward+.
		# This compensates for the different color space and light rendering for lights with shadows enabled.
		$Sun.light_energy = 0.24
		$Sun.shadow_opacity = 0.85
		$Environment.environment.background_energy_multiplier = 0.25
