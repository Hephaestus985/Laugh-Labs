extends ArcadeGame
# The Last Knight: Bolt from the Blue. Eleven years of sword school, then
# someone invented the crossbow. Chase the inventor through five eras and
# beat him in his tower. Progress is saved at every level and at the boss.
# The level runs in the web version's world units (32 px tiles, 440 tall)
# and is scaled up to the screen.

const K := 720.0 / 440.0
const VW := 1280.0 / K
const VH := 440.0
const T := 32.0
const ROWS := 13
const LH := ROWS * T
const FALLY := LH + 40.0
const FLOOR := 320.0
const RUN := 215.0
const JV := 590.0
const GR := 1500.0
const MAXF := 760.0
const OL := Color("#2a2131")
const SAVE_PATH := "user://the_last_knight_save.json"
const DIFS := [
	{"k": "easy", "lab": "Easy", "spd": .75, "fire": 1.35, "lives": 4, "hp": 4, "boss": 7},
	{"k": "normal", "lab": "Normal", "spd": 1.0, "fire": 1.0, "lives": 3, "hp": 3, "boss": 9},
	{"k": "hard", "lab": "Hard", "spd": 1.3, "fire": .72, "lives": 2, "hp": 3, "boss": 12},
]
const ED := {
	"dummy": {"w": 20, "h": 36, "hp": 1, "pts": 50, "hurts": false, "tag": ["PRACTICE DUMMY", "Record: 0 wins, 4,000 losses"]},
	"goose": {"w": 26, "h": 24, "hp": 1, "pts": 100, "hurts": true, "nm": "a Goose of Ill Intent", "tag": ["GOOSE OF ILL INTENT", "Has never lost an argument"]},
	"viking": {"w": 26, "h": 38, "hp": 2, "pts": 150, "hurts": true, "nm": "Leif Erikswrong", "tag": ["LEIF ERIKSWRONG", "Navigator. Has never asked for directions"]},
	"gull": {"w": 26, "h": 16, "hp": 1, "pts": 100, "hurts": true, "nm": "Seagull Ragnar", "tag": ["SEAGULL RAGNAR", "Wants your chips. Chips not invented yet"]},
	"legion": {"w": 24, "h": 38, "hp": 1, "pts": 200, "hurts": true, "nm": "Centurion Obstinatus", "tag": ["CENTURION OBSTINATUS", "Shield wall of one. Get behind him"]},
	"cyclist": {"w": 32, "h": 38, "hp": 1, "pts": 150, "hurts": true, "nm": "a Dutch cyclist", "tag": ["FIETSER", "Has right of way. Always. Jump!"]},
	"clerk": {"w": 22, "h": 34, "hp": 1, "pts": 150, "hurts": true, "nm": "a Patent Clerk", "tag": ["PATENT CLERK", "Files bolts in triplicate"]},
	"turret": {"w": 28, "h": 24, "hp": 2, "pts": 200, "hurts": true, "nm": "the Auto-Crossbow 3000", "tag": ["AUTO-CROSSBOW 3000", "The original pop-up ad"]},
	"cow": {"w": 46, "h": 32, "hp": 1, "pts": 0, "hurts": false, "npc": true, "tag": ["COW", "Neutral. But judging you"]},
	"contractor": {"w": 22, "h": 34, "hp": 1, "pts": 0, "hurts": false, "npc": true},
}
const TH := {
	"castle": {"g": [Color("#9b8d7c"), Color("#7d705f")], "top": Color("#6fae4b"), "sky": [Color("#121a35"), Color("#3a3d68")]},
	"sea": {"g": [Color("#5d6670"), Color("#454c55")], "top": Color("#6f8c5a"), "sky": [Color("#0d1424"), Color("#253652")]},
	"aq": {"g": [Color("#b89a6a"), Color("#9c7f55")], "top": Color("#8fae5a"), "sky": [Color("#1b1838"), Color("#5a3a58")]},
	"polder": {"g": [Color("#5b3f2e"), Color("#47301f")], "top": Color("#5fae4a"), "sky": [Color("#0b1430"), Color("#2c4266")]},
	"tower": {"g": [Color("#57514f"), Color("#423d3c")], "top": Color("#7a726d"), "sky": [Color("#1d1b24"), Color("#2a2730")]},
}

enum S { TITLE, PLAY, DYING, CLEAR, BOSSDEAD, END, OVER }
var state: int = S.TITLE
var diff := 1
var D: Dictionary
var L: Dictionary = {}
var p := {}
var gt := 0.0  # animation time
var wt := 0.0  # world time
var lv := 0
var score := 0
var coins := 0
var kills := 0
var geese := 0
var parries := 0
var play_time := 0.0
var lt := 0.0
var lives := 3
var cause := ""
var parts: Array = []
var fx: Array = []
var proj: Array = []
var banner_t := -1.0
var toast_d = null
var seen := {}
var boss = null
var boss_on := false
var flash := 0.0
var cam_x := 0.0
var cam_y := LH - VH
var dtm := 0.0
var ct := 0.0
var tally := {}
var cp := Vector2.ZERO
var saved = null
var new_best := false
var jump_held := false
var jump_pressed := false
var atk_pressed := false
var title_cam := 0.0


func _ready() -> void:
	game_id = "the_last_knight"
	use_stick = true
	use_b = true
	custom_keys = true
	load_best()
	D = DIFS[diff]
	saved = load_save()
	L = build_level(1)
	p = new_player()
	p["x"] = 6 * T
	p["y"] = FLOOR - p["h"]


func new_player() -> Dictionary:
	return {"x": 0.0, "y": 0.0, "w": 20.0, "h": 30.0, "vx": 0.0, "vy": 0.0, "face": 1.0, "on": false, "on_plat": null, "co": 0.0, "jb": 0.0, "kb": 0.0, "inv": 0.0, "atk": 0.0, "atk_cd": 0.0, "hp": 3, "run": 0.0, "haz": 0, "safe": null, "sid": 0, "dead": false}


# ---------------------------------------------------------------- saving

func load_save():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var o = JSON.parse_string(f.get_as_text())
	if typeof(o) == TYPE_DICTIONARY and int(o.get("lv", 0)) >= 1 and int(o.get("lv", 0)) <= 5 and int(o.get("lives", 0)) >= 1:
		return o
	return null


func save_ck(at_boss: bool) -> void:
	var o := {"v": 1, "diff": diff, "lv": lv, "boss": at_boss, "score": score, "lives": lives, "time": play_time, "coins": coins, "kills": kills, "geese": geese, "parries": parries, "seen": seen}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(o))


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	saved = null


# ---------------------------------------------------------------- level building

func mk(o: Dictionary) -> Dictionary:
	var g := PackedByteArray()
	g.resize(o["cols"] * ROWS)
	var base := {"grid": g, "ents": [], "plats": [], "zones": [], "coins": [], "signs": [], "flags": [], "mills": [], "arena": null, "goal": 1e9}
	base.merge(o, true)
	return base


func setg(x: int, y: int, v: int) -> void:
	if x >= 0 and x < L["cols"] and y >= 0 and y < ROWS:
		L["grid"][y * L["cols"] + x] = v


func h_g(a: int, b: int, r: int, t := 1) -> void:
	for x in range(a, b):
		for y in ROWS:
			setg(x, y, t if y >= r else 0)


func h_bx(x: int, y: int, w: int, h: int, t := 2) -> void:
	for i in w:
		for j in h:
			setg(x + i, y + j, t)


func h_pl(x: int, y: int, w: int) -> void:
	for i in w:
		setg(x + i, y, 3)


func h_sp(a: int, b: int, r: int) -> void:
	for x in range(a, b):
		setg(x, r, 4)


func h_wa(a: int, b: int, r := 11) -> void:
	for x in range(a, b):
		for y in range(r, ROWS):
			if L["grid"][y * L["cols"] + x] == 0:
				setg(x, y, 5)


func h_co(x: float, y: float, n: int, dx := 1.0, dy := 0.0) -> void:
	for i in n:
		L["coins"].append({"x": (x + i * dx) * T + 16, "y": (y + i * dy) * T + 16, "got": false})


func h_ar(a: int, b: int, r: float) -> void:
	var n := b - a + 1
	for i in n:
		var u := float(i) / (n - 1)
		L["coins"].append({"x": (a + i) * T + 16, "y": (r - sin(u * PI) * 2) * T + 16, "got": false})


func h_e(ty: String, x: float, r: float, o := {}) -> Dictionary:
	var d: Dictionary = ED[ty]
	var e := {"ty": ty, "x": x * T + (T - d["w"]) / 2.0, "y": r * T - d["h"], "w": float(d["w"]), "h": float(d["h"]), "vx": 0.0, "vy": 0.0, "face": -1.0, "hp": d["hp"], "t": randf() * 5, "st": "idle", "cd": 1 + randf(), "hf": 0.0, "dead": false, "dt": 0.0, "bub": null, "sid": -1, "x0": -1e9, "x1": 1e9, "mt": 0.0}
	if o.has("a"):
		e["x0"] = o["a"] * T
		e["x1"] = o["b"] * T
	if o.has("face"):
		e["face"] = float(o["face"])
	L["ents"].append(e)
	return e


func h_sg(x: float, s: String, r := 0) -> void:
	L["signs"].append({"x": x * T + 16, "y": r * T, "s": s.split("|")})


func h_fl(x: float) -> void:
	L["flags"].append({"x": x * T + 16, "on": false})


func h_ship(a: float, b: float, w: float, row: float, per: float, ph: float, vik := []) -> void:
	var q := {"k": "ship", "a": a * T, "b": b * T, "w": w * T, "y0": row * T, "per": per, "ph": ph, "h": 12.0, "gone": false}
	L["plats"].append(q)
	for v in vik:
		var d: Dictionary = ED["viking"]
		L["ents"].append({"ty": "viking", "x": 0.0, "y": 0.0, "w": float(d["w"]), "h": float(d["h"]), "vx": 0.0, "vy": 0.0, "face": -1.0, "hp": d["hp"], "t": randf() * 5, "st": "idle", "cd": 1.5 + randf() * 1.5, "hf": 0.0, "dead": false, "dt": 0.0, "bub": null, "sid": -1, "pl": q, "lx": v * T, "x0": -1e9, "x1": 1e9, "mt": 0.0})


func h_raft(x: float, w: float, ra: float, rb: float, per: float, ph: float) -> void:
	L["plats"].append({"k": "raft", "x0": x * T, "w": w * T, "a": ra * T, "b": rb * T, "per": per, "ph": ph, "h": 12.0, "gone": false})


func h_cr(x: float, r: float) -> void:
	L["plats"].append({"k": "crumble", "x0": x * T, "y0": r * T, "w": T, "h": T, "dy": 0.0, "st": 0, "tm": 0.0, "vy": 0.0, "gone": false, "rt": 0.0})


func h_mill(hx: float, hy: float, R: float, per: float, dir: float) -> void:
	L["mills"].append({"hx": hx * T, "hy": hy, "R": R, "per": per, "dir": dir})
	for k in 4:
		L["plats"].append({"k": "blade", "hx": hx * T, "hy": hy, "R": R, "per": per, "dir": dir, "a0": k * PI / 2 + .3, "w": 66.0, "h": 10.0, "gone": false})


func h_zone(o: Dictionary) -> void:
	o["snd"] = false
	L["zones"].append(o)


func build_level(n: int) -> Dictionary:
	match n:
		1:
			L = mk({"n": 1, "cols": 176, "th": "castle", "year": "1146 AD", "title": "The Castle Courtyard", "sub": "Training Day (Year 11 of 11)", "hint": "Swing at the dummies. Stomp or slash the geese.", "short": "Courtyard", "par": 65.0, "sx": 2, "sr": 10})
			h_g(0, 20, 10); h_sg(5, "SWORD SCHOOL|Graduates: 1 (you)"); h_e("dummy", 10, 10); h_e("dummy", 14, 10); h_co(16, 8, 4)
			h_wa(20, 23); h_g(23, 40, 10); h_bx(27, 9, 2, 1); h_co(27, 7, 2); h_e("goose", 33, 10, {"a": 30, "b": 36}); h_bx(37, 8, 2, 2); h_co(37, 6, 2)
			h_g(40, 48, 9); h_ar(47, 52, 7); h_wa(48, 51); h_g(51, 64, 10); h_sp(55, 57, 9); h_pl(54, 7, 4); h_co(54, 6, 4); h_e("goose", 60, 10, {"a": 58, "b": 64})
			h_g(64, 70, 8); h_co(65, 6, 4); h_g(70, 84, 10); h_sg(72, "CHECKPOINT|Honk responsibly"); h_fl(76); h_e("goose", 81, 10, {"a": 78, "b": 84})
			h_wa(84, 88); h_pl(85, 8, 2); h_co(85, 7, 2); h_g(88, 104, 10); h_bx(92, 9, 1, 1); h_bx(93, 8, 1, 2); h_bx(94, 7, 2, 3); h_co(94, 5, 2); h_e("goose", 99, 10, {"a": 96, "b": 104}); h_e("goose", 102, 10, {"a": 96, "b": 104})
			h_wa(104, 107); h_g(107, 120, 10); h_sp(112, 114, 9); h_pl(110, 7, 5); h_co(110, 6, 5); h_e("goose", 117, 10, {"a": 114, "b": 120})
			h_g(120, 128, 9); h_co(121, 7, 6); h_wa(128, 131); h_g(131, 150, 10); h_sg(133, "A GAGGLE|collective noun: trouble"); h_e("goose", 138, 10, {"a": 135, "b": 150}); h_e("goose", 142, 10, {"a": 135, "b": 150}); h_e("goose", 147, 10, {"a": 135, "b": 150}); h_pl(138, 6, 6); h_co(138, 5, 6)
			h_g(150, 176, 10); h_sg(155, "TIME PORTAL|to the past. Probably."); h_co(158, 8, 5); L["goal"] = 168 * T
		2:
			L = mk({"n": 2, "cols": 184, "th": "sea", "year": "1000 AD", "title": "Off the Coast of Probably-Vinland", "sub": "We Are Definitely Not Lost", "hint": "Ride the longships. Vikings throw axes: parry them!", "short": "North Sea", "par": 80.0, "sx": 3, "sr": 9})
			h_wa(0, 184); h_g(0, 12, 9, 6); h_sg(5, "VINLAND ->|(probably)"); h_co(8, 7, 3)
			h_ship(12.5, 19.5, 6, 9, 5.5, 0); h_g(26, 30, 9); h_e("gull", 28, 4, {"a": 24, "b": 33}); h_co(26, 7, 4)
			h_ship(30.5, 38.5, 7, 9, 6, 1.5, [4]); h_g(46, 49, 8); h_co(46, 6, 3)
			h_raft(51, 2, 6, 9, 3.2, 0); h_g(55, 62, 9); h_fl(57); h_sg(60, "ASKING FOR|DIRECTIONS: NO")
			h_ship(62.5, 70, 6, 9, 5, .5, [3]); h_e("gull", 70, 3, {"a": 65, "b": 78}); h_ship(76.5, 83.5, 6, 9, 5, .5 + PI); h_co(78, 6, 4)
			h_g(90, 94, 8); h_co(90, 6, 4); h_raft(96, 2, 5, 9, 3, 0); h_raft(100, 2, 5, 9, 3, 1.6); h_co(96, 4, 2); h_co(100, 4, 2)
			h_g(104, 110, 9); h_e("viking", 107, 9, {"a": 104, "b": 110})
			h_ship(110.5, 120.5, 8, 9, 6.5, 0, [2, 6]); h_e("gull", 118, 3, {"a": 112, "b": 126}); h_g(129, 133, 9); h_co(129, 7, 4)
			h_ship(133.5, 139.5, 4, 9, 4.2, 1); h_g(144, 148, 8); h_co(144, 6, 4)
			h_ship(148.5, 155.5, 6, 9, 4.8, .7, [3]); h_g(162, 184, 9, 6); h_e("viking", 168, 9, {"a": 164, "b": 172}); h_sg(165, "FAMOUS LAST WORDS|\"I know a shortcut\""); L["goal"] = 176 * T
		3:
			L = mk({"n": 3, "cols": 178, "th": "aq", "year": "19 BC", "title": "Aqueduct Ad Infinitum", "sub": "Contractor Arriving Tuesday (Which Tuesday?)", "hint": "Currents push you. Cracked arches crumble. Legionaries block from the front.", "short": "Aqueduct", "par": 70.0, "sx": 3, "sr": 8})
			h_g(0, 14, 8); h_sg(5, "AQVA APPIA|ready by Tuesday"); h_g(14, 40, 7, 7); h_zone({"k": "cur", "x0": 14 * T, "x1": 40 * T, "y": 7 * T, "f": 80.0}); h_co(18, 5, 8, 2); h_e("legion", 33, 7)
			h_sg(38, "ARCHES BY|lowest bidder", 7)
			for x in range(40, 44):
				h_cr(x, 7)
			h_g(44, 60, 7, 7); h_zone({"k": "cur", "x0": 44 * T, "x1": 60 * T, "y": 7 * T, "f": -110.0}); h_sg(47, "PUMP INSTALLED|backwards", 7); h_e("legion", 54, 7); h_co(49, 5, 4)
			for x in [60, 61, 64, 65]:
				h_cr(x, 7)
			h_co(62, 5, 2)
			h_g(66, 74, 7, 7); h_fl(68); h_pl(76, 6, 3); h_pl(80, 5, 3); h_cr(84, 6); h_cr(85, 6); h_co(80, 4, 3)
			h_g(88, 104, 7, 7); h_zone({"k": "cur", "x0": 88 * T, "x1": 104 * T, "y": 7 * T, "f": 150.0}); h_sg(90, "RAPIDS|pre-approved", 7); h_co(92, 6, 10)
			h_cr(106, 7); h_g(108, 124, 7, 7); h_zone({"k": "cur", "x0": 108 * T, "x1": 124 * T, "y": 7 * T, "f": -80.0}); h_e("legion", 114, 7); h_e("legion", 121, 7)
			h_pl(125, 5, 2); h_co(125, 4, 2); h_g(128, 152, 7, 7); h_e("legion", 136, 7)
			for x in range(142, 146):
				h_cr(x, 7)
			h_g(146, 152, 7, 7); h_e("legion", 150, 7); h_co(140, 5, 8)
			h_g(152, 178, 8); h_e("contractor", 163, 8); L["goal"] = 170 * T
		4:
			L = mk({"n": 4, "cols": 178, "th": "polder", "year": "1592 AD", "title": "Polder Zuid, Twente-ish", "sub": "Headwind in Both Directions", "hint": "Ride the windmill sails. Jump between gusts.", "short": "Polder", "par": 80.0, "sx": 2, "sr": 10})
			h_g(0, 16, 10); h_sg(5, "WIND|against you, always"); h_e("goose", 12, 10, {"a": 8, "b": 16}); h_wa(16, 18)
			h_g(18, 34, 10); h_zone({"k": "wind", "x0": 18 * T, "x1": 47 * T, "y0": 0.0, "per": 4.6, "on": 2.0, "ph": 0.0, "f": -170.0}); h_e("cyclist", 30, 10, {"a": 20, "b": 34}); h_wa(34, 37)
			h_g(37, 48, 10); h_e("goose", 44, 10, {"a": 40, "b": 48}); h_co(39, 8, 4); h_sg(46, "WINDMILL|ride at own risk"); h_wa(48, 58, 10); h_mill(53, 210, 110, 6.5, -1); h_co(52, 9, 2)
			h_g(58, 72, 10); h_fl(60); h_e("cyclist", 68, 10, {"a": 62, "b": 72}); h_co(63, 8, 5); h_wa(72, 75); h_zone({"k": "wind", "x0": 66 * T, "x1": 100 * T, "y0": 0.0, "per": 4.2, "on": 1.8, "ph": 1.5, "f": -200.0})
			h_g(75, 88, 10); h_e("cow", 80, 10); h_e("goose", 86, 10, {"a": 83, "b": 88}); h_wa(88, 98, 10); h_mill(93, 215, 112, 7, 1); h_co(91, 1, 4)
			h_g(98, 118, 10); h_sg(100, "FIETSPAD|knights yield"); h_e("cyclist", 108, 10, {"a": 101, "b": 118}); h_e("cyclist", 113, 10, {"a": 104, "b": 117, "face": 1}); h_wa(118, 121); h_zone({"k": "wind", "x0": 110 * T, "x1": 135 * T, "y0": 0.0, "per": 4.0, "on": 1.8, "ph": .6, "f": -210.0})
			h_g(121, 132, 10); h_co(122, 8, 4); h_e("goose", 129, 10, {"a": 124, "b": 132}); h_wa(132, 142, 10); h_mill(137, 210, 110, 5, -1)
			h_g(142, 178, 10); h_e("cyclist", 152, 10, {"a": 146, "b": 162}); h_co(146, 8, 6); h_sg(164, "TIME PORTAL|mind the gap"); L["goal"] = 170 * T
		5:
			L = mk({"n": 5, "cols": 100, "th": "tower", "year": "1199 AD-ish", "title": "The Inventor's Tower", "sub": "Peer Review", "hint": "Swing at bolts to parry them back. Hit him while he reloads.", "short": "Tower", "par": 40.0, "sx": 2, "sr": 10, "arena": [76, 98]})
			h_g(0, 12, 10); h_sg(5, "NO SWORDS|beyond this point"); h_g(12, 30, 10); h_sp(16, 18, 9); h_pl(15, 7, 4); h_co(15, 6, 4); h_e("clerk", 26, 10)
			h_sp(30, 34, 12); h_raft(31, 2, 6, 9, 2.6, 0); h_g(34, 48, 9); h_e("clerk", 41, 9); h_bx(46, 7, 2, 2); h_e("turret", 45, 9, {"face": -1}); h_co(36, 7, 4)
			h_g(48, 62, 10); h_fl(51); h_e("clerk", 57, 10); h_co(53, 8, 3); h_sp(62, 70, 12); h_raft(63, 2, 6, 9, 2.4, 0); h_raft(66, 2, 6, 9, 2.4, PI); h_co(65, 4, 1)
			h_g(70, 100, 10); h_sg(71, "PROF. BOLT|office hours: now"); h_fl(73); h_pl(79, 7, 3); h_pl(92, 7, 3); h_bx(98, 0, 2, 10); L["goal"] = 1e9
	return L


# ---------------------------------------------------------------- physics helpers

func is_solid(c: int) -> bool:
	return c == 1 or c == 2 or c == 6 or c == 7


func tile(cx: int, cy: int) -> int:
	if cx < 0 or cx >= L["cols"]:
		return 1
	if cy < 0 or cy >= ROWS:
		return 0
	return L["grid"][cy * L["cols"] + cx]


func pl_pos(q: Dictionary, t2: float) -> Vector2:
	match q["k"]:
		"ship":
			var u := .5 - .5 * clampf(cos(TAU * t2 / q["per"] + q["ph"]) * 1.35, -1, 1)
			return Vector2(lerpf(q["a"], q["b"], u), q["y0"] + sin(t2 * 1.9 + q["ph"] * 3) * 2.5)
		"raft":
			var u2 := .5 - .5 * cos(TAU * t2 / q["per"] + q["ph"])
			return Vector2(q["x0"], lerpf(q["a"], q["b"], u2))
		"blade":
			var an: float = q["a0"] + q["dir"] * TAU * t2 / q["per"]
			return Vector2(q["hx"] + cos(an) * q["R"] - q["w"] / 2, q["hy"] + sin(an) * q["R"] - 5)
		"crumble":
			return Vector2(q["x0"], q["y0"] + q["dy"])
	return Vector2(q.get("x0", 0.0), q.get("y0", 0.0))


func move_x(o: Dictionary, dx: float) -> int:
	if dx == 0.0:
		return 0
	o["x"] += dx
	var y0 := floori(o["y"] / T)
	var y1 := floori((o["y"] + o["h"] - .01) / T)
	if dx > 0:
		var cx := floori((o["x"] + o["w"]) / T)
		for cy in range(y0, y1 + 1):
			if is_solid(tile(cx, cy)):
				o["x"] = cx * T - o["w"] - .01
				o["vx"] = 0.0
				return 1
	else:
		var cx2 := floori(o["x"] / T)
		for cy in range(y0, y1 + 1):
			if is_solid(tile(cx2, cy)):
				o["x"] = (cx2 + 1) * T + .01
				o["vx"] = 0.0
				return -1
	return 0


func move_y(o: Dictionary, dy: float) -> int:
	var pb: float = o["y"] + o["h"]
	o["y"] += dy
	var x0 := floori(o["x"] / T)
	var x1 := floori((o["x"] + o["w"] - .01) / T)
	if dy > 0:
		var cy := floori((o["y"] + o["h"]) / T)
		for cx in range(x0, x1 + 1):
			var c := tile(cx, cy)
			if is_solid(c) or (c == 3 and pb <= cy * T + .5):
				o["y"] = cy * T - o["h"]
				o["vy"] = 0.0
				return 1
	elif dy < 0:
		var cy2 := floori(o["y"] / T)
		for cx in range(x0, x1 + 1):
			if is_solid(tile(cx, cy2)):
				o["y"] = (cy2 + 1) * T
				o["vy"] = 0.0
				return -1
	return 0


func zone_f(z: Dictionary, t2: float) -> float:
	if z["k"] == "cur":
		return z["f"]
	var s: float = z["per"] - z["on"]
	var ph := fposmod(t2 + z["ph"], z["per"])
	if ph < s:
		return 0.0
	var u: float = (ph - s) / z["on"]
	return z["f"] * minf(1.0, minf(u * 4, (1 - u) * 4))


func zone_warn(z: Dictionary, t2: float) -> bool:
	if z["k"] == "cur":
		return false
	var s: float = z["per"] - z["on"]
	var ph := fposmod(t2 + z["ph"], z["per"])
	return ph > s - .9 and ph < s


func push_on(o: Dictionary, t2: float) -> float:
	var ex := 0.0
	for z in L["zones"]:
		if o["x"] + o["w"] < z["x0"] or o["x"] > z["x1"]:
			continue
		if z["k"] == "cur":
			if o["on"] and o.get("on_plat") == null and absf(o["y"] + o["h"] - z["y"]) < 3:
				ex += z["f"]
		elif o["y"] + o["h"] > z["y0"]:
			ex += zone_f(z, t2) * (1.0 if o["on"] else 1.25)
	return ex


func pstep(i: Dictionary, dt: float, t2: float) -> int:
	var tg: Variant = 0.0 if p["kb"] > 0 else (i["r"] - i["l"]) * RUN
	if p["kb"] > 0:
		p["kb"] -= dt
	if tg != 0.0:
		var a := 2400.0 if p["on"] else 1400.0
		p["vx"] += signf(tg - p["vx"]) * minf(absf(tg - p["vx"]), a * dt)
		if not (p["atk"] > 0):
			p["face"] = 1.0 if tg > 0 else -1.0
	else:
		var fr := 2600.0 if p["on"] else (200.0 if p["kb"] > 0 else 600.0)
		p["vx"] -= signf(p["vx"]) * minf(absf(p["vx"]), fr * dt)
	if i["jp"]:
		p["jb"] = .13
	else:
		p["jb"] -= dt
	if p["on"]:
		p["co"] = .1
	else:
		p["co"] -= dt
	if p["jb"] > 0 and p["co"] > 0:
		if p["on_plat"] != null:
			var a2 := pl_pos(p["on_plat"], t2)
			var b2 := pl_pos(p["on_plat"], t2 - dt)
			p["vx"] += (a2.x - b2.x) / dt * .6
		p["vy"] = -JV
		p["on"] = false
		p["on_plat"] = null
		p["co"] = 0.0
		p["jb"] = 0.0
	var g := GR
	if p["vy"] < 0 and not i["j"]:
		g *= 2.5
	p["vy"] = minf(MAXF, p["vy"] + g * dt)
	var ex := push_on(p, t2)
	var q = p["on_plat"]
	var cdx := 0.0
	if q != null:
		cdx = pl_pos(q, t2).x - pl_pos(q, t2 - dt).x
	move_x(p, (p["vx"] + ex) * dt + cdx)
	if q != null and p["vy"] >= 0:
		var a3 := pl_pos(q, t2)
		if not q["gone"] and p["x"] + p["w"] > a3.x + 1 and p["x"] < a3.x + q["w"] - 1:
			p["y"] = a3.y - p["h"]
			p["vy"] = 0.0
			p["on"] = true
			return post()
	p["on_plat"] = null
	var pb: float = p["y"] + p["h"]
	p["on"] = move_y(p, p["vy"] * dt) == 1
	if not p["on"] and p["vy"] >= 0:
		for r in L["plats"]:
			if r["gone"]:
				continue
			var a4 := pl_pos(r, t2)
			var b4 := pl_pos(r, t2 - dt)
			if p["x"] + p["w"] > a4.x + 1 and p["x"] < a4.x + r["w"] - 1 and pb <= b4.y + 5 and p["y"] + p["h"] >= a4.y:
				p["y"] = a4.y - p["h"]
				p["vy"] = 0.0
				p["on"] = true
				p["on_plat"] = r
				break
	return post()


func post() -> int:
	p["haz"] = 0
	if p["y"] > FALLY:
		p["haz"] = 2
		return 2
	var x0 := floori((p["x"] + 3) / T)
	var x1 := floori((p["x"] + p["w"] - 3) / T)
	var y0 := floori(p["y"] / T)
	var y1 := floori((p["y"] + p["h"] - 1) / T)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := tile(cx, cy)
			if c == 4 and p["y"] + p["h"] > cy * T + 18:
				p["haz"] = 1
			elif c == 5 and p["y"] + p["h"] > cy * T + 12:
				p["haz"] = 3
				return 3
	return p["haz"]


func ov(a: Dictionary, b: Dictionary) -> bool:
	return a["x"] < b["x"] + b["w"] and a["x"] + a["w"] > b["x"] and a["y"] < b["y"] + b["h"] and a["y"] + a["h"] > b["y"]


func rect(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h}


# ---------------------------------------------------------------- fx

func add_fx(x: float, y: float, s: String, c := Color(1, 1, 1), big := false) -> void:
	fx.append({"x": x, "y": y, "s": s, "c": c, "t": 0.0, "big": big})


func burst(x: float, y: float, n: int, cols: Array, v := 120.0, g := 600.0, life := .6, up := 0.0, ang = null, spread := 1.0) -> void:
	for i in n:
		var a: float = (ang + (randf() - .5) * spread) if ang != null else randf() * TAU
		var sp := v * (.4 + randf() * .8)
		parts.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp - up, "g": g, "l": 0.0, "m": life * (.6 + randf() * .6), "c": cols[i % cols.size()], "s": 3.0})


func bubble(e: Dictionary, s: String, dur := 1.6) -> void:
	e["bub"] = {"s": s, "t": dur}


func toast(a: String, b: String, dur := 2.8) -> void:
	toast_d = {"a": a, "b": b, "t": dur}


func add_score(n: int, x = null, y := 0.0, lab := "") -> void:
	score += n
	if x != null:
		add_fx(x, y, lab if lab != "" else "+%d" % n, Color("#ffd34d"))


func fmt_t(s: float) -> String:
	var n := maxi(0, int(s))
	return "%d:%02d" % [n / 60, n % 60]


# ---------------------------------------------------------------- flow

func begin_run() -> void:
	D = DIFS[diff]
	lives = D["lives"]
	score = 0
	play_time = 0.0
	seen = {}
	coins = 0
	kills = 0
	geese = 0
	parries = 0
	new_best = false


func load_level(n: int) -> void:
	build_level(n)
	lv = n
	lt = 0.0
	proj.clear()
	parts.clear()
	fx.clear()
	boss = null
	boss_on = false
	wt = 0.0
	var hp: int = D["hp"]
	p = new_player()
	p["hp"] = hp
	p["x"] = L["sx"] * T + 6
	p["y"] = L["sr"] * T - p["h"]
	cp = Vector2(p["x"], p["y"])
	banner_t = 0.0
	toast_d = null
	cam_update(1.0, true)
	state = S.PLAY
	save_ck(false)


func resume_save(o: Dictionary) -> void:
	diff = clampi(int(o.get("diff", 1)), 0, 2)
	D = DIFS[diff]
	score = int(o.get("score", 0))
	lives = maxi(1, int(o.get("lives", 1)))
	play_time = float(o.get("time", 0.0))
	coins = int(o.get("coins", 0))
	kills = int(o.get("kills", 0))
	geese = int(o.get("geese", 0))
	parries = int(o.get("parries", 0))
	seen = o.get("seen", {}) if typeof(o.get("seen")) == TYPE_DICTIONARY else {}
	new_best = false
	var n := int(o["lv"])
	load_level(n)
	if o.get("boss", false) and n == 5:
		var a0: float = L["arena"][0] * T
		var cf = null
		for f in L["flags"]:
			if f["x"] < a0:
				f["on"] = true
				cf = f
		if cf != null:
			cp = Vector2(cf["x"] - p["w"] / 2, ground_y(cf["x"]) - p["h"])
			p["x"] = cp.x
			p["y"] = cp.y
		for c in L["coins"]:
			if c["x"] < a0:
				c["got"] = true
		L["ents"] = L["ents"].filter(func(e): return e["x"] >= a0 - 2 * T)
		cam_update(1.0, true)
		save_ck(true)


func respawn() -> void:
	p["x"] = cp.x
	p["y"] = cp.y
	p["vx"] = 0.0
	p["vy"] = 0.0
	p["on_plat"] = null
	p["on"] = false
	p["hp"] = D["hp"]
	p["inv"] = 1.6
	p["kb"] = 0.0
	p["safe"] = null
	p["dead"] = false
	proj.clear()
	if L["arena"] != null:
		for y in 10:
			L["grid"][y * L["cols"] + L["arena"][0]] = 0
		if boss != null:
			var b: Dictionary = boss
			b["hp"] = b["max"] if b["ph"] == 1 else (ceili(b["max"] * 2.0 / 3.0) if b["ph"] == 2 else ceili(b["max"] / 3.0))
		boss_on = false
		L["ents"] = L["ents"].filter(func(e): return not e.get("minion", false))
	state = S.PLAY
	cam_update(1.0, true)


func damage(src: String) -> void:
	if p["inv"] > 0 or state != S.PLAY:
		return
	p["hp"] -= 1
	p["inv"] = 1.4
	cause = src
	shake(8.0)
	flash = .15
	burst(p["x"] + 10, p["y"] + 12, 8, [Color("#d8dde5"), Color("#ffcf4d")], 160)
	if p["hp"] <= 0:
		die()
		return
	p["vx"] = -p["face"] * 230
	p["vy"] = -330.0
	p["on"] = false
	p["on_plat"] = null
	p["kb"] = .28


func fall_pit(water: int) -> void:
	if state != S.PLAY:
		return
	p["hp"] -= 1
	if water:
		cause = "the North Sea (no directions asked)" if lv == 2 else ("a Dutch ditch" if lv == 4 else "a moat")
		burst(p["x"] + 10, p["y"] + p["h"] if water == 3 else FALLY - 40, 14, [Color("#bfe6ff"), Color("#ffffff"), Color("#7cc4ef")], 260, 900, .6, 0, -PI / 2, 1.4)
	else:
		cause = "gravity, a classic"
	shake(6.0)
	if p["hp"] <= 0:
		die()
		return
	var s = p["safe"]
	if s != null and s.has("pl") and not s["pl"]["gone"]:
		var a := pl_pos(s["pl"], wt)
		p["x"] = a.x + s["lx"]
		p["y"] = a.y - p["h"] - 2
		p["on_plat"] = null
	elif s != null and not s.has("pl"):
		p["x"] = s["x"]
		p["y"] = s["y"] - 2
	else:
		p["x"] = cp.x
		p["y"] = cp.y
	p["vx"] = 0.0
	p["vy"] = 0.0
	p["inv"] = 1.5
	p["on"] = false
	p["kb"] = 0.0
	add_fx(p["x"] + 10, p["y"] - 10, "-1 heart", Color("#ff7a7a"))


func die() -> void:
	state = S.DYING
	dtm = 1.6
	lives -= 1
	p["vy"] = -300.0
	p["dead"] = true
	shake(10.0)


func level_clear() -> void:
	state = S.CLEAR
	ct = 3.2
	var tb := maxi(0, roundi((L["par"] - lt) * 15))
	tally = {"t": lt, "tb": tb}
	score += tb


func next_after_clear() -> void:
	if lv < 5:
		lives = lives
		load_level(lv + 1)


# ---------------------------------------------------------------- boss

func boss_init() -> void:
	var ax0: float = L["arena"][0] * T
	var ax1: float = L["arena"][1] * T
	var old = boss
	boss = {"x": ax1 - 5 * T, "y": FLOOR - 60, "w": 40.0, "h": 60.0, "hp": old["hp"] if old != null else D["boss"], "max": D["boss"], "ph": old["ph"] if old != null else 1,
		"st": "intro", "tm": 1.4 if old != null else 3.2, "face": -1.0, "shots": 0, "inv": 0.0, "vx": 0.0, "vy": 0.0, "bub": null, "hf": 0.0, "ax0": ax0, "ax1": ax1,
		"vol": 0, "drops": 0, "dtm": 1.0, "t": 0.0, "crank": 0.0, "mark": null, "sid": -1, "sx": 0.0, "sy": 0.0, "tx": 0.0}
	var b: Dictionary = boss
	if b["ph"] == 3:
		b["y"] = 110.0
		b["st"] = "fly"
	if old == null:
		save_ck(true)
	bubble(b, "Back for more peer review?" if old != null else "Ah, the \"knight\". Behold: point, click, medieval!", 2.8)
	shake(5.0)
	boss_on = true
	for y in range(1, 10):
		L["grid"][y * L["cols"] + L["arena"][0]] = 2
	toast("PROF. BOLT VON TRIGGER", "Inventor of the crossbow (patent pending)", 3)


func side_x(b: Dictionary, right: bool) -> float:
	return b["ax1"] - 4 * T - b["w"] / 2 if right else b["ax0"] + 4 * T - b["w"] / 2


func boss_leap(b: Dictionary) -> void:
	var mid: float = (b["ax0"] + b["ax1"]) / 2
	var tx := side_x(b, true) if b["x"] + b["w"] / 2 < mid else side_x(b, false)
	b["st"] = "leap"
	b["vx"] = (tx - b["x"]) / .9
	b["vy"] = -675.0
	b["y"] -= 2


func boss_fire(b: Dictionary) -> void:
	var cx: float = b["x"] + b["w"] / 2 + b["face"] * 24
	var cy: float = b["y"] + 34
	if b["ph"] == 1:
		proj.append({"x": cx, "y": FLOOR - 20, "vx": b["face"] * 330 * D["spd"], "vy": 0.0, "g": 0.0, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": null})
		b["shots"] += 1
		if b["shots"] >= 3:
			b["st"] = "reload"
			b["tm"] = 2.3 * D["fire"]
			b["crank"] = 0.0
			bubble(b, ["Reloading... (patent pending)", "Hold on, cranking!", "Nobody move!"][randi() % 3], 1.6)
		else:
			b["st"] = "aim"
			b["tm"] = .95 * D["fire"]
	elif b["ph"] == 2:
		var px: float = p["x"] + p["w"] / 2
		for o in [-100, 0, 100]:
			var tx := clampf(px + o, b["ax0"] + T * 1.5, b["ax1"] - T * 1.5)
			var tf := 1.05
			var g := 900.0
			proj.append({"x": cx, "y": cy - 14, "vx": (tx - cx) / tf, "vy": (FLOOR - 6 - (cy - 14) - .5 * g * tf * tf) / tf, "g": g, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": tx})
		b["vol"] += 1
		if b["vol"] >= 2:
			b["vol"] = 0
			b["st"] = "reload"
			b["tm"] = 1.9 * D["fire"]
			bubble(b, "Triple-shot! ...needs a moment.", 1.5)
		else:
			b["st"] = "aimS"
			b["tm"] = .55 * D["fire"]


func boss_hit(src: String, x: float, y: float) -> int:
	var b = boss
	if b == null or b["inv"] > 0 or b["st"] in ["intro", "phase", "dead"]:
		return 0
	if src == "sword" and b["st"] != "reload" and b["st"] != "crash":
		add_fx(x, y, "BLOCKED", Color("#cfd8e6"))
		burst(x, y, 6, [Color("#ffe27a")], 180)
		bubble(b, "Out of reach, knight!" if b["ph"] == 3 else "Pavise! Patent pending!", 1)
		return 2
	b["hp"] -= 1
	b["inv"] = .7
	b["hf"] = .3
	shake(8.0)
	add_score(300, b["x"] + b["w"] / 2, b["y"] - 10)
	burst(b["x"] + b["w"] / 2, b["y"] + 20, 14, [Color("#ffd34d"), Color("#8a5a2b"), Color(1, 1, 1)], 220)
	if b["hp"] <= 0:
		b["st"] = "dead"
		b["vy"] = -380.0
		b["vx"] = -b["face"] * 80
		state = S.BOSSDEAD
		dtm = 4.6
		proj.clear()
		bubble(b, "Fine! Swords win! ...have you heard of GUNPOWDER?", 4.4)
		add_score(3000, b["x"] + b["w"] / 2, b["y"] - 30, "+3000 BOSS")
		for e in L["ents"]:
			if e.get("minion", false):
				e["dead"] = true
		return 1
	if b["ph"] == 1 and b["hp"] <= ceili(b["max"] * 2.0 / 3.0):
		b["ph"] = 2
		b["st"] = "phase"
		b["tm"] = 2.2
		b["vol"] = 0
		bubble(b, "Phase two! Now with THREE bolts! And a hired goose!", 2.2)
		proj.clear()
		for s in ([0, 1] if D["k"] == "hard" else [0]):
			var d: Dictionary = ED["goose"]
			L["ents"].append({"ty": "goose", "x": b["ax1"] - 3 * T if s else b["ax0"] + 2 * T, "y": FLOOR - d["h"], "w": float(d["w"]), "h": float(d["h"]), "vx": 0.0, "vy": 0.0, "face": -1.0 if s else 1.0, "hp": 1, "t": 0.0, "st": "idle", "cd": 1.5, "hf": 0.0, "dead": false, "dt": 0.0, "bub": null, "sid": -1, "x0": b["ax0"] + T, "x1": b["ax1"] - T, "minion": true, "mt": 0.0})
	elif b["ph"] == 2 and b["hp"] <= ceili(b["max"] / 3.0):
		b["ph"] = 3
		b["st"] = "phase"
		b["tm"] = 2.4
		bubble(b, "To the skies! Leonardo still owes me a wing!", 2.4)
		proj.clear()
	elif b["ph"] < 3:
		boss_leap(b)
	else:
		b["st"] = "rise"
		b["tm"] = .9
		bubble(b, "My ornithopter!", 1)
	return 1


func boss_upd(dt: float) -> void:
	var b = boss
	if b == null:
		return
	b["inv"] -= dt
	b["hf"] -= dt
	b["tm"] -= dt
	b["t"] += dt
	if b["bub"] != null:
		b["bub"]["t"] -= dt
		if b["bub"]["t"] <= 0:
			b["bub"] = null
	var pcx: float = p["x"] + p["w"] / 2
	var bcx: float = b["x"] + b["w"] / 2
	var mid: float = (b["ax0"] + b["ax1"]) / 2
	match b["st"]:
		"intro":
			if b["tm"] <= 0:
				b["st"] = "fly" if b["ph"] == 3 else "aim"
				b["tm"] = 1.0
		"aim":
			b["face"] = -1.0 if pcx < bcx else 1.0
			if b["tm"] <= 0:
				boss_fire(b)
		"aimS":
			b["face"] = -1.0 if pcx < bcx else 1.0
			if b["tm"] <= 0:
				proj.append({"x": bcx + b["face"] * 24, "y": FLOOR - 20, "vx": b["face"] * 380 * D["spd"], "vy": 0.0, "g": 0.0, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": null})
				boss_leap(b)
		"reload":
			b["crank"] += dt * 6
			if b["tm"] <= 0:
				b["shots"] = 0
				b["st"] = "aim"
				b["tm"] = .7 * D["fire"]
		"leap":
			b["vy"] += 1500 * dt
			b["x"] += b["vx"] * dt
			b["y"] += b["vy"] * dt
			if b["y"] >= FLOOR - b["h"] and b["vy"] > 0:
				b["y"] = FLOOR - b["h"]
				b["st"] = "aim"
				b["tm"] = .75 * D["fire"]
				shake(5.0)
				burst(bcx, FLOOR, 10, [Color("#b9ad9c")], 140, 600, .6, 0, -PI / 2, 2.5)
		"phase":
			if b["ph"] == 3:
				b["y"] = lerpf(b["y"], 110, minf(1, dt * 2))
				b["x"] = lerpf(b["x"], mid - b["w"] / 2, minf(1, dt * 1.5))
			if b["tm"] <= 0:
				b["st"] = "fly" if b["ph"] == 3 else "aim"
				b["tm"] = 1.0
				b["dtm"] = 1.0
		"fly":
			var tx: float = mid - b["w"] / 2 + sin(b["t"] * .85) * ((b["ax1"] - b["ax0"]) / 2 - 110)
			b["x"] = lerpf(b["x"], tx, minf(1, dt * 2.5))
			b["y"] = lerpf(b["y"], 104 + sin(b["t"] * 2.4) * 10, minf(1, dt * 3))
			b["face"] = -1.0 if pcx < bcx else 1.0
			b["dtm"] -= dt
			if b["dtm"] <= 0:
				proj.append({"x": bcx, "y": b["y"] + b["h"], "vx": 0.0, "vy": 120.0, "g": 500.0, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": bcx})
				b["drops"] += 1
				b["dtm"] = .95 * D["fire"]
				if b["drops"] >= 4:
					b["drops"] = 0
					b["st"] = "warn"
					b["tm"] = 1.0
					b["tx"] = clampf(pcx - b["w"] / 2, b["ax0"] + T * 1.2, b["ax1"] - T * 1.2 - b["w"])
					bubble(b, "Kamikaze is not a word yet!", 1)
		"warn":
			b["x"] += sin(b["t"] * 60) * 1.2
			b["mark"] = b["tx"] + b["w"] / 2
			if b["tm"] <= 0:
				b["st"] = "swoop"
				b["sx"] = b["x"]
				b["sy"] = b["y"]
				b["tm"] = .7
		"swoop":
			var u := 1.0 - maxf(0, b["tm"]) / .7
			var e := u * u
			b["x"] = lerpf(b["sx"], b["tx"], e)
			b["y"] = lerpf(b["sy"], FLOOR - b["h"], e)
			if b["tm"] <= 0:
				b["st"] = "crash"
				b["mark"] = null
				b["y"] = FLOOR - b["h"]
				b["tm"] = 2.1 * (1.25 if D["k"] == "easy" else (.8 if D["k"] == "hard" else 1.0))
				shake(12.0)
				burst(b["x"] + b["w"] / 2, FLOOR, 22, [Color("#a0702c"), Color("#e8e0cf"), Color("#7b5530")], 260, 600, .6, 0, -PI / 2, 2.6)
				bubble(b, "Out of pedal power!", 1.6)
		"crash":
			if b["tm"] <= 0:
				b["st"] = "rise"
				b["tm"] = .9
		"rise":
			b["y"] = lerpf(b["y"], 104, minf(1, dt * 3))
			if b["tm"] <= 0:
				b["st"] = "fly"
				b["dtm"] = .9
		"dead":
			b["vy"] += 1200 * dt
			b["y"] += b["vy"] * dt
			b["x"] += b["vx"] * dt
			if b["y"] > FLOOR - b["h"] + 8:
				b["y"] = FLOOR - b["h"] + 8
				b["vy"] = 0.0
				b["vx"] = 0.0
	if not (b["st"] in ["dead", "phase", "intro"]) and p["inv"] <= 0 and ov(p, rect(b["x"] + 6, b["y"] + 8, b["w"] - 12, b["h"] - 8)):
		damage("Professor Bolt himself")


# ---------------------------------------------------------------- enemies

func walk(e: Dictionary, dt: float, sp: float) -> bool:
	var nx: float = e["x"] + e["face"] * sp * dt
	var fx2: float = nx + e["w"] if e["face"] > 0 else nx
	var fcx := floori(fx2 / T)
	var fy := floori((e["y"] + e["h"] + 2) / T)
	var my := floori((e["y"] + e["h"] - 6) / T)
	var gc := tile(fcx, fy)
	var ok: bool = (is_solid(gc) or gc == 3) and not is_solid(tile(fcx, my)) and nx >= e["x0"] and nx + e["w"] <= e["x1"]
	if not ok:
		e["face"] *= -1
		return false
	e["x"] = nx
	return true


func seen_by(e: Dictionary, r: float, dy := 60.0) -> bool:
	return state == S.PLAY and absf(p["x"] + p["w"] / 2 - (e["x"] + e["w"] / 2)) < r and absf(p["y"] + p["h"] - (e["y"] + e["h"])) < dy


func upd_enemy(e: Dictionary, dt: float) -> void:
	e["t"] += dt
	e["hf"] -= dt
	if e["bub"] != null:
		e["bub"]["t"] -= dt
		if e["bub"]["t"] <= 0:
			e["bub"] = null
	if e["dead"]:
		e["dt"] += dt
		e["vy"] += 900 * dt
		e["x"] += e["vx"] * dt
		e["y"] += e["vy"] * dt
		return
	var px: float = p["x"] + p["w"] / 2
	var ex: float = e["x"] + e["w"] / 2
	if e.has("pl"):
		var a := pl_pos(e["pl"], wt)
		e["x"] = a.x + e["lx"]
		e["y"] = a.y - e["h"]
	match e["ty"]:
		"goose":
			if e["st"] == "charge":
				e["mt"] -= dt
				if not walk(e, dt, 170 * D["spd"]) or e["mt"] <= 0:
					e["st"] = "idle"
					e["cd"] = 1.3
			else:
				walk(e, dt, 40 * D["spd"])
				e["cd"] -= dt
				if e["cd"] <= 0 and seen_by(e, 190, 50):
					e["face"] = -1.0 if px < ex else 1.0
					e["st"] = "charge"
					e["mt"] = 1.1
					bubble(e, "HONK?!" if randf() < .2 else "HONK!", .9)
		"viking":
			if e.has("pl"):
				if e["st"] != "throw":
					e["lx"] += e["face"] * 28 * dt
					if e["lx"] < 4 or e["lx"] > e["pl"]["w"] - e["w"] - 4:
						e["lx"] = clampf(e["lx"], 4, e["pl"]["w"] - e["w"] - 4)
						e["face"] *= -1
			elif e["st"] != "throw":
				walk(e, dt, 30 * D["spd"])
			e["cd"] -= dt
			if e["st"] == "throw":
				e["face"] = -1.0 if px < ex else 1.0
				e["mt"] -= dt
				if e["mt"] <= 0:
					e["st"] = "idle"
					e["cd"] = 3.3 * D["fire"]
					var tf := clampf(absf(px - ex) / 230, .8, 1.35)
					var g := 900.0
					var sx: float = ex + e["face"] * 8
					var sy: float = e["y"] + 6
					var ty: float = p["y"] + p["h"] / 2
					proj.append({"x": sx, "y": sy, "vx": (px - sx) / tf, "vy": (ty - sy - .5 * g * tf * tf) / tf, "g": g, "k": "axe", "r": 7.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": null})
			elif e["cd"] <= 0 and seen_by(e, 300, 140):
				e["st"] = "throw"
				e["mt"] = .5
				if randf() < .35:
					bubble(e, ["Valhalla or bust!", "We are NOT lost!", "Left at Iceland!", "Axe-cellent!"][randi() % 4], 1.3)
		"gull":
			if not e.has("y0"):
				e["y0"] = e["y"]
			if e["st"] == "swoop":
				e["x"] += e["vx"] * dt
				e["y"] += e["vy"] * dt
				e["mt"] -= dt
				if e["mt"] <= 0:
					e["st"] = "rise"
			elif e["st"] == "rise":
				e["y"] -= 160 * dt
				e["x"] += e["face"] * 70 * dt
				if e["y"] <= e["y0"]:
					e["st"] = "idle"
					e["cd"] = 2.2
			elif e["st"] == "warn":
				e["mt"] -= dt
				if e["mt"] <= 0:
					var tx: float = px - e["w"] / 2
					var ty2: float = p["y"] - 4
					e["vx"] = (tx - e["x"]) / .65
					e["vy"] = (ty2 - e["y"]) / .65
					e["mt"] = .75
					e["st"] = "swoop"
			else:
				e["x"] += e["face"] * 75 * D["spd"] * dt
				if e["x"] < e["x0"] or e["x"] + e["w"] > e["x1"]:
					e["face"] *= -1
					e["x"] = clampf(e["x"], e["x0"], e["x1"] - e["w"])
				e["y"] = e["y0"] + sin(e["t"] * 2.4) * 8
				e["cd"] -= dt
				if e["cd"] <= 0 and absf(px - ex) < 150 and p["y"] > e["y"] + 50 and state == S.PLAY:
					e["st"] = "warn"
					e["mt"] = .4
					e["face"] = -1.0 if px < ex else 1.0
					bubble(e, "SKRAA!", .6)
		"legion":
			e["cd"] -= dt
			if e["cd"] <= 0:
				e["cd"] = .75
				if seen_by(e, 260, 70):
					var nf := -1.0 if px < ex else 1.0
					if nf != e["face"]:
						e["face"] = nf
						e["turn"] = .25
			e["turn"] = e.get("turn", 0.0) - dt
			if seen_by(e, 260, 70) and absf(px - ex) > 18 and e["turn"] <= 0:
				walk(e, dt, 32 * D["spd"])
			if randf() < dt * .15 and seen_by(e, 300):
				bubble(e, ["Testudo!", "SPQR: Shields, Pointy, Quite Rude", "Halt! Toll road!", "Veni, vidi, blocki"][randi() % 4], 1.4)
		"cyclist":
			var sp: float = (190 + push_on({"x": e["x"], "y": e["y"], "w": e["w"], "h": e["h"], "on": true}, wt) * .45 * e["face"]) * D["spd"]
			if e["st"] == "skid":
				e["mt"] -= dt
				if e["mt"] <= 0:
					e["st"] = "ride"
			elif not walk(e, dt, maxf(40, sp)):
				e["st"] = "skid"
				e["mt"] = .45
			if absf(px - ex) < 330 and (px - ex) * e["face"] > 0 and not e.get("rang", false) and state == S.PLAY:
				e["rang"] = true
				bubble(e, "TRING TRING!", 1)
			if (px - ex) * e["face"] < 0:
				e["rang"] = false
		"clerk":
			e["face"] = -1.0 if px < ex else 1.0
			e["cd"] -= dt
			if e["st"] == "aim":
				e["mt"] -= dt
				if e["mt"] <= 0:
					e["st"] = "idle"
					e["cd"] = 2.5 * D["fire"]
					proj.append({"x": ex + e["face"] * 14, "y": e["y"] + 17, "vx": e["face"] * 300 * D["spd"], "vy": 0.0, "g": 0.0, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": null})
			elif e["cd"] <= 0 and seen_by(e, 400, 90):
				e["st"] = "aim"
				e["mt"] = .6
				if randf() < .3:
					bubble(e, ["Patented!", "Form 27-B: bolt", "Royalties!"][randi() % 3], 1.2)
		"turret":
			e["cd"] -= dt
			if e["st"] == "aim":
				e["mt"] -= dt
				if e["mt"] <= 0:
					e["st"] = "idle"
					e["cd"] = 2 * D["fire"]
					proj.append({"x": e["x"] + (0.0 if e["face"] < 0 else e["w"]), "y": e["y"] + 11, "vx": e["face"] * 330 * D["spd"], "vy": 0.0, "g": 0.0, "k": "bolt", "r": 5.0, "host": true, "fr": false, "age": 0.0, "rot": 0.0, "mk": null})
			elif e["cd"] <= 0 and absf(px - ex) < 420:
				e["st"] = "aim"
				e["mt"] = .5
		"cow":
			if seen_by(e, 120) and not e.get("mooed", false):
				e["mooed"] = true
				bubble(e, "Moo. (judgmentally)", 2)
		"contractor":
			if seen_by(e, 260, 200) and not e.get("said", false):
				e["said"] = true
				bubble(e, "Sorry I'm late! Traffic in Gaul. Invoice attached.", 3.5)


func kill_e(e: Dictionary, how: String) -> void:
	e["dead"] = true
	e["dt"] = 0.0
	e["vy"] = -320.0
	e["vx"] = (-1.0 if e["x"] + e["w"] / 2 < p["x"] + p["w"] / 2 else 1.0) * 140
	kills += 1
	var d: Dictionary = ED[e["ty"]]
	add_score(int(d["pts"] * (1.5 if how == "stomp" else 1.0)), e["x"] + e["w"] / 2, e["y"] - 6)
	if e["ty"] == "goose":
		geese += 1
		burst(e["x"] + 13, e["y"] + 10, 14, [Color(1, 1, 1), Color("#e9e6dd")], 150, 120, 1.3)
		add_fx(e["x"] + 13, e["y"] - 22, "honk...")
	elif e["ty"] == "dummy":
		burst(e["x"] + 10, e["y"] + 12, 14, [Color("#e2c46b"), Color("#c9a347"), Color("#f0dc94")], 170, 300, 1.0)
	elif e["ty"] == "turret":
		burst(e["x"] + 14, e["y"] + 10, 14, [Color("#7b5530"), Color("#a0702c"), Color("#5b5f66")], 200)
		add_fx(e["x"] + 14, e["y"] - 20, "Decommissioned!")
	else:
		burst(e["x"] + e["w"] / 2, e["y"] + e["h"] / 2, 10, [Color("#ffd34d"), Color(1, 1, 1), Color("#c8ced8")], 180)
	if e["ty"] == "cyclist":
		add_fx(e["x"] + 16, e["y"] - 22, "Fiets confiscated!")


func hit_e(e: Dictionary, how: String) -> int:
	if e["dead"] or e["hf"] > 0:
		return 0
	var d: Dictionary = ED[e["ty"]]
	if d.get("npc", false):
		if e["ty"] == "cow":
			bubble(e, "MOO. (very disappointed)", 1.5)
		return 0
	if e["ty"] == "legion" and how == "sword" and (p["x"] + p["w"] / 2 - (e["x"] + e["w"] / 2)) * e["face"] > 0:
		var sx: float = e["x"] + (e["w"] if e["face"] > 0 else 0.0)
		burst(sx, e["y"] + 18, 8, [Color("#ffe27a"), Color(1, 1, 1)], 200)
		add_fx(sx, e["y"] - 4, "CLANG!", Color("#ffe27a"))
		p["vx"] = -p["face"] * 200
		p["kb"] = .15
		e["x"] += e["face"] * -4
		return 2
	e["hp"] -= 1
	e["hf"] = .25
	if e["hp"] <= 0:
		kill_e(e, how)
	else:
		burst(e["x"] + e["w"] / 2, e["y"] + 10, 5, [Color(1, 1, 1)], 120)
		if e.has("pl"):
			e["lx"] = clampf(e["lx"] + (-10.0 if e["x"] + e["w"] / 2 < p["x"] + p["w"] / 2 else 10.0), 4, e["pl"]["w"] - e["w"] - 4)
	return 1


# ---------------------------------------------------------------- main update

func intro(e: Dictionary) -> void:
	var d: Dictionary = ED[e["ty"]]
	if seen.has(e["ty"]) or not d.has("tag"):
		return
	var sx: float = e["x"] - cam_x
	if sx > -10 and sx < VW - 20:
		seen[e["ty"]] = true
		toast(d["tag"][0], d["tag"][1], 3)


func cam_update(dt: float, snap := false) -> void:
	var lead: float = p["face"] * VW * .07
	var tx: float = p["x"] + p["w"] / 2 - VW * .42 + lead
	var lo := 0.0
	var hi: float = L["cols"] * T
	if boss_on and L["arena"] != null:
		lo = L["arena"][0] * T
		hi = (L["arena"][1] + 1) * T
	if hi - lo <= VW:
		tx = (lo + hi) / 2 - VW / 2
	else:
		tx = clampf(tx, lo, hi - VW)
	if snap:
		cam_x = tx
	else:
		cam_x = lerpf(cam_x, tx, minf(1, dt * 7))


func on_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var k: int = event.keycode
		if k in [KEY_UP, KEY_W, KEY_SPACE, KEY_Z]:
			if event.pressed:
				jump_pressed = true
		elif k in [KEY_X, KEY_J, KEY_K, KEY_ENTER, KEY_KP_ENTER, KEY_SHIFT]:
			if event.pressed:
				atk_pressed = true
		if event.pressed and state == S.TITLE:
			if k in [KEY_LEFT, KEY_A]:
				diff = maxi(0, diff - 1)
			elif k in [KEY_RIGHT, KEY_D]:
				diff = mini(2, diff + 1)
			elif k == KEY_N and saved != null:
				clear_save()


func read_input() -> Dictionary:
	var ax := axis().x
	var jh: bool = a_down or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_Z)
	var jp := jump_pressed or pressed_a()
	var ap := atk_pressed or pressed_b()
	jump_pressed = false
	atk_pressed = false
	return {"l": 1 if ax < -0.3 else 0, "r": 1 if ax > 0.3 else 0, "j": jh, "jp": jp, "ap": ap}


func _process(delta: float) -> void:
	tick(delta)
	var dt := minf(delta, 1.0 / 30.0)
	gt += dt
	if state == S.TITLE:
		title_cam += dt * 30
		if title_cam > L["cols"] * T - VW - 10:
			title_cam = 0.0
		cam_x = title_cam
		var tap := pressed_a() or jump_pressed or atk_pressed or pressed_b()
		jump_pressed = false
		atk_pressed = false
		if tap:
			begin_run()
			if saved != null:
				resume_save(saved)
				saved = null
			else:
				load_level(1)
		queue_redraw()
		return
	if state == S.END or state == S.OVER:
		var tap2 := pressed_a() or jump_pressed or atk_pressed or pressed_b()
		jump_pressed = false
		atk_pressed = false
		if tap2 and t > 1.5:
			state = S.TITLE
			saved = load_save()
			L = build_level(1)
			p = new_player()
			p["x"] = 6 * T
			p["y"] = FLOOR - p["h"]
		queue_redraw()
		return
	var inp := read_input()
	# two physics substeps for stability
	step(dt / 2.0, inp)
	inp["jp"] = false
	inp["ap"] = false
	step(dt / 2.0, inp)
	queue_redraw()


func step(dt: float, i: Dictionary) -> void:
	for q in parts:
		q["l"] += dt
		q["vy"] += q["g"] * dt
		q["x"] += q["vx"] * dt
		q["y"] += q["vy"] * dt
	parts = parts.filter(func(q): return q["l"] < q["m"])
	for f in fx:
		f["t"] += dt
	fx = fx.filter(func(f): return f["t"] < 1.1)
	if flash > 0:
		flash -= dt
	if toast_d != null:
		toast_d["t"] -= dt
		if toast_d["t"] <= 0:
			toast_d = null
	if banner_t >= 0:
		banner_t += dt
		if banner_t > 4:
			banner_t = -1.0
	wt += dt
	for q in L["plats"]:
		if q["k"] == "crumble":
			if q["st"] == 1:
				q["tm"] -= dt
				if q["tm"] <= 0:
					q["st"] = 2
					q["vy"] = 0.0
			elif q["st"] == 2:
				q["vy"] += 1300 * dt
				q["dy"] += q["vy"] * dt
				if q["dy"] > 520:
					q["st"] = 3
					q["gone"] = true
					q["rt"] = 3.0
			elif q["st"] == 3:
				q["rt"] -= dt
				if q["rt"] <= 0 and not (p["x"] + p["w"] > q["x0"] and p["x"] < q["x0"] + T and absf(p["y"] + p["h"] - q["y0"]) < 40):
					q["st"] = 0
					q["dy"] = 0.0
					q["gone"] = false
	if state == S.DYING:
		dtm -= dt
		p["vy"] += 900 * dt
		p["y"] += p["vy"] * dt
		if dtm <= 0:
			if lives <= 0:
				game_over()
			else:
				respawn()
		cam_update(dt)
		return
	if state == S.CLEAR:
		ct -= dt
		p["x"] += 60 * dt
		p["run"] += dt * 6
		if ct <= 0:
			next_after_clear()
		upd_proj(dt, null)
		return
	if state == S.BOSSDEAD:
		dtm -= dt
		boss_upd(dt)
		pstep({"l": 0, "r": 0, "j": false, "jp": false}, dt, wt)
		if dtm <= 0:
			ending()
		cam_update(dt)
		return
	play_time += dt
	lt += dt
	p["atk_cd"] -= dt
	if i["ap"] and p["atk_cd"] <= 0:
		p["atk"] = .25
		p["atk_cd"] = .3
		p["sid"] += 1
	if p["atk"] > 0:
		p["atk"] -= dt
	p["inv"] -= dt
	var was_on: bool = p["on"]
	var vy0: float = p["vy"]
	pstep(i, dt, wt)
	if p["on"] and not was_on and vy0 > 350:
		burst(p["x"] + 10, p["y"] + p["h"], 6, [Color("#cfc6b4")], 90, 600, .35, 0, -PI / 2, 2.8)
	var op = p["on_plat"]
	if op != null and op["k"] == "crumble" and op["st"] == 0:
		op["st"] = 1
		op["tm"] = .4
		if not seen.has("cr"):
			seen["cr"] = true
			toast("ARCHES BY THE LOWEST BIDDER", "Keep moving. They crumble.", 2.6)
	if op != null and op["k"] == "ship" and not seen.has("ship"):
		seen["ship"] = true
		toast("LONGSHIP", "Never asks for directions", 2.4)
	if op != null and op["k"] == "blade" and not seen.has("bl"):
		seen["bl"] = true
		toast("WINDMILL SAIL", "Ride it. Don't ask why.", 2.4)
	if p["on"] and p["haz"] == 0:
		if op != null:
			if op["k"] == "blade":
				var a := pl_pos(op, wt)
				p["safe"] = {"pl": op, "lx": clampf(p["x"] - a.x, 4, op["w"] - p["w"] - 4)}
		else:
			var fy := floori((p["y"] + p["h"] + 2) / T)
			var c1 := tile(floori((p["x"] - 4) / T), fy)
			var c2 := tile(floori((p["x"] + p["w"] + 4) / T), fy)
			if (is_solid(c1) or c1 == 3) and (is_solid(c2) or c2 == 3) and p["x"] > 8:
				p["safe"] = {"x": p["x"], "y": p["y"]}
	for z in L["zones"]:
		if p["x"] + p["w"] > z["x0"] and p["x"] < z["x1"]:
			if z["k"] == "cur" and p["on"] and absf(p["y"] + p["h"] - z["y"]) < 3 and not seen.has("cur"):
				seen["cur"] = true
				toast("ROMAN CURRENT", "Plumbing, now with direction", 2.6)
			if z["k"] == "wind":
				var f := zone_f(z, wt)
				if f != 0.0 and not z["snd"]:
					z["snd"] = true
					if not seen.has("wind"):
						seen["wind"] = true
						toast("HEADWIND", "Dutch weather, standard issue", 2.6)
				if f == 0.0:
					z["snd"] = false
	if p["haz"] == 1:
		damage("caltrops (pointy side up)")
		if state == S.PLAY:
			p["vy"] = -470.0
			p["kb"] = .1
	elif p["haz"] == 2:
		fall_pit(0)
	elif p["haz"] == 3:
		fall_pit(3)
	if state != S.PLAY:
		cam_update(dt)
		return
	p["run"] += absf(p["vx"]) * dt * .085
	var sb = null
	if p["atk"] > .03 and p["atk"] < .22:
		sb = rect(p["x"] + p["w"] - 4 if p["face"] > 0 else p["x"] - 38, p["y"] - 8, 42, p["h"] + 10)
	for e in L["ents"]:
		upd_enemy(e, dt)
		if e["dead"]:
			continue
		intro(e)
		var d: Dictionary = ED[e["ty"]]
		if sb != null and e["sid"] != p["sid"] and ov(sb, e):
			e["sid"] = p["sid"]
			hit_e(e, "sword")
		if not e["dead"] and d["hurts"] and ov(p, rect(e["x"] + 3, e["y"] + 3, e["w"] - 6, e["h"] - 3)):
			if p["vy"] > 60 and p["y"] + p["h"] - e["y"] < 14 + p["vy"] * .03 and e["ty"] != "turret":
				hit_e(e, "stomp")
				p["vy"] = -600.0 if i["j"] else -390.0
				p["on"] = false
				p["on_plat"] = null
			else:
				damage(d["nm"])
	L["ents"] = L["ents"].filter(func(e): return not e["dead"] or e["dt"] < 2)
	if boss != null and boss_on:
		boss_upd(dt)
		if sb != null and boss["sid"] != p["sid"] and ov(sb, boss):
			boss["sid"] = p["sid"]
			boss_hit("sword", p["x"] + p["w"] / 2 + p["face"] * 24, p["y"] + 8)
	upd_proj(dt, sb)
	for c in L["coins"]:
		if not c["got"] and absf(c["x"] - (p["x"] + p["w"] / 2)) < 18 and absf(c["y"] - (p["y"] + p["h"] / 2)) < 22:
			c["got"] = true
			coins += 1
			add_score(25)
			burst(c["x"], c["y"], 5, [Color("#ffe27a")], 90, 0, .35)
	for f in L["flags"]:
		if not f["on"] and p["x"] + p["w"] > f["x"] - 8 and p["x"] < f["x"] + 8:
			f["on"] = true
			cp = Vector2(f["x"] - p["w"] / 2, ground_y(f["x"]) - p["h"])
			toast("CHECKPOINT", "Progress saved on parchment", 1.8)
	if p["x"] > L["goal"]:
		level_clear()
	if L["arena"] != null and not boss_on and p["x"] > (L["arena"][0] + 2.5) * T:
		boss_init()
	cam_update(dt)


func upd_proj(dt: float, sb) -> void:
	var b = boss
	for q in proj:
		q["x"] += q["vx"] * dt
		q["vy"] += q["g"] * dt
		q["y"] += q["vy"] * dt
		if q["k"] == "axe":
			q["rot"] += dt * 14 * signf(q["vx"] if q["vx"] != 0.0 else 1.0)
		q["age"] += dt
		var c := tile(floori(q["x"] / T), floori(q["y"] / T))
		if is_solid(c) or q["y"] > LH + 20 or q["age"] > 6:
			q["dead"] = true
			if is_solid(c) and q["y"] < LH:
				burst(q["x"], q["y"], 4, [Color("#cdb48a")], 80, 600, .3)
			continue
		if q["host"] and state == S.PLAY:
			if sb != null and q["x"] > sb["x"] - q["r"] and q["x"] < sb["x"] + sb["w"] + q["r"] and q["y"] > sb["y"] - q["r"] and q["y"] < sb["y"] + sb["h"] + q["r"]:
				q["host"] = false
				q["fr"] = true
				parries += 1
				add_score(25, q["x"], q["y"] - 10, "PARRY!")
				burst(q["x"], q["y"], 8, [Color(1, 1, 1), Color("#ffe27a")], 200, 600, .3)
				if q["k"] == "bolt" and b != null and boss_on:
					var dv := Vector2(b["x"] + b["w"] / 2 - q["x"], b["y"] + b["h"] * .45 - q["y"])
					var dd := maxf(1.0, dv.length())
					q["vx"] = dv.x / dd * 560
					q["vy"] = dv.y / dd * 560
					q["g"] = 0.0
				elif q["k"] == "bolt":
					q["vx"] = p["face"] * 480
					q["vy"] = -30.0
					q["g"] = 0.0
				else:
					q["vx"] = p["face"] * 260
					q["vy"] = -380.0
					q["g"] = 900.0
				if not seen.has("parry"):
					seen["parry"] = true
					toast("PARRY!", "Eleven years of training: finally useful", 2.2)
				continue
			if absf(q["x"] - (p["x"] + p["w"] / 2)) < p["w"] / 2 + q["r"] - 2 and absf(q["y"] - (p["y"] + p["h"] / 2)) < p["h"] / 2 + q["r"] - 2:
				q["dead"] = true
				damage("a flying Viking axe" if q["k"] == "axe" else "a crossbow bolt (the irony)")
		elif q["fr"]:
			var qr := rect(q["x"] - q["r"], q["y"] - q["r"], q["r"] * 2, q["r"] * 2)
			for e in L["ents"]:
				if not e["dead"] and not ED[e["ty"]].get("npc", false) and ov(qr, e):
					q["dead"] = true
					e["hf"] = 0.0
					hit_e(e, "bolt")
					break
			if b != null and boss_on and not q.get("dead", false) and ov(qr, b):
				q["dead"] = true
				boss_hit("bolt", q["x"], q["y"])
	proj = proj.filter(func(q): return not q.get("dead", false))


func ground_y(x: float) -> float:
	var cx := floori(x / T)
	for cy in ROWS:
		if is_solid(tile(cx, cy)):
			return cy * T
	return FLOOR


func verdict() -> String:
	if cause.contains("Goose"):
		return "Defeated by poultry. The bards are already composing \"The Ballad of Honk\"."
	return ["", "Felled in the courtyard. Eleven years of training, refunded in store credit.", "Lost at sea. Asking for directions was never an option.", "Your quest is under construction. Expected completion: Tuesday.", "Blown away by Dutch headwind. Even the cow saw it coming.", "Peer-reviewed by crossbow. Verdict: major revisions."][lv]


func game_over() -> void:
	state = S.OVER
	t = 0.0
	clear_save()
	new_best = submit_score(score)


func ending() -> void:
	state = S.END
	t = 0.0
	score += lives * 500
	clear_save()
	new_best = submit_score(score)


# ---------------------------------------------------------------- drawing helpers

func wpos(x: float, y: float) -> Vector2:
	return (Vector2(x, y) - Vector2(cam_x, cam_y)) * K


func world() -> void:
	draw_set_transform(-Vector2(cam_x, cam_y) * K, 0, Vector2(K, K))


func at(x: float, y: float, rot := 0.0, sx := 1.0, sy := 1.0) -> void:
	draw_set_transform(wpos(x, y), rot, Vector2(K * sx, K * sy))


func screen() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func ell(c: Vector2, a: float, b: float, col: Color) -> void:
	# ellipse in the current transform
	var pts := PackedVector2Array()
	for i in 20:
		var an := i / 20.0 * TAU
		pts.append(c + Vector2(cos(an) * a, sin(an) * b))
	draw_colored_polygon(pts, col)


func poly(pts: Array, col: Color, outline := true) -> void:
	var pa := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		pa.append(Vector2(pts[i], pts[i + 1]))
	draw_colored_polygon(pa, col)
	if outline:
		pa.append(pa[0])
		draw_polyline(pa, OL, 1.2)


func box(x: float, y: float, w: float, h: float, col: Color, outline := true) -> void:
	draw_rect(Rect2(x, y, w, h), col)
	if outline:
		draw_rect(Rect2(x, y, w, h), OL, false, 1.3)


func wtext(x: float, y: float, s: String, size: float, col: Color, outline := true) -> void:
	# centred text at a world position, drawn sharp in screen space
	var fs := int(size * K)
	var sp := wpos(x, y)
	screen()
	if outline:
		draw_string_outline(font, sp + Vector2(-400, fs * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 800, fs, maxi(3, fs / 4), Color(0.08, 0.06, 0.11, 0.85 * col.a))
	draw_string(font, sp + Vector2(-400, fs * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 800, fs, col)
	world()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	screen()
	if state == S.END:
		draw_ending()
		draw_overlay("JUMP", "SWORD")
		return
	var th: Dictionary = TH[L["th"]]
	for i in 20:
		draw_rect(Rect2(-40, i * 38 - 40, W + 80, 40), th["sky"][0].lerp(th["sky"][1], i / 19.0))
	draw_background()
	world()
	draw_rect(Rect2(cam_x - 40, LH, VW + 80, VH), Color("#1d4f6e") if L["th"] == "sea" else (Color("#3e5f3a") if L["th"] == "polder" else th["g"][1]))
	for s in L["signs"]:
		if s["x"] > cam_x - 100 and s["x"] < cam_x + VW + 100:
			draw_sign(s)
	for f in L["flags"]:
		if f["x"] > cam_x - 60 and f["x"] < cam_x + VW + 60:
			draw_flag(f)
	if L["goal"] < 1e8 and L["goal"] > cam_x - 100 and L["goal"] < cam_x + VW + 100:
		draw_portal(L["goal"] + 20)
	draw_mills_back()
	draw_tiles()
	draw_plats()
	for z in L["zones"]:
		if z["k"] == "cur" and not (z["x1"] < cam_x or z["x0"] > cam_x + VW):
			var x0 := maxf(z["x0"], cam_x - 10)
			var x1 := minf(z["x1"], cam_x + VW + 10)
			draw_rect(Rect2(x0, z["y"] - 9, x1 - x0, 9), Color(.35, .67, .9, .55))
			var o := fposmod(gt * absf(z["f"]) * signf(z["f"]), 40.0)
			var x: float = z["x0"] + o - 40
			while x < z["x1"]:
				if x > x0 - 20 and x < x1:
					var d := signf(z["f"])
					draw_polyline(PackedVector2Array([Vector2(x, z["y"] - 5), Vector2(x + d * 12, z["y"] - 5), Vector2(x + d * 8, z["y"] - 8)]), Color(1, 1, 1, .75), 1.5)
				x += 40.0
	for c in L["coins"]:
		if not c["got"] and c["x"] > cam_x - 20 and c["x"] < cam_x + VW + 20:
			var s := absf(cos(gt * 3 + c["x"] * .01))
			var cy: float = c["y"] + sin(gt * 3 + c["x"]) * 1.5
			ell(Vector2(c["x"], cy), 7 * maxf(.15, s), 8, Color("#f2b632"))
	for e in L["ents"]:
		if e["x"] > cam_x + VW + 80 or e["x"] + e["w"] < cam_x - 80:
			continue
		draw_enemy(e)
	if boss != null and (boss_on or state == S.BOSSDEAD):
		draw_boss(boss)
	for q in proj:
		draw_proj(q)
	if state != S.TITLE:
		var vis: bool = not (p["inv"] > 0 and sin(p["inv"] * 40) > .3) or state != S.PLAY
		if state == S.CLEAR:
			var u := 1.0 - maxf(0, (ct - 1.4) / 1.8)
			draw_knight(p["x"] + p["w"] / 2, p["y"] + p["h"], 1, true, false, 0, -1, u * u * 6, 1 - u * .6, 1 - clampf((u - .6) * 2.5, 0, 1))
		elif vis:
			if p["dead"]:
				draw_knight(p["x"] + p["w"] / 2, p["y"] + p["h"], p["face"], false, true, 1, -1, -p["face"] * 1.3)
			else:
				draw_knight(p["x"] + p["w"] / 2, p["y"] + p["h"], p["face"], absf(p["vx"]) > 20 and p["on"], not p["on"], p["vy"], 1 - p["atk"] / .25 if p["atk"] > 0 else -1.0)
	if L["th"] == "sea":
		draw_rect(Rect2(cam_x - 20, 360, VW + 40, LH - 346), Color(.24, .51, .67, .5))
	for q in parts:
		var a: float = clampf((1 - q["l"] / q["m"]) * 1.5, 0, 1)
		draw_rect(Rect2(q["x"] - 1.5, q["y"] - 1.5, 3, 3), Color(q["c"], a))
	for e in L["ents"]:
		if e["bub"] != null and not e["dead"] and e["x"] > cam_x - 100 and e["x"] < cam_x + VW + 100:
			draw_bub(e["x"] + e["w"] / 2, e["y"] - 6, e["bub"]["s"])
	if boss != null and boss["bub"] != null and (boss_on or state == S.BOSSDEAD):
		draw_bub(boss["x"] + boss["w"] / 2, boss["y"] - (40 if boss["ph"] == 3 and boss["st"] != "dead" else 8), boss["bub"]["s"])
	for f in fx:
		wtext(f["x"], f["y"] - f["t"] * 34, f["s"], 16 if f["big"] else 11, Color(f["c"], clampf((1 - f["t"] / 1.1) * 2, 0, 1)))
	screen()
	var gust := 0.0
	for z in L["zones"]:
		if z["k"] == "wind" and p["x"] + p["w"] > z["x0"] - 200 and p["x"] < z["x1"] + 100:
			gust = maxf(gust, absf(zone_f(z, wt)) / absf(z["f"]))
	if gust > 0:
		for k in 26:
			var r1 := fposmod(k * 0.6180339 + 0.13, 1.0)
			var r2 := fposmod(k * 0.4142135 + 0.71, 1.0)
			var y := r1 * H
			var len := 60.0 + r2 * 100.0
			var x := fposmod(r2 * W - gt * (800 + r1 * 400), W + 300) - 150
			draw_line(Vector2(x, y), Vector2(x + len, y), Color(1, 1, 1, .5 * gust), 3.0)
		text(Vector2(W - 260, 200), "HEADWIND!", 30, Color(1, 1, 1, gust))
	if flash > 0:
		draw_rect(Rect2(0, 0, W, H), Color(1, .24, .24, flash * 1.5))
	if state == S.TITLE:
		draw_title()
	else:
		draw_hud()
	draw_overlay("JUMP", "SWORD")


func draw_background() -> void:
	# a simple parallax backdrop per era, in screen space
	var th: String = L["th"]
	var o := cam_x * K
	match th:
		"castle":
			for i in 6:
				var x := fposmod(i * 300.0 - o * .3, W + 300) - 150
				draw_rect(Rect2(x, 260, 90, 200), Color("#383a5c"))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 260), Vector2(x + 45, 200), Vector2(x + 100, 260)]), Color("#5a3550"))
			draw_rect(Rect2(0, 420, W, 300), Color("#4a4560"))
		"sea":
			for i in 5:
				var x := fposmod(i * 330.0 - o * .1, W + 330) - 165
				draw_colored_polygon(PackedVector2Array([Vector2(x, 560), Vector2(x + 165, 360 + (i % 2) * 60), Vector2(x + 330, 560)]), Color("#2a3850"))
			draw_rect(Rect2(0, 560, W, 200), Color("#1f4d6b"))
		"aq":
			var ox := fposmod(o * .3, 72.0)
			draw_rect(Rect2(0, 350, W, 20), Color("#5b5266"))
			var x2 := -ox - 72
			while x2 < W + 72:
				draw_rect(Rect2(x2, 350, 16, 130), Color("#5b5266"))
				x2 += 72.0
			draw_rect(Rect2(0, 480, W, 300), Color("#2f2c3d"))
		"polder":
			draw_rect(Rect2(0, 440, W, 300), Color("#1c3a2c"))
			for i in 5:
				var mx := fposmod(i * 540.0 - o * .22, W + 540) - 270
				draw_colored_polygon(PackedVector2Array([Vector2(mx - 15, 440), Vector2(mx - 10, 375), Vector2(mx + 10, 375), Vector2(mx + 15, 440)]), Color("#2a3346"))
				for k in 4:
					var a := gt * .9 + k * PI / 2 + i
					draw_line(Vector2(mx, 375), Vector2(mx, 375) + Vector2(cos(a), sin(a)) * 42, Color("#2a3346"), 5.0)
		"tower":
			var ox2 := fposmod(o * .5, 105.0)
			for r in 20:
				var y := r * 40.0
				draw_line(Vector2(0, y), Vector2(W, y), Color(0, 0, 0, .3), 2.0)
				var xx := -ox2 - 105 + (r % 2) * 52
				while xx < W + 105:
					draw_line(Vector2(xx, y), Vector2(xx, y + 40), Color(0, 0, 0, .3), 2.0)
					xx += 105.0


func draw_tiles() -> void:
	var th: Dictionary = TH[L["th"]]
	var x0 := maxi(0, floori(cam_x / T) - 1)
	var x1 := mini(L["cols"] - 1, floori((cam_x + VW) / T) + 1)
	for cx in range(x0, x1 + 1):
		for cy in ROWS:
			var c: int = L["grid"][cy * L["cols"] + cx]
			if c == 0:
				continue
			var x := cx * T
			var y := cy * T
			var up: int = L["grid"][(cy - 1) * L["cols"] + cx] if cy > 0 else 0
			var exposed := not is_solid(up) and up != 5
			match c:
				1:
					draw_rect(Rect2(x, y, T, T), th["g"][0])
					var o := (cy % 2) * 16
					draw_rect(Rect2(x, y + 15, T, 2), th["g"][1])
					draw_rect(Rect2(x + (o + 8) % 32, y, 2, 15), th["g"][1])
					draw_rect(Rect2(x + (o + 24) % 32, y + 17, 2, 15), th["g"][1])
					if exposed:
						draw_rect(Rect2(x, y, T, 7), th["top"])
						draw_rect(Rect2(x, y + 7, T, 2), Color(0, 0, 0, .18))
				2:
					if L["th"] == "tower":
						draw_rect(Rect2(x, y, T, T), Color("#6d6562"))
						draw_rect(Rect2(x + 1, y + 1, T - 2, T - 2), OL, false, 1.5)
					else:
						draw_rect(Rect2(x + 1, y + 1, T - 2, T - 2), Color("#b98547"))
						draw_line(Vector2(x + 4, y + 4), Vector2(x + T - 4, y + T - 4), Color("#6b4425"), 3.0)
						draw_rect(Rect2(x + 3, y + 3, T - 6, T - 6), Color("#6b4425"), false, 2.0)
						draw_rect(Rect2(x + 1, y + 1, T - 2, T - 2), OL, false, 1.5)
				3:
					draw_plank(x, y, T)
				4:
					draw_rect(Rect2(x, y + T - 5, T, 5), Color("#3b3640") if L["th"] == "tower" else Color("#6b5a4a"))
					for k in 4:
						var sx := x + k * 8
						draw_colored_polygon(PackedVector2Array([Vector2(sx, y + T - 4), Vector2(sx + 4, y + 12), Vector2(sx + 8, y + T - 4)]), Color("#c9d0da"))
				5:
					var top := up != 5
					draw_rect(Rect2(x, y + (10 if top else 0), T, T - (10 if top else 0)), Color(.12, .31, .45, .92))
					if top:
						draw_rect(Rect2(x, y + 9 + sin(gt * 3 + cx), T, 2), Color(.59, .78, .9, .6))
				6:
					draw_rect(Rect2(x, y, T, T), Color("#8a5a32"))
					if exposed:
						draw_rect(Rect2(x, y, T, 8), Color("#b07a45"))
					draw_rect(Rect2(x, y + (8 if exposed else 0), 6, T), Color("#1a2a3a"))
					draw_rect(Rect2(x + 12, y + (8 if exposed else 0), 8, T), Color("#1a2a3a"))
					draw_rect(Rect2(x + 26, y + (8 if exposed else 0), 6, T), Color("#1a2a3a"))
				7:
					draw_aq_tile(x, y, cx, cy, exposed)


func draw_aq_tile(x: float, y: float, cx: int, cy: int, exposed: bool) -> void:
	draw_rect(Rect2(x, y, T, T), Color("#8d7f66"))
	if cy > 8:
		var k := posmod(cx, 3)
		if k == 1 or k == 2:
			draw_rect(Rect2(x + (6 if k == 1 else 0), y + (6 if cy == 9 else 0), T - 6, T), Color("#4a3f40"))
	draw_line(Vector2(x, y + 16), Vector2(x + T, y + 16), Color(0, 0, 0, .3), 1.0)
	if exposed:
		draw_rect(Rect2(x, y, T, 5), Color("#a89a7c"))


func draw_plank(x: float, y: float, w: float) -> void:
	draw_rect(Rect2(x + 4, y + 8, 4, 10), Color("#8a5a32"))
	draw_rect(Rect2(x + w - 8, y + 8, 4, 10), Color("#8a5a32"))
	box(x, y, w, 9, Color("#c18b52"))


func draw_plats() -> void:
	for q in L["plats"]:
		if q["gone"]:
			continue
		var a := pl_pos(q, wt)
		if a.x > cam_x + VW + 300 or a.x + q["w"] < cam_x - 300:
			continue
		match q["k"]:
			"ship":
				draw_ship(a.x, a.y, q["w"])
			"raft":
				var k := 0.0
				while k < q["w"]:
					box(a.x + k, a.y, 8, 12, Color("#a8743f") if int(k / 8) % 2 else Color("#93633a"))
					k += 8.0
			"blade":
				box(a.x, a.y, q["w"], 10, Color("#c18b52"))
				draw_rect(Rect2(a.x + q["w"] / 2 - 3, a.y + 9, 6, 6), Color("#8a5a32"))
			"crumble":
				var sx := a.x
				var sy := a.y
				if q["st"] == 1:
					sx += randf_range(-1.5, 1.5)
					sy += randf_range(-1, 1)
				draw_aq_tile(sx, sy, 0, 7, true)
				draw_polyline(PackedVector2Array([Vector2(sx + 8, sy + 5), Vector2(sx + 14, sy + 14), Vector2(sx + 11, sy + 22)]), Color("#5a4a32"), 1.5)
				draw_line(Vector2(sx + 14, sy + 14), Vector2(sx + 23, sy + 18), Color("#5a4a32"), 1.5)


func draw_ship(x: float, y: float, w: float) -> void:
	# mast and sail
	var mx := x + w / 2
	draw_line(Vector2(mx, y), Vector2(mx, y - 100), Color("#5a3418"), 4.0)
	var sw := minf(78, w * .55)
	var sy := y - 92
	for k in 6:
		draw_rect(Rect2(mx - sw / 2 + k * sw / 6, sy, sw / 6 + 1, 58), Color("#f3ece0") if k % 2 else Color("#c0392b"))
	draw_rect(Rect2(mx - sw / 2, sy, sw, 58), OL, false, 1.6)
	# hull
	var bot := y + 50
	var hull := PackedVector2Array([Vector2(x - 10, y - 14), Vector2(x - 2, y + 20), Vector2(x + 18, bot), Vector2(x + w - 18, bot), Vector2(x + w + 2, y + 20), Vector2(x + w + 10, y - 14), Vector2(x + w, y), Vector2(x, y)])
	draw_colored_polygon(hull, Color("#7a4a26"))
	hull.append(hull[0])
	draw_polyline(hull, OL, 2.0)
	for k in range(1, 4):
		draw_line(Vector2(x - 6 + k * 3, y + k * 11), Vector2(x + w + 6 - k * 3, y + k * 11), Color("#5a3418"), 1.5)
	var n := maxi(2, floori(w / 22))
	for k in n:
		var sx := x + 12 + k * (w - 24) / (n - 1)
		draw_circle(Vector2(sx, y + 8), 7, [Color("#c0392b"), Color("#f1c40f"), Color("#2e86c1")][k % 3])
		draw_circle(Vector2(sx, y + 8), 2, Color("#dddddd"))
	draw_polyline(PackedVector2Array([Vector2(x + w + 6, y - 8), Vector2(x + w + 16, y - 24), Vector2(x + w + 12, y - 38)]), Color("#7a4a26"), 7.0)
	draw_circle(Vector2(x + w + 16, y - 41), 7, Color("#7a4a26"))
	poly([x + w + 18, y - 44, x + w + 30, y - 40, x + w + 18, y - 36], Color("#7a4a26"))
	draw_circle(Vector2(x + w + 17, y - 42), 1.6, Color("#ffd34d"))
	draw_rect(Rect2(x, y - 1, w, 6), Color("#a8743f"))
	draw_rect(Rect2(x, y - 1, w, 6), OL, false, 1.5)


func draw_mills_back() -> void:
	for m in L["mills"]:
		var x: float = m["hx"]
		var y: float = m["hy"]
		if x < cam_x - 260 or x > cam_x + VW + 260:
			continue
		poly([x - 30, LH, x - 20, y + 6, x + 20, y + 6, x + 30, LH], Color("#7d5f49"))
		poly([x - 26, y + 10, x, y - 18, x + 26, y + 10], Color("#5b8a4a"))
		box(x - 6, y + 40, 12, 18, Color("#3b2a20"))
		var an0: float = m["dir"] * TAU * wt / m["per"]
		for k in 4:
			var a: float = k * PI / 2 + .3 + an0
			at(x, y, a)
			draw_rect(Rect2(14, -12, m["R"] - 26, 10), Color(.94, .91, .84, .85))
			var s := 14.0
			while s < m["R"] - 10:
				draw_line(Vector2(s, -12), Vector2(s, -2), Color("#5a3a24"), 1.0)
				s += 8.0
			box(0, -2, m["R"] - 4, 5, Color("#6b4425"))
			world()
		draw_circle(Vector2(x, y), 8, Color("#4a3020"))


func draw_sign(s: Dictionary) -> void:
	var lines: PackedStringArray = s["s"]
	var mw := 0
	for l in lines:
		mw = maxi(mw, l.length())
	var w := mw * 5.6 + 14
	var h := lines.size() * 11 + 8
	var x: float = s["x"]
	var y: float = s["y"] if s["y"] > 0 else ground_y(x)
	draw_line(Vector2(x, y), Vector2(x, y - 30), Color("#6b4425"), 4.0)
	box(x - w / 2, y - 30 - h, w, h, Color("#d9b47a"))
	for i in lines.size():
		var fs := int((9.5 if i == 0 else 8.5) * K)
		var sp := wpos(x, y - 30 - h + 9 + i * 11)
		screen()
		draw_string(font, sp + Vector2(-300, fs * 0.35), lines[i], HORIZONTAL_ALIGNMENT_CENTER, 600, fs, Color("#3b2a1a"))
		world()


func draw_flag(f: Dictionary) -> void:
	var x: float = f["x"]
	var y := ground_y(x)
	draw_line(Vector2(x, y), Vector2(x, y - 58), Color("#6b4425"), 3.0)
	draw_circle(Vector2(x, y - 58), 3, Color("#ffd34d"))
	var w := sin(gt * 6) * 3 if f["on"] else 0.0
	poly([x + 1, y - 55, x + 28, y - 55 + w, x + 28, y - 38 + w, x + 1, y - 38], Color("#ff5a82") if f["on"] else Color("#9aa1ad"))


func draw_portal(x: float) -> void:
	var y := ground_y(x) - 46
	for k in range(5, 0, -1):
		ell(Vector2(x, y), 24 + k * 3, 40 + k * 4, Color(.55, .35, 1, .1 + k * .03) if k % 2 else Color(.27, .78, 1, .1 + k * .03))
	for k in 3:
		var pts := PackedVector2Array()
		for s in 30:
			var r := s * 1.2
			var a := s * .25 + gt * 2 + k * TAU / 3
			pts.append(Vector2(x + cos(a) * r * .75, y + sin(a) * r * 1.2))
		draw_polyline(pts, Color(1, 1, 1, .7), 2.0)
	wtext(x, y - 62, "NEXT ERA", 10, Color(1, 1, 1))


func draw_knight(x: float, y: float, f: float, mv: bool, air: bool, vy: float, atk: float, rot := 0.0, sc := 1.0, alpha := 1.0) -> void:
	at(x, y, rot, f * sc, sc)
	var ph: float = p["run"]
	var bob := -absf(sin(ph)) * 1.8 if mv and not air else 0.0
	var la := ((-.7 if vy < 0 else .3) if air else (sin(ph) * .8 if mv else 0.0))
	var lb := ((.5 if vy < 0 else -.3) if air else -la)
	var steel := Color("#8f98a5", alpha)
	# legs
	for leg in [[-3.0, lb, steel], [3.0, la, Color("#aab3bf", alpha)]]:
		var o := Vector2(leg[0], -12 + bob)
		var dirv := Vector2(sin(-leg[1]), cos(leg[1]))
		draw_line(o, o + dirv * 11, OL, 6.4)
		draw_line(o, o + dirv * 11, leg[2], 4.6)
		draw_rect(Rect2(o + dirv * 10 + Vector2(-2.8, -1), Vector2(7.5, 4)), Color("#4b4f58", alpha))
	# cape
	var cw := sin(gt * 8) * 2 + (4.0 if mv else 0.0)
	poly([-5, -24 + bob, -14 - cw * 1.5, -6 + bob, -6, -10 + bob], Color("#8f1d2c", alpha))
	# shield
	poly([-11, -25 + bob, -1, -25 + bob, -1, -17 + bob, -6, -8 + bob, -11, -17 + bob], Color("#6ea4ff", alpha))
	draw_line(Vector2(-6, -24 + bob), Vector2(-6, -10 + bob), Color("#f5f0e1", alpha), 2.0)
	# torso
	box(-7, -24 + bob, 14, 13, Color("#c9d1dc", alpha))
	poly([-6, -17 + bob, 6, -17 + bob, 5, -11 + bob, -5, -11 + bob], Color("#ff5a82", alpha), false)
	draw_rect(Rect2(-7, -14 + bob, 14, 2.5), Color("#6b4425", alpha))
	# plume + helmet
	var hy := -36.0 + bob
	poly([0, hy, -8, hy - 5, -18 - (3.0 if mv else 0.0), hy + 5 + sin(gt * 9) * 2, -2, hy + 2], Color("#e0393f", alpha))
	box(-7, hy + 1, 15, 14, Color("#d7dee7", alpha))
	draw_rect(Rect2(0, hy + 6, 8, 2.2), Color("#2a2131", alpha))
	# sword arm
	var a := lerpf(-2.3, 1.1, 1 - pow(1 - atk, 2)) if atk >= 0 else (-1.4 if air else -1.05 + sin(gt * 2) * .05)
	if atk >= 0 and atk < .85:
		var a0 := lerpf(-2.3, 1.1, maxf(0, 1 - pow(1 - atk, 2) - .5))
		var arc_pts := PackedVector2Array()
		for i in 9:
			var aa := lerpf(a0, a, i / 8.0)
			arc_pts.append(Vector2(1, -20 + bob) + Vector2(cos(aa), sin(aa)) * 34)
		for i in range(8, -1, -1):
			var aa2 := lerpf(a0, a, i / 8.0)
			arc_pts.append(Vector2(1, -20 + bob) + Vector2(cos(aa2), sin(aa2)) * 16)
		draw_colored_polygon(arc_pts, Color(1, 1, 1, .55 * (1 - atk)))
	at(x, y, rot, f * sc, sc)
	var sh := Vector2(2, -20 + bob)
	var dir := Vector2(cos(a), sin(a))
	var nrm := Vector2(-dir.y, dir.x)
	draw_line(sh, sh + dir * 10, Color("#aab3bf", alpha), 5.0)
	var hand := sh + dir * 12
	draw_line(hand - nrm * 6, hand + nrm * 6, Color("#c9a54a", alpha), 3.0)
	draw_colored_polygon(PackedVector2Array([hand + nrm * 2, hand + dir * 21 + nrm * 1.4, hand + dir * 24, hand + dir * 21 - nrm * 1.4, hand - nrm * 2]), Color("#eef2f6", alpha))
	world()


func draw_enemy(e: Dictionary) -> void:
	var x: float = e["x"] + e["w"] / 2
	var y: float = e["y"] + e["h"]
	var f: float = e["face"]
	var dead_rot: float = e["dt"] * 6 if e["dead"] else 0.0
	var alpha := .5 if (e["hf"] > 0 and not e["dead"] and sin(e["hf"] * 70) > 0) else 1.0
	match e["ty"]:
		"goose":
			at(x, y, dead_rot, f, 1)
			var ch: bool = e["st"] == "charge"
			var wc := Color("#f7f5ef", alpha)
			ell(Vector2(-1, -12), 12, 8, wc)
			draw_line(Vector2(-3, -7), Vector2(-4, 0), Color("#e98a1a"), 2.2)
			draw_line(Vector2(3, -7), Vector2(4, 0), Color("#e98a1a"), 2.2)
			var hx := 17.0 if ch else 9.0
			var hy := -15.0 if ch else -27.0
			draw_line(Vector2(6, -14), Vector2(hx - 2, hy + 1), OL, 8.0)
			draw_line(Vector2(6, -14), Vector2(hx - 2, hy + 1), wc, 5.0)
			ell(Vector2(hx, hy), 5, 4.2, wc)
			poly([hx + 3, hy - 2, hx + 12 if ch else hx + 10, hy - 1, hx + 3, hy + 2], Color("#f08a12"))
			draw_circle(Vector2(hx + 1, hy - 1), 1.3, OL)
			draw_line(Vector2(hx - 2, hy - 4), Vector2(hx + 3, hy - 2.2), OL, 1.4)
		"dummy":
			var w := sin(e["hf"] * 60) * .25 if e["hf"] > 0 else sin(gt * 1.5 + e["x"]) * .03
			at(x, y, minf(1.5, e["dt"] * 4) * signf(e["vx"]) if e["dead"] else w)
			draw_line(Vector2(0, 0), Vector2(0, -36), Color("#6b4425"), 3.0)
			draw_line(Vector2(-12, -24), Vector2(12, -24), Color("#6b4425"), 3.0)
			ell(Vector2(0, -20), 8, 10, Color("#d8bf7a"))
			ell(Vector2(0, -20), 4, 5, Color("#ff5a82"))
			draw_circle(Vector2(0, -34), 6.5, Color("#e2cc8e"))
		"viking":
			at(x, y, dead_rot, f, 1)
			box(-8, -12, 6, 12, Color("#6b4a2b"))
			box(2, -12, 6, 12, Color("#6b4a2b"))
			ell(Vector2(0, -20), 13, 12, Color("#8a5a32", alpha))
			poly([-5, -30, -7, -16, 0, -11, 9, -16, 9, -30], Color("#e07b2a"))
			draw_circle(Vector2(2, -33), 7, Color("#f2c7a0"))
			draw_circle(Vector2(5, -34), 1.4, OL)
			poly([-6.5, -36, -4, -42, 2, -44.5, 8, -42, 10.5, -36], Color("#9aa3ad"))
			poly([-6, -38, -12, -52, -3, -42], Color("#f5f0e1"))
			poly([9, -38, 15, -52, 6, -42], Color("#f5f0e1"))
			if not (e["st"] == "throw" and e["mt"] < .2):
				var aa: float = -2.4 + (.42 - e["mt"]) * 2 if e["st"] == "throw" else -.4
				var hd := Vector2(8, -22)
				var dv := Vector2(sin(aa), -cos(aa))
				draw_line(hd, hd + dv * 18, Color("#6b4425"), 3.0)
				draw_circle(hd + dv * 18, 5, Color("#cfd6de"))
		"gull":
			at(x, e["y"] + e["h"] / 2, e["dt"] * 7 if e["dead"] else 0.0, f, 1)
			var fl: float = -.2 if e["st"] == "swoop" else sin(e["t"] * 12) * .6
			poly([-2, -2, -20 * cos(fl), -8 - 10 * sin(fl), -2, 2], Color("#dfe4ea"))
			ell(Vector2.ZERO, 11, 5.5, Color("#fbfbfb", alpha))
			ell(Vector2(9, -3), 4.5, 4, Color("#fbfbfb"))
			poly([12, -3, 19, -1, 12, 0], Color("#f2c11a"))
			draw_circle(Vector2(10, -4), 1, OL)
			poly([-1, -1, -14 * cos(fl), -14 + 6 * sin(fl), -4, 2], Color("#eef1f4"))
		"legion":
			at(x, y, dead_rot * signf(e["vx"]) * f if e["dead"] else 0.0, f, 1)
			var wk := sin(e["t"] * 6) * .4
			draw_line(Vector2(-3, -12), Vector2(-3 + sin(wk) * 12, 0), Color("#c48a5a"), 5.0)
			draw_line(Vector2(3, -12), Vector2(3 - sin(wk) * 12, 0), Color("#c48a5a"), 5.0)
			box(-8, -16, 16, 6, Color("#b02a2a"))
			box(-8, -27, 16, 13, Color("#c9a75a", alpha))
			draw_circle(Vector2(1, -32), 6.3, Color("#e8b48a"))
			draw_circle(Vector2(4, -33), 1.2, OL)
			poly([-6.5, -34, -5, -40, 1, -41.5, 7, -40, 8.5, -34], Color("#c9a75a"))
			poly([-6, -40, 1, -47, 8, -40, 1, -43], Color("#c0392b"))
			draw_line(Vector2(-6, -8), Vector2(-6, -48), Color("#6b4425"), 2.2)
			poly([-6, -56, -8, -48, -4, -48], Color("#cfd6de"))
			box(5, -36, 10, 30, Color("#b02a2a"))
			draw_rect(Rect2(6, -22.5, 8, 3), Color("#e8c25a"))
		"cyclist":
			at(x, y, dead_rot, f, 1)
			var wa: float = e["t"] * (2.0 if e["st"] == "skid" else 14.0)
			for wx in [-11.0, 12.0]:
				draw_arc(Vector2(wx, -8), 8, 0, TAU, 16, OL, 2.2)
				draw_line(Vector2(wx, -8) + Vector2(cos(wa), sin(wa)) * 7, Vector2(wx, -8) - Vector2(cos(wa), sin(wa)) * 7, Color("#777777"), 1.0)
			draw_polyline(PackedVector2Array([Vector2(-11, -8), Vector2(-2, -8), Vector2(9, -20), Vector2(-4, -20), Vector2(-11, -8)]), Color("#1d1d1d"), 2.4)
			draw_line(Vector2(12, -8), Vector2(9, -26), Color("#1d1d1d"), 2.4)
			var pp := sin(wa)
			draw_line(Vector2(-3, -22), Vector2(-2 + pp * 4, -12), Color("#2c4a7a"), 3.2)
			box(-8, -38, 10, 15, Color("#ef7d22", alpha))
			draw_line(Vector2(3, -34), Vector2(10, -26), Color("#ef7d22"), 3.0)
			draw_circle(Vector2(4, -41), 6, Color("#f1c8a2"))
			draw_circle(Vector2(7, -42), 1.2, OL)
			poly([-2.5, -43, 0, -48, 4, -49.5, 8, -48, 10.5, -43], Color("#2e86c1"))
		"clerk":
			at(x, y, dead_rot, f, 1)
			poly([-8, 0, -6, -22, 6, -22, 9, 0], Color("#6b5a8a", alpha))
			draw_circle(Vector2(1, -27), 6.5, Color("#efc9a6"))
			draw_arc(Vector2(3, -28), 2.3, 0, TAU, 10, OL, 1.0)
			draw_arc(Vector2(-2, -28), 2.3, 0, TAU, 10, OL, 1.0)
			draw_line(Vector2(-4, -34), Vector2(7, -34), Color("#555555"), 2.0)
			var ra := 0.0 if e["st"] == "aim" else .5
			var hd2 := Vector2(4, -17)
			var dv2 := Vector2(cos(ra), sin(ra))
			draw_line(hd2, hd2 + dv2 * 13, Color("#6b4425"), 3.0)
			draw_arc(hd2 + dv2 * 10, 7, ra - 1.2, ra + 1.2, 8, Color("#5a3418"), 2.0)
			world()
			if e["st"] == "aim" and not e["dead"]:
				var gx := x + f * 18
				draw_circle(Vector2(gx, y - 17), 3 + sin(gt * 40) * 1.2, Color(1, .35, .35, .85))
				draw_dashed_line(Vector2(gx, y - 17), Vector2(gx + f * 90, y - 17), Color(1, .27, .27, .45), 1.2, 4.0)
		"turret":
			at(x + (sin(e["hf"] * 80) * 2 if e["hf"] > 0 else 0.0), y, e["dt"] * 5 if e["dead"] else 0.0, f, 1)
			box(-12, -8, 24, 8, Color("#5b5f66"))
			box(-12, -20, 24, 12, Color("#7b5530", alpha))
			draw_arc(Vector2(8, -14), 11, -1.2, 1.2, 8, Color("#3a2a1a"), 2.5)
			draw_line(Vector2(-12, -14), Vector2(16, -14), Color("#3a2a1a"), 2.5)
			draw_rect(Rect2(-6, -18, 8, 3), Color("#ffd34d"))
			world()
			if e["st"] == "aim" and not e["dead"]:
				draw_circle(Vector2(x + f * 20, y - 13), 3.5, Color(1, .35, .35, .9))
		"cow":
			at(x, y, 0, -1, 1)
			for lx in [-16.0, -9.0, 9.0, 16.0]:
				draw_rect(Rect2(lx - 2, -12, 4, 12), Color("#f5f2ea"))
				draw_rect(Rect2(lx - 2, -3, 4, 3), OL)
			box(-22, -28, 44, 18, Color("#f5f2ea"))
			ell(Vector2(-8, -22), 7, 5, Color("#2a2131"))
			ell(Vector2(9, -17), 5, 4, Color("#2a2131"))
			ell(Vector2(24, -26 + sin(gt * 3) * .5), 8, 7, Color("#f5f2ea"))
			ell(Vector2(29, -22), 5, 3.5, Color("#f2b7c0"))
			draw_circle(Vector2(25, -28), 1.3, OL)
		"contractor":
			at(x, y, 0, -1, 1)
			box(-7, -24, 14, 18, Color("#c9a26a"))
			draw_rect(Rect2(-7, -12, 14, 3), Color("#6b4425"))
			draw_rect(Rect2(-6, -6, 5, 6), Color("#8a5a32"))
			draw_rect(Rect2(1, -6, 5, 6), Color("#8a5a32"))
			draw_circle(Vector2(0, -29), 6, Color("#e8b48a"))
			poly([-6.5, -31, 0, -37.5, 6.5, -31], Color("#f2c11a"))
			box(6, -22, 9, 12, Color("#c8a060"))
	world()


func draw_boss(b: Dictionary) -> void:
	var x: float = b["x"] + b["w"] / 2
	var y: float = b["y"] + b["h"]
	var alpha := .55 if (b["hf"] > 0 and sin(b["hf"] * 60) > 0) else 1.0
	var fly: bool = b["ph"] == 3 and b["st"] != "dead" and not (b["st"] == "phase" and b["tm"] > 1.9)
	if fly:
		var fl: float = .5 if b["st"] == "crash" else sin(b["t"] * (30.0 if b["st"] == "warn" else 12.0)) * .5
		for s in [-1.0, 1.0]:
			at(x, y - 30, 0, s, 1)
			at(x, y - 30, (-.25 + fl) * s, s, 1)
			poly([4, -4, 40, -30, 78, -10, 56, 4, 36, 6, 16, 6], Color(.93, .87, .75, .95))
		at(x, y - 30)
		box(-26, 24, 52, 6, Color("#7b5530"))
	at(x, y, -.3 if b["st"] == "dead" else 0.0, b["face"], 1)
	var rl: bool = b["st"] == "reload"
	if not fly and b["ph"] < 3 and not rl and b["st"] != "leap" and b["st"] != "dead":
		box(20, -46, 16, 46, Color("#2e5aa8"))
		draw_rect(Rect2(22, -30, 12, 3), Color("#f1c40f"))
	poly([-15, 0, -11, -38, 0, -41, 11, -38, 16, 0], Color("#5b2a7a", alpha))
	draw_rect(Rect2(-14, -6, 30, 3), Color("#f1c40f"))
	draw_circle(Vector2(2, -48), 10, Color("#efc9a6", alpha))
	poly([-7, -46, -6, -30, 3, -20 + sin(b["t"] * 3) * 1.5, 12, -30, 12, -46, 3, -41], Color("#f4f4f2"))
	box(-6, -60, 18, 6, Color("#7b5530"))
	ell(Vector2(0, -57), 3.5, 3, Color("#9fd8f5"))
	ell(Vector2(8, -57), 3.5, 3, Color("#9fd8f5"))
	draw_circle(Vector2(6, -49), 1.8, OL)
	var ca := (.9 + sin(b["crank"]) * .15) if rl else (0.0 if b["st"] in ["aim", "aimS"] else (-.5 if b["ph"] == 2 else .15))
	var o := Vector2(10, -26)
	var dv := Vector2(cos(ca), sin(ca))
	var nv := Vector2(-dv.y, dv.x)
	draw_line(o - dv * 4, o + dv * 30, Color("#6b4425"), 5.0)
	draw_polyline(PackedVector2Array([o + dv * 24 - nv * 15, o + dv * 32, o + dv * 24 + nv * 15]), Color("#3a2a1a"), 3.0)
	world()
	if b["st"] in ["aim", "aimS"] and b["ph"] < 3 and b["tm"] < .6:
		var gx: float = x + b["face"] * 40
		draw_circle(Vector2(gx, FLOOR - 20), 4 + sin(gt * 40) * 1.5, Color(1, .27, .27, .95))
		draw_dashed_line(Vector2(gx, FLOOR - 20), Vector2(gx + b["face"] * 200, FLOOR - 20), Color(1, .24, .24, .45), 1.5, 5.0)
	if b["mark"] != null and b["st"] == "warn":
		ell(Vector2(b["mark"], FLOOR - 2), 30 + sin(gt * 20) * 3, 6, Color(.86, .16, .24, .35))
		wtext(b["mark"], FLOOR - 40, "!", 22, Color("#ff5a5a"))


func draw_proj(q: Dictionary) -> void:
	if q["k"] == "axe":
		at(q["x"], q["y"], q["rot"])
		draw_line(Vector2(-8, 0), Vector2(8, 0), Color("#6b4425"), 3.0)
		poly([6, -6, 12, 0, 6, 6, 4, 0], Color("#cfd6de"))
	else:
		at(q["x"], q["y"], atan2(q["vy"], q["vx"]))
		draw_line(Vector2(-12, 0), Vector2(8, 0), Color("#ffd34d") if q["fr"] else Color("#5a3418"), 2.4)
		poly([8, -3.5, 14, 0, 8, 3.5], Color("#cfd6de"))
		poly([-12, 0, -16, -4, -10, 0, -16, 4], Color("#ffd34d") if q["fr"] else Color("#ff5a82"), false)
	world()
	if q["mk"] != null and q["host"]:
		ell(Vector2(q["mk"], FLOOR - 2), 12, 4, Color(.86, .16, .24, .35))


func draw_bub(x: float, y: float, s: String) -> void:
	var fs := int(10 * K)
	var w := minf(220 * K, font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16)
	var lines := [s]
	if w >= 220 * K:
		lines = []
		var cur := ""
		for wd in s.split(" "):
			if font.get_string_size(cur + " " + wd, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 200 * K:
				lines.append(cur)
				cur = wd
			else:
				cur = wd if cur == "" else cur + " " + wd
		lines.append(cur)
	var hh := lines.size() * (fs + 4) + 10
	var sp := wpos(x, y)
	screen()
	var bx := clampf(sp.x - w / 2, 4, W - w - 4)
	var by := maxf(sp.y - hh - 12, 90)
	draw_rect(Rect2(bx, by, w, hh), Color("#fffdf6"))
	draw_rect(Rect2(bx, by, w, hh), OL, false, 2.0)
	if by + hh < sp.y:
		draw_colored_polygon(PackedVector2Array([Vector2(sp.x - 7, by + hh), Vector2(sp.x + 7, by + hh), Vector2(sp.x, by + hh + 10)]), Color("#fffdf6"))
	for i in lines.size():
		draw_string(font, Vector2(bx, by + 6 + fs + i * (fs + 4)), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color("#2a2131"))
	world()


func draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, 82), Color(0.09, 0.08, 0.13, 0.88))
	var x := 150.0
	for k in D["hp"]:
		draw_circle(Vector2(x + 12, 28), 11, Color("#e5383b") if k < p["hp"] else Color(.5, .5, .5, .35))
		x += 30
	text(Vector2(x + 10, 38), "Lives x%d" % maxi(0, lives), 24, Color(1, 1, 1))
	text(Vector2(150, 70), "Level %d/5 · %s" % [lv, L["short"]], 22, Color(1, .55, .6))
	text(Vector2(W - 380, 38), "%d pts" % score, 28, Color(1, 1, 1))
	text(Vector2(W - 380, 70), "%s   ducats %d   best %d" % [fmt_t(play_time), coins, best], 20, Color(.8, .8, .9))
	if boss != null and (boss_on and state == S.PLAY or state == S.BOSSDEAD):
		var b: Dictionary = boss
		var bw := 420.0
		draw_rect(Rect2(W / 2 - bw / 2, 96, bw, 18), Color(.08, .06, .11, .7))
		draw_rect(Rect2(W / 2 - bw / 2 + 3, 99, (bw - 6) * maxf(0, b["hp"]) / b["max"], 12), Color("#e05a2a") if b["ph"] == 3 else (Color("#e0a12a") if b["ph"] == 2 else Color("#ff5a82")))
		text(Vector2(0, 136), "PROF. BOLT VON TRIGGER · PHASE %d" % b["ph"], 18, Color(1, 1, 1), true)
	if banner_t >= 0 and banner_t < 4:
		var a := banner_t / .3 if banner_t < .3 else ((4 - banner_t) / .6 if banner_t > 3.4 else 1.0)
		a = clampf(a, 0, 1)
		draw_rect(Rect2(W / 2 - 380, 150, 760, 150), Color(0.1, 0.09, 0.15, 0.94 * a))
		draw_rect(Rect2(W / 2 - 380, 150, 10, 150), Color(1, .35, .5, a))
		text(Vector2(0, 182), "LEVEL %d · %s" % [L["n"], String(L["year"]).to_upper()], 18, Color(1, .4, .55, a), true)
		text(Vector2(0, 222), L["title"], 32, Color(1, 1, 1, a), true)
		text(Vector2(0, 255), "\"%s\"" % L["sub"], 19, Color(.75, .75, .85, a), true)
		text(Vector2(0, 285), L["hint"], 18, Color(1, 1, 1, a), true)
	elif toast_d != null:
		var a2 := clampf(minf(toast_d["t"] * 3, 1.0), 0, 1)
		draw_rect(Rect2(W / 2 - 300, 150, 600, 70), Color(0.1, 0.09, 0.15, 0.94 * a2))
		draw_rect(Rect2(W / 2 - 300, 150, 600, 70), Color(1, .35, .5, a2), false, 2.0)
		text(Vector2(0, 180), toast_d["a"], 22, Color(1, .4, .55, a2), true)
		text(Vector2(0, 208), toast_d["b"], 18, Color(1, 1, 1, a2), true)
	if state == S.CLEAR and not tally.is_empty():
		var a3 := clampf((3.2 - ct) * 3, 0, 1)
		draw_rect(Rect2(W / 2 - 300, 300, 600, 150), Color(0.1, 0.09, 0.15, 0.94 * a3))
		text(Vector2(0, 340), "ERA COMPLETE", 22, Color(1, .4, .55, a3), true)
		text(Vector2(0, 378), ["", "Training: complete.", "Directions: not asked.", "Aqueduct: still not done.", "Headwind: survived.", ""][lv], 28, Color(1, 1, 1, a3), true)
		text(Vector2(0, 410), "Time %s  ·  Time bonus +%d" % [fmt_t(tally["t"]), tally["tb"]], 19, Color(.8, .8, .9, a3), true)
		text(Vector2(0, 438), "Score %d" % score, 20, Color(1, 1, 1, a3), true)
	if state == S.OVER:
		card("YOU HAVE BEEN MADE OBSOLETE", [
			"%d pts%s   ·   Level %d of 5 (%s)" % [score, "   NEW BEST!" if new_best else "", lv, L["short"]],
			"Cause of defeat: %s" % (cause if cause != "" else "history"),
			"Ducats %d · Foes bonked %d · Geese %d · Time %s" % [coins, kills, geese, fmt_t(play_time)],
			verdict(),
		], "Tap or press SPACE to continue" if t > 1.5 else "")


func draw_title() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, .5))
	var lines := [
		"Eleven years of sword school, then someone invented the crossbow.",
		"Chase the inventor through five eras and settle this in his tower.",
		"Move: arrows / stick.  Jump: SPACE or up / JUMP.  Sword: X or J / SWORD.",
		"Swing at bolts and axes to parry them back. Stomp geese from above.",
		"Difficulty: < %s >   (left/right to change)" % DIFS[diff]["lab"],
	]
	var prompt := "Tap or press SPACE to start"
	if saved != null:
		var sl := int(saved["lv"])
		prompt = "Tap or press SPACE to continue %s" % ("at the boss" if saved.get("boss", false) and sl == 5 else "from level %d" % sl)
		lines.append("(Press N to start a new game instead)")
	card("THE LAST KNIGHT", lines, prompt)


func draw_ending() -> void:
	for i in 20:
		draw_rect(Rect2(0, i * 36, W, 37), Color("#2b2530").lerp(Color("#1b171f"), i / 19.0))
	var fy := 196.0 * K
	draw_rect(Rect2(0, fy, W, H - fy), Color("#3a2f2a"))
	text(Vector2(0, 80), "THE END", 64, Color(1, 1, 1), true)
	text(Vector2(0, 118), "(of the Middle Ages)", 22, Color(.8, .75, .85), true)
	cam_x = 0.0
	var save_p := p.duplicate()
	p["run"] = 0.0
	draw_knight(VW / 2 - 130, 196 + cam_y - 34 + 0.0, 1, false, false, 0, -1)
	p = save_p
	screen()
	draw_rect(Rect2(W / 2 - 130 * K - 50, fy - 34 * K, 100, 34 * K), Color("#5b4a3a"))
	text(Vector2(W / 2 - 130 * K - 70, fy - 8), "THE LAST KNIGHT", 13, Color(1, 1, 1))
	draw_rect(Rect2(W / 2 + 130 * K - 50, fy - 34 * K, 100, 34 * K), Color("#5b4a3a"))
	text(Vector2(W / 2 + 130 * K - 60, fy - 8), "CROSSBOW, 1147", 13, Color(1, 1, 1))
	text(Vector2(0, 470), "You defeated the crossbow. Three weeks later, someone invented gunpowder.", 22, Color(1, 1, 1), true)
	text(Vector2(0, 505), "You now work at the museum. As an exhibit.", 22, Color(1, 1, 1), true)
	var v := "Legendary. Bards will get every detail wrong." if score >= 16000 else ("Knight of the Round Table (flat-pack edition)." if score >= 12000 else ("Respectable chivalry. Your horse is mildly impressed." if score >= 8000 else "Victorious, technically. History is written by the winners, in pencil."))
	text(Vector2(0, 560), "%d pts%s   ·   Time %s · Ducats %d · Foes %d · Geese %d · Parries %d" % [score, "  NEW BEST!" if new_best else "", fmt_t(play_time), coins, kills, geese, parries], 20, Color(1, .85, .45), true)
	text(Vector2(0, 595), v, 20, Color(.85, .85, .95), true)
	if t > 1.5 and int(t * 2) % 2 == 0:
		text(Vector2(0, 650), "Tap or press SPACE to continue", 26, Color(.6, 1, .6), true)


func card(title: String, lines: Array, prompt: String) -> void:
	draw_rect(Rect2(W / 2 - 580, 110, 1160, 500), Color(0.08, 0.07, 0.12, 0.95))
	text(Vector2(0, 190), title, 52, Color(1, .4, .55), true)
	var y := 255.0
	for l in lines:
		text(Vector2(0, y), l, 22, Color(1, 1, 1), true)
		y += 40.0
	if prompt != "" and int(t * 2.0) % 2 == 0:
		text(Vector2(0, 575), prompt, 28, Color(0.6, 1, 0.6), true)
