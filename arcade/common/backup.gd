class_name Backup
extends RefCounted
# One file with all your progress: settings, ratings and collections, high scores,
# saved games and achievements (everything in user:// except downloaded games).
# It is JSON: {"app": "Lab Arcade", "version", "made", "files": {path: base64}}.
#
# Restoring only writes plain data files back (no scripts or Godot resources, which
# could run code), only inside user://, and never touches the downloads.

const APP := "Lab Arcade"
# Open RPG's story saves (dialogic) are read back with objects allowed, so a doctored
# backup could run code through them: they stay out.
const SKIP_DIRS := ["packs", "logs", "shader_cache", "vulkan", "objectdb_snapshots", "test_report", "dialogic"]
const DATA_EXT := ["cfg", "json", "dat"]
const MAX_FILE := 2 * 1024 * 1024


static func _files(dir: String, rel: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var p := rel + f
		if allowed(p) and FileAccess.get_size(dir.path_join(f)) <= MAX_FILE:
			out.append(p)
	for sub in d.get_directories():
		if rel == "" and SKIP_DIRS.has(sub):
			continue
		_files(dir.path_join(sub), rel + sub + "/", out)


## A path that may go in (and come out of) a backup.
static func allowed(rel: String) -> bool:
	if rel == "" or rel.begins_with("/") or rel.contains("..") or rel.contains("\\") or rel.contains(":"):
		return false
	if rel.contains("/") and SKIP_DIRS.has(rel.get_slice("/", 0)):
		return false
	var name := rel.get_file()
	if name.begins_with(".") or not DATA_EXT.has(name.get_extension().to_lower()):
		return false
	var re := RegEx.create_from_string("^[A-Za-z0-9_\\-./ ]+$")
	return re.search(rel) != null


static func make() -> String:
	var paths := []
	_files("user://", "", paths)
	paths.sort()
	var files := {}
	for p in paths:
		files[p] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes("user://" + p))
	return JSON.stringify({"app": APP, "version": GameData.app_version(), "made": Time.get_datetime_string_from_system(), "files": files}, " ")


## Checks a backup; returns "" when good, else what is wrong.
static func check(text: String) -> String:
	var d = JSON.parse_string(text)
	if not d is Dictionary or d.get("app", "") != APP or not d.get("files") is Dictionary:
		return "This is not a Lab Arcade backup."
	for p in d["files"]:
		if not p is String or not allowed(p) or not d["files"][p] is String:
			return "The backup has a file it may not restore: %s" % str(p).left(60)
		var raw := Marshalls.base64_to_raw(d["files"][p])
		if raw.size() > MAX_FILE:
			return "The backup has a file that is too big: %s" % p
		if p.get_extension().to_lower() == "cfg":
			# settings files are plain values only; objects or resources could run code
			var s := raw.get_string_from_utf8()
			for bad in ["Object(", "Resource(", "SubResource(", "ExtResource(", "Callable(", "Signal("]:
				if s.contains(bad):
					return "The backup has a settings file with things that aren't plain data."
	return ""


## Writes a backup back. Returns "" when done, else why not.
static func restore(text: String) -> String:
	var problem := check(text)
	if problem != "":
		return problem
	var files: Dictionary = (JSON.parse_string(text) as Dictionary)["files"]
	for p in files:
		var path: String = "user://" + str(p)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return "Could not write %s." % p
		f.store_buffer(Marshalls.base64_to_raw(files[p]))
		f.close()
	return ""


static func summary(text: String) -> String:
	var d = JSON.parse_string(text)
	if not d is Dictionary:
		return ""
	return "%d files from Lab Arcade %s, made %s" % [(d.get("files", {}) as Dictionary).size(), d.get("version", "?"), str(d.get("made", "?")).replace("T", " ")]


static func file_name() -> String:
	return "lab-arcade-backup-%s.json" % Time.get_date_string_from_system()
