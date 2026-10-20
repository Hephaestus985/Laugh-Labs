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


# ---------------------------------------------------------------- playtime and progress

## Seconds played in a game (counted from Play on its start screen until you come back).
static func playtime(id: String) -> int:
	return int(get_setting("time", id, 0))


static func add_playtime(id: String, seconds: int) -> void:
	if seconds <= 0:
		return
	# a phone left on a game for hours isn't play: count at most 3 hours per session
	set_setting("time", id, playtime(id) + mini(seconds, 3 * 3600))


static func total_playtime(ids: Array) -> int:
	var s := 0
	for id in ids:
		s += playtime(id)
	return s


static func time_text(seconds: int) -> String:
	if seconds < 60:
		return "%d s" % seconds
	var m := seconds / 60
	if m < 60:
		return "%d min" % m
	return "%d h %02d min" % [m / 60, m % 60]


## A round won or a game finished (Puzzle wins, the Knight's ending...).
static func add_win(id: String) -> void:
	set_setting("wins", id, wins(id) + 1)


static func wins(id: String) -> int:
	return int(get_setting("wins", id, 0))


# ---------------------------------------------------------------- what the player has seen

## The newest version of each game the player has seen in the launcher. A game the
## player never saw is NEW; a game with a newer version than they saw is UPDATED.
static func badge(g: Dictionary) -> String:
	var seen: Dictionary = get_setting("seen", "versions", {})
	if seen.is_empty():
		return ""  # first run: everything is new, so nothing is
	var vs: Array = g["versions"]
	var newest: int = vs[vs.size() - 1]["v"]
	if not seen.has(g["id"]):
		return "NEW"
	return "UPDATED" if int(seen[g["id"]]) < newest else ""


static func mark_seen(g: Dictionary) -> void:
	var seen: Dictionary = get_setting("seen", "versions", {})
	var vs: Array = g["versions"]
	seen[g["id"]] = vs[vs.size() - 1]["v"]
	set_setting("seen", "versions", seen)


static func mark_all_seen(games: Array) -> void:
	var seen: Dictionary = get_setting("seen", "versions", {})
	for g in games:
		if not seen.has(g["id"]):
			var vs: Array = g["versions"]
			seen[g["id"]] = vs[vs.size() - 1]["v"]
	set_setting("seen", "versions", seen)


## Compare app versions like "1.9" and "1.22" by their numbers: -1, 0 or 1.
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


static func app_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))
