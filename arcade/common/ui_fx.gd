class_name UiFx
extends RefCounted
# Small touches that make the launcher feel smooth: a soft click sound and a short
# vibration on taps, and fades for pages and cover art. Sounds and vibration can be
# switched off in Settings (stored in settings.cfg, section "ui").

static var _click: AudioStreamWAV = null
static var _player: AudioStreamPlayer = null


static func sounds_on() -> bool:
	return bool(GameData.get_setting("ui", "sounds", true))


static func vibration_on() -> bool:
	return bool(GameData.get_setting("ui", "vibration", true))


## A 25 ms soft "tick", made once in code (no sound files needed).
static func _make_click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.025)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 180.0)
		var v := int(clampf(sin(TAU * 1800.0 * t) * env * 0.35, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


## The tap feedback: call from any button press in the launcher.
static func tap(node: Node) -> void:
	if sounds_on() and node and node.is_inside_tree():
		if _click == null:
			_click = _make_click()
		if not is_instance_valid(_player) or not _player.is_inside_tree():
			_player = AudioStreamPlayer.new()
			_player.stream = _click
			_player.volume_db = -8.0
			node.get_tree().root.add_child(_player)
		_player.play()
	if vibration_on() and OS.has_feature("mobile"):
		Input.vibrate_handheld(12)


## Fade a control in (pages, cover art).
static func fade_in(c: CanvasItem, seconds := 0.18, slide := 0.0) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(c, "modulate:a", 1.0, seconds)
	if slide != 0.0 and c is Control:
		var ctrl := c as Control
		var to := ctrl.position
		ctrl.position = to + Vector2(0, slide)
		tw.parallel().tween_property(ctrl, "position", to, seconds)
