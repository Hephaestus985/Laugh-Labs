extends Node3D
# [Lab Arcade] Kenney Racing 2.0: a kart race on Kenney's racing kit.
# Five tracks built from the kit's pieces, three computer drivers, 3 laps, boost pads,
# item boxes (mushroom, banana, shell), a drift boost, a start boost on GO, a cup over
# all tracks, and a time trial against the ghost of your best time on each track.
# Free drive (v1.0, scenes/main.tscn) stays as it was.

const VEHICLE := preload("res://external/racing/scenes/vehicle.tscn")
const TRUCKS := [
	preload("res://external/racing/models/vehicle-truck-red.glb"),
	preload("res://external/racing/models/vehicle-truck-green.glb"),
	preload("res://external/racing/models/vehicle-truck-purple.glb"),
]
const GHOST_MODEL := preload("res://external/racing/models/vehicle-truck-yellow.glb")
const SAVE_DIR := "user://racing"
const LAPS := 3
const CELL := 9.99 * 0.75  # the track grid is scaled down
const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
# a track: moves from the finish line (heading north) back to it; B = bumps, P = boost
# pads, I = item boxes, by cell number along the track
const TRACKS := [
	{"id": "oval", "name": "Oval", "moves": "NNNWWWSSSSSSEEENNN", "bumps": [], "pads": [2, 11], "items": [5, 14]},
	{"id": "classic", "name": "Classic", "moves": "NNNWWWSSESSSEENN", "bumps": [10], "pads": [1, 6], "items": [4, 12]},
	{"id": "hairpins", "name": "Hairpins", "moves": "NNNNWWSSSWWNNNWWSSSSSSSEEEEEENNN", "bumps": [18, 25], "pads": [2, 20, 27], "items": [7, 15, 23]},
	{"id": "snake", "name": "Snake", "moves": "NNNNNEEESSSEEENNNNNNWWWWWWWWWSSSSSSSSSSEEENN", "bumps": [17, 32], "pads": [3, 23, 34], "items": [9, 19, 28, 38]},
	{"id": "grand_tour", "name": "Grand Tour", "moves": "NNNNNNWWWWNNNEEEEEEEESSSSSEEESSSSSSWWWWNNWWSSSWNNN", "bumps": [9, 26, 33], "pads": [3, 15, 30, 44], "items": [7, 18, 28, 38, 46]},
]
const ITEMS := ["mushroom", "banana", "shell"]
const PLACES := ["1st", "2nd", "3rd", "4th"]
const CUP_POINTS := [10, 6, 3, 1]

@onready var grid: GridMap = $GridMap
@onready var player: Vehicle = $Vehicle
@onready var view: Node3D = $View

var lib: MeshLibrary
var path: Array[Vector2i] = []  # track cells in driving order; path[0] is the finish
var centers: Array[Vector3] = []
var track := 0
var mode := "race"  # race, trial or cup
var state := "menu"  # menu, countdown, race, finished
var cars: Array = []  # all vehicles; cars[0] is the player
var info := {}  # vehicle -> {idx, laps (finish crossings), done, time, item, stuck, spin}
var race_time := 0.0
var count_t := 0.0
var go_time := -1.0
var cup_points := {}
var cup_round := 0
var props: Node3D  # boost pads, item boxes, bananas, shells, ghost
var ghost: Node3D
var ghost_play: Array = []  # [x, z, yaw] every REC_EVERY frames of the best run
var ghost_rec: Array = []
var frame := 0
const REC_EVERY := 3
var drift_t := 0.0
var skill := 0.9
var hud: CanvasLayer
var hud_lap: Label
var hud_pos: Label
var hud_time: Label
var hud_item: Label
var hud_big: Label
var menu: Control
var finish_panel: Control
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Kenney's bump piece (track-ramp) has no collision in the kit, so its fences could be
	# driven through and its bump wasn't there: it gets a shape made from its mesh
	lib = grid.mesh_library.duplicate()
	for id in lib.get_item_list():
		if lib.get_item_name(id).begins_with("track-") and lib.get_item_shapes(id).is_empty():
			lib.set_item_shapes(id, [lib.get_item_mesh(id).create_trimesh_shape(), Transform3D.IDENTITY])
	grid.mesh_library = lib
	rng.randomize()
	skill = [0.84, 0.91, 0.98][ArcadeGame.get_difficulty("racing")]
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	_build_hud()
	cars = [player]
	for i in 3:
		cars.append(_make_ai(i))
	HelpPage.open_first_time(self, "racing", "res://external/racing/lab_arcade_help.json")
	show_menu()


## The phone buttons, read by view.gd: steer and drive with the stick, ITEM, REVERSE, II.
func touch_config() -> Dictionary:
	return {
		"stick": ["left", "right", "forward", "back"],
		"buttons": [["ITEM", use_player_item], ["REVERSE", "back"]],
		"small": [["II", toggle_pause]],
		"help": "res://external/racing/lab_arcade_help.json",
		"help_id": "racing",
	}


func _make_ai(i: int) -> Vehicle:
	var v: Vehicle = VEHICLE.instantiate()
	var box: Node3D = v.get_node("Container")
	var old: Node = box.get_node("Model")
	box.remove_child(old)
	old.free()
	var m: Node3D = TRUCKS[i].instantiate()
	m.name = "Model"
	box.add_child(m)
	box.move_child(m, 0)
	v.ai = true
	v.name = "Rival%d" % (i + 1)
	add_child(v)
	return v


# ---------------------------------------------------------------- building a track

func _item_id(item_name: String) -> int:
	for id in lib.get_item_list():
		if lib.get_item_name(id) == item_name:
			return id
	return -1


## Which way a corner piece turns: the two open sides for each orientation.
const CORNERS := {0: [Vector2i(0, 1), Vector2i(-1, 0)], 16: [Vector2i(1, 0), Vector2i(0, 1)], 10: [Vector2i(0, -1), Vector2i(1, 0)], 22: [Vector2i(-1, 0), Vector2i(0, -1)]}


func build_track(n: int) -> void:
	track = n
	var t: Dictionary = TRACKS[n]
	grid.clear()
	_clear(props)
	ghost = null
	path.clear()
	centers.clear()
	var p := Vector2i.ZERO
	path.append(p)
	for ch in String(t["moves"]):
		p += DIRS[ch]
		path.append(p)
	path.pop_back()  # back at the finish
	var count := path.size()
	var on_track := {}
	for i in count:
		var here := path[i]
		on_track[here] = true
		var into := here - path[(i - 1 + count) % count]
		var out := path[(i + 1) % count] - here
		var cell := Vector3i(here.x, 0, here.y)
		if into == out:
			var o := 0 if out.x == 0 else 16
			var piece := "track-straight"
			if i == 0:
				piece = "track-finish"
			elif t["bumps"].has(i):
				piece = "track-ramp"
			grid.set_cell_item(cell, _item_id(piece), o)
		else:
			var want := [-into, out]
			for o in CORNERS:
				var sides: Array = CORNERS[o]
				if sides.has(want[0]) and sides.has(want[1]):
					grid.set_cell_item(cell, _item_id("track-corner"), o)
		centers.append(cell_center(here))
	# scenery around the track: grass, forest and tents
	var lo := path[0]
	var hi := path[0]
	for c in path:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var deco := [_item_id("decoration-empty"), _item_id("decoration-forest"), _item_id("decoration-tents")]
	var r := RandomNumberGenerator.new()
	r.seed = hash(t["id"])
	for x in range(lo.x - 2, hi.x + 3):
		for z in range(lo.y - 2, hi.y + 3):
			if on_track.has(Vector2i(x, z)):
				continue
			var roll := r.randf()
			# next to the track only grass, so trees don't hide the cars from the camera
			var near := false
			for dx in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					near = near or on_track.has(Vector2i(x + dx, z + dz))
			if near:
				roll = 0.0
			var item: int = deco[0] if roll < 0.45 else (deco[1] if roll < 0.92 else deco[2])
			grid.set_cell_item(Vector3i(x, 0, z), item, [0, 10, 16, 22][r.randi() % 4])
	for i in t["pads"]:
		_add_pad(i)
	for i in t["items"]:
		_add_item_box(i)


func cell_center(c: Vector2i) -> Vector3:
	var g := grid.to_global(grid.map_to_local(Vector3i(c.x, 0, c.y)))
	return Vector3(g.x, 0.0, g.z)


func dir_at(i: int) -> Vector3:
	var n := path.size()
	var d := path[(i + 1) % n] - path[i]
	return Vector3(d.x, 0, d.y)


# ---------------------------------------------------------------- boost pads and item boxes

const PAD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	float v = fract(UV.y * 3.0 - TIME * 2.0);
	float chevron = step(abs(UV.x - 0.5) * 0.9, v) - step(abs(UV.x - 0.5) * 0.9 + 0.35, v);
	ALBEDO = mix(vec3(1.0, 0.45, 0.05), vec3(1.0, 0.95, 0.3), chevron);
	ALPHA = 0.55 + 0.45 * chevron;
}
"""


func _area(pos: Vector3, radius: float) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 8  # the vehicles' spheres
	a.monitorable = false
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	shape.shape = s
	a.add_child(shape)
	props.add_child(a)
	a.global_position = pos
	return a


func _add_pad(i: int) -> void:
	var d := dir_at(i)
	var a := _area(centers[i] + Vector3(0, 0.6, 0), 1.8)
	a.name = "BoostPad"
	var mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 3.2)
	q.orientation = PlaneMesh.FACE_Y
	mesh.mesh = q
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PAD_SHADER
	mat.shader = sh
	mesh.material_override = mat
	mesh.position = Vector3(0, -0.45, 0)
	mesh.rotation.y = atan2(d.x, d.z) + PI  # the arrows point the way to drive
	a.add_child(mesh)
	a.body_entered.connect(func(b): _boost(_car_of(b), 1.2))


func _add_item_box(i: int) -> void:
	var d := dir_at(i)
	var side := Vector3(d.z, 0, -d.x)
	for k in [-1, 1]:
		var a := _area(centers[i] + side * 1.2 * k + Vector3(0, 0.9, 0), 0.9)
		a.name = "ItemBox"
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.9)
		box.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.7, 1.0, 0.75)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.25, 0.5, 1.0)
		box.material_override = mat
		box.name = "Box"
		a.add_child(box)
		var q := Label3D.new()
		q.text = "?"
		q.font_size = 96
		q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		q.no_depth_test = true
		a.add_child(q)
		a.body_entered.connect(func(b): _take_item_box(a, _car_of(b)))


func _car_of(body: Node) -> Vehicle:
	var n := body
	while n != null and not n is Vehicle:
		n = n.get_parent()
	return n


func _take_item_box(box: Area3D, v: Vehicle) -> void:
	if v == null or not box.visible or not info.has(v) or info[v]["item"] != "":
		return
	box.visible = false
	box.set_deferred("monitoring", false)
	box.set_meta("back_at", race_time + 3.0)
	# the further behind, the better the luck (a mushroom to catch up)
	var place := _place_of(v)
	var item: String = ITEMS[rng.randi() % ITEMS.size()]
	if place >= 2 and rng.randf() < 0.5:
		item = "mushroom"
	if place == 0 and item == "mushroom" and rng.randf() < 0.6:
		item = "banana"
	info[v]["item"] = item
	if v.ai:
		info[v]["item_at"] = race_time + rng.randf_range(1.0, 4.0)


func use_player_item() -> void:
	if state == "race" and info.has(player):
		use_item(player)


func use_item(v: Vehicle) -> void:
	var item: String = info[v]["item"]
	info[v]["item"] = ""
	match item:
		"mushroom":
			_boost(v, 1.4)
		"banana":
			_drop_banana(v)
		"shell":
			_fire_shell(v)


func _boost(v: Vehicle, seconds: float) -> void:
	if v == null or not info.has(v):
		return
	v.boost = maxf(v.boost, seconds)
	if v == player:
		_flash("BOOST!", Color(1, 0.6, 0.1))


func _drop_banana(v: Vehicle) -> void:
	var back: Vector3 = -v.vehicle_model.global_basis.z
	var b := _area(v.get_vehicle_position() + back * 2.2 + Vector3(0, 0.5, 0), 0.8)
	b.name = "Banana"
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.0
	m.mesh = cap
	m.rotation.z = PI / 2.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.86, 0.15)
	m.material_override = mat
	b.add_child(m)
	b.set_meta("owner", v)
	b.set_meta("born", race_time)
	b.body_entered.connect(func(body):
		var hit := _car_of(body)
		if hit == null or (hit == b.get_meta("owner") and race_time - float(b.get_meta("born")) < 1.0):
			return
		_spin(hit)
		b.queue_free())


func _fire_shell(v: Vehicle) -> void:
	var s := _area(v.get_vehicle_position() + v.vehicle_model.global_basis.z * 2.0 + Vector3(0, 0.6, 0), 0.7)
	s.name = "Shell"
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.15)
	m.material_override = mat
	s.add_child(m)
	s.set_meta("owner", v)
	s.set_meta("target", _car_ahead(v))
	s.set_meta("life", 6.0)
	s.body_entered.connect(func(body):
		var hit := _car_of(body)
		if hit == null or hit == s.get_meta("owner"):
			return
		_spin(hit)
		s.queue_free())


func _car_ahead(v: Vehicle) -> Vehicle:
	var order := _standings()
	var at := order.find(v)
	return order[at - 1] if at > 0 else null


func _spin(v: Vehicle) -> void:
	if v == null or not info.has(v) or info[v]["spin"] > 0.0:
		return
	info[v]["spin"] = 1.0
	v.controls_on = false
	v.linear_speed *= 0.2
	v.boost = 0.0
	if v == player:
		_flash("Spin out!", Color(1, 0.4, 0.4))


# ---------------------------------------------------------------- the race

func start_race(n: int, race_mode: String) -> void:
	mode = race_mode
	get_tree().paused = false
	build_track(n)
	info.clear()
	var grid_slots := [Vector2(-1.3, 0.0), Vector2(1.3, 1.6), Vector2(-1.3, 3.2), Vector2(1.3, 4.8)]
	var last := path.size() - 1
	var d := dir_at(last)
	var side := Vector3(d.z, 0, -d.x)
	for i in cars.size():
		var v: Vehicle = cars[i]
		var racing := mode != "trial" or v == player
		v.visible = racing
		v.process_mode = Node.PROCESS_MODE_INHERIT if racing else Node.PROCESS_MODE_DISABLED
		var slot: Vector2 = grid_slots[i] if mode != "trial" else Vector2(0, 2)
		var pos: Vector3 = centers[0] - d * (CELL * 0.5 + 1.5 + slot.y) + side * slot.x
		place(v, pos, atan2(d.x, d.z))
		v.controls_on = false
		if racing:
			info[v] = {"idx": last, "laps": 0, "done": false, "time": 0.0, "item": "", "item_at": 0.0, "stuck": 0.0, "spin": 0.0, "reverse": 0.0}
	view.position = player.get_vehicle_position()
	race_time = 0.0
	count_t = 3.2
	go_time = -1.0
	frame = 0
	drift_t = 0.0
	ghost_rec = []
	ghost_play = _load_best(TRACKS[n]["id"]).get("ghost", []) if mode == "trial" else []
	if not ghost_play.is_empty():
		_make_ghost()
	state = "countdown"
	_controls(true)
	menu.hide()
	finish_panel.hide()
	hud.show()


## Puts a vehicle on the track, standing still, facing yaw.
func place(v: Vehicle, pos: Vector3, yaw: float) -> void:
	var s: RigidBody3D = v.sphere
	s.global_position = pos + Vector3(0, 0.7, 0)
	s.linear_velocity = Vector3.ZERO
	s.angular_velocity = Vector3.ZERO
	v.vehicle_model.global_position = pos
	v.vehicle_model.global_rotation = Vector3(0, yaw, 0)
	v.linear_speed = 0.0
	v.angular_speed = 0.0
	v.acceleration = 0.0
	v.boost = 0.0
	v.prev_position = v.vehicle_model.position


func _physics_process(delta: float) -> void:
	if state == "countdown":
		count_t -= delta
		var n := ceili(count_t)
		hud_big.text = str(n) if n > 0 and n <= 3 else ""
		hud_big.modulate = Color(1, 1, 1)
		# start boost: be on the gas right at GO
		if count_t <= 0.0:
			state = "race"
			go_time = race_time
			for v in info:
				v.controls_on = true
				if v.ai and rng.randf() < 0.5:
					_boost(v, 0.6)
			if Input.get_action_strength("forward") > 0.5 or (is_instance_valid(TouchOverlay.current) and TouchOverlay.current.stick_vec.length() > 0.5):
				_boost(player, 0.8)
				_flash("START BOOST!", Color(1, 0.8, 0.2))
			else:
				_flash("GO!", Color(0.4, 1, 0.4))
		return
	if state != "race":
		return
	race_time += delta
	frame += 1
	for v in info:
		_track_progress(v)
		var it: Dictionary = info[v]
		if it["spin"] > 0.0:
			it["spin"] -= delta
			v.controls_on = false
			v.vehicle_model.rotate_y(delta * TAU * 1.4)
			if it["spin"] <= 0.0 and not it["done"]:
				v.controls_on = true
		if v.ai and not it["done"]:
			_drive_ai(v, delta)
	_move_shells(delta)
	_drift_boost(delta)
	if frame % REC_EVERY == 0:
		var p := player.get_vehicle_position()
		ghost_rec.append([snappedf(p.x, 0.01), snappedf(p.z, 0.01), snappedf(player.vehicle_model.global_rotation.y, 0.01)])
		if ghost and ghost_rec.size() <= ghost_play.size():
			var g: Array = ghost_play[ghost_rec.size() - 1]
			ghost.global_position = Vector3(g[0], 0.1, g[1])
			ghost.global_rotation = Vector3(0, g[2], 0)
	_update_hud()
	# FOV kick while boosting
	var cam: Camera3D = view.get_node("Camera")
	cam.fov = lerpf(cam.fov, 48.0 if player.boost > 0.0 else 40.0, delta * 4.0)


func _track_progress(v: Vehicle) -> void:
	var it: Dictionary = info[v]
	if it["done"]:
		return
	var n := path.size()
	var pos := v.get_vehicle_position()
	pos.y = 0
	for step in [1, 2]:
		var nxt: int = (it["idx"] + step) % n
		if pos.distance_to(centers[nxt]) < CELL * 0.62:
			var wrapped: bool = nxt < it["idx"] or (step == 2 and nxt == 1 and it["idx"] == n - 1)
			it["idx"] = nxt
			if nxt == 0 or (wrapped and nxt == 1):
				it["laps"] += 1
				if it["laps"] > LAPS:
					_finish(v)
				elif v == player and it["laps"] > 1:
					_flash("FINAL LAP!" if it["laps"] == LAPS else "Lap %d" % it["laps"], Color(1, 1, 1))
			break


func _progress(v: Vehicle) -> float:
	var it: Dictionary = info[v]
	if it["done"]:
		return 1000000.0 - it["time"]
	var n := path.size()
	var nxt: int = (it["idx"] + 1) % n
	var d: float = v.get_vehicle_position().distance_to(centers[nxt])
	return it["laps"] * n + it["idx"] - d / (CELL * 4.0)


func _standings() -> Array:
	var order: Array = info.keys()
	order.sort_custom(func(a, b): return _progress(a) > _progress(b))
	return order


func _place_of(v: Vehicle) -> int:
	return _standings().find(v)


func _drive_ai(v: Vehicle, delta: float) -> void:
	var it: Dictionary = info[v]
	var n := path.size()
	var lane: float = [0.0, -1.0, 1.0, 0.5][cars.find(v) % 4]
	var a: int = (it["idx"] + 2) % n
	var target: Vector3 = centers[a] + Vector3(dir_at(a).z, 0, -dir_at(a).x) * lane
	var here := v.get_vehicle_position()
	var want := target - here
	want.y = 0
	var facing: Vector3 = v.vehicle_model.global_basis.z
	facing.y = 0
	var turn: float = facing.normalized().signed_angle_to(want.normalized(), Vector3.UP)
	# rubber band: a little faster when far behind the player, a little slower when far ahead
	var gap: float = _progress(player) - _progress(v)
	var speed: float = skill * clampf(1.0 + gap * 0.02, 0.88, 1.12) * (1.0 - 0.35 * clampf(absf(turn), 0.0, 1.0))
	# stuck against a wall: back up for a moment
	if absf(v.linear_speed) < 0.08 and race_time - go_time > 2.0:
		it["stuck"] += delta
	else:
		it["stuck"] = 0.0
	if it["stuck"] > 1.2:
		it["reverse"] = 0.9
		it["stuck"] = 0.0
	if it["reverse"] > 0.0:
		it["reverse"] -= delta
		v.ai_input = Vector2(clampf(turn * 2.0, -1.0, 1.0), -1.0)
	else:
		v.ai_input = Vector2(-clampf(turn * 2.0, -1.0, 1.0), speed)
	if it["item"] != "" and race_time > it["item_at"]:
		use_item(v)


func _move_shells(delta: float) -> void:
	for s in props.get_children():
		if s.has_meta("back_at") and race_time > float(s.get_meta("back_at")):
			s.remove_meta("back_at")  # an item box comes back
			s.visible = true
			s.monitoring = true
		if s.name.begins_with("Shell") and s.has_meta("life"):
			var life: float = s.get_meta("life") - delta
			s.set_meta("life", life)
			if life <= 0.0:
				s.queue_free()
				continue
			var t = s.get_meta("target") if s.has_meta("target") else null
			var aim: Vector3
			if is_instance_valid(t):
				aim = (t.get_vehicle_position() + Vector3(0, 0.6, 0) - s.global_position)
			else:
				aim = s.get_meta("dir", Vector3.FORWARD)
			aim.y = 0
			s.set_meta("dir", aim.normalized())
			s.global_position += aim.normalized() * 22.0 * delta


## Drift boost: hold a hard turn at speed (the tyres smoke), then let go for a burst.
func _drift_boost(delta: float) -> void:
	if not player.controls_on:
		drift_t = 0.0
		return
	if absf(player.input.x) > 0.7 and absf(player.linear_speed) > 0.6:
		drift_t += delta
	else:
		if drift_t > 1.1:
			_boost(player, minf(1.0, drift_t * 0.4))
		drift_t = 0.0


func _finish(v: Vehicle) -> void:
	var it: Dictionary = info[v]
	it["done"] = true
	it["time"] = race_time
	if v == player:
		v.controls_on = false
		_on_player_finished()
	else:
		# computer drivers keep cruising past the line
		v.ai_input = Vector2(0, 0.4)


func _on_player_finished() -> void:
	state = "finished"
	_controls(false)
	var place := 0
	for v in info:
		if v != player and info[v]["done"] and info[v]["time"] < info[player]["time"]:
			place += 1
	# the others finish where they are now
	var t: float = info[player]["time"]
	var id: String = TRACKS[track]["id"]
	var best := _load_best(id)
	var new_best: bool = not best.has("time") or t < float(best["time"])
	if new_best:
		_save_best(id, t, ghost_rec)
	var score := 0
	if mode != "trial":
		score = (4 - place) * 1000 + maxi(0, 3000 - int(t * 10))
		GameData.add_score("racing", score, ArcadeGame.get_difficulty("racing"))
		if place == 0:
			GameData.add_win("racing")
	if mode == "cup":
		cup_points["you"] = cup_points.get("you", 0) + CUP_POINTS[place]
	_show_finish(place, t, new_best, best.get("time", 0.0), score)


# ---------------------------------------------------------------- best times and ghosts

func _load_best(id: String) -> Dictionary:
	var p := "%s/%s.json" % [SAVE_DIR, id]
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


func _save_best(id: String, t: float, rec: Array) -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, id], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"time": snappedf(t, 0.01), "ghost": rec}))


func _make_ghost() -> void:
	ghost = GHOST_MODEL.instantiate()
	ghost.name = "Ghost"
	props.add_child(ghost)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in ghost.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
	ghost.global_position = centers[0]


static func time_text(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


# ---------------------------------------------------------------- screens

func _panel(parent: Node, rect_min := Vector2(640, 0)) -> VBoxContainer:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.12, 0.92)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(26)
	bg.add_theme_stylebox_override("panel", sb)
	bg.custom_minimum_size = rect_min
	bg.set_anchors_preset(Control.PRESET_CENTER)
	bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(bg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	bg.add_child(v)
	return v


## The stick, ITEM and REVERSE only show while driving (not over the menus).
func _controls(on: bool) -> void:
	for o in view.find_children("*", "TouchOverlay", false, false):
		(o as TouchOverlay).menu_only = not on


func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## Free practice for the test runner's generic stick and button checks.
func lab_test_drive() -> void:
	start_race(0, "trial")
	count_t = 0.01


func _label(parent: Node, s: String, size: int, c := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _button(parent: Node, s: String, call: Callable, c := Color(0.2, 0.3, 0.45)) -> Button:
	var b := Button.new()
	b.text = s
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(call)
	parent.add_child(b)
	return b


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 10
	add_child(hud)
	var box := VBoxContainer.new()
	box.position = Vector2(180, 14)
	hud.add_child(box)
	hud_pos = _label(box, "", 44, Color(1, 0.85, 0.3))
	hud_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_lap = _label(box, "", 26)
	hud_lap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_time = _label(box, "", 24, Color(0.85, 0.9, 1))
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_item = _label(box, "", 26, Color(0.6, 1, 0.6))
	hud_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud_big = _label(hud, "", 120, Color.WHITE)
	hud_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_big.offset_bottom = -120
	hud_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = 15
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	menu = Control.new()
	menu.name = "Menu"
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	finish_panel = Control.new()
	finish_panel.name = "FinishPanel"
	finish_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(finish_panel)


func _update_hud() -> void:
	var it: Dictionary = info[player]
	hud_pos.text = "" if mode == "trial" else PLACES[_place_of(player)]
	hud_lap.text = "Lap %d / %d" % [clampi(it["laps"], 1, LAPS), LAPS]
	var best := _load_best(TRACKS[track]["id"]) if frame % 60 == 1 else {}
	if best.has("time"):
		hud_time.set_meta("best", best["time"])
	hud_time.text = time_text(race_time) + ("   best " + time_text(hud_time.get_meta("best")) if hud_time.has_meta("best") else "")
	hud_item.text = ("Item: " + {"mushroom": "Mushroom (boost)", "banana": "Banana", "shell": "Shell"}[it["item"]] + "  (ITEM)") if it["item"] != "" else ""
	if hud_big.has_meta("t"):
		var left: float = hud_big.get_meta("t") - get_physics_process_delta_time()
		hud_big.set_meta("t", left)
		if left <= 0.0:
			hud_big.text = ""
			hud_big.remove_meta("t")


func _flash(s: String, c: Color) -> void:
	hud_big.text = s
	hud_big.modulate = c
	hud_big.add_theme_font_size_override("font_size", 72 if s.length() > 4 else 120)
	hud_big.set_meta("t", 1.2)


func show_menu() -> void:
	state = "menu"
	get_tree().paused = false
	_clear(menu)
	finish_panel.hide()
	hud.hide()
	menu.show()
	_controls(false)
	if path.is_empty():
		build_track(0)
		for v in cars:
			place(v, centers[0] + Vector3(cars.find(v) * 2.0 - 3.0, 0, 6), PI)
			v.controls_on = false
	var v := _panel(menu, Vector2(720, 0))
	_label(v, "KENNEY RACING", 52, Color(1, 0.85, 0.3))
	_label(v, "Race: 3 laps against 3 drivers.  Time trial: beat your ghost.", 20, Color(0.8, 0.85, 0.95))
	var grid_box := GridContainer.new()
	grid_box.columns = 2
	grid_box.add_theme_constant_override("h_separation", 10)
	grid_box.add_theme_constant_override("v_separation", 10)
	v.add_child(grid_box)
	for i in TRACKS.size():
		var t: Dictionary = TRACKS[i]
		var best := _load_best(t["id"])
		var label := "%s   %s" % [t["name"], ("best " + time_text(best["time"])) if best.has("time") else "no time yet"]
		var b := _button(grid_box, label, start_race.bind(i, "race"))
		b.name = "Race_" + t["id"]
		b.custom_minimum_size = Vector2(440, 64)
		var tt := _button(grid_box, "Time trial", start_race.bind(i, "trial"), Color(0.25, 0.22, 0.4))
		tt.name = "Trial_" + t["id"]
		tt.custom_minimum_size = Vector2(220, 64)
	var cup := _button(v, "Cup: all 5 tracks in a row", start_cup, Color(0.5, 0.35, 0.1))
	cup.name = "Cup"


func start_cup() -> void:
	cup_points = {}
	cup_round = 0
	start_race(0, "cup")


func _show_finish(place: int, t: float, new_best: bool, old_best, score: int) -> void:
	_clear(finish_panel)
	finish_panel.show()
	var v := _panel(finish_panel, Vector2(620, 0))
	if mode == "trial":
		_label(v, "NEW BEST TIME!" if new_best else "Time trial", 48, Color(1, 0.85, 0.3))
	else:
		_label(v, "%s place%s" % [PLACES[place], "!" if place == 0 else ""], 56, Color(1, 0.85, 0.3) if place == 0 else Color.WHITE)
	_label(v, "Time " + time_text(t) + ("   (new best!)" if new_best and mode != "trial" else ""), 28)
	if not new_best and old_best:
		_label(v, "Best " + time_text(float(old_best)), 22, Color(0.8, 0.85, 0.95))
	if score > 0:
		_label(v, "Score %d" % score, 24, Color(0.7, 1, 0.7))
	if mode == "cup":
		cup_round += 1
		_label(v, "Cup: %d points after %d of %d tracks" % [cup_points.get("you", 0), cup_round, TRACKS.size()], 22, Color(1, 0.8, 0.5))
		if cup_round < TRACKS.size():
			_button(v, "Next track", func(): start_race(cup_round, "cup"), Color(0.2, 0.5, 0.2)).name = "Next"
		else:
			_label(v, "Cup finished: %d of %d points" % [cup_points.get("you", 0), CUP_POINTS[0] * TRACKS.size()], 26, Color(1, 0.85, 0.3))
	else:
		_button(v, "Race again" if mode == "race" else "Try again", start_race.bind(track, mode), Color(0.2, 0.5, 0.2)).name = "Again"
		if track + 1 < TRACKS.size():
			_button(v, "Next track", start_race.bind(track + 1, mode)).name = "Next"
	_button(v, "Tracks", show_menu, Color(0.3, 0.3, 0.35)).name = "Tracks"


func toggle_pause() -> void:
	if state != "race" and state != "countdown":
		return
	if get_tree().paused:
		get_tree().paused = false
		finish_panel.hide()
		_controls(true)
		return
	get_tree().paused = true
	_controls(false)
	_clear(finish_panel)
	finish_panel.show()
	var v := _panel(finish_panel, Vector2(480, 0))
	_label(v, "Paused", 48)
	_button(v, "Go on", toggle_pause, Color(0.2, 0.5, 0.2)).name = "Resume"
	_button(v, "Restart", start_race.bind(track, mode)).name = "Restart"
	_button(v, "Tracks", show_menu, Color(0.3, 0.3, 0.35)).name = "Tracks"
