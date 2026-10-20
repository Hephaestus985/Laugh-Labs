class_name Packs
extends RefCounted
# Game downloads. The APK holds the launcher; every game version is a pack (.pck)
# that the launcher downloads from the public Laugh-Labs repo on first play.
#
# Safety: res://packs.json, built into the app, lists each pack's SHA-256. A pack
# is only installed and loaded when its bytes match that fingerprint, so the app
# never runs anything that wasn't built and reviewed for this version.
#
# Updates: an app update only asks to download a game again when that game's pack
# changed. Unchanged packs are rebuilt byte for byte the same (tools/packs.py
# skips them), so their fingerprint matches and the copy on the phone is kept.

const URL := "https://raw.githubusercontent.com/Hephaestus985/Laugh-Labs/downloads/packs/"
const DIR := "user://packs"
const STATE := "user://packs/state.json"

static var manifest := {}  # key ("<id>/v<N>") -> {file, sha256, size, scene}
static var mounted := {}  # packs loaded this session
static var builtin := {}  # games that are inside this build (PC, tests): no download needed
static var _ready := false


static func setup() -> void:
	if _ready:
		return
	_ready = true
	if FileAccess.file_exists("res://packs.json"):
		var m = JSON.parse_string(FileAccess.get_file_as_string("res://packs.json"))
		if typeof(m) == TYPE_DICTIONARY:
			manifest = m
	for key in manifest:
		if ResourceLoader.exists(manifest[key]["scene"]):
			builtin[key] = true
	DirAccess.make_dir_recursive_absolute(DIR)
	mount_all()


static func key_for(g: Dictionary, scene: String) -> String:
	var vs: Array = g["versions"]
	for v in vs:
		if v["scene"] == scene:
			return "%s/v%d" % [g["id"], v["v"]]
	return "%s/v%d" % [g["id"], vs[vs.size() - 1]["v"]]


static func path_for(key: String) -> String:
	return DIR.path_join(key.replace("/", "_") + ".pck")


static func state() -> Dictionary:
	if not FileAccess.file_exists(STATE):
		return {}
	var s = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	return s if typeof(s) == TYPE_DICTIONARY else {}


static func _save_state(s: Dictionary) -> void:
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))


## "ready" (play now), "download" (not on the phone yet) or "update" (an older copy is).
static func status(key: String) -> String:
	setup()
	if builtin.has(key) or mounted.has(key) or not manifest.has(key):
		return "ready"
	var have: String = state().get(key, "")
	if have == "":
		return "download"
	return "ready" if have == manifest[key]["sha256"] else "update"


static func size_of(key: String) -> int:
	return int(manifest.get(key, {}).get("size", 0))


static func size_text(bytes: int) -> String:
	if bytes < 1_000_000:
		return "%d KB" % maxi(1, bytes / 1000)
	return "%.1f MB" % (bytes / 1e6)


## Load every downloaded pack that matches this app's fingerprints.
static func mount_all() -> void:
	var s := state()
	for key in s:
		if manifest.has(key) and s[key] == manifest[key]["sha256"] and FileAccess.file_exists(path_for(key)):
			_mount(key)


static func _mount(key: String) -> bool:
	if mounted.has(key):
		return true
	# replace_files = false: a pack never overrides the launcher's own files
	if ProjectSettings.load_resource_pack(path_for(key), false):
		mounted[key] = true
		# teach the app the pack's resource IDs (scenes refer to files by uid://)
		var uids: Dictionary = manifest[key].get("uids", {})
		for u in uids:
			var id := ResourceUID.text_to_id(u)
			if id != ResourceUID.INVALID_ID and not ResourceUID.has_id(id):
				ResourceUID.add_id(id, uids[u])
		return true
	return false


## Check a downloaded file against the fingerprint, then keep and load it.
static func install_file(key: String, file: String) -> String:
	setup()
	if not manifest.has(key):
		return "unknown game"
	if FileAccess.get_sha256(file) != manifest[key]["sha256"]:
		DirAccess.remove_absolute(file)
		return "the download was damaged or not the expected file"
	var dest := path_for(key)
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if file != dest:
		var err := DirAccess.rename_absolute(file, dest)
		if err != OK:
			err = DirAccess.copy_absolute(file, dest)
			DirAccess.remove_absolute(file)
		if err != OK:
			return "could not save the game (storage full?)"
	var s := state()
	s[key] = manifest[key]["sha256"]
	_save_state(s)
	if not _mount(key):
		return "could not open the game"
	return ""


## Remove a download. It stays playable until the app restarts.
static func remove(key: String) -> void:
	if FileAccess.file_exists(path_for(key)):
		DirAccess.remove_absolute(path_for(key))
	var s := state()
	s.erase(key)
	_save_state(s)


## Bytes of downloads on the phone.
static func used_bytes() -> int:
	var total := 0
	for key in state():
		var f := FileAccess.open(path_for(key), FileAccess.READ)
		if f:
			total += f.get_length()
	return total
