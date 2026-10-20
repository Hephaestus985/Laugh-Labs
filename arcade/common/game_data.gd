class_name GameData
extends RefCounted
# What the launcher and each game's start screen know about a game: plays, best
# score, the list of high scores, its saved game and its settings (difficulty, sound).
# Everything lives in user:// so it survives app updates.

const SETTINGS := "user://settings.cfg"
const HUB := "res://common/game_hub.tscn"
const LAUNCHER := "res://menu.tscn"


static func cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	return c


static func get_setting(section: String, key: String, default):
	return cfg().get_value(section, key, default)


static func set_setting(section: String, key: String, value) -> void:
	var c := cfg()
	c.set_value(section, key, value)
	c.save(SETTINGS)


static func plays(id: String) -> int:
	return int(get_setting("stats", "plays_" + id, 0))


static func last_played(id: String) -> int:
	return int(get_setting("stats", "last_" + id, 0))


static func record_play(id: String) -> void:
	var c := cfg()
	c.set_value("stats", "plays_" + id, int(c.get_value("stats", "plays_" + id, 0)) + 1)
	c.set_value("stats", "last_" + id, int(Time.get_unix_time_from_system()))
	c.save(SETTINGS)


static func best_path(g: Dictionary) -> String:
	return g.get("best_file", "user://best_%s.dat" % g["id"])


static func read_best(g: Dictionary) -> int:
	var best := 0
	var path := best_path(g)
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			best = f.get_32()
	var list := scores(g["id"])
	if not list.is_empty():
		best = maxi(best, int(list[0]["score"]))
	return best


## "level 3" / "at the boss" / "score 512" for a game with a saved game, "" otherwise.
static func save_info(g: Dictionary) -> String:
	if not g.has("save_file") or not FileAccess.file_exists(g["save_file"]):
		return ""
	var o = JSON.parse_string(FileAccess.get_file_as_string(g["save_file"]))
	if typeof(o) != TYPE_DICTIONARY:
		return "saved"
	if o.has("info"):
		return str(o["info"])
	if o.get("boss", false):
		return "at the boss"
	return "level %d" % int(o.get("lv", 1))


static func delete_save(g: Dictionary) -> void:
	if g.has("save_file") and FileAccess.file_exists(g["save_file"]):
		DirAccess.remove_absolute(g["save_file"])


# ---------------------------------------------------------------- high scores

static func scores_path(id: String) -> String:
	return "user://scores_%s.json" % id


## The 10 best finished runs: [{score, date, difficulty}], best first.
static func scores(id: String) -> Array:
	if not FileAccess.file_exists(scores_path(id)):
		return []
	var a = JSON.parse_string(FileAccess.get_file_as_string(scores_path(id)))
	return a if typeof(a) == TYPE_ARRAY else []


static func add_score(id: String, score: int, difficulty: int) -> void:
	if score <= 0:
		return
	var a := scores(id)
	a.append({"score": score, "date": Time.get_date_string_from_system(), "difficulty": difficulty})
	a.sort_custom(func(x, y): return int(x["score"]) > int(y["score"]))
	a = a.slice(0, 10)
	var f := FileAccess.open(scores_path(id), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(a))


static func clear_scores(g: Dictionary) -> void:
	for p in [scores_path(g["id"]), best_path(g)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# ---------------------------------------------------------------- settings per game

static func sound_on(id: String) -> bool:
	return bool(get_setting("sound", id, true))


static func set_sound(id: String, on: bool) -> void:
	set_setting("sound", id, on)


static func apply_sound(id: String) -> void:
	AudioServer.set_bus_mute(0, not sound_on(id))


# ---------------------------------------------------------------- leaving a game

## Where "< MENU" in a game goes: its own start screen (if it was opened from one),
## otherwise the launcher.
static func back_scene() -> String:
	return HUB if Engine.has_meta("hub_game") else LAUNCHER
