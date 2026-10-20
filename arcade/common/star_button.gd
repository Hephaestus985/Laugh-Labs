class_name StarButton
extends Button
# One star of a 1-5 rating, drawn in code (fonts on phones may lack a star glyph).

var filled := false:
	set(v):
		filled = v
		queue_redraw()


func _init() -> void:
	flat = true
	custom_minimum_size = Vector2(52, 52)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.42
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if filled:
		draw_colored_polygon(pts, Color(1.0, 0.8, 0.25))
	else:
		pts.append(pts[0])
		draw_polyline(pts, Color(0.75, 0.75, 0.85), 2.5, true)
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.4), false, 2.0)
